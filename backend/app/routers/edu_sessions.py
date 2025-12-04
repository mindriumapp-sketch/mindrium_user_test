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
USER_COLLECTION = "users"


# ========= 공통 직렬화 =========

def _serialize_session(doc: dict) -> dict:
    """
    Mongo 문서를 EduSessionResponse 에 들어갈 dict 로 변환.
    (datetime 은 parse_datetime_value 로 정규화)
    """
    base: Dict[str, Any] = {
        "session_id": doc.get("session_id"),
        "week_number": doc.get("week_number"),
        "diary_id": doc.get("diary_id"),
        "total_screens": doc.get("total_screens"),
        "last_screen_idx": doc.get("last_screen_idx"),
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


async def _update_last_completed_week_if_needed(
    db,
    user_id: str,
    common: EduSessionCommonIn,
) -> None:
    """
    last_completed_week / last_completed_at 갱신 규칙:

    - completed == True 이고
    - last_screen_idx 가 "마지막 화면"까지 간 세션만 인정
      (1-based 라고 가정해서 last_screen_idx >= total_screens)
    - 기존 last_completed_week 보다 '더 큰' 주차만 갱신
    """
    if not common.completed:
        return

    if common.total_screens is None or common.total_screens <= 0:
        return

    if common.last_screen_idx is None:
        return

    # 1-based index (마지막 화면 번호 = total_screens)
    if common.last_screen_idx < common.total_screens:
        # 아직 끝까지 안 간 세션
        return

    users = db[USER_COLLECTION]
    user_doc = await users.find_one(
        {"user_id": user_id},
        {"last_completed_week": 1},
    )
    if not user_doc:
        # 사용자 문서 자체가 없으면 조용히 무시
        return

    current_last = user_doc.get("last_completed_week")
    new_week = common.week_number

    # 이미 더 높은(혹은 같은) 주차를 완료했다면 갱신 안 함
    if current_last is not None and new_week <= current_last:
        return

    # 완료 시점: end_time 있으면 그거, 없으면 지금
    completed_at = ensure_utc(common.end_time) if common.end_time else datetime.now(
        timezone.utc
    )

    await users.update_one(
        {"user_id": user_id},
        {
            "$set": {
                "last_completed_week": new_week,
                "last_completed_at": completed_at,
            }
        },
    )


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
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    사용자의 edu_sessions 목록을 조회.
    - week_number / diary_id 로 필터링 가능
    - 최신(start_time 기준) 순으로 정렬
    """
    collection = db[EDU_SESSION_COLLECTION]

    query: Dict[str, Any] = {"user_id": user_id}
    if week_number is not None:
        query["week_number"] = week_number
    if diary_id is not None:
        query["diary_id"] = diary_id

    cursor = collection.find(query).sort("start_time", -1)

    docs: List[EduSessionResponse] = []
    async for doc in cursor:
        docs.append(EduSessionResponse(**_serialize_session(doc)))
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
    await _update_last_completed_week_if_needed(db, user_id, payload)

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
    await _update_last_completed_week_if_needed(db, user_id, payload)

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
    await _update_last_completed_week_if_needed(db, user_id, payload)

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
    await _update_last_completed_week_if_needed(db, user_id, payload)

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
    update_data["updated_at"] = now_utc

    doc = await collection.find_one_and_update(
        {"user_id": user_id, "session_id": session_id},
        {"$set": update_data},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다")

    # last_completed_week 재평가 (에러 나도 전체 요청 막지는 않음)
    try:
        common = EduSessionCommonIn(
            week_number=doc.get("week_number"),
            diary_id=doc.get("diary_id"),
            total_screens=doc.get("total_screens"),
            last_screen_idx=doc.get("last_screen_idx"),
            completed=bool(doc.get("completed", False)),
            start_time=parse_datetime_value(doc.get("start_time")),
            end_time=parse_datetime_value(doc.get("end_time")),
        )
        await _update_last_completed_week_if_needed(db, user_id, common)
    except Exception as e:
        print(f"[edu-sessions] last_completed_week 갱신 중 오류: {e}")

    return EduSessionResponse(**_serialize_session(doc))


# ========= 7주차 전용: behavior_items 개별 add/update/delete =========

class Week7ItemUpsert(BaseModel):
    """7주차 행동 한 개 추가/수정용"""
    chip_id: str
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
        raise HTTPException(status_code=404, detail="8주차 세션을 찾을 수 없습니다")

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
