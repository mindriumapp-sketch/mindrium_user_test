from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pymongo import ReturnDocument

from core.security import get_current_user_id
from core.utils import parse_datetime_value, ensure_utc
from db.mongo import get_db
from schemas.schedule_event import (
    ScheduleAction,
    ScheduleEventCreate,
    ScheduleEventUpdate,
    ScheduleEventDelete,
    ScheduleEventResponse,
)

router = APIRouter(prefix="/schedule-events", tags=["schedule-events"])
EVENT_COLLECTION = "schedule_events"


# ==============================
# 공통 헬퍼
# ==============================
def _serialize_event(doc: dict) -> dict:
    start_date = doc.get("start_date")
    end_date = doc.get("end_date")

    if isinstance(start_date, str):
        start_date = date.fromisoformat(start_date)
    if isinstance(end_date, str):
        end_date = date.fromisoformat(end_date)

    actions = [
        ScheduleAction(**action) if isinstance(action, dict) else action
        for action in doc.get("actions", [])
    ]

    return {
        "event_id": doc["event_id"],
        "start_date": start_date,
        "end_date": end_date,
        "actions": actions,
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


async def _find_conflicts(
    db,
    *,
    user_id: str,
    start_date: date,
    end_date: date,
    exclude_event_id: Optional[str] = None,
) -> List[dict]:
    """
    주어진 [start_date, end_date] 구간과 겹치는 이벤트들 조회.
    - 겹침 조건:
      existing.start_date <= new_end
      AND existing.end_date >= new_start
    - exclude_event_id가 있으면 해당 event_id는 제외 (업데이트 시 자기 자신 제외용)
    """
    query: Dict[str, Any] = {
        "user_id": user_id,
        "deleted": {"$ne": True},
        "start_date": {"$lte": end_date.isoformat()},
        "end_date": {"$gte": start_date.isoformat()},
    }
    if exclude_event_id:
        query["event_id"] = {"$ne": exclude_event_id}

    cursor = db[EVENT_COLLECTION].find(query).sort("start_date", 1)

    conflicts: List[dict] = []
    async for doc in cursor:
        conflicts.append(_serialize_event(doc))
    return conflicts


# ==============================
# 엔드포인트
# ==============================

@router.post(
    "",
    response_model=ScheduleEventResponse,
    status_code=status.HTTP_201_CREATED,
    summary="캘린더 이벤트 생성",
)
async def create_schedule_event(
    payload: ScheduleEventCreate,
    reject_on_conflict: bool = Query(
        False,
        description="True일 경우, 기간이 겹치는 이벤트가 있으면 409 + conflicts 목록 반환",
    ),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    # 기본 유효성: start <= end
    if payload.end_date < payload.start_date:
        raise HTTPException(
            status_code=400,
            detail="end_date는 start_date보다 빠를 수 없습니다.",
        )

    # 필요하면 겹침 체크
    if reject_on_conflict:
        conflicts = await _find_conflicts(
            db,
            user_id=user_id,
            start_date=payload.start_date,
            end_date=payload.end_date,
        )
        if conflicts:
            # 409로 conflicts 목록 반환 → 프론트에서 팝업 띄운 뒤,
            # 사용자가 "그래도 추가" 선택 시 reject_on_conflict=False로 다시 호출
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "EVENT_CONFLICT",
                    "message": "선택한 기간과 겹치는 이벤트가 있습니다.",
                    "conflicts": conflicts,
                },
            )

    event_id = f"se_{uuid.uuid4().hex[:8]}"

    doc = {
        "event_id": event_id,
        "user_id": user_id,
        "start_date": payload.start_date.isoformat(),
        "end_date": payload.end_date.isoformat(),
        "actions": [action.model_dump() for action in payload.actions],
        "created_at": now_utc,
        "updated_at": now_utc,
        "client_timestamp": client_ts_utc,
        "deleted": False,
    }

    await db[EVENT_COLLECTION].insert_one(doc)
    return ScheduleEventResponse(**_serialize_event(doc))


