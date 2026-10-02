from datetime import datetime, timezone
from typing import Any, Dict, List

from core.security import get_current_user_id
from core.utils import parse_datetime_value
from db.mongo import get_db
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pymongo import ReturnDocument
from schemas.counseling_session import (
    CounselingSessionResponse,
    CounselingSessionUpsert,
)

router = APIRouter(prefix="/counseling-sessions", tags=["counseling_sessions"])

COUNSELING_SESSIONS_COLLECTION = "counseling_sessions"


def _serialize(doc: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "session_id": doc.get("session_id"),
        "user_id": doc.get("user_id"),
        "week": doc.get("week"),
        "completion_status": doc.get("completion_status"),
        "final_state": doc.get("final_state"),
        "safety_level": doc.get("safety_level"),
        "main_concern": doc.get("main_concern"),
        "core_thought": doc.get("core_thought"),
        "core_thought_source": doc.get("core_thought_source"),
        "alternative_thought": doc.get("alternative_thought"),
        "affect": doc.get("affect"),
        "sud_start": doc.get("sud_start"),
        "sud_end": doc.get("sud_end"),
        "intervention_used": doc.get("intervention_used"),
        "activity_recommended": doc.get("activity_recommended"),
        "unfinished_issue": doc.get("unfinished_issue"),
        "provenance_ids": list(doc.get("provenance_ids") or []),
        "turn_count": int(doc.get("turn_count") or 0),
        "started_at": parse_datetime_value(doc.get("started_at")),
        "ended_at": parse_datetime_value(doc.get("ended_at")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


@router.put(
    "/{session_id}",
    response_model=CounselingSessionResponse,
    summary="상담 세션 요약 upsert",
)
async def upsert_counseling_session(
    session_id: str,
    payload: CounselingSessionUpsert,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    if payload.session_id != session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="session_id가 경로와 본문에서 다릅니다.",
        )

    collection = db[COUNSELING_SESSIONS_COLLECTION]
    now = datetime.now(timezone.utc)

    existing = await collection.find_one(
        {"user_id": user_id, "session_id": session_id}
    )

    # 정상 종료된 세션은 화면 이탈 스냅샷으로 덮어쓰지 않는다.
    # 두 저장 경로가 같은 세션을 두고 경쟁하기 때문이다.
    if (
        existing is not None
        and existing.get("completion_status") == "completed"
        and payload.completion_status != "completed"
    ):
        return CounselingSessionResponse(**_serialize(existing))

    document = payload.model_dump()
    document.pop("session_id", None)
    document["updated_at"] = now

    updated = await collection.find_one_and_update(
        {"user_id": user_id, "session_id": session_id},
        {
            "$set": document,
            "$setOnInsert": {
                "user_id": user_id,
                "session_id": session_id,
                "created_at": now,
            },
        },
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )

    return CounselingSessionResponse(**_serialize(updated))


@router.get(
    "",
    response_model=List[CounselingSessionResponse],
    summary="최근 상담 세션 조회",
)
async def list_counseling_sessions(
    limit: int = Query(5, ge=1, le=20),
    completion_status: str | None = Query(
        None,
        description="completed 만 받으려면 지정한다. 다음 세션 개인화는 completed 를 우선한다.",
    ),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    query: Dict[str, Any] = {"user_id": user_id}
    if completion_status is not None:
        query["completion_status"] = completion_status

    cursor = (
        db[COUNSELING_SESSIONS_COLLECTION]
        .find(query)
        .sort("ended_at", -1)
        .limit(limit)
    )

    return [CounselingSessionResponse(**_serialize(doc)) async for doc in cursor]
