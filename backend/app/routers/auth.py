from datetime import datetime, timedelta, timezone
from bson import ObjectId
import os
import uuid

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pymongo.errors import DuplicateKeyError

from core.config import get_settings
from db.mongo import get_db
from routers.custom_tags import ensure_default_custom_tags
from routers.worry_groups import ensure_default_worry_group
from routers.treatment_progress import ensure_week1_progress
from schemas.auth import (
    TokenPair,
    SignupRequest,
    LoginRequest,
    RefreshRequest,
    PasswordResetStartRequest,
    PasswordResetFinishRequest,
    EmailVerifyRequest,
    PasswordChangeRequest,
)
from core.security import (
    sub_to_obj,
    get_user_obj_id,
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    create_email_verification_token,
    create_password_reset_token,
    decode_token,
    hash_token,
    hash_refresh_token,
    verify_refresh_token,
)

settings = get_settings()
router = APIRouter(prefix="/auth")

# =========================================================
# phone 정규화 정책
# - MongoDB users.phone: digits(예: 01038472918) 로 저장
# =========================================================
def phone_to_digits(phone: str) -> str:
    raw = (phone or "").strip()
    return "".join(ch for ch in raw if ch.isdigit())


def _norm_pid(v) -> str | None:
    if v is None:
        return None
    s = str(v).strip()
    return s or None


# 로컬 네이티브 실행 시 127.0.0.1 권장. Docker 안에서 호스트로 붙을 때는 PLATFORM_SIGNUP_URL=http://host.docker.internal:8061/auth/signup
PLATFORM_SIGNUP_URL = (
    os.getenv("PLATFORM_SIGNUP_URL")
    or os.getenv("PLATFORM_VERIFY_URL")
    or "http://127.0.0.1:8061/auth/signup"
)


# 인증정보 변경 주기 정책_IA-04
DEFAULT_PASSWORD_POLICY_DAYS = 90 

# 로그인 실패 제한 정책_IA-07
MAX_LOGIN_FAILED_ATTEMPTS = 5
LOGIN_LOCK_MINUTES = 15


def as_utc_datetime(value):
    """
    MongoDB에서 가져온 datetime이 timezone 정보 없이 들어오는 경우를 대비해 UTC로 보정.
    """
    if value is None:
        return None

    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)

    return None


def is_password_expired(user: dict, now: datetime) -> bool:
    """
    password_changed_at 기준으로 password_policy_days가 지났는지 확인.
    """
    password_changed_at = as_utc_datetime(user.get("password_changed_at"))
    password_policy_days = int(user.get("password_policy_days", DEFAULT_PASSWORD_POLICY_DAYS))

    if password_changed_at is None:
        return False

    return now >= password_changed_at + timedelta(days=password_policy_days)

def get_login_locked_until(user: dict) -> datetime | None:
    """
    로그인 잠금 만료 시각을 UTC datetime으로 반환.
    """
    return as_utc_datetime(user.get("login_locked_until"))


def is_login_locked(user: dict, now: datetime) -> bool:
    """
    현재 시각 기준 로그인 잠금 상태인지 확인.
    """
    locked_until = get_login_locked_until(user)
    if locked_until is None:
        return False
    return now < locked_until


def get_remaining_lock_minutes(user: dict, now: datetime) -> int:
    """
    로그인 잠금 해제까지 남은 시간을 분 단위로 반환.
    """
    locked_until = get_login_locked_until(user)
    if locked_until is None:
        return 0

    remaining_seconds = max(0, int((locked_until - now).total_seconds()))
    return max(1, (remaining_seconds + 59) // 60)


async def record_failed_login(db, user: dict, now: datetime):
    """
    로그인 실패 횟수를 증가시키고, 기준 횟수 초과 시 계정을 일시 잠금.
    """
    current_count = int(user.get("failed_login_count", 0))
    next_count = current_count + 1

    update_doc = {
        "failed_login_count": next_count,
        "last_failed_login_at": now,
        "updated_at": now,
    }

    if next_count >= MAX_LOGIN_FAILED_ATTEMPTS:
        update_doc["login_locked_until"] = now + timedelta(
            minutes=LOGIN_LOCK_MINUTES
        )

    await db["users"].update_one(
        {"_id": user["_id"]},
        {"$set": update_doc},
    )

    return next_count, update_doc.get("login_locked_until")


async def clear_failed_login_state(db, user: dict, now: datetime):
    """
    로그인 성공 시 실패 횟수 및 잠금 상태 초기화.
    """
    await db["users"].update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "failed_login_count": 0,
                "last_active_at": now,
                "updated_at": now,
            },
            "$unset": {
                "login_locked_until": "",
                "last_failed_login_at": "",
            },
        },
    )

