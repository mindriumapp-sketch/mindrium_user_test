from datetime import datetime, timezone
from bson import ObjectId
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pymongo.errors import DuplicateKeyError

from core.config import get_settings
from db.mongo import get_db
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
# NOTE: codes 컬렉션과 기본 그룹 생성을 signup에서 처리하여 Flutter 쪽 로직 단순화.
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=TokenPair)
async def signup(payload: SignupRequest, db=Depends(get_db)):
    # 사전 이메일 중복 체크 (친절한 에러 메시지)
    existing = await db["users"].find_one({"email": payload.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    obj_id = ObjectId()  # 내부 PK용 ObjectId
    user_id = f"user_{uuid.uuid4().hex[:8]}"  # 외부/public용 user_id (예전 그대로 유지)

    now = datetime.now(timezone.utc)

    doc = {
        "_id": obj_id,
        "user_id": user_id,
        "email": payload.email,
        "name": payload.name,
        "gender": payload.gender,
        "code": payload.code,
        "password_hash": hash_password(payload.password),
        "survey_completed": False,
        "surveys": [],
        "week_progress": [],
        "email_verified": False,
        "created_at": now,
    }

    # unique_email_index (main.py)와 레이스될 때를 대비해 DuplicateKeyError 방어
    try:
        await db["users"].insert_one(doc)
    except DuplicateKeyError:
        # 동시 가입 등으로 유니크 인덱스에 걸린 경우
        raise HTTPException(status_code=400, detail="Email already registered")

    # Refresh token 저장 (hash)
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

    sub = str(user["_id"])  # 토큰에 들어갈 user 식별자
    now = datetime.now(timezone.utc)
    refresh_raw = create_refresh_token(sub)

    await db["users"].update_one(
        {"_id": user["_id"]},
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

    # 회전: 새 refresh 발급 후 hash 교체
    now = datetime.now(timezone.utc)
    new_refresh = create_refresh_token(sub)  # 토큰 안에는 문자열 sub
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
            "$set": {"password_hash": hash_password(payload.new_password)},
            "$unset": {"refresh_hash": "", "refresh_issued_at": ""},
        },
    )
    return {"success": True}


@router.post("/password/reset/start")
async def password_reset_start(payload: PasswordResetStartRequest, db=Depends(get_db)):
    user = await db["users"].find_one({"email": payload.email})
    if not user:
        # TODO: 200 + “If this email exists, we sent a reset link” 로 갈지
        raise HTTPException(status_code=404, detail="User not found")

    token = create_password_reset_token(str(user["_id"]))  # raw token
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
    # TODO: send email via SMTP with link containing token (token_debug 삭제)
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

    # hash 비교 (one-time / rotation 방어)
    stored_hash = user.get("password_reset_hash")
    incoming_hash = hash_token(payload.token)
    if not stored_hash or stored_hash != incoming_hash:
        raise HTTPException(
            status_code=400,
            detail="Reset token mismatch or already used",
        )

    # DB timestamp 기반 만료 검사
    requested_at = user.get("password_reset_requested_at")
    if not requested_at:
        raise HTTPException(status_code=400, detail="Reset token state invalid")

    now = datetime.now(timezone.utc)
    elapsed_sec = (now - requested_at).total_seconds()
    if elapsed_sec > settings.reset_token_expire_minutes * 60:
        raise HTTPException(status_code=400, detail="Reset token has expired")

    # 여기까지 통과하면 비밀번호 변경 + 토큰 정보 제거
    await db["users"].update_one(
        {"_id": obj_id},
        {
            "$set": {"password_hash": hash_password(payload.new_password)},
            "$unset": {
                "password_reset_hash": "",
                "password_reset_requested_at": "",
            },
        },
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
        # TODO: 200 + “If this email exists, we sent a reset link” 로 갈지
        raise HTTPException(status_code=404, detail="User not found")

    await db["users"].update_one(
        {"_id": obj_id},
        {"$set": {"email_verified": True}},
    )
    return {"success": True, "message": "Email verified"}
