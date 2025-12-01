from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class ScheduleAction(BaseModel):
    label: str = Field(..., min_length=1, description="실천할 행동 이름")
    chip_id: Optional[str] = Field(
        None, description="연결된 custom tag chip_id"
    )


class ScheduleEventBase(BaseModel):
    start_date: date = Field(..., description="계획 시작일")
    end_date: date = Field(..., description="계획 종료일 (포함)")
    actions: List[ScheduleAction] = Field(
        default_factory=list, description="실천할 행동 목록"
    )


class ScheduleEventCreate(ScheduleEventBase):
    client_timestamp: datetime


class ScheduleEventUpdate(BaseModel):
    # 부분 수정용
    start_date: Optional[date] = Field(
        None, description="계획 시작일"
    )
    end_date: Optional[date] = Field(
        None, description="계획 종료일 (포함)"
    )
    actions: Optional[List[ScheduleAction]] = Field(
        None, description="실천할 행동 목록"
    )
    client_timestamp: datetime


class ScheduleEventDelete(BaseModel):
    client_timestamp: datetime


class ScheduleEventResponse(ScheduleEventBase):
    event_id: str
    created_at: datetime
    updated_at: datetime