async def signup_with_platform(payload: SignupRequest) -> str:
    """
    플랫폼 /auth/signup에 회원가입을 위임하고 patient_id를 반환한다.
    플랫폼은 검증 전용 API가 아닌, 실제 가입(write)까지 수행한다.
    """
    platform_payload = {
        "email": payload.email,
        "password": payload.password,
        "name": payload.name,
        "patient_code": (payload.patient_code or "").strip(),
        "gender": payload.gender,
        "address": payload.address,
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            res = await client.post(PLATFORM_SIGNUP_URL, json=platform_payload)
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=502,
            detail=(
                "Platform signup service unavailable: "
                f"cannot reach {PLATFORM_SIGNUP_URL} ({type(e).__name__}). "
                "Check that the platform server is running and PLATFORM_SIGNUP_URL is correct."
            ),
        )

    try:
        data = res.json()
    except Exception:
        data = {}

    if res.status_code != 200:
        detail = data.get("detail") or data.get("message") or "Platform signup failed"
        raise HTTPException(status_code=res.status_code, detail=detail)

    patient_id = data.get("patient_id") or data.get("user_id") or (payload.patient_code or "").strip()
    if not patient_id:
        raise HTTPException(status_code=500, detail="patient_id missing from platform signup response")

    return str(patient_id)


@router.post("/signup", response_model=TokenPair)
async def signup(payload: SignupRequest, db=Depends(get_db)):
    # 1) 입력 검증
    phone_digits = phone_to_digits(payload.phone)
    if not phone_digits:
        raise HTTPException(status_code=400, detail="phone은 필수입니다.")
    if len(phone_digits) < 9:
        raise HTTPException(status_code=400, detail="phone 형식이 올바르지 않습니다.")

    patient_code = (payload.patient_code or "").strip()
    if not patient_code:
        raise HTTPException(status_code=400, detail="patient_code는 필수입니다.")

    # 2) 동일 이메일 선검사 — patient_id가 이미 있으면만 차단(이메일만 있는 스텁은 플랫폼으로 이어서 채움)
    existing_by_email = await db["users"].find_one({"email": payload.email})
    if existing_by_email:
        pid = _norm_pid(existing_by_email.get("patient_id"))
        if pid is not None:
            raise HTTPException(
                status_code=409,
                detail="이미 등록된 이메일입니다. (동일 이메일이 Mongo에 이미 있음, 플랫폼 호출 전)",
            )

    # 3) 플랫폼 /auth/signup 위임 (플랫폼이 write 수행)
    patient_id = await signup_with_platform(payload)
    np = _norm_pid(patient_id)
    if np is not None:
        patient_id = np

    # 4) 로컬 users 동기화 (upsert) — 둘 다 patient_id가 있을 때만 불일치 시 409
    existing = await db["users"].find_one({"email": payload.email})
    if existing:
        ex_pid = _norm_pid(existing.get("patient_id"))
        new_pid = _norm_pid(patient_id)
        if (
            ex_pid is not None
            and new_pid is not None
            and ex_pid != new_pid
        ):
            raise HTTPException(
                status_code=409,
                detail=(
                    "가입을 마무리할 수 없습니다: 이 이메일은 Mongo에 다른 patient_id와 이미 연결되어 있습니다. "
                    "(플랫폼은 이미 처리됐을 수 있으니 Mongo users·플랫폼 MySQL을 맞춰 주세요.)"
                ),
            )

    existing_patient = await db["users"].find_one({"patient_id": patient_id})
    now = datetime.now(timezone.utc)
    user_id = (
        existing_patient.get("user_id")
        if existing_patient and existing_patient.get("user_id")
        else f"user_{uuid.uuid4().hex[:8]}"
    )

    update_doc = {
        "user_id": user_id,
        "patient_id": patient_id,
        "email": payload.email,
        "name": payload.name,
        "gender": payload.gender,
        "address": payload.address,
        "patient_code": patient_code,
        "phone": phone_digits,
        "password_hash": hash_password(payload.password),
        # 인증정보 관리 정책 확인용 필드_IA-04/ 일반 회원가입은 사용자가 직접 비밀번호를 설정하므로 최초 변경 강제는 False
        "must_change_password": False,
        "password_changed_at": now,
        "password_policy_days": DEFAULT_PASSWORD_POLICY_DAYS,
        "initial_password_issued_at": None,
        "updated_at": now,
        # 로그인 실패 제한 정책_IA-07
        "failed_login_count": 0,
        "last_failed_login_at": None,
        "login_locked_until": None,
    }

    if existing_patient:
        obj_id = existing_patient["_id"]
        await db["users"].update_one({"_id": obj_id}, {"$set": update_doc})
    elif existing:
        obj_id = existing["_id"]
        await db["users"].update_one({"_id": obj_id}, {"$set": update_doc})
    else:
        obj_id = ObjectId()
        doc = {
            "_id": obj_id,
            **update_doc,
            "survey_completed": False,
            "surveys": [],
            "email_verified": False,
            "created_at": now,
        }
        try:
            await db["users"].insert_one(doc)
        except DuplicateKeyError:
            raise HTTPException(
                status_code=409,
                detail=(
                    "가입을 마무리할 수 없습니다: Mongo users에 동일 이메일이 이미 있습니다(유니크 인덱스). "
                    "로그인을 시도하거나, 올바른 DB·중복 문서를 확인해 주세요."
                ),
            )

    await ensure_week1_progress(db, user_id)
    await ensure_default_custom_tags(db, user_id)
    await ensure_default_worry_group(db, user_id)

    sub = str(obj_id)
    refresh_raw = create_refresh_token(sub)
    await db["users"].update_one(
        {"_id": obj_id},
        {"$set": {"refresh_hash": hash_refresh_token(refresh_raw), "refresh_issued_at": now}},
    )
    return TokenPair(
        access_token=create_access_token(sub),
        refresh_token=refresh_raw,
    )


