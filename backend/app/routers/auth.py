from datetime import datetime, timezone
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
        "updated_at": now,
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
    user = await db["users"].find_one({"email": payload.email})
    stored_hash = user.get("password_hash") if user else None
    if not user or not stored_hash or not verify_password(payload.password, stored_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    sub = str(user["_id"])
    now = datetime.now(timezone.utc)
    refresh_raw = create_refresh_token(sub)

    await db["users"].update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "refresh_hash": hash_refresh_token(refresh_raw),
                "refresh_issued_at": now,
                "last_active_at": now,
            }
        },
    )
    return TokenPair(
        access_token=create_access_token(sub),
        refresh_token=refresh_raw,
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
