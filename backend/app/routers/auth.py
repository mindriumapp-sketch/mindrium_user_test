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

PLATFORM_VERIFY_URL = os.getenv(
    "PLATFORM_VERIFY_URL",
    "http://host.docker.internal:8061/api/integrations/mindrium/verify-signup",
)


async def verify_patient_code_with_platform(patient_code: str, email: str) -> str:
    """
    플랫폼에 patient_code + email 검증 요청 후 patient_id를 반환.
    플랫폼 응답 예시:
    {
      "valid": true,
      "patient_id": "P000123"
    }

    실패 예시:
    {
      "valid": false,
      "reason": "INVALID_CODE"
    }
    """
    payload = {
        "service": "mindrium",
        "patient_code": patient_code,
        "email": email,
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            res = await client.post(PLATFORM_VERIFY_URL, json=payload)
    except httpx.RequestError:
        raise HTTPException(
            status_code=502,
            detail="Platform verification service unavailable",
        )

    if res.status_code != 200:
        # 플랫폼이 4xx/5xx를 반환한 경우
        try:
            data = res.json()
            detail = data.get("detail") or data.get("reason") or "Platform verification failed"
        except Exception:
            detail = "Platform verification failed"
        raise HTTPException(status_code=400, detail=detail)

    try:
        data = res.json()
    except Exception:
        raise HTTPException(status_code=500, detail="Invalid platform verification response")

    if not data.get("valid"):
        reason = data.get("reason", "INVALID_CODE")
        raise HTTPException(status_code=400, detail=reason)

    patient_id = data.get("patient_id")
    if not patient_id:
        raise HTTPException(status_code=500, detail="patient_id missing from platform response")

    return patient_id


@router.post("/signup", response_model=TokenPair)
async def signup(payload: SignupRequest, db=Depends(get_db)):
    # 1) 이메일 중복 체크
    existing = await db["users"].find_one({"email": payload.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    # 2) 플랫폼에서 patient_code + email 검증 후 patient_id 확보
    patient_id = await verify_patient_code_with_platform(
        patient_code=payload.patient_code,
        email=payload.email,
    )

    # 3) 동일 patient_id 중복 가입 방지
    existing_patient = await db["users"].find_one({"patient_id": patient_id})
    if existing_patient:
        raise HTTPException(status_code=400, detail="Patient already linked")

    obj_id = ObjectId()
    user_id = f"user_{uuid.uuid4().hex[:8]}"  # 1차에서는 유지
    now = datetime.now(timezone.utc)

    doc = {
        "_id": obj_id,
        "user_id": user_id,
        "patient_id": patient_id,
        "email": payload.email,
        "name": payload.name,
        "gender": payload.gender,
        "address": payload.address,
        "patient_code": payload.patient_code,
        "password_hash": hash_password(payload.password),
        "survey_completed": False,
        "surveys": [],
        "email_verified": False,
        "created_at": now,
        "updated_at": now,
    }

    try:
        await db["users"].insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(status_code=400, detail="Email already registered")

    # 1차에서는 기존 user_id 기반 보조 데이터 생성 유지
    await ensure_default_custom_tags(db, user_id)
    await ensure_default_worry_group(db, user_id)

    sub = str(obj_id)
    refresh_raw = create_refresh_token(sub)

    await db["users"].update_one(
        {"_id": obj_id},
        {
            "$set": {
                "refresh_hash": hash_refresh_token(refresh_raw),
                "refresh_issued_at": now,
            }
        },
    )

    return TokenPair(
        access_token=create_access_token(sub),
        refresh_token=refresh_raw,
    )


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