@router.post("/login", response_model=TokenPair)
async def login(payload: LoginRequest, db=Depends(get_db)):
    now = datetime.now(timezone.utc)

    user = await db["users"].find_one({"email": payload.email})

    # 사용자가 없는 경우에는 계정 존재 여부를 숨기기 위해 동일한 메시지 반환
    if not user:
        raise HTTPException(
            status_code=401,
            detail="가입되지 않은 이메일입니다.",
        )
    
    # 이미 잠금 상태인 경우
    if is_login_locked(user, now):
        remaining_minutes = get_remaining_lock_minutes(user, now)
        raise HTTPException(
            status_code=423,
            detail=f"로그인 실패 횟수가 초과되어 계정이 일시 잠금되었습니다. {remaining_minutes}분 후 다시 시도해주세요.",
        )

    stored_hash = user.get("password_hash")

    # 비밀번호 미설정 또는 비밀번호 불일치
    if not stored_hash or not verify_password(payload.password, stored_hash):
        failed_count, locked_until = await record_failed_login(db, user, now)

        if locked_until is not None:
            raise HTTPException(
                status_code=423,
                detail=f"로그인 실패 횟수가 초과되어 {LOGIN_LOCK_MINUTES}분 동안 로그인이 제한됩니다.",
            )

        remaining_attempts = max(
            0,
            MAX_LOGIN_FAILED_ATTEMPTS - failed_count,
        )

        raise HTTPException(
            status_code=401,
            detail=f"비밀번호가 일치하지 않습니다. 남은 시도 횟수: {remaining_attempts}회",
        )

    sub = str(user["_id"])
    refresh_raw = create_refresh_token(sub)

    # 인증정보 관리 정책 확인용 필드_IA-04
    password_expired = is_password_expired(user, now)
    must_change_password = bool(user.get("must_change_password", False)) or password_expired

    await db["users"].update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "refresh_hash": hash_refresh_token(refresh_raw),
                "refresh_issued_at": now,
                "last_active_at": now,
                "failed_login_count": 0,
                "updated_at": now,
            },
            "$unset": {
                "login_locked_until": "",
                "last_failed_login_at": "",
            },
        },
    )

    return TokenPair(
        access_token=create_access_token(sub),
        refresh_token=refresh_raw,
        must_change_password=must_change_password,
        password_expired=password_expired,
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(payload: RefreshRequest, db=Depends(get_db)):
    decoded = decode_token(payload.refresh_token, refresh=True)
    if not decoded or decoded.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    sub = decoded["sub"]
    obj_id = sub_to_obj(sub)

    user = await db["users"].find_one({"_id": obj_id})
    if not user or "refresh_hash" not in user:
        raise HTTPException(status_code=401, detail="Invalid refresh state")
    if not verify_refresh_token(payload.refresh_token, user["refresh_hash"]):
        raise HTTPException(status_code=401, detail="Refresh token mismatch (rotated)")

    now = datetime.now(timezone.utc)
    new_refresh = create_refresh_token(sub)

    await db["users"].update_one(
        {"_id": obj_id},
        {
            "$set": {
                "refresh_hash": hash_refresh_token(new_refresh),
                "refresh_issued_at": now,
            }
        },
    )
    return TokenPair(
        access_token=create_access_token(sub),
        refresh_token=new_refresh,
    )


@router.post("/password/change")
async def change_password(
        payload: PasswordChangeRequest,
        db=Depends(get_db),
        user_obj_id: ObjectId = Depends(get_user_obj_id),
):
    user = await db["users"].find_one({"_id": user_obj_id})
    if not user or not verify_password(payload.current_password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    await db["users"].update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "password_hash": hash_password(payload.new_password),
                # 인증정보 관리 정책 확인용 필드_IA-04
                "must_change_password": False,
                "password_changed_at":  datetime.now(timezone.utc),
                "password_policy_days": int(user.get("password_policy_days", DEFAULT_PASSWORD_POLICY_DAYS)),
                "updated_at": datetime.now(timezone.utc),
            },
            "$unset": {"refresh_hash": "", "refresh_issued_at": ""},
        },
    )
    return {"success": True}


