#!/usr/bin/env python3
"""
시연 전용 데모 계정을 만든다: 6주차까지 성실히 앱을 쓴 사용자 (실제 사용자 기록 아님).

  cd backend/app
  MONGO_URI=mongodb://127.0.0.1:27017 DB_NAME=mindrium_dogfood \
    DEMO_PASSWORD='<원하는 비밀번호>' ../.venv/bin/python ../scripts/seed_demo_account.py

- 활동 기록은 합성 데이터(demo_data/synthetic_user_w1_6.json)에서 온다. 원본은 8주 합성 사용자
  40명 중 syn_user_023의 1~6주차(일기 61, 이완 41, 교육 6, 걱정 그룹 5, 알림·위치 라벨 등).
- 날짜는 실행할 때마다 '지금' 기준으로 옮긴다. 마지막 기록이 30분 전이 되도록 맞추고,
  6주차는 진행 중(교육 완료, 마지막 날)으로 둔다.
- 걱정 그룹 '가족 대화'는 해결해서 보관한 상태(마이페이지 '보관된 걱정 물고기').
- 지난 상담 기록 2건은 이 사용자의 일기에 맞춰 직접 만든다(합성 데이터에 상담 기록이 없음).
  발표 상담은 시연 대본의 과거 회상("예전에도 발표…")에 쓰인다.
- 다시 실행하면 데모 계정의 데이터만 지우고 같은 상태로 다시 만든다(멱등).
- DEMO_PASSWORD가 없으면 임의 비밀번호를 만들어 한 번 출력한다.
- 상담 경로 B를 쓰려면 이메일이 lib/features/counseling/policy/rollout/
  internal_account_allowlist.dart 에 있어야 한다.
"""

from __future__ import annotations

import asyncio
import os
import secrets
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from bson import json_util

APP_DIR = Path(__file__).resolve().parents[1] / "app"
sys.path.insert(0, str(APP_DIR))

from core.security import hash_password  # noqa: E402
from db.mongo import get_db  # noqa: E402

EMAIL = "mindrium.demo@example.com"
USER_ID = "user_demo0001"
CURRENT_WEEK = 6
DATA_FILE = Path(__file__).resolve().parent / "demo_data" / "synthetic_user_w1_6.json"
ARCHIVED_GROUP_TITLE = "가족 대화"

COLLECTIONS = [
    "treatment_progress", "worry_groups", "custom_tags", "diaries", "relaxation_tasks",
    "counseling_sessions", "edu_sessions", "screen_time", "location_label", "notification_settings",
]


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _shift(value, delta: timedelta):
    """Every datetime in a document, at any depth, moved by delta."""
    if isinstance(value, datetime):
        return _aware(value) + delta
    if isinstance(value, dict):
        return {k: _shift(v, delta) for k, v in value.items()}
    if isinstance(value, list):
        return [_shift(v, delta) for v in value]
    return value


def _latest_activity(data: dict) -> datetime:
    stamps = [_aware(d["created_at"]) for d in data["diaries"]]
    stamps += [_aware(r["start_time"]) for r in data["relaxation_tasks"]]
    stamps += [_aware(s["start_time"]) for s in data["screen_time"]]
    return max(stamps)


def _counseling_sessions(diaries: list[dict], groups: dict[str, str], now: datetime) -> list[dict]:
    def first_diary(title: str) -> str | None:
        gid = next((g for g, t in groups.items() if t == title), None)
        d = next((d for d in diaries if d.get("group_id") == gid), None)
        return d["diary_id"] if d else None

    s1, s2 = now - timedelta(days=9), now - timedelta(days=3)
    base = {"user_id": USER_ID, "completion_status": "completed", "final_state": "closing",
            "safety_level": "none", "core_thought_source": "current_utterance", "affect": "anxious",
            "activity_recommended": None, "unfinished_issue": None}
    return [
        {**base, "session_id": "demo-sess-001", "week": 5,
         "main_concern": "다음 주 발표 준비 때문에 걱정돼요",
         "core_thought": "발표 준비하다가 내가 분위기를 망칠 것 같다",
         "alternative_thought": "지금 불안하지만 이것이 곧 위험이라는 뜻은 아니다. 작게 확인하고 다시 선택할 수 있다.",
         "sud_start": 6, "sud_end": 4, "intervention_used": "week4_alternative_thought_01",
         "intervention_outcome": "credited",
         "provenance_ids": [f"diary:{x}" for x in [first_diary("발표와 평가")] if x], "turn_count": 12,
         "started_at": s1, "ended_at": s1 + timedelta(minutes=15),
         "created_at": s1, "updated_at": s1 + timedelta(minutes=15)},
        {**base, "session_id": "demo-sess-002", "week": 6,
         "main_concern": "팀 프로젝트 회의 때마다 긴장돼요",
         "core_thought": "팀 프로젝트에서 모두 나를 평가할 것 같다",
         "alternative_thought": "모두가 나만 보고 있는 건 아니고, 내 몫을 차근차근 하면 된다",
         "sud_start": 7, "sud_end": 5, "intervention_used": "week5_confront_avoid_01",
         "intervention_outcome": "acknowledged",
         "provenance_ids": [f"diary:{x}" for x in [first_diary("학업과 과제")] if x], "turn_count": 10,
         "started_at": s2, "ended_at": s2 + timedelta(minutes=12),
         "created_at": s2, "updated_at": s2 + timedelta(minutes=12)},
    ]


