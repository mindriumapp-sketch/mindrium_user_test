from datetime import datetime
from typing import Any, List, Literal, Optional

from pydantic import BaseModel, Field

from schemas.sud import SudScoreResponse  # 경로 맞게

# ---------- LocTime ----------


class LocTimeBase(BaseModel):
    time: Optional[str] = None
    location: Optional[str] = None


class LocTimeCreate(LocTimeBase):
    client_timestamp: datetime


class LocTimeUpdate(BaseModel):
    time: Optional[str] = None
    location: Optional[str] = None
    client_timestamp: datetime


class LocTimeDelete(BaseModel):
    client_timestamp: datetime


class LocTimeResponse(LocTimeBase):
    id: str


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
    loc_time: Optional[Any] = None
    # 이전 payload 호환용 (권장: loc_time 사용)
    alarms: Optional[List[Any]] = None
    client_timestamp: datetime


class DiaryUpdate(BaseModel):
    group_id: Optional[str] = None
    activation: Optional[DiaryChip] = None
    belief: Optional[List[DiaryChip]] = None
    consequence_physical: Optional[List[DiaryChip]] = None
    consequence_emotion: Optional[List[DiaryChip]] = None
    consequence_action: Optional[List[DiaryChip]] = None
    alternative_thoughts: Optional[List[str]] = None

    loc_time: Optional[Any] = None
    # 이전 payload 호환용 (권장: loc_time 사용)
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
    loc_time: Optional[LocTimeResponse] = None


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
