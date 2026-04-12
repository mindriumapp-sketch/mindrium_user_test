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
from core.today_task_draft_progress import (
    TODAY_TASK_ROUTE,
    completed_draft_progress_filter,
)
from core.utils import parse_datetime_value, ensure_utc, get_week_range_kst, kst_midnight

from fastapi import APIRouter, Depends, HTTPException, status
from db.mongo import get_db
from schemas.user import (
    ValueGoalUpdate,
    ValueGoalResponse,
    SurveyCreate,
    SurveyResponse,
    UserDataResponse,
    TodayTaskResponse,
)

router = APIRouter(prefix="/users/me")

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

    - value_goal: 핵심 가치
    - survey_completed: 사전 설문 완료 여부
    - current_week: 현재 주차 (이번 주 안에 완료한 주차는 다음 주부터 열림)
    - last_completed_week
    - last_completed_at
    - total_diaries: 작성한 다이어리 수
    - total_relaxations: 완료한 이완 훈련 수
    """
    raw_last_week = current_user.get("last_completed_week")
    last_completed_week = raw_last_week if raw_last_week is not None else 0
    last_completed_at = parse_datetime_value(current_user.get("last_completed_at"))

    MAX_WEEK = 8

    # ---- current_week 계산 ----
    if last_completed_week <= 0:
        # 아무 주차도 완료 안 했으면 무조건 1주차
        current_week = 1
    elif last_completed_week >= MAX_WEEK:
        # 8주차까지 다 끝냈으면 계속 8 고정
        current_week = MAX_WEEK
    else:
        # 1~7주차 사이에서 완료 기록이 있는 경우
        if last_completed_at is None:
            # 날짜 정보가 없으면 기존처럼 +1
            current_week = min(last_completed_week + 1, MAX_WEEK)
        else:
            # 오늘(KST) 기준 이번 주 범위 계산
            now_utc = datetime.now(timezone.utc)
            today_start_kst = kst_midnight(now_utc)
            today_date = today_start_kst.date()

            week_start_kst, week_end_kst = get_week_range_kst(today_date)
            week_start_utc = week_start_kst.astimezone(timezone.utc)
            week_end_utc = week_end_kst.astimezone(timezone.utc)

            # last_completed_at 이 "이번 주" 안이면 → 아직 다음 주차 오픈 X
            if week_start_utc <= last_completed_at < week_end_utc:
                current_week = last_completed_week
            else:
                # 지난주(이전 주)에 완료한 거면 → 다음 주차 오픈
                current_week = min(last_completed_week + 1, MAX_WEEK)

    # ---- 다이어리 및 이완 카운트 ----
    diary_collection = db["diaries"]
    total_diaries = await diary_collection.count_documents(
        {
            "user_id": current_user.get("user_id"),
            "activation.label": {"$not": {"$regex": "자동 생성"}},
        }
    )

    relaxation_collection = db["relaxation_tasks"]
    total_relaxations = await relaxation_collection.count_documents(
        {
            "user_id": current_user.get("user_id"),
            "end_time": {"$ne": None},  # 완료된 이완만 카운트
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

# ============= today task =============
DIARY_COLLECTION = "diaries"
RELAX_COLLECTION = "relaxation_tasks"

@router.get(
    "/todaytask",
    response_model=TodayTaskResponse,
    summary="홈 화면용: 오늘 일기/이완/주차 교육 완료 여부",
)
async def get_today_task(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    홈 화면 '오늘의 할 일' 체크용 상태 요약.

    - has_diary_today:
        오늘(KST 기준) 작성된 일기가 1개 이상이면 True
    - has_relaxation_today:
        오늘(KST 기준) 시작한 이완 세션 중 duration_seconds > 0
        이면서 end_time != None 인 세션이 1개 이상이면 True
    - has_education_this_week:
        users.last_completed_at 이 이번 주(월~일, KST 기준) 안에 있으면 True
    """
    user_id = current_user.get("user_id")
    if not user_id:
        raise RuntimeError("current_user에 user_id가 없습니다.")

    # ---- 1) 오늘(KST) 날짜 계산 ----
    now_utc = datetime.now(timezone.utc)
    today_start_kst = kst_midnight(now_utc)          # 오늘 00:00 KST
    today_end_kst = today_start_kst + timedelta(days=1)

    today_start_utc = today_start_kst.astimezone(timezone.utc)
    today_end_utc = today_end_kst.astimezone(timezone.utc)

    today_date = today_start_kst.date()

    # ---- 2) todaytask용 current_week 계산 ----
    raw_last_week = current_user.get("last_completed_week")
    last_completed_week = raw_last_week if raw_last_week is not None else 0
    last_completed_at = parse_datetime_value(current_user.get("last_completed_at"))

    MAX_WEEK = 8
    if last_completed_week <= 0:
        current_week = 1
    elif last_completed_week >= MAX_WEEK:
        current_week = MAX_WEEK
    elif last_completed_at is None:
        current_week = min(last_completed_week + 1, MAX_WEEK)
    else:
        week_start_kst, week_end_kst = get_week_range_kst(today_date)
        week_start_utc = week_start_kst.astimezone(timezone.utc)
        week_end_utc = week_end_kst.astimezone(timezone.utc)
        if week_start_utc <= last_completed_at < week_end_utc:
            current_week = last_completed_week
        else:
            current_week = min(last_completed_week + 1, MAX_WEEK)

    # ---- 3) 오늘 일기 작성 여부 (diaries.created_at 기준) ----
    diary_count_today = await db[DIARY_COLLECTION].count_documents(
        {
            "user_id": user_id,
            "created_at": {
                "$gte": today_start_utc,
                "$lt": today_end_utc,
            },
            # 🔹 자동생성 label 포함된 애들 제외
            "activation.label": {"$not": {"$regex": "자동 생성"}},
            # today_task는 draft_progress=100만 완료로 간주한다.
            "$or": [
                {"route": {"$ne": TODAY_TASK_ROUTE}},
                {
                    "route": TODAY_TASK_ROUTE,
                    "draft_progress": completed_draft_progress_filter(),
                },
            ],
        }
    )
    has_diary_today = diary_count_today > 0

    # ---- 4) 오늘 이완 여부 (relaxation_tasks.start_time 기준) ----
    relax_collection = db[RELAX_COLLECTION]
    daily_review_count_today = await relax_collection.count_documents(
        {
            "user_id": user_id,
            "task_id": "daily_review",
            "duration_seconds": {"$gt": 0},
            "end_time": {"$ne": None},  # 완료된 이완만 '했다'로 간주
            "start_time": {
                "$gte": today_start_utc,
                "$lt": today_end_utc,
            },
        }
    )
    week_education_task_id = f"week{current_week}_education"
    week_education_count_today = await relax_collection.count_documents(
        {
            "user_id": user_id,
            "task_id": week_education_task_id,
            "duration_seconds": {"$gt": 0},
            "end_time": {"$ne": None},
            "start_time": {
                "$gte": today_start_utc,
                "$lt": today_end_utc,
            },
        }
    )
    has_relaxation_today = (
        (daily_review_count_today > 0) or (week_education_count_today > 0)
    )

    # ---- 5) 이번 주 교육 완료 여부 (users.last_completed_at 기준) ----
    # 기존 /users/me/progress 에서 쓰는 필드 그대로 사용
    week_start_kst, week_end_kst = get_week_range_kst(today_date)
    week_start_utc = week_start_kst.astimezone(timezone.utc)
    week_end_utc = week_end_kst.astimezone(timezone.utc)

    if last_completed_at is not None:
        # last_completed_at 이 timezone-aware 라는 가정 (parse_datetime_value 사용)
        has_education_this_week = week_start_utc <= last_completed_at < week_end_utc
    else:
        has_education_this_week = False

    return TodayTaskResponse(
        date=today_date,
        has_diary_today=has_diary_today,
        has_relaxation_today=has_relaxation_today,
        has_education_this_week=has_education_this_week,
        last_education_at=last_completed_at,
    )
