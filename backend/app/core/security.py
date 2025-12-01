from datetime import datetime, timedelta, timezone
from bson import ObjectId
import uuid
import hashlib
import secrets

from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Depends, Header, HTTPException

from core.config import get_settings
from db.mongo import get_db

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
settings = get_settings()

ALGORITHM = "HS256"


# ========= 비밀번호 해시/검증 =========

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)


# ========= JWT 토큰 생성/디코드 =========

def _create_token(data: dict, expires_delta: timedelta, secret: str) -> str:
    """
    공통 토큰 생성기.
    exp / iat / jti 포함.
    """
    to_encode = data.copy()
    now = datetime.now(timezone.utc)
    expire = now + expires_delta
    to_encode.update(
        {
            "exp": expire,
            "iat": now,
            "jti": str(uuid.uuid4()),
        }
    )
    return jwt.encode(to_encode, secret, algorithm=ALGORITHM)


def create_access_token(sub: str) -> str:
    return _create_token(
        {"sub": sub, "type": "access"},
        timedelta(minutes=settings.access_token_expire_minutes),
        settings.jwt_secret,
    )


def create_refresh_token(sub: str) -> str:
    return _create_token(
        {"sub": sub, "type": "refresh"},
        timedelta(days=settings.refresh_token_expire_days),
        settings.jwt_refresh_secret,
    )


def create_email_verification_token(sub: str) -> str:
    return _create_token(
        {"sub": sub, "type": "verify"},
        timedelta(minutes=settings.email_verification_expire_minutes),
        settings.jwt_secret,
    )


def create_password_reset_token(sub: str) -> str:
    return _create_token(
        {"sub": sub, "type": "reset"},
        timedelta(minutes=settings.reset_token_expire_minutes),
        settings.jwt_secret,
    )


def decode_token(token: str, refresh: bool = False) -> dict | None:
    """
    refresh=True 이면 refresh 시크릿으로 디코드.
    디코드 실패 시 None 리턴.
    """
    secret = settings.jwt_refresh_secret if refresh else settings.jwt_secret
    try:
        payload = jwt.decode(token, secret, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None


# ========= 토큰 해시 (리프레시 저장용) =========

def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def hash_refresh_token(token: str) -> str:
    """
    리프레시 토큰은 원문 대신 해시만 저장.
    (토큰 로테이션 대비)
    """
    return hash_token(token)


def verify_refresh_token(raw_token: str, stored_hash: str) -> bool:
    return secrets.compare_digest(hash_refresh_token(raw_token), stored_hash)


# ========= 공통 헬퍼 =========

def sub_to_obj(sub: str) -> ObjectId:
    if not sub:
        raise HTTPException(status_code=401, detail="Invalid token (no subject)")
    try:
        obj_id = ObjectId(sub)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid user id in token")
    return obj_id


def extract_bearer_token(authorization: str | None) -> str:
    """
    Authorization 헤더에서 Bearer 토큰만 깔끔히 떼어내는 공통 함수.
    잘못된 형식이면 401.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return token


# ========= FastAPI 의존성 =========

async def get_current_user(
    authorization: str | None = Header(default=None),
    db=Depends(get_db),
):
    """
    Bearer access 토큰을 검증하고 Mongo users 도큐먼트 리턴.
    """
    token = extract_bearer_token(authorization)
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid or expired access token")

    sub = payload.get("sub")
    obj_id = sub_to_obj(sub)
    user = await db["users"].find_one({"_id": obj_id})
    if not user:
        # TODO: "User not found" 대신 통합 메시지로 숨길지 결정
        raise HTTPException(status_code=401, detail="User not found")
    return user


async def get_user_obj_id(
    authorization: str | None = Header(default=None),
) -> ObjectId:
    """
    Mongo _id(ObjectId)만 필요할 때 사용하는 dependency.
    DB 조회는 하지 않음.
    """
    token = extract_bearer_token(authorization)
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid or expired access token")
    sub = payload.get("sub")
    return sub_to_obj(sub)


async def get_current_user_id(current_user=Depends(get_current_user)) -> str:
    """
    access 토큰 기반으로 현재 로그인한 유저의 user_id(str)만 뽑아서 쓰고 싶을 때 사용.
    (Mongo _id 말고, 외부 노출용 user_id)
    """
    user_id = current_user.get("user_id")
    if not user_id:
        # 혹시라도 기존 유저에 user_id 필드가 없는 경우 대비
        raise HTTPException(status_code=500, detail="User ID not set")
    return user_id