async def run() -> None:
    db = get_db()
    now = datetime.now(timezone.utc)
    password = os.environ.get("DEMO_PASSWORD") or secrets.token_urlsafe(9)
    data = json_util.loads(DATA_FILE.read_text(encoding="utf-8"))

    delta = (now - timedelta(minutes=30)) - _latest_activity(data)
    src_user = data["users"][0]

    def own(rows: list[dict]) -> list[dict]:
        return [{**_shift(r, delta), "user_id": USER_ID} for r in rows]

    for c in COLLECTIONS:
        await db[c].delete_many({"user_id": USER_ID})
    await db["users"].delete_many({"email": EMAIL})

    progress = sorted(own(data["treatment_progress"]), key=lambda p: p["week_number"])
    for p in progress:
        if p["week_number"] == CURRENT_WEEK:
            # in progress: education done, last day of the week, weekly targets not yet met
            p.update(completed_at=None, requirements_met=False, ends_at=now + timedelta(hours=12),
                     updated_at=now)
    last_done = max((p for p in progress if p["completed_at"]), key=lambda p: p["week_number"])

    await db["users"].insert_one({
        "user_id": USER_ID, "patient_id": "demo-0001", "email": EMAIL,
        "name": "데모 사용자", "gender": "", "address": "", "patient_code": "DEMO0001",
        "phone": "01000000000", "password_hash": hash_password(password),
        "password_changed_at": now, "failed_login_count": 0, "locked_until": None,
        "is_deleted": False, "email_verified": False, "survey_completed": True,
        "surveys": _shift(src_user.get("surveys", []), delta),
        "value_goal": src_user.get("value_goal"),
        "last_completed_week": last_done["week_number"], "last_completed_at": last_done["completed_at"],
        "created_at": _shift(src_user["created_at"], delta), "updated_at": now,
    })
    await db["treatment_progress"].insert_many(progress)

    diaries = own(data["diaries"])
    groups = own(data["worry_groups"])
    titles = {g["group_id"]: g["group_title"] for g in groups}
    for g in groups:
        mine = [d for d in diaries if d.get("group_id") == g["group_id"]]
        g["diary_count"] = len(mine)
        g["sud_sum"] = float(sum(d["latest_sud"] for d in mine if d.get("latest_sud") is not None))
        if g["group_title"] == ARCHIVED_GROUP_TITLE:
            g.update(archived=True, archived_at=now - timedelta(days=2), updated_at=now - timedelta(days=2))

    await db["worry_groups"].insert_many(groups)
    await db["diaries"].insert_many(diaries)
    for name in ("custom_tags", "relaxation_tasks", "edu_sessions", "screen_time",
                 "location_label", "notification_settings"):
        rows = own(data[name])
        if rows:
            await db[name].insert_many(rows)
    await db["counseling_sessions"].insert_many(_counseling_sessions(diaries, titles, now))

    print(f"demo account ready: {EMAIL} (user_id {USER_ID}, week {CURRENT_WEEK} in progress, "
          f"{len(diaries)} diaries, {len(data['relaxation_tasks'])} relaxations)")
    if not os.environ.get("DEMO_PASSWORD"):
        print(f"generated password: {password}")


if __name__ == "__main__":
    asyncio.run(run())
