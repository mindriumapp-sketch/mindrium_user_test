import re
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
import uuid
from core.security import get_current_user_id
from core.utils import parse_datetime_value, ensure_utc

from fastapi import APIRouter, Depends, HTTPException, status

from db.mongo import get_db
from pymongo import ReturnDocument
from routers.worry_groups import adjust_group_metrics
from routers.sud_scores import parse_sud_value, serialize_sud, normalize_sud_scores
from schemas.sud import SudScoreResponse
from schemas.diary import (
    # DiaryChip,
    DiaryCreate,
    DiaryUpdate,
    DiaryResponse,
    DiarySummaryResponse,
    AlarmCreate,
    AlarmUpdate,
    AlarmDelete,
    AlarmResponse,
)

router = APIRouter(prefix="/diaries", tags=["diaries"])

DIARY_COLLECTION = "diaries"
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
) -> Dict[str, Any]:
    query: Dict[str, Any] = {"user_id": user_id}
    if group_id is not None:
        query["group_id"] = group_id

    if exclude_auto:
        # activation.label 에 "자동 생성" 이 포함된 문서는 제외
        pattern = re.compile("자동 생성")
        query["activation.label"] = {"$not": pattern}

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


# ---------- 알람 직렬화/정규화 ----------

def _serialize_alarm(doc: dict) -> dict:
    return {
        "alarm_id": doc.get("alarm_id"),
        "time": doc.get("time", ""),
        "location_desc": doc.get("location_desc"),
        "repeat_option": doc.get("repeat_option"),
        "weekdays": doc.get("weekdays", []),
        "reminder_minutes": doc.get("reminder_minutes"),
        "enter": doc.get("enter", False),
        "exit": doc.get("exit", False),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


def _normalize_single_alarm(value: Any, now_utc: datetime) -> Optional[dict]:
    """
    개별 alarm 엔트리 하나를 정규화.
    - dict가 아니면 무시
    - alarm_id / created_at / updated_at 채워 넣기
    """
    if not isinstance(value, dict):
        return None

    doc = dict(value or {})
    doc["alarm_id"] = doc.get("alarm_id") or f"alarm_{uuid.uuid4().hex[:6]}"

    created_raw = doc.get("created_at") or doc.get("updated_at")
    doc["created_at"] = parse_datetime_value(created_raw, fallback=now_utc)
    doc["updated_at"] = parse_datetime_value(doc.get("updated_at"), fallback=now_utc)
    return doc


def _normalize_alarms(raw) -> List[dict]:
    """
    - dict 또는 list 형태로 들어오는 알람 배열을
      내부적으로 일관된 리스트[dict]로 정규화.
    """
    normalized: List[dict] = []
    now_utc = datetime.now(timezone.utc)

    if isinstance(raw, dict):
        iterable = raw.values()
    elif isinstance(raw, list):
        iterable = raw
    else:
        iterable = []

    for value in iterable:
        doc = _normalize_single_alarm(value, now_utc)
        if doc is not None:
            normalized.append(doc)

    normalized.sort(key=lambda d: d["created_at"])
    return normalized


# ---------- 직렬화 (Diary) ----------

def _serialize_diary(doc: dict) -> dict:
    diary_id = doc.get("diary_id")

    return {
        "diary_id": diary_id,
        "group_id": doc.get("group_id"),

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

        # 알람 리스트 -> AlarmResponse 리스트
        "alarms": [
            AlarmResponse(**_serialize_alarm(entry))
            for entry in (doc.get("alarms") or [])
            if isinstance(entry, dict)
        ],

        "latitude": doc.get("latitude"),
        "longitude": doc.get("longitude"),
        "address_name": doc.get("address_name"),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


def _serialize_diary_summary(doc: dict) -> dict:
    return {
        "diary_id": doc.get("diary_id"),
        "group_id": doc.get("group_id"),
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
    client_ts_utc = ensure_utc(payload.client_timestamp)
    group_id = payload.group_id or DEFAULT_GROUP_ID

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

    # 2) DiaryChip 필드들은 dict로 저장
    diary_doc = {
        "user_id": user_id,
        "diary_id": f"diary_{uuid.uuid4().hex[:8]}",
        "group_id": group_id,

        "activation": payload.activation.model_dump(),
        "belief": [chip.model_dump() for chip in payload.belief],
        "consequence_physical": [chip.model_dump() for chip in payload.consequence_physical],
        "consequence_emotion": [chip.model_dump() for chip in payload.consequence_emotion],
        "consequence_action": [chip.model_dump() for chip in payload.consequence_action],

        "sud_scores": sud_entries,
        "latest_sud": latest_sud,
        "alarms": _normalize_alarms(payload.alarms),
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "address_name": payload.address_name,
        "created_at": now_utc,
        "updated_at": now_utc,
        "client_timestamp": client_ts_utc,
    }

    await collection.insert_one(diary_doc)

    # 4) 그룹 카운터 반영
    if group_id and not is_auto_generated:
        await adjust_group_metrics(
            db=db,
            user_id=user_id,
            group_id=group_id,
            diary_delta=1,
            sud_delta=float(latest_sud or 0.0),
        )

    return DiaryResponse(**_serialize_diary(diary_doc))


@router.get("", response_model=List[DiaryResponse])
async def list_diaries(
    group_id: Optional[str] = None,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
    include_auto: bool = False,
):
    """
    전체 일기 목록 (풀 데이터) 반환.
    sud_scores / alarms / alternative_thoughts 포함.
    """
    collection = db[DIARY_COLLECTION]
    query = _build_diary_query(
        user_id=user_id,
        group_id=group_id,
        exclude_auto=not include_auto,
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
    - sud_scores / alarms 등 무거운 배열은 가져오지 않고,
      latest_sud, 주요 텍스트/칩 필드만 포함.
    """
    collection = db[DIARY_COLLECTION]
    query = _build_diary_query(
        user_id=user_id,
        group_id=group_id,
        exclude_auto=not include_auto,
    )

    projection = {
        "diary_id": 1,
        "group_id": 1,
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
    summary_flag: bool = True,
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
    )

    projection = {
        "diary_id": 1,
        "group_id": 1,
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
        exclude={"client_timestamp"},
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    collection = db[DIARY_COLLECTION]

    diary = await collection.find_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "alternative_thoughts": 1,
            "alarms": 1,
            "group_id": 1,
            "latest_sud": 1,
        },
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    old_group_id = diary.get("group_id")
    latest_sud = parse_sud_value(diary.get("latest_sud")) or 0

    new_group_id = update_data.get("group_id", old_group_id)

    set_fields: Dict[str, Any] = {}

    # 1) 알람 들어오면 normalize 후 전체 교체
    if "alarms" in update_data:
        set_fields["alarms"] = _normalize_alarms(update_data.pop("alarms"))

    # 2) 나머지 필드(activation, belief, consequence_*, 좌표 등)는
    #    이미 model_dump 된 dict/list[dict]라 그대로 덮어쓰기
    set_fields.update(update_data)

    # group_id 고정
    set_fields["group_id"] = new_group_id
    set_fields["updated_at"] = now_utc
    set_fields["client_timestamp"] = client_ts_utc

    updated_doc = await collection.find_one_and_update(
        {"diary_id": diary_id, "user_id": user_id},
        {"$set": set_fields},
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

    return DiaryResponse(**_serialize_diary(updated_doc))


# ---------- 알람 서브엔드포인트 ----------

@router.get("/{diary_id}/alarms", response_model=List[AlarmResponse])
async def list_alarms(
    diary_id: str,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    diary = await collection.find_one(
        {"diary_id": diary_id, "user_id": user_id},
        {"alarms": 1},
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    alarms = _normalize_alarms(diary.get("alarms", []))
    return [AlarmResponse(**_serialize_alarm(a)) for a in alarms]


@router.post(
    "/{diary_id}/alarms",
    response_model=AlarmResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_alarm(
    diary_id: str,
    payload: AlarmCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]

    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    alarm_id = f"alarm_{uuid.uuid4().hex[:6]}"
    alarm_doc = {
        "alarm_id": alarm_id,
        "time": payload.time,
        "location_desc": payload.location_desc,
        "repeat_option": payload.repeat_option,
        "weekdays": payload.weekdays,
        "reminder_minutes": payload.reminder_minutes,
        "enter": payload.enter,
        "exit": payload.exit,
        "created_at": now_utc,
        "updated_at": now_utc,
    }

    result = await collection.update_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "$push": {"alarms": alarm_doc},
            "$set": {
                "updated_at": now_utc,
                "client_timestamp": client_ts_utc,
            },
        },
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Diary not found")

    return AlarmResponse(**_serialize_alarm(alarm_doc))


@router.put("/{diary_id}/alarms/{alarm_id}", response_model=AlarmResponse)
async def update_alarm(
    diary_id: str,
    alarm_id: str,
    payload: AlarmUpdate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    update_data = payload.model_dump(
        exclude_unset=True,
        by_alias=True,
        exclude={"client_timestamp"},
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    collection = db[DIARY_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    # $set dot notation으로 업데이트할 필드 맵 생성
    set_fields = {
        f"alarms.$.{key}": value for key, value in update_data.items()
    }
    set_fields["alarms.$.updated_at"] = now_utc
    set_fields["updated_at"] = now_utc
    set_fields["client_timestamp"] = client_ts_utc

    updated_doc = await collection.find_one_and_update(
        {
            "diary_id": diary_id,
            "user_id": user_id,
            "alarms.alarm_id": alarm_id,
        },
        {"$set": set_fields},
        return_document=ReturnDocument.AFTER,
    )

    if not updated_doc:
        raise HTTPException(status_code=404, detail="Diary or Alarm not found")

    updated_alarm = next(
        (a for a in updated_doc.get("alarms", []) if a.get("alarm_id") == alarm_id),
        None,
    )

    if updated_alarm is None:
        raise HTTPException(status_code=500, detail="Updated alarm not found in document")

    return AlarmResponse(**_serialize_alarm(updated_alarm))


@router.delete("/{diary_id}/alarms/{alarm_id}", status_code=status.HTTP_200_OK)
async def delete_alarm(
    diary_id: str,
    alarm_id: str,
    payload: AlarmDelete,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    result = await collection.update_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "$pull": {"alarms": {"alarm_id": alarm_id}},
            "$set": {
                "updated_at": now_utc,
                "client_timestamp": client_ts_utc,
            },
        },
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Diary not found")

    return {
        "client_timestamp": client_ts_utc,
        "deleted_at": now_utc,
    }

@router.delete("/{diary_id}/alarms", status_code=status.HTTP_200_OK)
async def delete_alarms(
        diary_id: str,
        payload: AlarmDelete,
        db=Depends(get_db),
        user_id: str = Depends(get_current_user_id),
):
    collection = db[DIARY_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(payload.client_timestamp)

    result = await collection.update_one(
        {"diary_id": diary_id, "user_id": user_id},
        {
            "$set": {
                "alarms": [],
                "updated_at": now_utc,
                "client_timestamp": client_ts_utc,
            },
        },
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Diary not found")

    return {
        "client_timestamp": client_ts_utc,
        "deleted_at": now_utc,
    }
