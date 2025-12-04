from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Dict, Any
from datetime import date, datetime

class UserBase(BaseModel):
    email: EmailStr
    name: str
    gender: Optional[str] = None

class UserMe(UserBase):
    user_id: str
    survey_completed: bool
    email_verified: bool
    last_active_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class UpdateUser(BaseModel):
    name: Optional[str] = None
    gender: Optional[str] = None

class ValueGoalUpdate(BaseModel):
    """핵심 가치 업데이트 요청"""
    value_goal: str = Field(..., min_length=1, max_length=500, description="사용자의 핵심 가치")

class ValueGoalResponse(BaseModel):
    """핵심 가치 응답"""
    value_goal: Optional[str] = None
    # updated_at: Optional[datetime] = None

class SurveyCreate(BaseModel):
    """설문 추가 요청"""
    type: str = Field(..., description="설문 유형 ID (예: GAD7_pre, GAD7_post)")
    description: Optional[str] = Field(None, description="설문 설명 (DB에는 저장되지 않음)")
    answers: Optional[Dict[str, Any]] = Field(None, description="설문 응답 데이터")
    completed_at: datetime = Field(..., description="설문 완료 시각")

class SurveyResponse(BaseModel):
    """설문 응답"""
    type: str
    answers: Optional[Dict[str, Any]] = None
    completed_at: datetime

class UserDataResponse(BaseModel):
    """종합 사용자 데이터 응답"""
    value_goal: Optional[str] = None
    survey_completed: bool = False
    current_week: int = 1  # 계산된 현재 주차 (DB에 저장 안 해도 됨, 응답에서만 사용)
    last_completed_week: int = Field(
        0, ge=0, le=8, description="마지막으로 완료한 주차 (1~8, 없으면 0)"
    )
    last_completed_at: Optional[datetime] = None
    total_diaries: int = 0
    total_relaxations: int = 0

class WeeklyUserStats(BaseModel):
    """
    플랫폼 첫 번째 카드용: 한 주에 대한 유저 통계
    """
    weekStart: date                                # 쿼리 시점
    totalUsers: int = Field(0, ge=0)        # 해당 시점 기준 전체 유저 수
    activeUsers: int = Field(0, ge=0)       # 그 주에 last_active_at 찍힌 유저 수
    newUsers: int = Field(0, ge=0)          # 그 주에 가입한 유저 수


class TodayTaskResponse(BaseModel):
    date: date
    has_diary_today: bool
    has_relaxation_today: bool
    has_education_this_week: bool
    last_education_at: Optional[datetime] = None
