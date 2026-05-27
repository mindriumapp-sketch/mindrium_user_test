#!/usr/bin/env python3
"""
MongoDB users 컬렉션 — IA-07·탈퇴·비밀번호 변경일 필드 초기화.

사용 (backend/app 기준):
  cd backend/app
  python ../scripts/migrate_security_fields.py

Compass에서 수동으로 넣을 때는 users 문서에 아래 필드를 추가:
  failed_login_count: 0
  locked_until: null
  password_changed_at: <기존 updated_at 또는 created_at>
  is_deleted: false
  deleted_at: null
"""

from __future__ import annotations

import asyncio
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# backend/app 을 import path에 추가
APP_DIR = Path(__file__).resolve().parents[1] / "app"
sys.path.insert(0, str(APP_DIR))

from db.mongo import get_db  # noqa: E402


async def run() -> None:
    db = get_db()
    users = db["users"]
    now = datetime.now(timezone.utc)
    cursor = users.find({})
    updated = 0
    async for doc in cursor:
        sets: dict = {}
        if doc.get("failed_login_count") is None:
            sets["failed_login_count"] = 0
        if "locked_until" not in doc:
            sets["locked_until"] = None
        if doc.get("is_deleted") is None:
            sets["is_deleted"] = False
        if "deleted_at" not in doc:
            sets["deleted_at"] = None
        if not doc.get("password_changed_at"):
            sets["password_changed_at"] = (
                doc.get("updated_at") or doc.get("created_at") or now
            )
        if sets:
            await users.update_one({"_id": doc["_id"]}, {"$set": sets})
            updated += 1
    print(f"[OK] migrated/initialized fields on {updated} user document(s).")


if __name__ == "__main__":
    asyncio.run(run())
