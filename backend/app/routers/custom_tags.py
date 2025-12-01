from datetime import datetime, timezone
from typing import List, Optional, Dict, Any, Literal
import uuid

from fastapi import APIRouter, Depends, HTTPException, status, Query

from core.security import get_current_user_id
from core.utils import parse_datetime_value, ensure_utc
from db.mongo import get_db
from pymongo import ReturnDocument
from routers.diaries import update_diary_chip_category  # 일기 컬렉션 category 업데이트용

from schemas.custom_tag import (
    CustomTagCreate,
    CustomTagUpdate,
    CustomTagDelete,
    CustomTagResponse,
    RealOddnessLogsCreate,
    CategoryLogsCreate,
    RealOddnessLogResponse,
    CategoryLogResponse,
)

router = APIRouter(prefix="/custom-tags", tags=["custom-tags"])
CUSTOM_TAG_COLLECTION = "custom_tags"


# ---------- 공통 직렬화 ----------

def _serialize_tag(doc: dict) -> dict:
    return {
        "chip_id": doc.get("chip_id"),
        "label": doc.get("label", ""),
        "type": doc.get("type"),
        "is_preset": bool(doc.get("is_preset", False)),
        "deleted": bool(doc.get("deleted", False)),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


def _serialize_real_oddness_log(raw: dict) -> dict:
    return {
        "log_id": raw.get("log_id"),
        "diary_id": raw.get("diary_id"),
        "chip_id": raw.get("chip_id"),
        "before_odd": raw.get("before_odd"),
        "after_odd": raw.get("after_odd"),
        "alternative_thought": raw.get("alternative_thought"),
        "completed_at": parse_datetime_value(raw.get("completed_at")),
        "created_at": parse_datetime_value(raw.get("created_at")),
        "updated_at": parse_datetime_value(raw.get("updated_at")),
    }


def _serialize_category_log(raw: dict) -> dict:
    return {
        "log_id": raw.get("log_id"),
        "diary_id": raw.get("diary_id"),
        "chip_id": raw.get("chip_id"),
        "category": raw.get("category"),
        "short_term": raw.get("short_term"),
        "long_term": raw.get("long_term"),
        "completed_at": parse_datetime_value(raw.get("completed_at")),
        "created_at": parse_datetime_value(raw.get("created_at")),
        "updated_at": parse_datetime_value(raw.get("updated_at")),
    }


# ---------- Custom Tag CRUD ----------

@router.post(
    "",
    response_model=CustomTagResponse,
    status_code=status.HTTP_201_CREATED,
    summary="커스텀 태그 생성",
)
async def create_custom_tag(
    payload: CustomTagCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    # chip_id는 클라에서 생성해 온다고 가정
    doc = {
        "user_id": user_id,
        "chip_id": payload.chip_id,
        "label": payload.label,
        "type": payload.type,
        "is_preset": payload.is_preset,
        "deleted": False,
        "created_at": now_utc,
        "updated_at": now_utc,
        "client_timestamp": client_ts_utc,
    }

    await collection.insert_one(doc)
    return CustomTagResponse(**_serialize_tag(doc))


@router.get(
    "",
    response_model=List[CustomTagResponse],
    summary="커스텀 태그 목록 조회",
)
async def list_custom_tags(
    chip_type: Optional[Literal["A", "B", "CP", "CE", "CA"]] = Query(
        default=None,
        description="특정 타입(A/B/CP/CE/CA)만 조회하고 싶을 때",
    ),
    include_deleted: bool = Query(
        default=False,
        description="삭제된 태그까지 포함할지 여부",
    ),
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]

    query: Dict[str, Any] = {"user_id": user_id}
    if chip_type is not None:
        query["type"] = chip_type
    if not include_deleted:
        query["deleted"] = False

    cursor = collection.find(query).sort("created_at", 1)
    docs = await cursor.to_list(length=None)

    return [CustomTagResponse(**_serialize_tag(d)) for d in docs]


@router.get(
    "/{chip_id}",
    response_model=CustomTagResponse,
    summary="단일 커스텀 태그 조회",
)
async def get_custom_tag(
    chip_id: str,
    include_deleted: bool = Query(
        default=False,
        description="soft-delete된 태그도 조회할지 여부",
    ),
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]

    query: Dict[str, Any] = {
        "user_id": user_id,
        "chip_id": chip_id,
    }
    if not include_deleted:
        query["deleted"] = False

    doc = await collection.find_one(query)
    if not doc:
        raise HTTPException(status_code=404, detail="태그를 찾을 수 없습니다")

    return CustomTagResponse(**_serialize_tag(doc))


@router.put(
    "/{chip_id}",
    response_model=CustomTagResponse,
    summary="커스텀 태그 수정",
)
async def update_custom_tag(
    chip_id: str,
    payload: CustomTagUpdate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]

    update_data = payload.model_dump(
        exclude_unset=True,
        exclude={"client_timestamp"},
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="업데이트할 필드가 없습니다")

    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    set_fields: Dict[str, Any] = {
        **update_data,
        "updated_at": now_utc,
        "client_timestamp": client_ts_utc,
    }

    updated_doc = await collection.find_one_and_update(
        {"user_id": user_id, "chip_id": chip_id},
        {"$set": set_fields},
        return_document=ReturnDocument.AFTER,
    )

    if not updated_doc:
        raise HTTPException(status_code=404, detail="태그를 찾을 수 없습니다")

    return CustomTagResponse(**_serialize_tag(updated_doc))


@router.delete(
    "/{chip_id}",
    status_code=status.HTTP_200_OK,
    summary="커스텀 태그 삭제(soft delete)",
)
async def delete_custom_tag(
    chip_id: str,
    payload: CustomTagDelete,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]

    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    result = await collection.update_one(
        {"user_id": user_id, "chip_id": chip_id},
        {
            "$set": {
                "deleted": True,
                "updated_at": now_utc,
                "client_timestamp": client_ts_utc,
            },
        },
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="태그를 찾을 수 없습니다")

    return {
        "chip_id": chip_id,
        "deleted": True,
        "client_timestamp": client_ts_utc,
        "updated_at": now_utc,
    }


# ---------- Real Oddness Logs (칩 문서 안에 내장) ----------

@router.post(
    "/{chip_id}/real-oddness-logs",
    response_model=RealOddnessLogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="칩에 Real Oddness 로그 추가",
)
async def create_real_oddness_log(
    chip_id: str,
    payload: RealOddnessLogsCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    if payload.chip_id != chip_id:
        raise HTTPException(status_code=400, detail="chip_id가 일치하지 않습니다")

    collection = db[CUSTOM_TAG_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    log_id = f"ro_{uuid.uuid4().hex[:8]}"

    log_doc = {
        "log_id": log_id,
        "diary_id": payload.diary_id,
        "chip_id": chip_id,
        "before_odd": payload.before_odd,
        "after_odd": payload.after_odd,
        "alternative_thought": payload.alternative_thought,
        "completed_at": ensure_utc(payload.completed_at),
        "created_at": now_utc,
        "updated_at": now_utc,
    }

    result = await collection.update_one(
        {"user_id": user_id, "chip_id": chip_id},
        {
            "$push": {"real_oddness_logs": log_doc},
            "$set": {"updated_at": now_utc},
        },
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="태그를 찾을 수 없습니다")

    return RealOddnessLogResponse(**_serialize_real_oddness_log(log_doc))


@router.get(
    "/logs/real-oddness",
    response_model=List[RealOddnessLogResponse],
    summary="Real Oddness 로그 조회 (chip_id/diary_id/기간 필터)",
)
async def list_real_oddness_logs(
    chip_id: Optional[str] = Query(
        default=None,
        description="특정 칩만 보고 싶으면 chip_id 전달",
    ),
    diary_id: Optional[str] = Query(
        default=None,
        description="특정 일기에서 나온 로그만 보고 싶으면 diary_id 전달",
    ),
    start_completed_at: Optional[datetime] = Query(
        default=None,
        description="이 시각 이후 completed_at",
    ),
    end_completed_at: Optional[datetime] = Query(
        default=None,
        description="이 시각 이전 completed_at",
    ),
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]

    # 쿼리 파라미터로 받은 시간도 UTC로 정규화
    safe_start = ensure_utc(start_completed_at) if start_completed_at else None
    safe_end = ensure_utc(end_completed_at) if end_completed_at else None

    query: Dict[str, Any] = {"user_id": user_id}
    if chip_id:
        query["chip_id"] = chip_id

    cursor = collection.find(query, {"real_oddness_logs": 1, "chip_id": 1})
    rows = await cursor.to_list(length=None)

    out: List[RealOddnessLogResponse] = []

    for tag_doc in rows:
        raw_logs = tag_doc.get("real_oddness_logs", []) or []

        for raw in raw_logs:
            serialized = _serialize_real_oddness_log(raw)
            ts = serialized["completed_at"]

            # completed_at이 없으면 필터링에서 제외(스킵)
            if ts is None:
                continue

            if diary_id and serialized["diary_id"] != diary_id:
                continue
            if safe_start and ts < safe_start:
                continue
            if safe_end and ts > safe_end:
                continue

            out.append(RealOddnessLogResponse(**serialized))

    out.sort(key=lambda x: x.completed_at)
    return out


# ---------- Category Logs (+ 일기 컬렉션 category 업데이트) ----------

@router.post(
    "/{chip_id}/category-logs",
    response_model=CategoryLogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="칩에 Category 로그 추가",
)
async def create_category_log(
    chip_id: str,
    payload: CategoryLogsCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    if payload.chip_id != chip_id:
        raise HTTPException(status_code=400, detail="chip_id가 일치하지 않습니다")

    collection = db[CUSTOM_TAG_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    completed_at = ensure_utc(payload.completed_at)

    log_id = f"cat_{uuid.uuid4().hex[:8]}"

    log_doc = {
        "log_id": log_id,
        "diary_id": payload.diary_id,
        "chip_id": chip_id,
        "category": payload.category,         # "anxious" / "healthy"
        "short_term": payload.short_term,     # "confront"/"avoid"/None
        "long_term": payload.long_term,
        "is_changed": payload.is_changed,
        "completed_at": completed_at,
        "created_at": now_utc,
        "updated_at": now_utc,
    }

    # 1) custom_tags 문서에 로그 추가
    result = await collection.update_one(
        {"user_id": user_id, "chip_id": chip_id},
        {
            "$push": {"category_logs": log_doc},
            "$set": {"updated_at": now_utc},
        },
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="태그를 찾을 수 없습니다")

    # 2) diary 컬렉션 내 해당 diary 의 칩 category 동기화
    await update_diary_chip_category(
        db=db,
        user_id=user_id,
        diary_id=payload.diary_id,
        chip_id=chip_id,
        category=payload.category,
    )

    return CategoryLogResponse(**_serialize_category_log(log_doc))


@router.get(
    "/logs/category",
    response_model=List[CategoryLogResponse],
    summary="Category 로그 조회 (chip_id/diary_id/기간 필터)",
)
async def list_category_logs(
    chip_id: Optional[str] = Query(
        default=None,
        description="특정 칩만 보고 싶으면 chip_id 전달",
    ),
    diary_id: Optional[str] = Query(
        default=None,
        description="특정 일기에서 나온 로그만",
    ),
    start_completed_at: Optional[datetime] = Query(
        default=None,
        description="이 시각 이후 completed_at",
    ),
    end_completed_at: Optional[datetime] = Query(
        default=None,
        description="이 시각 이전 completed_at",
    ),
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[CUSTOM_TAG_COLLECTION]

    safe_start = ensure_utc(start_completed_at) if start_completed_at else None
    safe_end = ensure_utc(end_completed_at) if end_completed_at else None

    query: Dict[str, Any] = {"user_id": user_id}
    if chip_id:
        query["chip_id"] = chip_id

    cursor = collection.find(query, {"category_logs": 1, "chip_id": 1})
    rows = await cursor.to_list(length=None)

    out: List[CategoryLogResponse] = []

    for tag_doc in rows:
        raw_logs = tag_doc.get("category_logs", []) or []

        for raw in raw_logs:
            serialized = _serialize_category_log(raw)
            ts = serialized["completed_at"]

            if ts is None:
                continue

            if diary_id and serialized["diary_id"] != diary_id:
                continue
            if safe_start and ts < safe_start:
                continue
            if safe_end and ts > safe_end:
                continue

            out.append(CategoryLogResponse(**serialized))

    out.sort(key=lambda x: x.completed_at)
    return out

