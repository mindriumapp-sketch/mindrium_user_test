from datetime import datetime, date
from typing import List, Optional
from pydantic import BaseModel, Field


class RelaxationLogEntry(BaseModel):
    """logs 안에 들어가는 개별 이벤트"""
    action: str
    timestamp: datetime
    elapsed_seconds: int = Field(..., ge=0)


class RelaxationTaskCreate(BaseModel):
    """
    Flutter에서 보내는 payload
    """
    task_id: str
    week_number: Optional[int] = Field(None, ge=1)
    start_time: datetime
    end_time: Optional[datetime] = None
    logs: List[RelaxationLogEntry] = Field(default_factory=list)

    # ✅ 새로 추가된 필드들 (nullable)
    latitude: Optional[float] = Field(
        default=None,
        description="위도 (optional)",
    )
    longitude: Optional[float] = Field(
        default=None,
        description="경도 (optional)",
    )
    address_name: Optional[str] = Field(
        default=None,
        description="주소명 (optional)",
    )


class RelaxationTaskResponse(BaseModel):
    """
    클라이언트로 돌려주는 응답
    """
    relax_id: str
    is_first_completed: Optional[bool] = None
    task_id: str
    week_number: Optional[int] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    logs: List[RelaxationLogEntry] = Field(default_factory=list)
    duration_seconds: int

    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime

class RelaxationTimeSummary(BaseModel):
    """
        이완 시간 요약
        - screen_time과 동일
    """
    totalMinutes: float = 0
    todayMinutes: float = 0
    weekMinutes: float = 0
    weekSessions: int = 0
    completedSessions: int = 0
    completedMinutes: float = 0
    lastEntryAt: Optional[datetime] = None


class RelaxationTaskTimeSummary(BaseModel):
    """
        이완 날짜/task별 시간 요약
    """
    taskId: Optional[str] = None
    weekNumber: Optional[int] = None
    queryDate: Optional[date] = None
    totalMinutes: float = 0
    totalSessions: int = 0
    completedSessions: int = 0
    completedMinutes: float = 0
    lastEntryAt: Optional[datetime] = None