@router.post("/password/reset/start")
async def password_reset_start(payload: PasswordResetStartRequest, db=Depends(get_db)):
    user = await db["users"].find_one({"email": payload.email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    token = create_password_reset_token(str(user["_id"]))
    token_hash = hash_token(token)
    now = datetime.now(timezone.utc)

    await db["users"].update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "password_reset_hash": token_hash,
                "password_reset_requested_at": now,
            }
        },
    )
    return {
        "success": True,
        "message": "Password reset token issued",
        "token_debug": token,
    }


@router.post("/password/reset/finish")
async def password_reset_finish(payload: PasswordResetFinishRequest, db=Depends(get_db)):
    decoded = decode_token(payload.token)
    if not decoded or decoded.get("type") != "reset":
        raise HTTPException(status_code=400, detail="Invalid reset token")

    sub = decoded["sub"]
    obj_id = sub_to_obj(sub)

    user = await db["users"].find_one({"_id": obj_id})
    if not user:
        raise HTTPException(status_code=400, detail="Invalid reset token")

    stored_hash = user.get("password_reset_hash")
    incoming_hash = hash_token(payload.token)
    if not stored_hash or stored_hash != incoming_hash:
        raise HTTPException(
            status_code=400,
            detail="Reset token mismatch or already used",
        )

    requested_at = user.get("password_reset_requested_at")
    if not requested_at:
        raise HTTPException(status_code=400, detail="Reset token state invalid")

    now = datetime.now(timezone.utc)
    elapsed_sec = (now - requested_at).total_seconds()
    if elapsed_sec > settings.reset_token_expire_minutes * 60:
        raise HTTPException(status_code=400, detail="Reset token has expired")

    await db["users"].update_one(
        {"_id": obj_id},
        {
            "$set": {
                "password_hash": hash_password(payload.new_password),
                # 인증정보 관리 정책 확인용 필드_IA-04
                "must_change_password": False,
                "password_changed_at": now,
                "password_policy_days": int(user.get("password_policy_days", DEFAULT_PASSWORD_POLICY_DAYS)),
                "updated_at": now,
            },
            "$unset": {
                "password_reset_hash": "",
                "password_reset_requested_at": "",
                "refresh_hash": "",
                "refresh_issued_at": "",
            },
        },
    )

    return {"success": True}
