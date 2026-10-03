#!/usr/bin/env python3
"""
시연 전용 데모 계정과 합성 과거 기록을 만든다 (실제 사용자 기록 아님).

  cd backend/app
  MONGO_URI=mongodb://127.0.0.1:27017 DB_NAME=mindrium_dogfood \
    DEMO_PASSWORD='<원하는 비밀번호>' python3 ../scripts/seed_demo_account.py

- 다시 실행하면 데모 계정의 데이터만 지우고 같은 상태로 다시 만든다(멱등).
- DEMO_PASSWORD가 없으면 임의 비밀번호를 만들어 한 번 출력한다.
- 계정은 5주차 진행 중이다(4~5주차 기법 사용 가능).
- 개인화 시연용 기록:
  - 발표 걱정 상담 세션(완료, 균형 잡힌 생각 기법이 도움됨) → 비슷한 걱정에서 회상
  - 발표 걱정 일기 3개 + 수면 걱정 일기 1개 (SUD 추이)
- 앱의 상담 경로 B를 쓰려면 이메일이 lib/features/counseling/policy/rollout/
  internal_account_allowlist.dart 에 있어야 한다.
"""

from __future__ import annotations

import asyncio
import os
import secrets
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[1] / "app"
sys.path.insert(0, str(APP_DIR))

from core.security import hash_password  # noqa: E402
from db.mongo import get_db  # noqa: E402
from routers.custom_tags import ensure_default_custom_tags  # noqa: E402
from routers.worry_groups import ensure_default_worry_group  # noqa: E402

EMAIL = "mindrium.demo@example.com"
USER_ID = "user_demo0001"
CURRENT_WEEK = 5

COLLECTIONS = [
    "treatment_progress", "worry_groups", "custom_tags", "diaries",
    "relaxation_tasks", "counseling_sessions",
]


def _chip(label, category=None):
    return {"label": label, "chip_id": None, "category": category}


def _diary(n, days_ago, group, situation, thought, emotion, action, sud, now):
    t = now - timedelta(days=days_ago)
    return {
        "user_id": USER_ID, "diary_id": f"diary_demo{n:04d}", "group_id": group,
        "route": "today_task",
        "activation": _chip(situation),
        "belief": [_chip(thought, "anxious")],
        "consequence_physical": [_chip("심장이 빨리 뜀")],
        "consequence_emotion": [_chip(emotion)],
        "consequence_action": [_chip(action)],
        "sud_scores": [], "latest_sud": sud,
        "loc_time": None, "loc_auto_filled": False,
        "created_at": t, "updated_at": t,
    }


