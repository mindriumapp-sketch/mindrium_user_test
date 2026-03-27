from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field

class CustomTagBase(BaseModel):
    is_preset: bool = False
    label: str = Field(..., min_length=1)
    type: Literal["A", "B", "CP", "CE", "CA"]

class CustomTagCreate(CustomTagBase):
    client_timestamp: datetime

class CustomTagUpdate(BaseModel):
    label: Optional[str] = None
    type: Optional[Literal["A", "B", "CP", "CE", "CA"]] = None
    is_preset: Optional[bool] = None
    client_timestamp: datetime

class CustomTagDelete(BaseModel):
    client_timestamp: datetime

class CustomTagResponse(BaseModel):
    chip_id: str
    label: str
    type: Literal["A", "B", "CP", "CE", "CA"]
    is_preset: bool = False
    deleted: bool = False
    created_at: datetime
    updated_at: datetime


class RealOddnessLogsCreate(BaseModel):
    diary_id: str
    chip_id: str
    before_odd: int = Field(0, ge=0, le=10)
    after_odd: Optional[int] = Field(None, ge=0, le=10)
    alternative_thought: str
    completed_at: datetime

class RealOddnessLogResponse(RealOddnessLogsCreate):
    log_id: str
    created_at: datetime
    updated_at: datetime


class CategoryLogsCreate(BaseModel):
    diary_id: str
    chip_id: str
    category: Literal["anxious", "healthy"] # 분류 퀴즈 변수명 그대로
    short_term: Optional[Literal["confront", "avoid"]] # 행동에서만 분류
    long_term: Optional[Literal["confront", "avoid"]]
    is_changed: bool = False
    completed_at: datetime


class CategoryLogResponse(CategoryLogsCreate):
    log_id: str
    created_at: datetime
    updated_at: datetime
