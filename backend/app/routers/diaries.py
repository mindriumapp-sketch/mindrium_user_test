import re
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any
import uuid
from core.security import get_current_user_id
from core.today_task_draft_progress import (
    COMPLETED_DRAFT_PROGRESS,
    TODAY_TASK_ROUTE,
    completed_draft_progress_filter,
    is_incomplete_draft_progress,
)
from core.utils import kst_midnight, parse_datetime_value, ensure_utc

from fastapi import APIRouter, Depends, HTTPException, status

from db.mongo import get_db
from pymongo import ReturnDocument
from routers.treatment_progress import _find_active_progress, _refresh_requirements_met
from routers.worry_groups import adjust_group_metrics
from routers.sud_scores import parse_sud_value, serialize_sud, normalize_sud_scores
from schemas.sud import SudScoreResponse
from schemas.diary import (
    # DiaryChip,
    DiaryCreate,
    DiaryUpdate,
    DiaryResponse,
    DiarySummaryResponse,
    LocTimeUpdate,
    LocTimeDelete,
    LocTimeResponse,
)

router = APIRouter(prefix="/diaries", tags=["diaries"])

DIARY_COLLECTION = "diaries"
TREATMENT_PROGRESS_COLLECTION = "treatment_progress"
DEFAULT_GROUP_ID = "group_example"

# ---------- 공통 헬퍼 ----------
async def update_diary_chip_category(
    db,
    user_id: str,
    diary_id: str,
    chip_id: str,
    category: str,  # "anxious" / "healthy"
) -> None:
    """
    특정 diary 안에서 chip_id에 해당하는 칩들의 category를 업데이트.
    - belief[]
    - consequence_physical[]
    - consequence_emotion[]
    - consequence_action[]
    (activation은 여기선 안 건드린다고 가정)
    """
    now_utc = datetime.now(timezone.utc)

    collection = db[DIARY_COLLECTION]

    result = await collection.update_one(
        {
            "user_id": user_id,
            "diary_id": diary_id,
        },
        {
            "$set": {
                "belief.$[b].category": category,
                "consequence_physical.$[cp].category": category,
                "consequence_emotion.$[ce].category": category,
                "consequence_action.$[ca].category": category,
                "updated_at": now_utc,
            }
        },
        array_filters=[
            {"b.chip_id": chip_id},
            {"cp.chip_id": chip_id},
            {"ce.chip_id": chip_id},
            {"ca.chip_id": chip_id},
        ],
    )

    if result.matched_count == 0:
        print(f"[WARN] diary not found or chip_id not present: {diary_id}, {chip_id}")


def _build_diary_query(
        user_id: str,
        group_id: Optional[str] = None,
        exclude_auto: bool = False,
        include_drafts: bool = False,
) -> Dict[str, Any]:
    query: Dict[str, Any] = {"user_id": user_id}
    if group_id is not None:
        query["group_id"] = group_id

    if exclude_auto:
        # activation.label 에 "자동 생성" 이 포함된 문서는 제외
        pattern = re.compile("자동 생성")
        query["activation.label"] = {"$not": pattern}

    if not include_drafts:
        query["$or"] = [
            {"draft_progress": {"$exists": False}},
            {"draft_progress": completed_draft_progress_filter()},
        ]

    return query


def _today_task_incomplete_draft_query(
    user_id: str,
    *,
    diary_id: Optional[str] = None,
    limit_to_today: bool = False,
    now_utc: Optional[datetime] = None,
) -> Dict[str, Any]:
    query: Dict[str, Any] = {
        "user_id": user_id,
        "route": TODAY_TASK_ROUTE,
        "draft_progress": {"$lt": COMPLETED_DRAFT_PROGRESS},
    }

    if diary_id:
        query["diary_id"] = diary_id

    if limit_to_today:
        reference_time = now_utc or datetime.now(timezone.utc)
        today_start_kst = kst_midnight(reference_time)
        today_end_kst = today_start_kst + timedelta(days=1)
        query["created_at"] = {
            "$gte": today_start_kst.astimezone(timezone.utc),
            "$lt": today_end_kst.astimezone(timezone.utc),
        }

    return query

def _is_auto_generated_from_activation(payload: DiaryCreate) -> bool:
    """
    별도 플래그 없이 activation.label 안에 '자동 생성' 문구로만 판단.
    """
    activation = getattr(payload, "activation", None)
    if activation is None:
        return False

    # Pydantic 모델일 테니까 .label 접근
    label = getattr(activation, "label", "") or ""
    return "자동 생성" in label  # 포함 여부만 체크


