from datetime import datetime, date, timedelta, timezone
from typing import List, Optional, Any, Dict, Tuple

from fastapi import APIRouter, Depends, HTTPException, status, Query
from pymongo import ReturnDocument

from core.security import get_current_user_id
from core.utils import (
    parse_datetime_value,
    ensure_utc,
    KST,
    kst_midnight,
    to_obj_id,
)
from db.mongo import get_db
from schemas.relaxation import (
    RelaxationLogEntry,
    RelaxationTaskCreate,
    RelaxationTaskResponse,
    RelaxationScoreUpdate,
    RelaxationTimeSummary,
    RelaxationTaskTimeSummary,
)

router = APIRouter(prefix="/relaxation_tasks", tags=["relaxation_tasks"])

RELAX_COLLECTION = "relaxation_tasks"


# =========================================================
# 헬퍼 함수
# =========================================================

def _serialize_task(doc: dict) -> dict:
    """Mongo 도큐먼트를 API 응답 형태로 변환."""
    start_utc = parse_datetime_value(doc.get("start_time"))
    end_utc = parse_datetime_value(doc.get("end_time"))
    logs_data = doc.get("logs") or []

    return {
        # Mongo _id(ObjectId)를 문자열로 노출
        "relax_id": str(doc["_id"]),
        "task_id": doc.get("task_id"),
        "week_number": doc.get("week_number"),
        "start_time": start_utc,
        "end_time": end_utc,
        "logs": [
            RelaxationLogEntry(
                action=entry.get("action"),
                timestamp=parse_datetime_value(entry.get("timestamp")),
                elapsed_seconds=int(entry.get("elapsed_seconds", 0)),
            )
            for entry in logs_data
            if isinstance(entry, dict)
        ],
        "latitude": doc.get("latitude"),
        "longitude": doc.get("longitude"),
        "address_name": doc.get("address_name"),
        "duration_seconds": doc.get("duration_seconds"),
        "relaxation_score": doc.get("relaxation_score"),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


def _compute_net_duration_seconds(logs: List[RelaxationLogEntry]) -> int:
    """
    logs에 담긴 elapsed_seconds와 action을 이용해서
    'pause ~ resume 사이 구간'은 제외한 net duration(초)을 계산.

    규칙:
    - elapsed_seconds: 세션 시작(t=0)으로부터 해당 이벤트까지 지난 초
    - 기본 상태: 처음엔 '재생 중(running)' 상태라고 가정
    - pause: 이후부터는 '일시 정지(paused)' 상태
    - resume: 이후부터는 다시 '재생 중(running)' 상태
    - 그 외 action들은 상태만 안 바꾸고 단순 이벤트로 취급
    """
    if not logs:
        return 0

    ordered = sorted(logs, key=lambda e: e.elapsed_seconds)

    net = 0
    last_elapsed = 0
    paused = False  # 처음엔 running 상태

    for entry in ordered:
        cur = max(0, int(entry.elapsed_seconds))
        if cur < last_elapsed:
            # 시간 역행하는 이상한 로그는 무시
            continue

        if not paused:
            net += cur - last_elapsed

        if entry.action == "pause":
            paused = True
        elif entry.action == "resume":
            paused = False

        last_elapsed = cur

    return max(net, 0)


def _build_kst_day_range(date_kst: date) -> Tuple[datetime, datetime]:
    """
    KST 기준 하루의 시작/끝을 UTC로 변환해서 반환.
    """
    day_start_kst = datetime(date_kst.year, date_kst.month, date_kst.day, tzinfo=KST)
    day_end_kst = day_start_kst + timedelta(days=1)
    return (
        day_start_kst.astimezone(timezone.utc),
        day_end_kst.astimezone(timezone.utc),
    )


def _build_task_match(
    *,
    user_id: str,
    week_number: Optional[int] = None,
    task_id: Optional[str] = None,
    date_kst: Optional[date] = None,
    require_positive_duration: bool = True,
) -> Dict[str, Any]:
    """
    요약/리스트 공통으로 사용하는 Mongo match 조건 빌더.
    """
    match: Dict[str, Any] = {"user_id": user_id}

    if require_positive_duration:
        match["duration_seconds"] = {"$gt": 0}

    if week_number is not None:
        match["week_number"] = int(week_number)
    if task_id is not None:
        match["task_id"] = task_id

    if date_kst is not None:
        day_start_utc, day_end_utc = _build_kst_day_range(date_kst)
        match["start_time"] = {"$gte": day_start_utc, "$lt": day_end_utc}

    return match


async def _find_relaxation_tasks(
    *,
    db,
    user_id: str,
    week_number: Optional[int] = None,
    task_id: Optional[str] = None,
    date_kst: Optional[date] = None,
    log_flag: bool = False,
    limit: Optional[int] = None,
    offset: int = 0,
) -> List[RelaxationTaskResponse]:
    """
    공통 리스트 조회 헬퍼:
    - duration_seconds > 0 필터 기본 적용
    - week_number / task_id / date_kst 조합 필터
    - logs 포함 여부(log_flag)에 따라 projection 제어
    """
    collection = db[RELAX_COLLECTION]

    match = _build_task_match(
        user_id=user_id,
        week_number=week_number,
        task_id=task_id,
        date_kst=date_kst,
        require_positive_duration=True,
    )

    projection: Optional[dict] = {"logs": 0} if not log_flag else None

    cursor = (
        collection.find(match, projection=projection)
        .sort("start_time", -1)
    )

    if offset:
        cursor = cursor.skip(offset)
    if limit is not None:
        cursor = cursor.limit(limit)

    tasks: List[RelaxationTaskResponse] = []
    async for doc in cursor:
        tasks.append(RelaxationTaskResponse(**_serialize_task(doc)))

    return tasks


# =========================================================
# Endpoints
# =========================================================

@router.post(
    "",
    response_model=RelaxationTaskResponse,
    status_code=status.HTTP_201_CREATED,
    summary="이완 세션 로그 생성 (별도 컬렉션)",
)
async def create_relaxation_task(
    payload: RelaxationTaskCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    이완 세션 로그를 저장합니다.
    - 필드 이름은 전부 Flutter 쪽에서 쓰는 그대로:
      - relax_id, task_id, week_number, start_time, end_time, logs[…]
      - latitude, longitude, address_name, duration_seconds (optional)
    """
    collection = db[RELAX_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    start_utc = ensure_utc(payload.start_time)
    end_utc = ensure_utc(payload.end_time) if payload.end_time is not None else None
    duration_seconds = _compute_net_duration_seconds(payload.logs)

    log_doc = {
        "user_id": user_id,
        "task_id": payload.task_id,
        "week_number": payload.week_number,
        "start_time": start_utc,
        "end_time": end_utc,
        "logs": [
            {
                "action": entry.action,
                "timestamp": ensure_utc(entry.timestamp),
                "elapsed_seconds": entry.elapsed_seconds,
            }
            for entry in payload.logs
        ],
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "address_name": payload.address_name,
        "duration_seconds": duration_seconds,
        "relaxation_score": None,
        "created_at": now_utc,
        "updated_at": now_utc,
    }

    result = await collection.insert_one(log_doc)
    log_doc["_id"] = result.inserted_id

    return RelaxationTaskResponse(**_serialize_task(log_doc))

@router.put(
    "/{relax_id}",
    response_model=RelaxationTaskResponse,
    summary="이완 세션 로그 업데이트 (한 세션당 upsert처럼 사용)",
)
async def update_relaxation_task(
        relax_id: str,
        payload: RelaxationTaskCreate,
        user_id: str = Depends(get_current_user_id),
        db=Depends(get_db),
):
    """
    한 세션에서 여러 번 저장할 때 사용하는 로그 전체 업데이트 엔드포인트.

    - relax_id 기준으로 기존 도큐먼트를 찾고
    - logs / start_time / end_time / duration_seconds / 위치 정보 / week_number / task_id 갱신
    - created_at은 유지, updated_at만 now로 변경
    """
    collection = db[RELAX_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    obj_id = to_obj_id(relax_id)

    start_utc = ensure_utc(payload.start_time)
    end_utc = ensure_utc(payload.end_time) if payload.end_time is not None else None
    duration_seconds = _compute_net_duration_seconds(payload.logs)

    update_doc = {
        "task_id": payload.task_id,
        "week_number": payload.week_number,
        "start_time": start_utc,
        "end_time": end_utc,
        "logs": [
            {
                "action": entry.action,
                "timestamp": ensure_utc(entry.timestamp),
                "elapsed_seconds": entry.elapsed_seconds,
            }
            for entry in payload.logs
        ],
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "address_name": payload.address_name,
        "duration_seconds": duration_seconds,
        "updated_at": now_utc,
    }

    result = await collection.find_one_and_update(
        {"_id": obj_id, "user_id": user_id},
        {"$set": update_doc},
        return_document=ReturnDocument.AFTER,
    )

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Relaxation session not found",
        )

    return RelaxationTaskResponse(**_serialize_task(result))


@router.patch(
    "/{relax_id}/score",
    response_model=RelaxationTaskResponse,
    summary="이완 점수(relaxation_score) 업데이트 (별도 컬렉션)",
)
async def update_relaxation_score(
    relax_id: str,
    payload: RelaxationScoreUpdate,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    다른 화면에서 측정한 이완 점수(relaxation_score)를 업데이트합니다.
    - path param의 `relax_id`와 일치하는 세션을 찾고, relaxation_score만 변경.
    """
    collection = db[RELAX_COLLECTION]
    obj_id = to_obj_id(relax_id)
    now_utc = datetime.now(timezone.utc)

    result = await collection.find_one_and_update(
        {"_id": obj_id, "user_id": user_id},
        {
            "$set": {
                "relaxation_score": payload.relaxation_score,
                "updated_at": now_utc,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Relaxation session not found",
        )

    return RelaxationTaskResponse(**_serialize_task(result))


@router.get(
    "",
    response_model=List[RelaxationTaskResponse],
    summary="이완 세션 로그 목록 조회 (별도 컬렉션)",
)
async def list_relaxation_tasks(
    week_number: Optional[int] = None,
    task_id: Optional[str] = None,
    date_kst: Optional[date] = None,
    log_flag: bool = False,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
    limit: int = Query(20, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """
    이완 세션 목록 조회:
    - week_number / task_id / date_kst로 필터링
    - duration_seconds > 0 인 세션만 포함
    - log_flag=False면 logs 배열은 projection에서 제외 (가볍게)
    """
    return await _find_relaxation_tasks(
        db=db,
        user_id=user_id,
        week_number=week_number,
        task_id=task_id,
        date_kst=date_kst,
        log_flag=log_flag,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/latest",
    response_model=Optional[RelaxationTaskResponse],
    summary="조건에 맞는 가장 최근 이완 로그 1개 조회 (별도 컬렉션)",
)
async def get_latest_relaxation_task(
    week_number: Optional[int] = None,
    task_id: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    - week_number가 주어지면: 해당 주차의 이완 로그 중 **가장 최근 1개**
    - task_id가 주어지면: 해당 taskId의 로그 중 **가장 최근 1개**
    - 둘 다 주어지면: 둘 다 만족하는 로그 중 가장 최근 1개
    - 아무 조건도 없으면: 전체 로그 중 가장 최근 1개
    - 로그가 전혀 없으면: `null` 반환
    """
    collection = db[RELAX_COLLECTION]

    query: Dict[str, Any] = {"user_id": user_id}
    if week_number is not None:
        query["week_number"] = int(week_number)
    if task_id is not None:
        query["task_id"] = task_id

    doc = await collection.find_one(query, sort=[("start_time", -1)])

    if not doc:
        return None

    return RelaxationTaskResponse(**_serialize_task(doc))


# TODO: 플랫폼팀에 넘기기 + 리포트 화면에 활용
@router.get(
    "/summary",
    response_model=RelaxationTimeSummary,
    summary="사용자의 전체 이완 시간 요약 (KST today/week, UTC datetime)",
)
async def get_relaxation_summary(
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    전체 이완 사용 요약:
    - totalMinutes: 전체 duration 합 (분)
    - todayMinutes: 오늘(KST 기준) 시작한 세션 duration 합
    - weekMinutes: 최근 7일(KST 기준, 오늘 포함) 세션 duration 합
    - weekSessions: 최근 7일 세션 수
    - completedSessions / completedMinutes: end_time 있는 세션만
    - lastEntryAt: 마지막 end_time
    """
    collection = db[RELAX_COLLECTION]

    now_utc = datetime.now(timezone.utc)
    today_start_kst = kst_midnight(now_utc)  # 오늘 00:00 KST
    today_end_kst = today_start_kst + timedelta(days=1)
    week_start_kst = today_start_kst - timedelta(days=6)

    today_start_utc = today_start_kst.astimezone(timezone.utc)
    today_end_utc = today_end_kst.astimezone(timezone.utc)
    week_start_utc = week_start_kst.astimezone(timezone.utc)

    base_match = {
        "user_id": user_id,
        "duration_seconds": {"$gt": 0},
    }

    pipeline = [
        {"$match": base_match},
        {
            "$group": {
                "_id": None,
                "total_seconds": {"$sum": "$duration_seconds"},
                "today_seconds": {
                    "$sum": {
                        "$cond": [
                            {
                                "$and": [
                                    {"$gte": ["$start_time", today_start_utc]},
                                    {"$lt": ["$start_time", today_end_utc]},
                                ]
                            },
                            "$duration_seconds",
                            0,
                        ]
                    }
                },
                "week_seconds": {
                    "$sum": {
                        "$cond": [
                            {
                                "$and": [
                                    {"$gte": ["$start_time", week_start_utc]},
                                    {"$lt": ["$start_time", today_end_utc]},
                                ]
                            },
                            "$duration_seconds",
                            0,
                        ]
                    }
                },
                "week_sessions": {
                    "$sum": {
                        "$cond": [
                            {
                                "$and": [
                                    {"$gte": ["$start_time", week_start_utc]},
                                    {"$lt": ["$start_time", today_end_utc]},
                                ]
                            },
                            1,
                            0,
                        ]
                    }
                },
                "completed_seconds": {
                    "$sum": {
                        "$cond": [
                            {"$ne": ["$end_time", None]},
                            "$duration_seconds",
                            0,
                        ]
                    }
                },
                "completed_sessions": {
                    "$sum": {
                        "$cond": [
                            {"$ne": ["$end_time", None]},
                            1,
                            0,
                        ]
                    }
                },
                "last_entry_at": {"$max": "$end_time"},
            }
        },
    ]

    agg_list = await collection.aggregate(pipeline).to_list(length=1)
    if not agg_list:
        return RelaxationTimeSummary()

    agg = agg_list[0]

    return RelaxationTimeSummary(
        totalMinutes=round(float(agg.get("total_seconds", 0)) / 60.0, 2),
        todayMinutes=round(float(agg.get("today_seconds", 0)) / 60.0, 2),
        weekMinutes=round(float(agg.get("week_seconds", 0)) / 60.0, 2),
        weekSessions=int(agg.get("week_sessions", 0) or 0),
        completedSessions=int(agg.get("completed_sessions", 0) or 0),
        completedMinutes=round(float(agg.get("completed_seconds", 0)) / 60.0, 2),
        lastEntryAt=ensure_utc(agg.get("last_entry_at")),
    )


@router.get(
    "/task-summary",
    response_model=RelaxationTaskTimeSummary,
    summary="특정 조건(week/task/date)에 해당하는 이완 시간 요약",
)
async def get_relaxation_task_summary(
    week_number: Optional[int] = None,
    task_id: Optional[str] = None,
    date_kst: Optional[date] = None,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    특정 조건(week_number / task_id / date_kst)에 해당하는 이완 시간 요약:
    - totalMinutes, totalSessions
    - completedSessions / completedMinutes
    - lastEntryAt
    """
    collection = db[RELAX_COLLECTION]

    match = _build_task_match(
        user_id=user_id,
        week_number=week_number,
        task_id=task_id,
        date_kst=date_kst,
        require_positive_duration=True,
    )

    pipeline = [
        {"$match": match},
        {
            "$group": {
                "_id": None,
                "total_seconds": {"$sum": "$duration_seconds"},
                "total_sessions": {"$sum": 1},
                "completed_seconds": {
                    "$sum": {
                        "$cond": [
                            {"$ne": ["$end_time", None]},
                            "$duration_seconds",
                            0,
                        ]
                    }
                },
                "completed_sessions": {
                    "$sum": {
                        "$cond": [
                            {"$ne": ["$end_time", None]},
                            1,
                            0,
                        ]
                    }
                },
                "last_entry_at": {"$max": "$end_time"},
            }
        },
    ]

    agg_list = await collection.aggregate(pipeline).to_list(length=1)
    if not agg_list:
        return RelaxationTaskTimeSummary(
            taskId=task_id,
            weekNumber=week_number,
            queryDate=date_kst,
        )

    agg = agg_list[0]

    return RelaxationTaskTimeSummary(
        taskId=task_id,
        weekNumber=week_number,
        queryDate=date_kst,
        totalMinutes=round(float(agg.get("total_seconds", 0)) / 60.0, 2),
        totalSessions=int(agg.get("total_sessions", 0) or 0),
        completedSessions=int(agg.get("completed_sessions", 0) or 0),
        completedMinutes=round(float(agg.get("completed_seconds", 0)) / 60.0, 2),
        lastEntryAt=ensure_utc(agg.get("last_entry_at")),
    )
