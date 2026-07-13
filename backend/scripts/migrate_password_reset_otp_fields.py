#!/usr/bin/env python3
"""
MongoDB users — 비밀번호 재설정 딥링크 필드 제거 (OTP 전환).

사용 (backend/app 기준):
  cd backend/app
  python ../scripts/migrate_password_reset_otp_fields.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[1] / "app"
sys.path.insert(0, str(APP_DIR))

from db.mongo import get_db  # noqa: E402

_LEGACY_UNSET = {
    "password_reset_hash": "",
    "password_reset_requested_at": "",
}


async def run() -> None:
    db = get_db()
    users = db["users"]
    result = await users.update_many(
        {
            "$or": [
                {"password_reset_hash": {"$exists": True}},
                {"password_reset_requested_at": {"$exists": True}},
            ]
        },
        {"$unset": _LEGACY_UNSET},
    )
    print(f"[OK] cleared legacy password reset fields on {result.modified_count} user(s).")


if __name__ == "__main__":
    asyncio.run(run())
