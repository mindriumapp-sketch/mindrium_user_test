"""
사용자 데이터 관리 API
- 핵심 가치 (core value)
- 설문 데이터
- 주차별 진행도
- 사용자 정보 업데이트
"""
from typing import List
from datetime import datetime, timezone, timedelta

from pymongo import ReturnDocument

from core.security import get_current_user
from core.utils import parse_datetime_value, ensure_utc

from fastapi import APIRouter, Depends, HTTPException, status
from db.mongo import get_db
from schemas.user import (
    ValueGoalUpdate,
    ValueGoalResponse,
    SurveyCreate,
    SurveyResponse,
    UserDataResponse,
)

router = APIRouter(prefix="/users/me", tags=["user-data"])

USER_COLLECTION = "users"


def _safe_completed_at(survey: dict) -> datetime:
    """
    completed_at이 없거나 이상한 형식이어도 정렬/최신 검색이 터지지 않게 하는 헬퍼.
    기본값은 아주 예전 시간으로 두어서, 잘못된 값이 있다면 뒤로 밀리게 함.
    """
    dt = parse_datetime_value(survey.get("completed_at"))
    if dt is not None:
        return dt
    # completed_at이 없다면 과거로 밀기
    return datetime.min.replace(tzinfo=timezone.utc)


# ============= value-goal =============
@router.get("/value-goal", response_model=ValueGoalResponse, summary="핵심 가치 조회")
async def get_value_goal(
    current_user: dict = Depends(get_current_user),
):
    """
    현재 로그인한 사용자의 핵심 가치를 조회합니다.
    """
    return ValueGoalResponse(
        value_goal=current_user.get("value_goal"),
    )


@router.put("/value-goal", response_model=ValueGoalResponse, summary="핵심 가치 설정/수정")
async def set_value_goal(
    data: ValueGoalUpdate,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    사용자의 핵심 가치를 설정하거나 수정합니다.
    - **value_goal**: 최대 500자까지 입력 가능
    """
    user_obj_id = current_user["_id"]
    now_utc = datetime.now(timezone.utc)

    updated_user = await db[USER_COLLECTION].find_one_and_update(
        {"_id": user_obj_id},
        {
            "$set": {
                "value_goal": data.value_goal,
                "updated_at": now_utc,
            },
        },
        return_document=ReturnDocument.AFTER,
    )

    if not updated_user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")

    return ValueGoalResponse(
        value_goal=updated_user.get("value_goal"),
    )

# TODO: 핵심 가치 이력 저장할까요 말까요...의사들한테 유용하긴 할 거 같은데..

# ============= surveys =============
@router.get("/surveys", response_model=List[SurveyResponse], summary="설문 목록 조회")
async def get_surveys(
    current_user: dict = Depends(get_current_user),
):
    """
    사용자가 완료한 모든 설문 목록을 조회합니다. (완료 시각 기준 최신순 정렬)
    """
    if not current_user.get("survey_completed"):
        raise HTTPException(status_code=404, detail="완료된 설문이 없습니다.")

    surveys = list(current_user.get("surveys", []))

    # completed_at을 datetime(UTC)로 정규화
    for s in surveys:
        s["completed_at"] = parse_datetime_value(s.get("completed_at"))

    # 안전하게 정렬 (completed_at 없으면 가장 과거로 처리)
    surveys.sort(key=_safe_completed_at, reverse=True)

    return surveys


@router.get("/surveys/latest", response_model=SurveyResponse, summary="설문 목록 조회")
async def get_latest_survey(
    current_user: dict = Depends(get_current_user),
):
    """
    사용자가 완료한 최신 설문 하나를 조회합니다.
    """
    if not current_user.get("survey_completed"):
        raise HTTPException(status_code=404, detail="완료된 설문이 없습니다.")

    surveys = list(current_user.get("surveys", []))
    if not surveys:
        raise HTTPException(status_code=404, detail="완료된 설문이 없습니다.")

    latest = max(surveys, key=_safe_completed_at)

    latest["completed_at"] = parse_datetime_value(latest.get("completed_at"))
    return latest


@router.post(
    "/surveys",
    response_model=SurveyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="설문 추가",
)
async def add_survey(
    survey: SurveyCreate,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    새로운 설문 결과를 추가합니다.

    - **type**: 고유한 설문 유형
    - **description**: 설문 제목 (DB에는 저장되지 않음)
    - **answers**: 설문 응답 데이터 (선택사항)
    """
    user_obj_id = current_user["_id"]
    completed_utc = ensure_utc(survey.completed_at)

    survey_doc = {
        "type": survey.type,
        "completed_at": completed_utc,
        "answers": survey.answers,
    }

    # 기존 설문 목록
    existing_surveys = list(current_user.get("surveys", []))
    survey_exists = False

    # before_survey / after_survey 만 type 중복 체크 (덮어쓰기)
    if survey.type.lower() in {"before_survey", "after_survey"}:
        for i, s in enumerate(existing_surveys):
            if s.get("type") == survey.type:
                existing_surveys[i] = survey_doc
                survey_exists = True
                break

    if not survey_exists:
        existing_surveys.append(survey_doc)

    update_fields = {
        "surveys": existing_surveys,
        "updated_at": datetime.now(timezone.utc),
    }

    if survey.type.lower() == "before_survey":
        update_fields["survey_completed"] = True

    await db[USER_COLLECTION].update_one(
        {"_id": user_obj_id},
        {"$set": update_fields},
    )

    return SurveyResponse(
        type=survey_doc["type"],
        completed_at=completed_utc,
        answers=survey_doc["answers"],
    )


# ============= progress =============
@router.get("/progress", response_model=UserDataResponse, summary="전체 진행도 조회")
async def get_user_progress(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    사용자의 전체 진행 상황을 조회합니다.

    - **value_goal**: 핵심 가치
    - **survey_completed**: 사전 설문 완료 여부
    - **current_week**: 현재 주차
    - **last_completed_week**
    - **last_completed_at**
    - **total_diaries**: 작성한 다이어리 수
    - **total_relaxations**: 완료한 이완 훈련 수
    """
    raw_last_week = current_user.get("last_completed_week")
    last_completed_week = raw_last_week if raw_last_week is not None else 0
    last_completed_at = parse_datetime_value(current_user.get("last_completed_at"))

    # 현재 주차 계산 (가장 최근 미완료 주차)
    MAX_WEEK = 8
    if last_completed_week == 0:
        current_week = 1
    else:
        current_week = min(last_completed_week + 1, MAX_WEEK)

    # 다이어리 및 이완 훈련 카운트
    diary_collection = db["diaries"]
    total_diaries = await diary_collection.count_documents(
        {"user_id": current_user.get("user_id")}
    )

    relaxation_collection = db["relaxation_tasks"]
    total_relaxations = await relaxation_collection.count_documents(
        {
            "user_id": current_user.get("user_id"),
            # ✅ end_time이 None이 아닌 것만 "완료된 이완 세션"으로 간주
            "end_time": {"$ne": None},
        }
    )

    value_goal = current_user.get("value_goal")

    return UserDataResponse(
        value_goal=value_goal,
        survey_completed=current_user.get("survey_completed", False),
        current_week=current_week,
        last_completed_week=last_completed_week,
        last_completed_at=last_completed_at,
        total_diaries=total_diaries,
        total_relaxations=total_relaxations,
    )

