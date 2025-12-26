# backend/app/routers/auth.py

from datetime import datetime, timezone
from bson import ObjectId
import uuid
import os

from fastapi import APIRouter, Depends, HTTPException
from pymongo.errors import DuplicateKeyError
import httpx

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
# - 플랫폼 claim 호출 시: 플랫폼 DB contact_information 이 하이픈 포함일 수 있으므로
#   010-3847-2918 형태로 포맷해서 전송
# =========================================================
def phone_to_digits(phone: str) -> str:
    raw = (phone or "").strip()
    return "".join(ch for ch in raw if ch.isdigit())


def digits_to_platform_format(digits: str) -> str:
    d = phone_to_digits(digits)
    # 010XXXXXXXX(11자리) -> 010-XXXX-XXXX
    if len(d) == 11 and d.startswith("010"):
        return f"{d[0:3]}-{d[3:7]}-{d[7:11]}"
    # 그 외: 일단 digits 그대로 (플랫폼 DB 저장 포맷이 다르면 여기서 정책 변경)
    return d


# =========================================================
# 플랫폼 Claim API 호출
# - 성공: patient_id 반환
# - 실패: 플랫폼 detail을 가능한 그대로 전달
# =========================================================
async def claim_patient_id_from_platform(mindrium_code: str, phone_digits: str) -> str:
    base_url = os.getenv("PLATFORM_BASE_URL", "http://localhost:8061").rstrip("/")
    url = f"{base_url}/api/onboarding/claim"

    code = (mindrium_code or "").strip()
    if not code:
        raise HTTPException(status_code=400, detail="mindrium_code(=code)가 비어있습니다.")
    if not code.isdigit() or len(code) != 6:
        raise HTTPException(status_code=400, detail="mindrium_code는 숫자 6자리여야 합니다.")

    phone_for_platform = digits_to_platform_format(phone_digits)
    if not phone_for_platform:
        raise HTTPException(status_code=400, detail="phone이 비어있습니다.")

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(
                url,
                json={"mindrium_code": code, "phone": phone_for_platform},
                headers={"Content-Type": "application/json"},
            )
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"플랫폼 Claim API 연결 실패: {e}")

    # 정상
    if resp.status_code == 200:
        data = resp.json()
        patient_id = data.get("patient_id")
        if not patient_id:
            raise HTTPException(status_code=502, detail="플랫폼 Claim API 응답에 patient_id가 없습니다.")
        return patient_id

    # 에러 detail 최대한 전달
    try:
        detail = resp.json().get("detail")
    except Exception:
        detail = resp.text

    # 플랫폼에서 이미 사용된 코드면 409 등을 줄 수도 있으니 그대로 매핑
    if resp.status_code in (400, 404, 409):
        raise HTTPException(status_code=resp.status_code, detail=detail or "플랫폼 Claim 실패")

    raise HTTPException(status_code=502, detail=f"플랫폼 Claim API 오류({resp.status_code}): {detail}")


