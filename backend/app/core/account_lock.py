"""IA-07: 계정 단위 로그인 실패 잠금 (DB 필드 기반)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

MAX_FAILED_LOGIN_ATTEMPTS = 5
ACCOUNT_LOCK_MINUTES = 15
PASSWORD_CHANGE_RECOMMEND_DAYS = 90

_ACCOUNT_LOCKED = "Account temporarily locked"
_INVALID_CREDENTIALS = "Invalid credentials"
_PASSWORD_CHANGE_NOTICE = (
    "비밀번호를 90일 이상 변경하지 않았습니다. 보안을 위해 비밀번호 변경을 권장합니다."
)


def _ensure_aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def is_account_locked(user: dict | None, now: datetime | None = None) -> bool:
    if not user:
        return False
    locked_until = user.get("locked_until")
    if not isinstance(locked_until, datetime):
        return False
    now = now or datetime.now(timezone.utc)
    return _ensure_aware(locked_until) > now


def assert_not_locked(user: dict | None) -> None:
    if is_account_locked(user):
        raise HTTPException(status_code=423, detail=_ACCOUNT_LOCKED)


def build_failed_login_update(user: dict, now: datetime | None = None) -> dict:
    """실패 1회 반영용 $set 필드. 호출 후 DB update 하고 HTTPException 발생."""
    now = now or datetime.now(timezone.utc)
    count = int(user.get("failed_login_count") or 0) + 1
    update: dict = {
        "failed_login_count": count,
        "updated_at": now,
    }
    if count >= MAX_FAILED_LOGIN_ATTEMPTS:
        update["locked_until"] = now + timedelta(minutes=ACCOUNT_LOCK_MINUTES)
    return update


def failed_login_http_error(update: dict) -> HTTPException:
    if update.get("locked_until") is not None:
        return HTTPException(status_code=423, detail=_ACCOUNT_LOCKED)
    return HTTPException(status_code=401, detail=_INVALID_CREDENTIALS)


def clear_login_lock_fields() -> dict:
    return {
        "failed_login_count": 0,
        "locked_until": None,
    }


def password_change_recommended(user: dict, now: datetime | None = None) -> bool:
    if user.get("is_deleted"):
        return False
    now = now or datetime.now(timezone.utc)
    changed_at = user.get("password_changed_at") or user.get("created_at") or user.get(
        "updated_at"
    )
    if not isinstance(changed_at, datetime):
        return False
    elapsed = now - _ensure_aware(changed_at)
    return elapsed.days >= PASSWORD_CHANGE_RECOMMEND_DAYS


def password_change_notice(user: dict) -> str | None:
    if password_change_recommended(user):
        return _PASSWORD_CHANGE_NOTICE
    return None
