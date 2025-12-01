from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

class WorryGroupBase(BaseModel):
    group_title: str = ""
    group_contents: str = ""
    character_id: int = Field(..., ge=1, le=20)

class WorryGroupCreate(WorryGroupBase):
    client_timestamp: datetime

class WorryGroupUpdate(BaseModel):
    group_title: Optional[str] = None
    group_contents: Optional[str] = None
    character_id: Optional[int] = Field(None, ge=1, le=20)
    client_timestamp: datetime

class WorryGroupDelete(BaseModel):
    client_timestamp: datetime

class WorryGroupResponse(WorryGroupBase):
    group_id: str
    created_at: datetime
    updated_at: datetime
    archived: bool = False
    diary_count: int = 0
    avg_sud: Optional[float] = None