@router.get(
    "",
    response_model=List[ScheduleEventResponse],
    summary="사용자 캘린더 이벤트 목록",
)
async def list_schedule_events(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    - 단순히 start_date 기준으로 범위를 필터링해서 리스트 조회
    - 겹침 여부 계산은 하지 않음 (필요하면 프론트에서 별도 처리)
    """
    query: Dict[str, Any] = {
        "user_id": user_id,
        "deleted": {"$ne": True},  # 소프트 삭제된 건 제외
    }

    if start_date or end_date:
        date_query: Dict[str, Any] = {}
        if start_date:
            date_query["$gte"] = start_date.isoformat()
        if end_date:
            date_query["$lte"] = end_date.isoformat()
        query["start_date"] = date_query

    cursor = db[EVENT_COLLECTION].find(query).sort("start_date", 1)

    events: List[ScheduleEventResponse] = []
    async for doc in cursor:
        events.append(ScheduleEventResponse(**_serialize_event(doc)))

    return events


@router.put(
    "/{event_id}",
    response_model=ScheduleEventResponse,
    summary="캘린더 이벤트 수정",
)
async def update_schedule_event(
    event_id: str,
    payload: ScheduleEventUpdate,
    reject_on_conflict: bool = Query(
        False,
        description="True일 경우, 수정 후 기간이 다른 이벤트와 겹치면 409 + conflicts 목록 반환",
    ),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    # 먼저 기존 이벤트 조회 (기간 계산/검증용)
    existing = await db[EVENT_COLLECTION].find_one(
        {"user_id": user_id, "event_id": event_id, "deleted": {"$ne": True}},
    )
    if not existing:
        raise HTTPException(status_code=404, detail="이벤트를 찾을 수 없습니다")

    # 수정 후 최종 start/end 계산
    original_start = date.fromisoformat(existing["start_date"])
    original_end = date.fromisoformat(existing["end_date"])

    new_start = payload.start_date or original_start
    new_end = payload.end_date or original_end

    if new_end < new_start:
        raise HTTPException(
            status_code=400,
            detail="end_date는 start_date보다 빠를 수 없습니다.",
        )

    # 필요하면 겹침 체크 (자기 자신은 제외)
    if reject_on_conflict:
        conflicts = await _find_conflicts(
            db,
            user_id=user_id,
            start_date=new_start,
            end_date=new_end,
            exclude_event_id=event_id,
        )
        if conflicts:
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "EVENT_CONFLICT",
                    "message": "수정 후 기간이 다른 이벤트와 겹칩니다.",
                    "conflicts": conflicts,
                },
            )

    # 실제 업데이트 필드 구성
    update_data: Dict[str, Any] = {}

    if payload.start_date is not None:
        update_data["start_date"] = payload.start_date.isoformat()
    if payload.end_date is not None:
        update_data["end_date"] = payload.end_date.isoformat()
    if payload.actions is not None:
        update_data["actions"] = [a.model_dump() for a in payload.actions]

    if not update_data:
        raise HTTPException(status_code=400, detail="수정할 필드가 없습니다")

    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)
    update_data["updated_at"] = now_utc
    update_data["client_timestamp"] = client_ts_utc

    doc = await db[EVENT_COLLECTION].find_one_and_update(
        {"user_id": user_id, "event_id": event_id, "deleted": {"$ne": True}},
        {"$set": update_data},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        # 이론상 race condition인 경우에만 올 수 있음
        raise HTTPException(status_code=404, detail="이벤트를 찾을 수 없습니다")

    return ScheduleEventResponse(**_serialize_event(doc))


@router.delete(
    "/{event_id}",
    status_code=status.HTTP_200_OK,
    summary="캘린더 이벤트 삭제 (소프트 삭제)",
)
async def delete_schedule_event(
    event_id: str,
    payload: ScheduleEventDelete,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    doc = await db[EVENT_COLLECTION].find_one_and_update(
        {"event_id": event_id, "user_id": user_id, "deleted": {"$ne": True}},
        {
            "$set": {
                "deleted": True,
                "updated_at": now_utc,
                "client_timestamp": client_ts_utc,
            }
        },
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        raise HTTPException(status_code=404, detail="이벤트를 찾을 수 없습니다")

    return {
        "client_timestamp": ensure_utc(payload.client_timestamp),
        "updated_at": datetime.now(timezone.utc),
    }
