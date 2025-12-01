from datetime import datetime, timezone, timedelta
from typing import Optional, Any

from bson import ObjectId
from fastapi import HTTPException, status

try:
    from zoneinfo import ZoneInfo
except ModuleNotFoundError:  # pragma: no cover
    ZoneInfo = None


# ========= 시간 관련 공통 유틸 =========

def ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """
    timezone 정보 없는 datetime은 UTC로 맞춰주고,
    이미 tzinfo 있으면 UTC로 변환해서 돌려줌.
    """
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def parse_datetime_value(
    value: Any,
    fallback: Optional[datetime] = None,
) -> Optional[datetime]:
    """
    문자열 / datetime 섞여 들어오는 값들을 datetime(UTC)로 정규화.
    - 문자열이면 ISO 8601로 파싱 (Z → +00:00 처리)
    - 실패 시 fallback 있으면 fallback 사용
    """
    if isinstance(value, datetime):
        return ensure_utc(value)

    if isinstance(value, str):
        try:
            # ISO 8601 문자열 대응 (Z → +00:00)
            return ensure_utc(
                datetime.fromisoformat(value.replace("Z", "+00:00"))
            )
        except Exception:
            pass

    if fallback is not None:
        return ensure_utc(fallback)

    return None


def _get_kst_tz():
    """
    Python 3.9+ 에서 ZoneInfo 있으면 Asia/Seoul 사용.
    아니면 고정 오프셋(+9)으로 fallback.
    """
    if ZoneInfo is not None:
        try:
            return ZoneInfo("Asia/Seoul")
        except Exception:
            pass
    return timezone(timedelta(hours=9))


KST = _get_kst_tz()


def to_kst(dt: Optional[datetime]) -> Optional[datetime]:
    """
    UTC 기반 datetime을 KST로 변환.
    (None 들어오면 None 그대로)
    """
    if dt is None:
        return None
    dt_utc = ensure_utc(dt)
    return dt_utc.astimezone(KST)


def kst_midnight(now_utc: datetime) -> datetime:
    """
    주어진 UTC 시각 기준으로,
    KST 날짜의 00:00(KST)을 datetime으로 리턴.
    """
    now_kst = ensure_utc(now_utc).astimezone(KST)
    return datetime(
        now_kst.year,
        now_kst.month,
        now_kst.day,
        tzinfo=KST,
    )


# ========= ObjectID 관련 공통 유틸 =========

def to_obj_id(id: str) -> ObjectId:
    """
    문자열을 Mongo ObjectId로 변환.
    실패하면 400 에러.
    """
    try:
        obj_id = ObjectId(id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid id",
        )
    return obj_id

