from datetime import date, datetime, timezone, timedelta
from typing import List, Optional, Dict, Any
import uuid

from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from pymongo import ReturnDocument

from core.security import get_current_user_id
from core.utils import parse_datetime_value, ensure_utc, KST
from db.mongo import get_db
from routers.worry_groups import adjust_group_metrics
from schemas.sud import (
    SudScoreCreate,
    SudScoreResponse,
    SudScoreUpdate,
    WeeklySUDStats,
    DailySUDStats,
)

router = APIRouter(prefix="/sud-scores")

DIARY_COLLECTION = "diaries"


# ---------- 공통 유틸 ----------

def parse_sud_value(value: Any) -> Optional[int]:
    """
    SUD 값(0~10)을 안전하게 파싱.
    - int / float / str 모두 허용
    - 범위 밖이면 0~10 사이로 클램핑
    - 파싱 불가 시 None
    """
    if isinstance(value, (int, float)):
        return max(0, min(10, int(value)))
    if isinstance(value, str):
        try:
            return max(0, min(10, int(float(value))))
        except Exception:
            return None
    return None


def serialize_sud(doc: dict, *, diary_id: Optional[str] = None) -> dict:
    """
    DB에 저장된 SUD 엔트리를 SudScoreResponse 스키마에 맞게 직렬화.
    """
    return {
        "sud_id": doc.get("sud_id"),
        "diary_id": diary_id,
        "before_sud": parse_sud_value(doc.get("before_sud")) or 0,
        "after_sud": parse_sud_value(doc.get("after_sud")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


def normalize_sud_scores(raw) -> List[dict]:
    """
    diaries 라우터에서 bulk로 SUD 리스트를 저장할 때 사용하는 정규화 함수.
    - 이 라우터 내부에서는 직접 사용하진 않지만, 외부에서 import 중이라 유지.
    """
    if not isinstance(raw, list):
        return []

    normalized: List[dict] = []
    now_utc = datetime.now(timezone.utc)

    for item in raw:
        if isinstance(item, dict):
            before = parse_sud_value(item.get("before_sud")) or 0
            after = parse_sud_value(item.get("after_sud"))
            created_raw = item.get("created_at") or item.get("updated_at")
            created_at = parse_datetime_value(created_raw, fallback=now_utc)
            updated_at = parse_datetime_value(item.get("updated_at"), fallback=now_utc)
            sud_id = item.get("sud_id")
        else:
            before = parse_sud_value(item) or 0
            after = None
            created_at = now_utc
            updated_at = now_utc
            sud_id = None

        entry = {
            "sud_id": sud_id or f"sud_{uuid.uuid4().hex[:8]}",
            "before_sud": before,
            "after_sud": after,
            "created_at": created_at,
            "updated_at": updated_at,
        }
        normalized.append(entry)

    normalized.sort(key=lambda e: e["created_at"])
    return normalized


def _compute_new_sud_value(before: Optional[int], after: Optional[int]) -> int:
    """
    새 SUD 엔트리에서 latest_sud로 사용할 값 계산.
    - after_sud가 있으면 그걸, 없으면 before_sud 사용
    - None일 경우 0으로 기본값
    """
    candidate = after if after is not None else before
    return parse_sud_value(candidate) or 0


# ---------- 엔드포인트 ----------

@router.post("", response_model=SudScoreResponse, status_code=status.HTTP_201_CREATED)
async def create_sud_score(
    diary_id: str,
    payload: SudScoreCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    SUD 점수 한 개 추가.
    - sud_scores 배열에 push
    - latest_sud 갱신
    - worry_group.sud_sum 누적 반영
    """
    collection = db[DIARY_COLLECTION]

    now_utc = datetime.now(timezone.utc)

    entry = {
        "sud_id": f"sud_{uuid.uuid4().hex[:8]}",
        "before_sud": payload.before_sud,
        "after_sud": payload.after_sud,
        "created_at": now_utc,
        "updated_at": now_utc,
    }

    new_value = _compute_new_sud_value(
        before=payload.before_sud,
        after=payload.after_sud,
    )

    # sud_scores에 push + latest_sud / updated_at 한 번에 갱신
    doc_before = await collection.find_one_and_update(
        {"user_id": user_id, "diary_id": diary_id},
        {
            "$push": {"sud_scores": entry},
            "$set": {
                "latest_sud": new_value,
                "updated_at": now_utc,
            },
        },
        projection={"group_id": 1, "latest_sud": 1},
        return_document=ReturnDocument.BEFORE,
    )

    if not doc_before:
        raise HTTPException(status_code=404, detail="Diary not found")

    old_value = parse_sud_value(doc_before.get("latest_sud")) or 0
    delta = new_value - old_value

    group_id = doc_before.get("group_id")
    if group_id and delta != 0:
        await adjust_group_metrics(
            db=db,
            user_id=user_id,
            group_id=group_id,
            sud_delta=delta,
        )

    return SudScoreResponse(**serialize_sud(entry, diary_id=diary_id))


@router.get("/{diary_id}", response_model=List[SudScoreResponse])
async def list_sud_scores(
    diary_id: str,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    특정 일기에 대한 SUD 기록 전체 조회.
    - 최신순(created_at desc)으로 정렬해서 반환
    """
    collection = db[DIARY_COLLECTION]

    diary = await collection.find_one(
        {"user_id": user_id, "diary_id": diary_id},
        {"sud_scores": 1},
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    entries = list(diary.get("sud_scores", []))

    # 한 번만 파싱해서 SudScoreResponse로 만들고, 그걸 created_at 기준으로 정렬
    responses: List[SudScoreResponse] = [
        SudScoreResponse(**serialize_sud(entry, diary_id=diary_id))
        for entry in entries
    ]
    responses.sort(key=lambda r: r.created_at, reverse=True)
    return responses


@router.put("/{diary_id}/{sud_id}", response_model=SudScoreResponse)
async def update_sud_score(
    diary_id: str,
    sud_id: str,
    payload: SudScoreUpdate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    """
    SUD 기록 수정.
    - 마지막 SUD 항목만 수정 가능
    - latest_sud 및 worry_group.sud_sum 조정
    """
    update_data = payload.model_dump(
        exclude_unset=True,
        by_alias=True,
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    collection = db[DIARY_COLLECTION]

    # 1) 마지막 SUD 항목이 이 sud_id인지 O(1)로 확인 (마지막 원소만 슬라이스)
    diary = await collection.find_one(
        {"user_id": user_id, "diary_id": diary_id},
        {
            "sud_scores": {"$slice": -1},  # 마지막 1개만
            "group_id": 1,
            "latest_sud": 1,
        },
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    last_entries = diary.get("sud_scores") or []
    if not last_entries or last_entries[0].get("sud_id") != sud_id:
        # 마지막이 아니면 수정 불가 (중간 것도 막음)
        raise HTTPException(
            status_code=400,
            detail="마지막 SUD 항목만 수정할 수 있습니다.",
        )

    now_utc = datetime.now(timezone.utc)
    old_value = parse_sud_value(diary.get("latest_sud")) or 0
    new_value = _compute_new_sud_value(
        before=update_data.get("before_sud", last_entries[0].get("before_sud")),
        after=update_data.get("after_sud", last_entries[0].get("after_sud")),
    )
    delta = new_value - old_value

    # 2) positional operator($)로 해당 SUD 항목만 부분 업데이트
    set_fields: Dict[str, Any] = {
        f"sud_scores.$.{key}": value for key, value in update_data.items()
    }
    set_fields["sud_scores.$.updated_at"] = now_utc
    set_fields["latest_sud"] = new_value
    set_fields["updated_at"] = now_utc

    updated_doc = await collection.find_one_and_update(
        {
            "diary_id": diary_id,
            "user_id": user_id,
            "sud_scores.sud_id": sud_id,
        },
        {"$set": set_fields},
        return_document=ReturnDocument.AFTER,
    )

    if not updated_doc:
        # 이론적으로 race condition일 때만 올 수 있음
        raise HTTPException(status_code=404, detail="Diary not found after update")

    group_id = updated_doc.get("group_id")
    if group_id and delta != 0:
        await adjust_group_metrics(
            db=db,
            user_id=user_id,
            group_id=group_id,
            sud_delta=delta,
        )

    # 업데이트된 문서에서 해당 SUD 항목 찾아서 반환
    updated_sud_entry = next(
        (e for e in updated_doc.get("sud_scores", []) if e.get("sud_id") == sud_id),
        None,
    )
    if updated_sud_entry is None:
        raise HTTPException(status_code=500, detail="Updated SUD entry not found in document")

    return SudScoreResponse(**serialize_sud(updated_sud_entry, diary_id=diary_id))


@router.delete("/{diary_id}/{sud_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_sud_score(
        diary_id: str,
        sud_id: str,
        db=Depends(get_db),
        user_id: str = Depends(get_current_user_id),
):
    """
    SUD 기록 하드 삭제.
    - **마지막 SUD 항목만 삭제 가능**
    - 삭제 후 latest_sud 재계산
    - worry_group.sud_sum 에도 delta 반영
    """
    collection = db[DIARY_COLLECTION]

    # 마지막 2개만 가져와서:
    #   - 진짜 마지막 sud_id가 맞는지 확인
    #   - 삭제 후 latest_sud가 될 값(두 번째 마지막) 계산
    diary = await collection.find_one(
        {"user_id": user_id, "diary_id": diary_id},
        {
            "sud_scores": {"$slice": -2},  # 마지막 2개만
            "group_id": 1,
            "latest_sud": 1,
        },
    )
    if not diary:
        raise HTTPException(status_code=404, detail="Diary not found")

    sud_scores = diary.get("sud_scores") or []
    if not sud_scores:
        raise HTTPException(status_code=404, detail="SUD record not found")

    # 마지막 엔트리
    last_entry = sud_scores[-1]
    if last_entry.get("sud_id") != sud_id:
        # 중간/과거 SUD는 삭제 막기
        raise HTTPException(
            status_code=400,
            detail="마지막 SUD 항목만 삭제할 수 있습니다.",
        )

    now_utc = datetime.now(timezone.utc)

    # 삭제 전 latest_sud 값
    old_latest = parse_sud_value(diary.get("latest_sud")) or 0

    # 삭제 후 latest_sud 값 = 두 번째 마지막 엔트리(or 0)
    if len(sud_scores) >= 2:
        prev_entry = sud_scores[-2]
        new_latest = _compute_new_sud_value(
            before=prev_entry.get("before_sud"),
            after=prev_entry.get("after_sud"),
        )
    else:
        # 삭제하면 sud_scores가 비게 되는 경우
        new_latest = 0

    delta = new_latest - old_latest

    # 실제 삭제: 배열의 마지막 원소 pop + latest_sud/updated_at 갱신
    updated_doc = await collection.find_one_and_update(
        {
            "user_id": user_id,
            "diary_id": diary_id,
            "sud_scores.sud_id": sud_id,  # 안전장치
        },
        {
            "$pop": {"sud_scores": 1},  # 마지막 요소 제거
            "$set": {
                "latest_sud": new_latest,
                "updated_at": now_utc,
            },
        },
        projection={"group_id": 1},
        return_document=ReturnDocument.AFTER,
    )

    if not updated_doc:
        # 거의 race condition일 때만 발생
        raise HTTPException(status_code=404, detail="Diary not found after delete")

    group_id = updated_doc.get("group_id")
    if group_id and delta != 0:
        await adjust_group_metrics(
            db=db,
            user_id=user_id,
            group_id=group_id,
            sud_delta=delta,
        )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/stats/weekly",
    response_model=List[WeeklySUDStats],
    summary="(플랫폼용) 주차별 평균 SUD 통계 (전체 환자 / 특정 환자)",
)
async def get_sud_weekly_stats(
    start: Optional[datetime] = Query(
        None,
        description="집계 시작 시각 (옵션, 없으면 전체 기간 시작)",
    ),
    end: Optional[datetime] = Query(
        None,
        description="집계 종료 시각 (옵션, 없으면 현재까지)",
    ),
    target_user_id: Optional[str] = Query(
        None,
        description="특정 환자만 보고 싶으면 user_id 지정, 없으면 전체 환자 기준",
    ),
    # 호출자 인증용 (실제 집계에는 사용 안 함)
    _: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    - 전체 Mindrium 사용자(혹은 특정 user_id)의 SUD 로그를 **주차별**로 집계한다.
    - 기준:
      - sud_scores.created_at 기준으로 주차 계산
      - 주 시작 기준은 KST(Asia/Seoul) 주간, MongoDB `$dateTrunc` 타임존 사용
    """
    collection = db[DIARY_COLLECTION]

    # 공통 match 조건
    match: Dict[str, Any] = {
        "sud_scores": {"$exists": True, "$ne": []},
    }
    if target_user_id:
        match["user_id"] = target_user_id

    # 시간 필터는 sud_scores.created_at 기준
    time_filter: Dict[str, Any] = {}
    if start is not None:
        time_filter["$gte"] = ensure_utc(start)
    if end is not None:
        time_filter["$lt"] = ensure_utc(end)

    pipeline: List[Dict[str, Any]] = [{"$match": match}, {"$unwind": "$sud_scores"}]

    if time_filter:
        pipeline.append({"$match": {"sud_scores.created_at": time_filter}})

    pipeline.extend(
        [
            # 주차 단위로 잘라내기 (KST 기준 주간)
            {
                "$addFields": {
                    "week_start": {
                        "$dateTrunc": {
                            "date": "$sud_scores.created_at",
                            "unit": "week",
                            "timezone": "Asia/Seoul",
                        }
                    }
                }
            },
            {
                "$group": {
                    "_id": "$week_start",
                    "avg_before": {"$avg": "$sud_scores.before_sud"},
                    "avg_after": {"$avg": "$sud_scores.after_sud"},
                    "count": {"$sum": 1},
                }
            },
            {"$sort": {"_id": 1}},
        ]
    )

    rows = await collection.aggregate(pipeline).to_list(length=None)

    stats: List[WeeklySUDStats] = []
    for row in rows:
        week_start = parse_datetime_value(row.get("_id"))
        stats.append(
            WeeklySUDStats(
                weekStart=week_start,
                avgBefore=float(row.get("avg_before") or 0.0),
                avgAfter=(
                    float(row["avg_after"])
                    if row.get("avg_after") is not None
                    else None
                ),
                count=int(row.get("count") or 0),
            )
        )

    return stats

@router.get(
    "/stats/daily",
    response_model=List[DailySUDStats],
    summary="(플랫폼용) 특정 주차의 일자별 평균 SUD 통계",
)
async def get_sud_daily_stats(
    week_start_date: date = Query(
        ...,
        description="해당 주의 시작 날짜 (KST 기준, 월요일/일요일 상관 없이 크고 작은 단위로만 사용)",
    ),
    target_user_id: Optional[str] = Query(
        None,
        description="특정 환자만 보고 싶으면 user_id 지정, 없으면 전체 환자 기준",
    ),
    _: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    - `week_start_date` ~ +7일 구간(KST)을 하나의 주로 보고,
      그 안의 SUD 로그를 **일자별**로 집계한다.
    - UI 흐름:
      1) 주차별 그래프에서 한 점(week_start)을 선택
      2) 그 week_start를 `week_start_date`로 넘겨서 이 API 호출
      3) 반환된 배열로 '1주차 상세' 일자별 그래프 그림
    """
    collection = db[DIARY_COLLECTION]

    # KST 기준 주 시작/끝을 UTC로 변환
    week_start_kst = datetime(
        week_start_date.year,
        week_start_date.month,
        week_start_date.day,
        tzinfo=KST,
    )
    week_end_kst = week_start_kst + timedelta(days=7)

    week_start_utc = week_start_kst.astimezone(timezone.utc)
    week_end_utc = week_end_kst.astimezone(timezone.utc)

    match: Dict[str, Any] = {
        "sud_scores": {"$exists": True, "$ne": []},
    }
    if target_user_id:
        match["user_id"] = target_user_id

    # sud_scores.created_at 기준 주간 범위 필터
    time_range = {"$gte": week_start_utc, "$lt": week_end_utc}

    pipeline: List[Dict[str, Any]] = [
        {"$match": match},
        {"$unwind": "$sud_scores"},
        {"$match": {"sud_scores.created_at": time_range}},
        # 날짜 단위(KST)로 잘라서 그룹
        {
            "$addFields": {
                "sud_date": {
                    "$dateTrunc": {
                        "date": "$sud_scores.created_at",
                        "unit": "day",
                        "timezone": "Asia/Seoul",
                    }
                }
            }
        },
        {
            "$group": {
                "_id": "$sud_date",
                "avg_before": {"$avg": "$sud_scores.before_sud"},
                "avg_after": {"$avg": "$sud_scores.after_sud"},
                "count": {"$sum": 1},
            }
        },
        {"$sort": {"_id": 1}},
    ]

    rows = await collection.aggregate(pipeline).to_list(length=None)

    stats: List[DailySUDStats] = []
    for row in rows:
        date_val = parse_datetime_value(row.get("_id"))
        stats.append(
            DailySUDStats(
                date=date_val,
                avgBefore=float(row.get("avg_before") or 0.0),
                avgAfter=(
                    float(row["avg_after"])
                    if row.get("avg_after") is not None
                    else None
                ),
                count=int(row.get("count") or 0),
            )
        )

    return stats