@router.post("/signup", response_model=TokenPair)
async def signup(payload: SignupRequest, db=Depends(get_db)):
    """
    ✅ 추천 최종 흐름 (코드 소진 사고 방지)
    1) Mongo에서 이메일 중복 체크
    2) 입력값 검증
    3) Mongo에 유저를 먼저 생성 (patient_id는 None)
    4) 플랫폼 Claim 호출 → patient_id 확보
    5) Mongo 유저에 patient_id 업데이트
    6) 중간 실패 시: 방금 만든 유저 롤백(삭제)
    """

    # -------------------------
    # 1) 이메일 중복 체크 (claim 전에!)
    # -------------------------
    existing = await db["users"].find_one({"email": payload.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    # -------------------------
    # 2) 입력 검증
    # -------------------------
    phone_digits = phone_to_digits(payload.phone)
    if not phone_digits:
        raise HTTPException(status_code=400, detail="phone은 필수입니다.")
    # 원하면 10~11자리 제한 등 추가 가능
    if len(phone_digits) < 9:
        raise HTTPException(status_code=400, detail="phone 형식이 올바르지 않습니다.")

    code = (payload.code or "").strip()
    if not code.isdigit() or len(code) != 6:
        raise HTTPException(status_code=400, detail="mindrium_code(code)는 숫자 6자리여야 합니다.")

    # -------------------------
    # 3) Mongo 유저 먼저 생성 (patient_id=None)
    # -------------------------
    obj_id = ObjectId()
    user_id = f"user_{uuid.uuid4().hex[:8]}"
    now = datetime.now(timezone.utc)

    doc = {
        "_id": obj_id,
        "user_id": user_id,
        "email": payload.email,
        "name": payload.name,
        "gender": payload.gender,

        # code는 이제 "마인드리움 코드(플랫폼 mindrium_code)" 의미로 고정
        "code": code,

        # Mongo에 저장되는 phone은 digits로 통일
        "phone": phone_digits,

        "password_hash": hash_password(payload.password),

        # ✅ 플랫폼 patient_id는 claim 성공 후 채움
        "patient_id": None,

        "survey_completed": False,
        "surveys": [],
        "email_verified": False,
        "created_at": now,
    }

    try:
        await db["users"].insert_one(doc)
    except DuplicateKeyError:
        # 동시 가입 등으로 유니크 인덱스에 걸릴 수 있음
        raise HTTPException(status_code=400, detail="Email already registered")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"회원가입 저장 실패: {e}")

    # 이후 단계 실패 시 롤백 대상
    created_obj_id = obj_id

    try:
        # -------------------------
        # 4) 플랫폼 claim 호출 (여기서 코드 소진이 일어남)
        # -------------------------
        patient_id = await claim_patient_id_from_platform(code, phone_digits)

        # -------------------------
        # 5) patient_id 업데이트
        # -------------------------
        await db["users"].update_one(
            {"_id": created_obj_id},
            {"$set": {"patient_id": patient_id}},
        )

        # -------------------------
        # 6) 기본 시딩 (기존 유지)
        # -------------------------
        await ensure_default_custom_tags(db, user_id)
        await ensure_default_worry_group(db, user_id)

        # Refresh token 저장 (기존 유지)
        sub = str(created_obj_id)
        refresh_raw = create_refresh_token(sub)
        await db["users"].update_one(
            {"_id": created_obj_id},
            {"$set": {"refresh_hash": hash_refresh_token(refresh_raw), "refresh_issued_at": now}},
        )

        return TokenPair(
            access_token=create_access_token(sub),
            refresh_token=refresh_raw,
        )

    except HTTPException as he:
        # ❗claim 실패/검증 실패 등: 방금 만든 유저 롤백(삭제)
        await db["users"].delete_one({"_id": created_obj_id})
        raise he

    except Exception as e:
        # 예외: 유저 롤백
        await db["users"].delete_one({"_id": created_obj_id})
        raise HTTPException(status_code=500, detail=f"회원가입 처리 중 오류: {e}")


@router.post("/login", response_model=TokenPair)
async def login(payload: LoginRequest, db=Depends(get_db)):
    user = await db["users"].find_one({"email": payload.email})
    if not user or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    sub = str(user["_id"])
    now = datetime.now(timezone.utc)
    refresh_raw = create_refresh_token(sub)

    await db["users"].update_one(
        {"_id": user["_id"]},
        {"$set": {"refresh_hash": hash_refresh_token(refresh_raw), "refresh_issued_at": now}},
    )
    return TokenPair(access_token=create_access_token(sub), refresh_token=refresh_raw)


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
        {"$set": {"refresh_hash": hash_refresh_token(new_refresh), "refresh_issued_at": now}},
    )
    return TokenPair(access_token=create_access_token(sub), refresh_token=new_refresh)


@router.post("/password/change")
async def change_password(payload: PasswordChangeRequest, db=Depends(get_db), user_obj_id: ObjectId = Depends(get_user_obj_id)):
    user = await db["users"].find_one({"_id": user_obj_id})
    if not user or not verify_password(payload.current_password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    await db["users"].update_one(
        {"_id": user["_id"]},
        {
            "$set": {"password_hash": hash_password(payload.new_password)},
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
        {"$set": {"password_reset_hash": token_hash, "password_reset_requested_at": now}},
    )
    return {"success": True, "message": "Password reset token issued", "token_debug": token}


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
        raise HTTPException(status_code=400, detail="Reset token mismatch or already used")

    requested_at = user.get("password_reset_requested_at")
    if not requested_at:
        raise HTTPException(status_code=400, detail="Reset token state invalid")

    now = datetime.now(timezone.utc)
    elapsed_sec = (now - requested_at).total_seconds()
    if elapsed_sec > settings.reset_token_expire_minutes * 60:
        raise HTTPException(status_code=400, detail="Reset token has expired")

    await db["users"].update_one(
        {"_id": obj_id},
        {"$set": {"password_hash": hash_password(payload.new_password)}, "$unset": {"password_reset_hash": "", "password_reset_requested_at": ""}},
    )
    return {"success": True, "message": "Password updated"}


@router.post("/verify/email")
async def verify_email(payload: EmailVerifyRequest, db=Depends(get_db)):
    decoded = decode_token(payload.token)
    if not decoded or decoded.get("type") != "verify":
        raise HTTPException(status_code=400, detail="Invalid verification token")

    sub = decoded["sub"]
    obj_id = sub_to_obj(sub)

    user = await db["users"].find_one({"_id": obj_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    await db["users"].update_one({"_id": obj_id}, {"$set": {"email_verified": True}})
    return {"success": True, "message": "Email verified"}