def merge_unique_str_list(
    existing_raw: Optional[List[Any]],
    incoming_raw: Optional[List[Any]],
) -> List[str]:
    """
    문자열 리스트 2개를 병합하면서:
    - 기존 순서 유지
    - 중복 제거
    - None / 비문자 타입은 str()로 캐스팅해서 처리
    """
    result: List[str] = []
    seen: set[str] = set()

    # 기존 값 먼저
    if existing_raw:
        for item in existing_raw:
            if item is None:
                continue
            s = str(item)
            if s not in seen:
                seen.add(s)
                result.append(s)

    # 새 값 뒤에
    if incoming_raw:
        for item in incoming_raw:
            if item is None:
                continue
            s = str(item)
            if s not in seen:
                seen.add(s)
                result.append(s)

    return result


def _read_float(raw: Any) -> Optional[float]:
    try:
        return float(raw)
    except Exception:
        return None


# ---------- DiaryChip 직렬화 ----------

def _serialize_chip(raw: Any) -> Optional[dict]:
    """
    DB에 저장된 activation 같은 chip 필드를
    DiaryChip에 맞는 dict로 정리.
    (이미 dict로 저장돼 있다고 가정하되, 혹시 string 들어오면 label로 처리)
    """
    if raw is None:
        return None

    if isinstance(raw, dict):
        label = raw.get("label") or ""
        if not label:
            return None
        return {
            "label": label,
            "chip_id": raw.get("chip_id"),
            "category": raw.get("category"),
        }

    # 혹시 string 등으로 들어온 이전 데이터 대비 (마이그레이션 신경 최소화)
    label = str(raw)
    if not label:
        return None
    return {"label": label, "chip_id": None, "category": None}


def _serialize_chip_list(raw: Any) -> List[dict]:
    items = raw or []
    out: List[dict] = []
    if not isinstance(items, list):
        # 혹시 단일 값 들어오면 리스트로 감싸기
        items = [items]

    for item in items:
        chip = _serialize_chip(item)
        if chip is not None:
            out.append(chip)
    return out


# ---------- 위치/시간 직렬화/정규화 ----------

def _serialize_loc_time(doc: dict) -> dict:
    return {
        "id": doc.get("id") or doc.get("alarm_id"),
        "time": doc.get("time", ""),
        "location": (
            doc.get("location")
            or doc.get("location_label")
            or doc.get("location_desc")
        ),
        "location_desc": doc.get("location_desc"),
        "latitude": doc.get("latitude"),
        "longitude": doc.get("longitude"),
    }


def _normalize_single_loc_time(value: Any) -> Optional[dict]:
    """
    개별 loc_time 엔트리 하나를 정규화.
    - dict가 아니면 무시
    - 이전 alarm_id/location_desc 형태도 자동 변환
    """
    if not isinstance(value, dict):
        return None

    doc = dict(value or {})
    loc_time_id = doc.get("id") or doc.get("alarm_id") or f"loc_time_{uuid.uuid4().hex[:6]}"
    time_value = doc.get("time")
    location_desc = doc.get("location_desc") or doc.get("description")
    location_value = doc.get("location") or doc.get("location_label") or location_desc
    latitude = _read_float(doc.get("latitude"))
    longitude = _read_float(doc.get("longitude"))

    normalized = {
        "id": str(loc_time_id),
        "time": time_value,
        "location": location_value,
        "location_desc": location_desc,
        "latitude": latitude,
        "longitude": longitude,
    }
    return {k: v for k, v in normalized.items() if v is not None}


def _normalize_loc_time(raw) -> Optional[dict]:
    """
    loc_time를 단일 객체로 정규화.
    - dict면 그대로 정규화
    - list면 마지막 유효 엔트리 1개만 선택
    - 이전 alarms(dict/list) 구조도 자동 변환
    """
    if isinstance(raw, dict):
        if {"id", "alarm_id", "time", "location", "location_desc"} & set(raw.keys()):
            return _normalize_single_loc_time(raw)
        for value in reversed(list(raw.values())):
            doc = _normalize_single_loc_time(value)
            if doc is not None:
                return doc
        return None

    if isinstance(raw, list):
        for value in reversed(raw):
            doc = _normalize_single_loc_time(value)
            if doc is not None:
                return doc
        return None

    return None


# ---------- 직렬화 (Diary) ----------

