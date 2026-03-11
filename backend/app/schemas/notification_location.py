from datetime import datetime

from pydantic import BaseModel, Field


class LocationLabelCreate(BaseModel):
    label: str = Field(..., min_length=1, max_length=30)
    client_timestamp: datetime


class LocationLabelResponse(BaseModel):
    label: str
    last_used_at: datetime
