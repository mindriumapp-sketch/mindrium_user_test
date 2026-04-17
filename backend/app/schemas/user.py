from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Dict, Any
from datetime import date, datetime


class UserBase(BaseModel):
    email: EmailStr
    name: str
    gender: Optional[str] = None
    address: Optional[str] = None

class UserMe(UserBase):
    user_id: str
    patient_id: Optional[str] = None
    survey_completed: bool
    email_verified: bool
    last_active_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UpdateUser(BaseModel):
    name: Optional[str] = None
    gender: Optional[str] = None
    address: Optional[str] = None


class ValueGoalUpdate(BaseModel):
    value_goal: str = Field(..., min_length=1, max_length=500, description="사용자의 핵심 가치")


class ValueGoalResponse(BaseModel):
    value_goal: Optional[str] = None


class SurveyCreate(BaseModel):
    type: str = Field(..., description="설문 유형 ID (예: GAD7_pre, GAD7_post)")
    description: Optional[str] = Field(None, description="설문 설명 (DB에는 저장되지 않음)")
    answers: Optional[Dict[str, Any]] = Field(None, description="설문 응답 데이터")
    completed_at: datetime = Field(..., description="설문 완료 시각")


class SurveyResponse(BaseModel):
    type: str
    answers: Optional[Dict[str, Any]] = None
    completed_at: datetime


class UserDataResponse(BaseModel):
    value_goal: Optional[str] = None
    survey_completed: bool = False
    current_week: int = 1
    last_completed_week: int = Field(
        0, ge=0, le=8, description="마지막으로 완료한 주차 (1~8, 없으면 0)"
    )
    last_completed_at: Optional[datetime] = None
    total_diaries: int = 0
    total_relaxations: int = 0


class WeeklyUserStats(BaseModel):
    weekStart: date
    totalUsers: int = Field(0, ge=0)
    activeUsers: int = Field(0, ge=0)
    newUsers: int = Field(0, ge=0)


class TodayTaskResponse(BaseModel):
    date: date
    has_diary_today: bool
    has_relaxation_today: bool
    relaxation_entry_mode_today: str = "review"
    relaxation_week_no_today: int = 1