def _serialize_diary(doc: dict) -> dict:
    diary_id = doc.get("diary_id")
    normalized_loc_time = _normalize_loc_time(doc.get("loc_time", doc.get("alarms", [])))

    return {
        "diary_id": diary_id,
        "group_id": doc.get("group_id"),
        "route": doc.get("route"),
        "draft_progress": doc.get("draft_progress"),

        # DiaryChip 구조 필드들
        "activation": _serialize_chip(doc.get("activation")),
        "belief": _serialize_chip_list(doc.get("belief")),
        "consequence_physical": _serialize_chip_list(doc.get("consequence_physical")),
        "consequence_emotion": _serialize_chip_list(doc.get("consequence_emotion")),
        "consequence_action": _serialize_chip_list(doc.get("consequence_action")),

        "latest_sud": parse_sud_value(doc.get("latest_sud")),

        # SUD 리스트 -> SudScoreResponse 리스트
        "sud_scores": [
            SudScoreResponse(
                **serialize_sud(entry, diary_id=diary_id)
            )
            for entry in (doc.get("sud_scores", []))
            if isinstance(entry, dict)
        ],

        "alternative_thoughts": doc.get("alternative_thoughts", []),

        "loc_time": (
            LocTimeResponse(**_serialize_loc_time(normalized_loc_time))
            if isinstance(normalized_loc_time, dict)
            else None
        ),
        "loc_auto_filled": doc.get("loc_auto_filled", False),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


def _serialize_diary_summary(doc: dict) -> dict:
    return {
        "diary_id": doc.get("diary_id"),
        "group_id": doc.get("group_id"),
        "route": doc.get("route"),
        "draft_progress": doc.get("draft_progress"),
        "activation": _serialize_chip(doc.get("activation")),
        "belief": _serialize_chip_list(doc.get("belief")),
        "consequence_physical": _serialize_chip_list(doc.get("consequence_physical")),
        "consequence_emotion": _serialize_chip_list(doc.get("consequence_emotion")),
        "consequence_action": _serialize_chip_list(doc.get("consequence_action")),
        "latest_sud": parse_sud_value(doc.get("latest_sud")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


# ---------- 엔드포인트 ----------

@router.post("", response_model=DiaryResponse, status_code=status.HTTP_201_CREATED)
async def create_diary(
    payload: DiaryCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    is_incomplete_draft = is_incomplete_draft_progress(payload.draft_progress)
    group_id = (
        payload.group_id
        if is_incomplete_draft
        else (payload.group_id or DEFAULT_GROUP_ID)
    )

    is_auto_generated = _is_auto_generated_from_activation(payload)

    # 1) SUD 리스트 정규화
    sud_entries = normalize_sud_scores(payload.sud_scores)
    latest_sud = None
    if sud_entries:
        last = sud_entries[-1]
        latest_sud = parse_sud_value(
            last.get("after_sud")
            if last.get("after_sud") is not None
            else last.get("before_sud")
        )

    loc_time_doc = _normalize_loc_time(payload.loc_time)

    # 2) DiaryChip 필드들은 dict로 저장
    diary_doc = {
        "user_id": user_id,
        "diary_id": f"diary_{uuid.uuid4().hex[:8]}",
        "group_id": group_id,
        "route": payload.route,

        "activation": payload.activation.model_dump(),
        "belief": [chip.model_dump() for chip in payload.belief],
        "consequence_physical": [chip.model_dump() for chip in payload.consequence_physical],
        "consequence_emotion": [chip.model_dump() for chip in payload.consequence_emotion],
        "consequence_action": [chip.model_dump() for chip in payload.consequence_action],

        "sud_scores": sud_entries,
        "latest_sud": latest_sud,
        "loc_time": loc_time_doc,
        "loc_auto_filled": payload.loc_auto_filled,
        "created_at": now_utc,
        "updated_at": now_utc,
    }
    if payload.draft_progress is not None:
        diary_doc["draft_progress"] = payload.draft_progress

    await collection.insert_one(diary_doc)

    # 4) 그룹 카운터 반영
    if group_id and not is_auto_generated and not is_incomplete_draft:
        await adjust_group_metrics(
            db=db,
            user_id=user_id,
            group_id=group_id,
            diary_delta=1,
            sud_delta=float(latest_sud or 0.0),
        )

    if (
        payload.route == TODAY_TASK_ROUTE
        and payload.draft_progress == completed_draft_progress_filter()
    ):
        await _sync_treatment_progress_daily_diary(
            db=db,
            user_id=user_id,
            synced_at=now_utc,
        )

    return DiaryResponse(**_serialize_diary(diary_doc))


@router.get("", response_model=List[DiaryResponse])
async def list_diaries(
    group_id: Optional[str] = None,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
    include_auto: bool = False,
    include_drafts: bool = False,
):
    """
    전체 일기 목록 (풀 데이터) 반환.
    sud_scores / loc_time / alternative_thoughts 포함.
    """
    collection = db[DIARY_COLLECTION]
    query = _build_diary_query(
        user_id=user_id,
        group_id=group_id,
        exclude_auto=not include_auto,
        include_drafts=include_drafts,
    )

    cursor = collection.find(query).sort("created_at", -1)

    diaries: List[DiaryResponse] = []
    async for doc in cursor:
        diaries.append(DiaryResponse(**_serialize_diary(doc)))
    return diaries


@router.get("/summaries", response_model=List[DiarySummaryResponse])
async def list_diary_summaries(
    group_id: Optional[str] = None,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
    include_auto: bool = False,
):
    """
    일기 목록 요약용 엔드포인트.
    - 리스트 화면 / 히스토리 타일 등에서 사용.
    - sud_scores / loc_time 등 무거운 배열은 가져오지 않고,
      latest_sud, 주요 텍스트/칩 필드만 포함.
    """
    collection = db[DIARY_COLLECTION]
    query = _build_diary_query(
        user_id=user_id,
        group_id=group_id,
        exclude_auto=not include_auto,
        include_drafts=False,
    )

    projection = {
        "diary_id": 1,
        "group_id": 1,
        "draft_progress": 1,
        "activation": 1,
        "belief": 1,
        "consequence_physical": 1,
        "consequence_emotion": 1,
        "consequence_action": 1,
        "created_at": 1,
        "updated_at": 1,
        "latest_sud": 1,
    }

    cursor = collection.find(query, projection=projection).sort("created_at", -1)

    diaries: List[DiarySummaryResponse] = []
    async for doc in cursor:
        diaries.append(DiarySummaryResponse(**_serialize_diary_summary(doc)))
    return diaries


@router.get("/latest", response_model=DiaryResponse)
async def get_latest_diary(
    group_id: Optional[str] = None,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
    include_auto: bool = False,
):
    """
    최신(가장 최근 created_at) 일기 반환
    """
    collection = db[DIARY_COLLECTION]
    query = _build_diary_query(
        user_id=user_id,
        group_id=group_id,
        exclude_auto=not include_auto,
        include_drafts=False,
    )

    projection = {
        "diary_id": 1,
        "group_id": 1,
        "draft_progress": 1,
        "activation": 1,
        "belief": 1,
        "consequence_physical": 1,
        "consequence_emotion": 1,
        "consequence_action": 1,
        "created_at": 1,
        "updated_at": 1,
        "latest_sud": 1,
    }

    doc = await collection.find_one(query, projection=projection, sort=[("created_at", -1)])
    if not doc:
        raise HTTPException(status_code=404, detail="No diaries")

    return DiarySummaryResponse(**_serialize_diary(doc))


@router.get("/today-task", response_model=List[DiaryResponse])
async def list_today_task_diaries(
    start_at: Optional[datetime] = None,
    end_at: Optional[datetime] = None,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    route=today_task 인 일기 중에서 기간(created_at)으로 필터링한
    전체 일기 정보를 반환.
    """
    start_utc = ensure_utc(start_at)
    end_utc = ensure_utc(end_at)
    if start_utc and end_utc and start_utc > end_utc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_at must be less than or equal to end_at",
        )

    query: Dict[str, Any] = {
        "user_id": user_id,
        "route": TODAY_TASK_ROUTE,
    }
    if start_utc or end_utc:
        created_range: Dict[str, Any] = {}
        if start_utc:
            created_range["$gte"] = start_utc
        if end_utc:
            created_range["$lte"] = end_utc
        query["created_at"] = created_range

    cursor = db[DIARY_COLLECTION].find(query).sort("created_at", 1)
    diaries: List[DiaryResponse] = []
    async for doc in cursor:
        diaries.append(DiaryResponse(**_serialize_diary(doc)))
    return diaries


async def _find_completed_daily_diaries_by_period(
    *,
    db,
    user_id: str,
    start_at: datetime,
    end_at: datetime,
) -> List[DiaryResponse]:
    """
    route=today_task 이고 기간 내(created_at 기준) 완료된(draft_progress=100) 일기 조회.
    """
    collection = db[DIARY_COLLECTION]
    start_utc = ensure_utc(start_at) or start_at
    end_utc = ensure_utc(end_at) or end_at

    query = {
        "user_id": user_id,
        "route": TODAY_TASK_ROUTE,
        "draft_progress": completed_draft_progress_filter(),
        "created_at": {
            "$gte": start_utc,
            "$lte": end_utc,
        },
    }

    cursor = collection.find(query).sort("created_at", -1)
    diaries: List[DiaryResponse] = []
    async for doc in cursor:
        diaries.append(DiaryResponse(**_serialize_diary(doc)))
    return diaries


async def _sync_treatment_progress_daily_diary(
    *,
    db,
    user_id: str,
    synced_at: datetime,
) -> None:
    progress_collection = db[TREATMENT_PROGRESS_COLLECTION]
    progress = await _find_active_progress(
        collection=progress_collection,
        user_id=user_id,
        projection={
            "user_id": 1,
            "week_number": 1,
            "started_at": 1,
            "completed_at": 1,
            "daily_diary_count": 1,
            "main_completed": 1,
            "daily_relax_count": 1,
        },
    )
    if not progress:
        return

    started_at = parse_datetime_value(progress.get("started_at"))
    synced_utc = ensure_utc(synced_at) or synced_at
    if started_at is None or synced_utc < started_at or progress.get("completed_at") is not None:
        return

    progress = await progress_collection.find_one_and_update(
        {"user_id": user_id, "week_number": int(progress["week_number"])},
        {
            "$set": {
                "daily_diary_count": int(progress.get("daily_diary_count") or 0) + 1,
                "updated_at": datetime.now(timezone.utc),
            }
        },
        return_document=ReturnDocument.AFTER,
    )
    if progress:
        await _refresh_requirements_met(
            db=db,
            collection=progress_collection,
            progress_doc=progress,
            synced_at=synced_utc,
        )


@router.get("/completed/daily-task", response_model=List[DiaryResponse])
async def list_completed_daily_diaries(
    start_at: datetime,
    end_at: datetime,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    start_utc = ensure_utc(start_at) or start_at
    end_utc = ensure_utc(end_at) or end_at
    if start_utc > end_utc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_at must be less than or equal to end_at",
        )

    return await _find_completed_daily_diaries_by_period(
        db=db,
        user_id=user_id,
        start_at=start_utc,
        end_at=end_utc,
    )


@router.get("/today-task/latest-draft", response_model=Optional[DiaryResponse])
async def get_latest_today_task_draft(
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    doc = await collection.find_one(
        _today_task_incomplete_draft_query(
            user_id,
            limit_to_today=True,
        ),
        sort=[("updated_at", -1), ("created_at", -1)],
    )

    if not doc:
        return None

    return DiaryResponse(**_serialize_diary(doc))


@router.delete("/{diary_id}/draft", status_code=status.HTTP_204_NO_CONTENT)
async def delete_incomplete_today_task_draft(
    diary_id: str,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    result = await collection.delete_one(
        _today_task_incomplete_draft_query(user_id, diary_id=diary_id)
    )

    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Draft diary not found")

    return None


@router.get("/{diary_id}", response_model=DiaryResponse)
async def get_diary(
    diary_id: str,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    diary = await collection.find_one({"diary_id": diary_id, "user_id": user_id})
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")
    return DiaryResponse(**_serialize_diary(diary))


@router.put("/{diary_id}", response_model=DiaryResponse)
async def update_diary(
    diary_id: str,
    payload: DiaryUpdate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    update_data = payload.model_dump(
        exclude_unset=True,
        by_alias=True,
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    collection = db[DIARY_COLLECTION]

    diary = await collection.find_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "alternative_thoughts": 1,
            "loc_time": 1,
            "alarms": 1,
            "group_id": 1,
            "latest_sud": 1,
            "route": 1,
            "draft_progress": 1,
        },
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    now_utc = datetime.now(timezone.utc)
    old_group_id = diary.get("group_id")
    latest_sud = parse_sud_value(diary.get("latest_sud")) or 0

    new_group_id = update_data.get("group_id", old_group_id)

    set_fields: Dict[str, Any] = {}
    unset_fields: Dict[str, str] = {}

    # 1) loc_time 들어오면 normalize 후 전체 교체
    if "loc_time" in update_data:
        set_fields["loc_time"] = _normalize_loc_time(update_data.pop("loc_time"))
        unset_fields["alarms"] = ""

    # 2) 나머지 필드(activation, belief, consequence_*, 좌표 등)는
    #    이미 model_dump 된 dict/list[dict]라 그대로 덮어쓰기
    if "alternative_thoughts" in update_data:
        update_data["alternative_thoughts"] = merge_unique_str_list(
            diary.get("alternative_thoughts"),
            update_data.get("alternative_thoughts"),
        )
    if "draft_progress" in update_data and update_data["draft_progress"] is None:
        update_data.pop("draft_progress", None)
        unset_fields["draft_progress"] = ""

    set_fields.update(update_data)

    # group_id 고정
    set_fields["group_id"] = new_group_id
    set_fields["updated_at"] = now_utc

    update_query: Dict[str, Any] = {"$set": set_fields}
    if unset_fields:
        update_query["$unset"] = unset_fields

    updated_doc = await collection.find_one_and_update(
        {"diary_id": diary_id, "user_id": user_id},
        update_query,
        return_document=ReturnDocument.AFTER,
    )

    if not updated_doc:
        raise HTTPException(status_code=404, detail="Diary not found (race condition)")

    if old_group_id != new_group_id:
        if old_group_id:
            await adjust_group_metrics(
                db=db,
                user_id=user_id,
                group_id=old_group_id,
                diary_delta=-1,
                sud_delta=-float(latest_sud),
            )
        if new_group_id:
            await adjust_group_metrics(
                db=db,
                user_id=user_id,
                group_id=new_group_id,
                diary_delta=1,
                sud_delta=float(latest_sud),
            )

    old_draft_progress = diary.get("draft_progress")
    if (
        updated_doc.get("route") == TODAY_TASK_ROUTE
        and updated_doc.get("draft_progress") == completed_draft_progress_filter()
        and old_draft_progress != completed_draft_progress_filter()
    ):
        await _sync_treatment_progress_daily_diary(
            db=db,
            user_id=user_id,
            synced_at=now_utc,
        )

    return DiaryResponse(**_serialize_diary(updated_doc))


# ---------- 위치/시간 서브엔드포인트 ----------


@router.get("/{diary_id}/loc_time", response_model=Optional[LocTimeResponse])
async def get_loc_time(
    diary_id: str,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    diary = await collection.find_one(
        {"diary_id": diary_id, "user_id": user_id},
        {"loc_time": 1, "alarms": 1},
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    normalized = _normalize_loc_time(diary.get("loc_time", diary.get("alarms", [])))
    if normalized is None:
        return None
    return LocTimeResponse(**_serialize_loc_time(normalized))


@router.put("/{diary_id}/loc_time", response_model=LocTimeResponse)
async def upsert_loc_time(
    diary_id: str,
    payload: LocTimeUpdate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    update_data = payload.model_dump(
        exclude_unset=True,
        by_alias=True,
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    collection = db[DIARY_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    existing = await collection.find_one(
        {"diary_id": diary_id, "user_id": user_id},
        {"loc_time": 1, "alarms": 1},
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Diary not found")

    current = _normalize_loc_time(existing.get("loc_time", existing.get("alarms", [])))
    loc_time_doc = {
        "id": (current.get("id") if current else None) or f"loc_time_{uuid.uuid4().hex[:6]}",
        "time": update_data.get("time", current.get("time") if current else None),
        "location": update_data.get(
            "location",
            current.get("location") if current else None,
        ),
        "location_desc": update_data.get(
            "location_desc",
            current.get("location_desc") if current else None,
        ),
        "latitude": _read_float(
            update_data.get(
                "latitude",
                current.get("latitude") if current else None,
            )
        ),
        "longitude": _read_float(
            update_data.get(
                "longitude",
                current.get("longitude") if current else None,
            )
        ),
    }
    loc_time_doc = {k: v for k, v in loc_time_doc.items() if v is not None}

    await collection.update_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "$set": {
                "loc_time": loc_time_doc,
                "updated_at": now_utc,
            },
            "$unset": {
                "alarms": "",
            },
        },
    )

    return LocTimeResponse(**_serialize_loc_time(loc_time_doc))


@router.delete("/{diary_id}/loc_time", status_code=status.HTTP_200_OK)
async def delete_loc_time(
    diary_id: str,
    payload: LocTimeDelete,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    result = await collection.update_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "$set": {
                "loc_time": None,
                "updated_at": now_utc,
            },
            "$unset": {
                "alarms": "",
            },
        },
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Diary not found")

    return {
        "deleted_at": now_utc,
    }