async def run() -> None:
    db = get_db()
    now = datetime.now(timezone.utc)
    password = os.environ.get("DEMO_PASSWORD") or secrets.token_urlsafe(9)

    for c in COLLECTIONS:
        await db[c].delete_many({"user_id": USER_ID})
    await db["users"].delete_many({"email": EMAIL})

    await db["users"].insert_one({
        "user_id": USER_ID, "patient_id": "demo-0001", "email": EMAIL,
        "name": "데모 사용자", "gender": "", "address": "", "patient_code": "DEMO0001",
        "phone": "01000000000", "password_hash": hash_password(password),
        "password_changed_at": now, "failed_login_count": 0, "locked_until": None,
        "is_deleted": False, "survey_completed": True, "surveys": [],
        "email_verified": False, "created_at": now - timedelta(days=30), "updated_at": now,
    })

    # weeks 1..4 completed, week 5 active
    for w in range(1, CURRENT_WEEK + 1):
        start = now - timedelta(days=7 * (CURRENT_WEEK - w) + 2)
        done = w < CURRENT_WEEK
        await db["treatment_progress"].insert_one({
            "progress_id": f"tp_demo{w:04d}", "user_id": USER_ID, "week_number": w,
            "started_at": start, "ends_at": start + timedelta(days=7),
            "edu_session_id": None, "relaxation_task_id": None,
            "main_completed": done, "main_completed_at": start + timedelta(days=6) if done else None,
            "daily_relax_count": 0, "daily_diary_count": 0, "requirements_met": done,
            "completed_at": start + timedelta(days=7) if done else None,
            "created_at": start, "updated_at": now,
        })

    await ensure_default_custom_tags(db, USER_ID)
    await ensure_default_worry_group(db, USER_ID)
    await db["worry_groups"].insert_many([
        {"user_id": USER_ID, "group_id": "group_demo_pres", "group_title": "발표 불안",
         "group_contents": "회의나 수업에서 발표할 때 실수할까 걱정됨", "character_id": 2,
         "archived": False, "diary_count": 3, "sud_sum": 21.0, "created_at": now, "updated_at": now},
        {"user_id": USER_ID, "group_id": "group_demo_sleep", "group_title": "잠 걱정",
         "group_contents": "잠을 못 자면 다음 날을 망칠까 걱정됨", "character_id": 3,
         "archived": False, "diary_count": 1, "sud_sum": 5.0, "created_at": now, "updated_at": now},
    ])

    await db["diaries"].insert_many([
        _diary(1, 20, "group_demo_pres", "팀 회의에서 분기 실적 발표",
               "실수하면 사람들이 나를 무능하다고 볼 거야", "불안", "발표 연습을 미룸", 8, now),
        _diary(2, 14, "group_demo_pres", "수업 조별 발표 리허설",
               "말이 막히면 다들 비웃을 것 같아", "긴장", "대본을 통째로 외우려 함", 7, now),
        _diary(3, 9, "group_demo_pres", "신입 교육에서 짧은 소개 발표",
               "목소리가 떨리면 다 티가 날 거야", "초조함", "앞사람 발표만 계속 봄", 6, now),
        _diary(4, 4, "group_demo_sleep", "중요한 일정 전날 밤",
               "오늘 못 자면 내일 다 망칠 거야", "걱정", "휴대폰을 계속 봄", 5, now),
    ])

    for i, (week, days_ago) in enumerate([(2, 25), (4, 10)], start=1):
        t = now - timedelta(days=days_ago)
        await db["relaxation_tasks"].insert_one({
            "user_id": USER_ID, "task_id": f"week{week}_education", "week_number": week,
            "start_time": t, "end_time": t + timedelta(minutes=10), "duration_seconds": 600,
            "logs": [], "created_at": t, "updated_at": t,
        })

    s1 = now - timedelta(days=8)
    s2 = now - timedelta(days=3)
    await db["counseling_sessions"].insert_many([
        {"user_id": USER_ID, "session_id": "demo-sess-001", "week": 4,
         "completion_status": "completed", "final_state": "closing", "safety_level": "none",
         "main_concern": "다음 주 팀 회의 발표 때문에 걱정돼요",
         "core_thought": "발표하다 실수하면 사람들이 나를 안 좋게 볼 것 같다",
         "core_thought_source": "current_utterance",
         "alternative_thought": "긴장해도 준비한 내용은 설명할 수 있고, 실수 하나로 나를 다 판단하지는 않는다",
         "affect": "anxious", "sud_start": 8, "sud_end": 5,
         "intervention_used": "week4_alternative_thought_01", "activity_recommended": None,
         "unfinished_issue": None, "intervention_outcome": "credited",
         "provenance_ids": ["diary:diary_demo0001"], "turn_count": 12,
         "started_at": s1, "ended_at": s1 + timedelta(minutes=15),
         "created_at": s1, "updated_at": s1 + timedelta(minutes=15)},
        {"user_id": USER_ID, "session_id": "demo-sess-002", "week": 4,
         "completion_status": "completed", "final_state": "closing", "safety_level": "none",
         "main_concern": "중요한 일정 전날 잠을 못 잘까 봐 걱정돼요",
         "core_thought": "오늘 못 자면 내일을 다 망칠 거야",
         "core_thought_source": "current_utterance",
         "alternative_thought": "조금 덜 자도 하루를 버틸 수는 있다",
         "affect": "anxious", "sud_start": 6, "sud_end": 4,
         "intervention_used": "week4_thought_check_01", "activity_recommended": None,
         "unfinished_issue": None, "intervention_outcome": "acknowledged",
         "provenance_ids": ["diary:diary_demo0004"], "turn_count": 9,
         "started_at": s2, "ended_at": s2 + timedelta(minutes=10),
         "created_at": s2, "updated_at": s2 + timedelta(minutes=10)},
    ])

    print(f"demo account ready: {EMAIL} (user_id {USER_ID}, week {CURRENT_WEEK})")
    if not os.environ.get("DEMO_PASSWORD"):
        print(f"generated password: {password}")


if __name__ == "__main__":
    asyncio.run(run())
