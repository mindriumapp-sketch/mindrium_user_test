from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, Field


class NotificationSchedule(BaseModel):
    hour: int = Field(..., ge=0, le=23)
    minute: int = Field(..., ge=0, le=59)
    weekdays: List[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5, 6, 7])
    timezone: str = "Asia/Seoul"


class NotificationLocation(BaseModel):
    latitude: float
    longitude: float
    label: Optional[str] = None
    radius_meters: int = Field(120, ge=30, le=1000)
    notify_on_enter: bool = True
    notify_on_exit: bool = False


class NotificationSettingPayload(BaseModel):
    alarm_id: str = Field(..., min_length=1)
    label: str = Field("Mindrium 알림", min_length=1)
    enabled: bool = True
    vibration: bool = True
    schedule: NotificationSchedule
    location: Optional[NotificationLocation] = None


class NotificationSettingsReplaceRequest(BaseModel):
    notifications: List[NotificationSettingPayload] = Field(default_factory=list)
    # 이전 payload 호환용 (flat alarms 배열)
    alarms: Optional[List[Any]] = None
    client_timestamp: datetime
