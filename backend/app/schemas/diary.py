from datetime import datetime
from typing import List, Optional, Any, Literal
from pydantic import BaseModel, Field
from schemas.sud import SudScoreResponse  # 경로 맞게

# ---------- Alarm ----------

class AlarmBase(BaseModel):
    time: Optional[str] = None
    location_desc: Optional[str] = None
    repeat_option: Optional[str] = None
    weekdays: List[int] = Field(default_factory=list)
    reminder_minutes: Optional[int] = None
    enter: bool = False
    exit: bool = False


class AlarmCreate(AlarmBase):
    client_timestamp: datetime


class AlarmUpdate(BaseModel):
    time: Optional[str] = None
    location_desc: Optional[str] = None
    repeat_option: Optional[str] = None
    weekdays: Optional[List[int]] = None
    reminder_minutes: Optional[int] = None
    enter: Optional[bool] = None
    exit: Optional[bool] = None
    client_timestamp: datetime


class AlarmDelete(BaseModel):
    client_timestamp: datetime


class AlarmResponse(AlarmBase):
    alarm_id: str
    created_at: datetime
    updated_at: datetime


# ---------- Diary chips ----------

class DiaryChip(BaseModel):
    label: str = Field(..., min_length=1, description="실천할 행동 이름")
    chip_id: Optional[str] = Field(
        None, description="연결된 custom tag chip_id (선택)"
    )
    category: Optional[Literal["anxious", "healthy"]] = None


# ---------- Diary ----------

class DiaryBase(BaseModel):
    group_id: Optional[str] = None
    activation: DiaryChip
    belief: List[DiaryChip] = Field(default_factory=list)
    consequence_physical: List[DiaryChip] = Field(default_factory=list)
    consequence_emotion: List[DiaryChip] = Field(default_factory=list)
    consequence_action: List[DiaryChip] = Field(default_factory=list)
    alternative_thoughts: List[str] = Field(default_factory=list)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address_name: Optional[str] = None


class DiaryCreate(DiaryBase):
    sud_scores: List[Any] = Field(default_factory=list)
    alarms: List[Any] = Field(default_factory=list)
    client_timestamp: datetime


class DiaryUpdate(BaseModel):
    group_id: Optional[str] = None
    activation: Optional[DiaryChip] = None
    belief: Optional[List[DiaryChip]] = None
    consequence_physical: Optional[List[DiaryChip]] = None
    consequence_emotion: Optional[List[DiaryChip]] = None
    consequence_action: Optional[List[DiaryChip]] = None
    alternative_thoughts: Optional[List[str]] = None

    alarms: Optional[List[Any]] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address_name: Optional[str] = None
    client_timestamp: datetime


class DiaryResponse(DiaryBase):
    diary_id: str
    created_at: datetime
    updated_at: datetime
    latest_sud: Optional[int] = None

    sud_scores: List[SudScoreResponse] = Field(default_factory=list)
    alarms: List[AlarmResponse] = Field(default_factory=list)


class DiarySummaryResponse(BaseModel):
    diary_id: str
    group_id: Optional[str] = None
    activation: DiaryChip
    belief: List[DiaryChip] = Field(default_factory=list)
    consequence_physical: List[DiaryChip] = Field(default_factory=list)
    consequence_emotion: List[DiaryChip] = Field(default_factory=list)
    consequence_action: List[DiaryChip] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
    latest_sud: Optional[int] = None
