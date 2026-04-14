# routers/edu_sessions.py
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any, Literal
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from core.security import get_current_user_id
from core.utils import ensure_utc, parse_datetime_value
from db.mongo import get_db
from pymongo import ReturnDocument
from routers.treatment_progress import _refresh_requirements_met
from schemas.edu_session import (
    EduSessionCreateCommon,
    EduSessionCreate3And5,
    EduSessionCreate7,
    EduSessionCreate8,
    EduSessionCommonIn,
    EduSessionUpdate,
    EduSessionResponse,
    EffectivenessEvaluation,
    UserJourneyResponse, BehaviorExecutionAnalysis,
)

router = APIRouter(prefix="/edu-sessions", tags=["edu-sessions"])

EDU_SESSION_COLLECTION = "edu_sessions"
TREATMENT_PROGRESS_COLLECTION = "treatment_progress"


# ========= 공통 직렬화 =========

def _serialize_session(doc: dict) -> dict:
    """
    Mongo 문서를 EduSessionResponse 에 들어갈 dict 로 변환.
    (datetime 은 parse_datetime_value 로 정규화)
    """
    base: Dict[str, Any] = {
        "session_id": doc.get("session_id"),
        "is_first_completed": doc.get("is_first_completed"),
        "week_number": doc.get("week_number"),
        "diary_id": doc.get("diary_id"),
        "total_stages": doc.get("total_stages"),
        "last_stage_idx": doc.get("last_stage_idx"),
        "completed": bool(doc.get("completed", False)),
        "start_time": parse_datetime_value(doc.get("start_time")),
        "end_time": parse_datetime_value(doc.get("end_time")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }

    # 선택적 주차별 필드들
    for key in [
        "negative_items",
        "positive_items",
        "classification_quiz",
        "behavior_items",
        "effectiveness_evaluations",
        "user_journey_responses",
    ]:
        if key in doc:
            base[key] = doc.get(key)

    return base


async def _insert_session_doc(
    db,
    user_id: str,
    payload: EduSessionCommonIn,
) -> dict:
    """
    공통 insert 로직:
    - payload.model_dump(exclude_none=True) 로 선택적 필드만 포함
    - user_id / session_id / created_at / updated_at 덧붙여서 저장
    (⚠️ upsert 아님, 항상 insert)
    """
    collection = db[EDU_SESSION_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    base_doc: Dict[str, Any] = payload.model_dump(exclude_none=True)
    base_doc.update(
        {
            "session_id": f"edu_{uuid.uuid4().hex[:8]}",
            "user_id": user_id,
            "is_first_completed": None,
            "created_at": now_utc,
            "updated_at": now_utc,
            "start_time": ensure_utc(base_doc.get("start_time")),
            "end_time": ensure_utc(base_doc.get("end_time"))
            if base_doc.get("end_time") is not None
            else None,
        }
    )

    await collection.insert_one(base_doc)
    return base_doc


async def _sync_treatment_progress_main_edu(
    *,
    db,
    user_id: str,
    week_number: int,
    session_id: str,
    completed_at: datetime,
) -> None:
    collection = db[TREATMENT_PROGRESS_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    progress = await collection.find_one_and_update(
        {"user_id": user_id, "week_number": week_number},
        {
            "$set": {
                "edu_session_id": session_id,
                "updated_at": now_utc,
            },
        },
        return_document=ReturnDocument.AFTER,
    )
    if not progress:
        return

    if progress and progress.get("relaxation_task_id"):
        progress = await collection.find_one_and_update(
            {"user_id": user_id, "week_number": week_number},
            {
                "$set": {
                    "main_completed": True,
                    "main_completed_at": completed_at,
                    "updated_at": now_utc,
                }
            },
            return_document=ReturnDocument.AFTER,
        )
        if progress:
            await _refresh_requirements_met(
                db=db,
                collection=collection,
                progress_doc=progress,
                synced_at=completed_at,
            )


# ========= 리스트 / 단일 조회 =========

@router.get(
    "",
    response_model=List[EduSessionResponse],
    summary="교육 세션 목록 조회",
)
async def list_edu_sessions(
    week_number: Optional[int] = Query(
        default=None,
        description="특정 주차만 보고 싶을 때 (1~8)",
    ),
    diary_id: Optional[str] = Query(
        default=None,
        description="특정 diary_id 에 연결된 세션만 보고 싶을 때",
    ),
    start_at: Optional[datetime] = Query(
        default=None,
        description="created_at 기준 시작 시각 필터",
    ),
    end_at: Optional[datetime] = Query(
        default=None,
        description="created_at 기준 종료 시각 필터",
    ),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    사용자의 edu_sessions 목록을 조회.
    - week_number / diary_id / created_at 기간으로 필터링 가능
    - 최신(start_time 기준) 순으로 정렬
    """
    collection = db[EDU_SESSION_COLLECTION]

    query: Dict[str, Any] = {"user_id": user_id}
    if week_number is not None:
        query["week_number"] = week_number
    if diary_id is not None:
        query["diary_id"] = diary_id
    if start_at is not None or end_at is not None:
        created_at_query: Dict[str, datetime] = {}
        if start_at is not None:
            created_at_query["$gte"] = ensure_utc(start_at) or start_at
        if end_at is not None:
            created_at_query["$lte"] = ensure_utc(end_at) or end_at
        query["created_at"] = created_at_query

    cursor = collection.find(query).sort("start_time", -1)

    docs: List[EduSessionResponse] = []
    async for doc in cursor:
        try:
            docs.append(EduSessionResponse(**_serialize_session(doc)))
        except Exception:
            # 과거 문서(total_stages/last_stage_idx 누락 등)는 건너뛰어 500 방지
            continue
    return docs


@router.get(
    "/{session_id}",
    response_model=EduSessionResponse,
    summary="단일 교육 세션 조회",
)
async def get_edu_session(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    collection = db[EDU_SESSION_COLLECTION]

    doc = await collection.find_one(
        {"user_id": user_id, "session_id": session_id}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")

    return EduSessionResponse(**_serialize_session(doc))


# ========= 생성: 공통 (1,2,4,6주차) =========

@router.post(
    "",
    response_model=EduSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="교육 세션 생성 (1,2,4,6주차 공통)",
)
async def create_common_session(
    payload: EduSessionCreateCommon,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    1,2,4,6주차처럼 '주차별 특수 필드가 없는' 세션을 생성할 때 사용.
    3,5,7,8주차용 특수 엔드포인트가 따로 있기 때문에,
    여기서는 week_number 가 1,2,4,6 인 경우만 허용한다.
    """
    doc = await _insert_session_doc(db, user_id, payload)
    # if not payload.completed or payload.end_time is None or payload.last_stage_idx < payload.total_stages:
    #     is_first_completed = None
    # else:
    #     existing_first = await db[EDU_SESSION_COLLECTION].find_one(
    #         {
    #             "user_id": user_id,
    #             "week_number": payload.week_number,
    #             "diary_id": payload.diary_id,
    #             "is_first_completed": True,
    #         }
    #     )
    #     is_first_completed = existing_first is None
    # await db[EDU_SESSION_COLLECTION].update_one(
    #     {"session_id": doc["session_id"]},
    #     {"$set": {"is_first_completed": is_first_completed}},
    # )
    # doc["is_first_completed"] = is_first_completed

    return EduSessionResponse(**_serialize_session(doc))


# ========= 생성: 3,5주차 (분류 퀴즈 / 리스트) =========

@router.post(
    "/week3-5",
    response_model=EduSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="3,5주차 교육 세션 생성",
)
async def create_week3_5_session(
    payload: EduSessionCreate3And5,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    3,5주차 세션 생성:
    - week_number: 3 또는 5
    - negative_items / positive_items: 부정/긍정 항목 리스트
    - classification_quiz: 분류 퀴즈 결과 (선택)
    """
    doc = await _insert_session_doc(db, user_id, payload)
    # if not payload.completed or payload.end_time is None or payload.last_stage_idx < payload.total_stages:
    #     is_first_completed = None
    # else:
    #     existing_first = await db[EDU_SESSION_COLLECTION].find_one(
    #         {
    #             "user_id": user_id,
    #             "week_number": payload.week_number,
    #             "diary_id": payload.diary_id,
    #             "is_first_completed": True,
    #         }
    #     )
    #     is_first_completed = existing_first is None
    # await db[EDU_SESSION_COLLECTION].update_one(
    #     {"session_id": doc["session_id"]},
    #     {"$set": {"is_first_completed": is_first_completed}},
    # )
    # doc["is_first_completed"] = is_first_completed

    return EduSessionResponse(**_serialize_session(doc))


# ========= 생성: 7주차 (행동 리스트 + 분석) =========

@router.post(
    "/week7",
    response_model=EduSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="7주차 교육 세션 생성",
)
async def create_week7_session(
    payload: EduSessionCreate7,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    7주차 세션 생성:
    - behavior_items: chip_id / category / reason / analysis 등 포함한 리스트
    """
    doc = await _insert_session_doc(db, user_id, payload)
    # if not payload.completed or payload.end_time is None or payload.last_stage_idx < payload.total_stages:
    #     is_first_completed = None
    # else:
    #     existing_first = await db[EDU_SESSION_COLLECTION].find_one(
    #         {
    #             "user_id": user_id,
    #             "week_number": payload.week_number,
    #             "diary_id": payload.diary_id,
    #             "is_first_completed": True,
    #         }
    #     )
    #     is_first_completed = existing_first is None
    # await db[EDU_SESSION_COLLECTION].update_one(
    #     {"session_id": doc["session_id"]},
    #     {"$set": {"is_first_completed": is_first_completed}},
    # )
    # doc["is_first_completed"] = is_first_completed

    return EduSessionResponse(**_serialize_session(doc))


# ========= 생성: 8주차 (효과성 평가 + 사용자 여정) =========

@router.post(
    "/week8",
    response_model=EduSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="8주차 교육 세션 생성",
)
async def create_week8_session(
    payload: EduSessionCreate8,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    8주차 세션 생성:
    - effectiveness_evaluations: 행동별 효과성 평가 리스트
    - user_journey_responses: 질문/답변 리스트
    """
    doc = await _insert_session_doc(db, user_id, payload)
    # if not payload.completed or payload.end_time is None or payload.last_stage_idx < payload.total_stages:
    #     is_first_completed = None
    # else:
    #     existing_first = await db[EDU_SESSION_COLLECTION].find_one(
    #         {
    #             "user_id": user_id,
    #             "week_number": payload.week_number,
    #             "diary_id": payload.diary_id,
    #             "is_first_completed": True,
    #         }
    #     )
    #     is_first_completed = existing_first is None
    # await db[EDU_SESSION_COLLECTION].update_one(
    #     {"session_id": doc["session_id"]},
    #     {"$set": {"is_first_completed": is_first_completed}},
    # )
    # doc["is_first_completed"] = is_first_completed

    return EduSessionResponse(**_serialize_session(doc))


# ========= 공통: 세션 전체/부분 수정 =========

@router.put(
    "/{session_id}",
    response_model=EduSessionResponse,
    summary="교육 세션 부분 수정 (공통)",
)
async def update_edu_session(
    session_id: str,
    payload: EduSessionUpdate,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    collection = db[EDU_SESSION_COLLECTION]

    update_data: Dict[str, Any] = payload.model_dump(
        exclude_unset=True,
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="수정할 필드가 없습니다")

    now_utc = datetime.now(timezone.utc)
    if "start_time" in update_data:
        update_data["start_time"] = ensure_utc(update_data["start_time"])
    if "end_time" in update_data:
        update_data["end_time"] = (
            ensure_utc(update_data["end_time"])
            if update_data["end_time"] is not None
            else None
        )
    update_data["updated_at"] = now_utc

    doc = await collection.find_one_and_update(
        {"user_id": user_id, "session_id": session_id},
        {"$set": update_data},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")

    completed = bool(doc.get("completed", False))
    total_stages = doc.get("total_stages")
    last_stage_idx = doc.get("last_stage_idx")
    end_time = doc.get("end_time")
    if (
        not completed
        or end_time is None
        or not isinstance(total_stages, int)
        or not isinstance(last_stage_idx, int)
        or last_stage_idx < total_stages
    ):
        is_first_completed = None
    else:
        existing_first = await collection.find_one(
            {
                "user_id": user_id,
                "week_number": int(doc["week_number"]),
                "diary_id": doc.get("diary_id") if isinstance(doc.get("diary_id"), str) else None,
                "is_first_completed": True,
                "session_id": {"$ne": session_id},
            }
        )
        is_first_completed = existing_first is None

    await collection.update_one(
        {"user_id": user_id, "session_id": session_id},
        {"$set": {"is_first_completed": is_first_completed}},
    )
    doc["is_first_completed"] = is_first_completed

    if is_first_completed:
        await _sync_treatment_progress_main_edu(
            db=db,
            user_id=user_id,
            week_number=int(doc["week_number"]),
            session_id=session_id,
            completed_at=ensure_utc(end_time) or now_utc,
        )

    return EduSessionResponse(**_serialize_session(doc))


# ========= 7주차 전용: behavior_items 개별 add/update/delete =========

class Week7ItemUpsert(BaseModel):
    """7주차 행동 한 개 추가/수정용"""
    chip_id: str
    label: Optional[str] = None
    category: Literal["confront", "avoid"]
    reason: Optional[str] = None
    # 분석 폼은 BehaviorExecutionAnalysis와 동일 구조를 기대
    analysis: Optional[BehaviorExecutionAnalysis] = None

@router.put(
    "/{session_id}/week7/items",
    response_model=EduSessionResponse,
    summary="7주차 행동 추가/수정 (단일 chip)",
)
async def upsert_week7_item(
    session_id: str,
    payload: Week7ItemUpsert,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    7주차 세션의 behavior_items 중 chip_id 기준으로
    - 있으면 교체
    - 없으면 append

    ⚠️ 세션 자체는 미리 생성되어 있어야 함 (insert-only 원칙 유지).
    """
    collection = db[EDU_SESSION_COLLECTION]

    doc = await collection.find_one(
        {"user_id": user_id, "session_id": session_id, "week_number": 7}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="7주차 세션을 찾을 수 없습니다")

    items: List[Dict[str, Any]] = list(doc.get("behavior_items") or [])
    replaced = False

    for idx, existing in enumerate(items):
        if existing.get("chip_id") == payload.chip_id:
            items[idx] = {
                "chip_id": payload.chip_id,
                "label": payload.label,
                "category": payload.category,
                "reason": payload.reason,
                "analysis": (
                    payload.analysis.model_dump(exclude_none=True)
                    if payload.analysis is not None
                    else None
                ),
            }
            replaced = True
            break

    if not replaced:
        items.append(
            {
                "chip_id": payload.chip_id,
                "label": payload.label,
                "category": payload.category,
                "reason": payload.reason,
                "analysis": (
                    payload.analysis.model_dump(exclude_none=True)
                    if payload.analysis is not None
                    else None
                ),
            }
        )

    now_utc = datetime.now(timezone.utc)
    updated_doc = await collection.find_one_and_update(
        {"user_id": user_id, "session_id": session_id, "week_number": 7},
        {
            "$set": {
                "behavior_items": items,
                "updated_at": now_utc,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    return EduSessionResponse(**_serialize_session(updated_doc))


@router.delete(
    "/{session_id}/week7/items/{chip_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="7주차 행동 삭제 (단일 chip)",
)
async def delete_week7_item(
    session_id: str,
    chip_id: str,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    7주차 세션의 behavior_items 에서 chip_id 일치하는 항목 하나 삭제.
    """
    collection = db[EDU_SESSION_COLLECTION]

    doc = await collection.find_one(
        {"user_id": user_id, "session_id": session_id, "week_number": 7}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="7주차 세션을 찾을 수 없습니다")

    items: List[Dict[str, Any]] = list(doc.get("behavior_items") or [])
    filtered = [i for i in items if i.get("chip_id") != chip_id]

    if len(filtered) == len(items):
        raise HTTPException(status_code=404, detail="해당 행동을 찾을 수 없습니다")

    now_utc = datetime.now(timezone.utc)
    await collection.update_one(
        {"user_id": user_id, "session_id": session_id, "week_number": 7},
        {
            "$set": {
                "behavior_items": filtered,
                "updated_at": now_utc,
            }
        },
    )
    return None


# ========= 8주차 전용: 효과성 평가 / 사용자 여정 =========

class Week8EffectivenessUpdate(BaseModel):
    evaluations: List[EffectivenessEvaluation]


class Week8UserJourneyUpdate(BaseModel):
    responses: List[UserJourneyResponse]


@router.put(
    "/{session_id}/week8/effectiveness",
    response_model=EduSessionResponse,
    summary="8주차 효과성 평가 저장/덮어쓰기",
)
async def update_week8_effectiveness(
    session_id: str,
    payload: Week8EffectivenessUpdate,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    8주차 세션의 effectiveness_evaluations 전체를 한 번에 교체.
    (개별 항목 단위가 아니라, 화면에서 편집한 결과를 통째로 보내는 용도)
    """
    collection = db[EDU_SESSION_COLLECTION]

    doc = await collection.find_one(
        {"user_id": user_id, "session_id": session_id, "week_number": 8}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="8주차 세션을 찾을 수 없습니다")

    now_utc = datetime.now(timezone.utc)
    updated_doc = await collection.find_one_and_update(
        {"user_id": user_id, "session_id": session_id, "week_number": 8},
        {
            "$set": {
                "effectiveness_evaluations": [
                    evaluation.model_dump(exclude_none=True)
                    for evaluation in payload.evaluations
                ],
                "updated_at": now_utc,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    return EduSessionResponse(**_serialize_session(updated_doc))


@router.put(
    "/{session_id}/week8/user-journey",
    response_model=EduSessionResponse,
    summary="8주차 사용자 여정 답변 저장/덮어쓰기",
)
async def update_week8_user_journey(
    session_id: str,
    payload: Week8UserJourneyUpdate,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    8주차 세션의 user_journey_responses 전체를 한 번에 교체.
    """
    collection = db[EDU_SESSION_COLLECTION]

    doc = await collection.find_one(
        {"user_id": user_id, "session_id": session_id, "week_number": 8}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="8주차차 세션을 찾을 수 없습니다")

    now_utc = datetime.now(timezone.utc)
    updated_doc = await collection.find_one_and_update(
        {"user_id": user_id, "session_id": session_id, "week_number": 8},
        {
            "$set": {
                "user_journey_responses": [
                    resp.model_dump(exclude_none=True)
                    for resp in payload.responses
                ],
                "updated_at": now_utc,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    return EduSessionResponse(**_serialize_session(updated_doc))
