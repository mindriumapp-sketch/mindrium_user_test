from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class TreatmentProgressBase(BaseModel):
    week_number: int = Field(..., ge=1, le=8)
    started_at: datetime
    ends_at: datetime
    edu_session_id: Optional[str] = None
    relaxation_task_id: Optional[str] = None
    main_completed: bool = False
    main_completed_at: Optional[datetime] = None
    daily_relax_count: int = Field(default=0, ge=0)
    daily_diary_count: int = Field(default=0, ge=0)
    requirements_met: bool = False
    completed_at: Optional[datetime] = None


class TreatmentProgressResponse(TreatmentProgressBase):
    progress_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
