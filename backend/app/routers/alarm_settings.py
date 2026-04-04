from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import uuid

from fastapi import APIRouter, Depends

from core.security import get_current_user_id
from db.mongo import get_db
from schemas.notification_setting import (
    NotificationSettingPayload,
    NotificationSettingsReplaceRequest,
)

router = APIRouter(prefix="/alarm-settings", tags=["alarm-settings"])
NOTIFICATION_SETTINGS_COLLECTION = "notification_settings"


def _normalize_weekdays(raw: Any) -> List[int]:
    if not isinstance(raw, list):
        return [1, 2, 3, 4, 5, 6, 7]

    values: List[int] = []
    for item in raw:
        try:
            day = int(item)
        except Exception:
            continue
        if 1 <= day <= 7:
            values.append(day)

    unique = sorted(set(values))
    return unique or [1, 2, 3, 4, 5, 6, 7]


def _read_int(raw: Any, fallback: int) -> int:
    try:
        return int(raw)
    except Exception:
        return fallback


def _read_float(raw: Any) -> Optional[float]:
    try:
        return float(raw)
    except Exception:
        return None


def _normalize_location(raw: dict) -> Optional[dict]:
    # 신규 포맷: location 객체
    if isinstance(raw.get("location"), dict):
        location = dict(raw["location"])
        location_name = location.get("location") or location.get("label")
        if location_name is not None:
            location["location"] = location_name
        location.pop("label", None)
        if "radius_meters" not in location:
            location["radius_meters"] = 100
        location.pop("notify_on_enter", None)
        location.pop("notify_on_exit", None)
        return location

    # 레거시 포맷: flat location fields
    location_enabled = raw.get("location_enabled") is True
    latitude = _read_float(raw.get("latitude"))
    longitude = _read_float(raw.get("longitude"))
    if not location_enabled or latitude is None or longitude is None:
        return None

    location_value = raw.get("location")
    if isinstance(location_value, dict):
        location_value = location_value.get("location") or location_value.get("label")

    return {
        "latitude": latitude,
        "longitude": longitude,
        "location": location_value or raw.get("location_label"),
        "address": raw.get("location_address")
        or raw.get("address_name")
        or raw.get("location_desc"),
        "radius_meters": max(30, min(_read_int(raw.get("location_radius_meters"), 100), 1000)),
    }


def _normalize_notification(raw: dict) -> NotificationSettingPayload:
    payload = dict(raw or {})

    # 신규 포맷: alarm_id + schedule
    if isinstance(payload.get("alarm_id"), str) and isinstance(payload.get("schedule"), dict):
        schedule = dict(payload["schedule"])
        schedule["weekdays"] = _normalize_weekdays(schedule.get("weekdays"))
        if not schedule.get("timezone"):
            schedule["timezone"] = "Asia/Seoul"
        payload["schedule"] = schedule
        payload["location"] = _normalize_location(payload)
        return NotificationSettingPayload(**payload)

    # 레거시 포맷: id/hour/minute/...
    schedule = {
        "hour": max(0, min(_read_int(payload.get("hour"), 9), 23)),
        "minute": max(0, min(_read_int(payload.get("minute"), 0), 59)),
        "weekdays": _normalize_weekdays(payload.get("weekdays")),
        "timezone": payload.get("timezone") or "Asia/Seoul",
    }
    normalized = {
        "alarm_id": payload.get("alarm_id")
        or payload.get("id")
        or f"alarm_{uuid.uuid4().hex[:8]}",
        "label": payload.get("label") or "Mindrium 알림",
        "enabled": payload.get("enabled") is True,
        "vibration": payload.get("vibration") is not False,
        "schedule": schedule,
        "location": _normalize_location(payload),
    }
    return NotificationSettingPayload(**normalized)


def _sort_notifications(
    notifications: List[NotificationSettingPayload],
) -> List[NotificationSettingPayload]:
    return sorted(
        notifications,
        key=lambda item: (
            item.schedule.hour * 60 + item.schedule.minute,
            item.alarm_id,
        ),
    )


@router.get("", response_model=List[NotificationSettingPayload])
async def list_alarm_settings(
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[NOTIFICATION_SETTINGS_COLLECTION]
    cursor = collection.find({"user_id": user_id})

    # alarm_id 기준 중복 제거 (마이그레이션 중 legacy/신규 문서 공존 대비)
    notification_map: Dict[str, NotificationSettingPayload] = {}

    async for doc in cursor:
        try:
            # legacy 형식: user 1문서 + alarms 배열
            if isinstance(doc.get("alarms"), list):
                for raw in doc.get("alarms", []):
                    if not isinstance(raw, dict):
                        continue
                    notification = _normalize_notification(raw)
                    notification_map[notification.alarm_id] = notification
                continue

            # 신규 형식: 알림 1건 = 문서 1개
            notification = _normalize_notification(doc)
            notification_map[notification.alarm_id] = notification
        except Exception:
            continue

    return _sort_notifications(list(notification_map.values()))


@router.put("", response_model=List[NotificationSettingPayload])
async def replace_alarm_settings(
    payload: NotificationSettingsReplaceRequest,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[NOTIFICATION_SETTINGS_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    notifications: List[NotificationSettingPayload] = []

    for item in payload.notifications:
        notifications.append(_normalize_notification(item.model_dump()))

    # 이전 payload(alarms 배열) 호환
    if not notifications and payload.alarms:
        for raw in payload.alarms:
            if isinstance(raw, dict):
                notifications.append(_normalize_notification(raw))

    notifications = _sort_notifications(notifications)

    # 사용자 알림 전체 교체: 기존 문서 삭제 후 알림별 문서 삽입
    await collection.delete_many({"user_id": user_id})

    if notifications:
        docs = [
            {
                "user_id": user_id,
                **notification.model_dump(exclude_none=True),
                "created_at": now_utc,
                "updated_at": now_utc,
            }
            for notification in notifications
        ]
        await collection.insert_many(docs)

    return notifications
