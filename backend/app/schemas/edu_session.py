# schemas/edu_session.py
from datetime import datetime
from typing import List, Optional, Literal
from pydantic import BaseModel, Field


# ================= 공통: 분류 퀴즈 (3,5주차) =================

class ClassificationQuizResult(BaseModel):
    """분류 퀴즈 개별 문항 결과"""
    text: str
    correct_type: str           # 예: "anxious" / "healthy" 등
    user_choice: str            # 사용자가 고른 타입
    is_correct: bool


class ClassificationQuiz(BaseModel):
    """분류 퀴즈 전체 결과"""
    correct_count: int
    total_count: int
    results: List[ClassificationQuizResult]


# ================= 공통: 7주차 행동 분석 =================

class BehaviorExecutionAnalysis(BaseModel):
    """
    7주차: 행동 분석 폼 내용
    (필요한 항목만 채워도 되도록 전부 Optional)
    """
    execution_short_gain: Optional[str] = None
    execution_long_gain: Optional[bool] = None
    non_execution_gain: Optional[str] = None
    non_execution_short_loss: Optional[str] = None
    non_execution_long_loss: Optional[bool] = None


class BehaviorClassificationItem(BaseModel):
    """
    7주차: 건강한 생활 습관 행동 목록의 단일 아이템
    """
    chip_id: str = Field(..., min_length=1)
    category: Literal["confront", "avoid"]
    # added_at 제거 (세션 단위로만 관리)
    reason: Optional[str] = None
    analysis: Optional[BehaviorExecutionAnalysis] = None


# ================= 공통: 8주차 회고 =================

class EffectivenessEvaluation(BaseModel):
    """
    8주차: 행동 효과성 평가
    - behavior: chip_id가 없는 자유 입력 행동용 식별 텍스트
    - chip_id: 이미 존재하는 칩과 연결할 때 사용(없으면 None 허용)
    """
    behavior: str = Field(..., min_length=1, description="행동 텍스트")
    chip_id: Optional[str] = Field(
        None,
        description="행동의 chip_id (새로 추가한 행동의 경우 null 가능)",
    )
    was_effective: bool
    will_continue: bool


class UserJourneyResponse(BaseModel):
    """8주차: 사용자 여정 질문/답변 한 쌍"""
    question: str = Field(..., min_length=1)
    answer: str = Field(..., min_length=1)


# ================= 공통: Edu Session (1~8주차) =================

class EduSessionCommonIn(BaseModel):
    """
    교육 세션 공통 필드 (요청용)
    - last_screen_idx 는 1-based 로 가정 (예: 전체 10개면 10이면 완주)
    """
    week_number: int = Field(
        ...,
        ge=1,
        le=8,
        description="주차 (1~8주차)",
    )
    diary_id: Optional[str] = Field(
        None,
        description=(
            "2,3,4,5,6주차: 일기 단위 세션일 때 연결되는 diary_id. "
            "1,7,8주차는 None 허용."
        ),
    )
    total_screens: int = Field(
        ...,
        ge=1,
        description="해당 주차 교육 전체 화면 수",
    )
    last_screen_idx: int = Field(
        ...,
        ge=1,
        description="마지막으로 본 화면 번호 (1-based, 예: 전체 10개면 10이면 완주)",
    )
    completed: bool = Field(
        False,
        description="해당 주차 교육 완료 여부",
    )
    start_time: datetime = Field(
        ...,
        description="이 세션을 처음 시작한 시각(최초 진입)",
    )
    end_time: Optional[datetime] = Field(
        None,
        description="마지막으로 떠난 시각(완료 시점 또는 마지막 진입 종료 시점)",
    )


class EduSessionCommonOut(EduSessionCommonIn):
    """
    교육 세션 공통 필드 (응답용: session_id, created/updated 추가)
    """
    session_id: str
    created_at: datetime
    updated_at: datetime


# ========== 생성용 스키마들 (주차별 확장) ==========

class EduSessionCreateCommon(EduSessionCommonIn):
    """
    1,2,4,6주차 등: 별도 콘텐츠 필드가 없는 기본 세션 생성용
    (week_number 는 3,5,7,8 이 아닌 주차에서만 사용)
    """
    week_number: Literal[1, 2, 4, 6]


class EduSessionCreate3And5(EduSessionCommonIn):
    """
    3,5주차: 부정/긍정 항목 + 분류 퀴즈
    """
    week_number: Literal[3, 5]
    negative_items: Optional[List[str]] = Field(
        default=None,
        description="부정적 항목 리스트 (3주차: 도움이 되지 않는 생각, 5주차: 회피 행동)",
    )
    positive_items: Optional[List[str]] = Field(
        default=None,
        description="긍정적 항목 리스트 (3주차: 도움이 되는 생각, 5주차: 직면 행동)",
    )
    classification_quiz: Optional[ClassificationQuiz] = Field(
        default=None,
        description="분류 퀴즈 결과(선택)",
    )


class EduSessionCreate7(EduSessionCommonIn):
    """
    7주차: 건강한 생활 습관 행동 목록
    """
    week_number: Literal[7]
    behavior_items: Optional[List[BehaviorClassificationItem]] = Field(
        default=None,
        description="7주차 건강한 생활 습관 행동 목록",
    )


class EduSessionCreate8(EduSessionCommonIn):
    """
    8주차: 효과성 평가 + 사용자 여정
    """
    week_number: Literal[8]
    effectiveness_evaluations: Optional[List[EffectivenessEvaluation]] = Field(
        default=None,
        description="8주차 행동 효과성 평가 리스트",
    )
    user_journey_responses: Optional[List[UserJourneyResponse]] = Field(
        default=None,
        description="8주차 사용자 여정 질문/답변 리스트",
    )


# ========== 수정용 공통 스키마 ==========
class EduSessionUpdate(BaseModel):
    """
    교육 세션 부분 수정용 공통 스키마.
    - week_number, diary_id 는 변경하지 않는다고 가정.
    - 주차별 특수 필드(3,5,7,8)도 한 번에 커버.
    """
    total_screens: Optional[int] = Field(None, ge=1)
    last_screen_idx: Optional[int] = Field(None, ge=1)
    completed: Optional[bool] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

    # 3,5주차
    negative_items: Optional[List[str]] = None
    positive_items: Optional[List[str]] = None
    classification_quiz: Optional[ClassificationQuiz] = None

    # 7주차
    behavior_items: Optional[List[BehaviorClassificationItem]] = None

    # 8주차
    effectiveness_evaluations: Optional[List[EffectivenessEvaluation]] = None
    user_journey_responses: Optional[List[UserJourneyResponse]] = None


# ========== 응답용 공통 스키마 ==========

class EduSessionResponse(EduSessionCommonOut):
    """
    edu_sessions 컬렉션 한 문서에 대응되는 풀 응답 모델.
    - week_number 에 따라 아래 필드들이 있을 수도 / 없을 수도 있음.
    - Optional + exclude_none 로 DB 에도 선택적으로만 들어가게 설계.
    """
    # 3,5주차
    negative_items: Optional[List[str]] = None
    positive_items: Optional[List[str]] = None
    classification_quiz: Optional[ClassificationQuiz] = None

    # 7주차
    behavior_items: Optional[List[BehaviorClassificationItem]] = None

    # 8주차
    effectiveness_evaluations: Optional[List[EffectivenessEvaluation]] = None
    user_journey_responses: Optional[List[UserJourneyResponse]] = None


