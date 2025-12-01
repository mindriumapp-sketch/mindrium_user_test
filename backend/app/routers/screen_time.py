from datetime import datetime, timezone, timedelta
from typing import Tuple
from core.security import get_current_user_id
from core.utils import parse_datetime_value, ensure_utc, kst_midnight

from fastapi import APIRouter, Depends,  HTTPException, Query

from db.mongo import get_db
from schemas.screen_time import ScreenTimeCreate, ScreenTimeEntry, ScreenTimeSummary

router = APIRouter(prefix="/screen-time", tags=["screen-time"])

SCREEN_COLLECTION = "screen_time"

def _serialize_entry(doc: dict) -> dict:
    return {
        "screen_id": str(doc.get("_id")),
        "start_time": parse_datetime_value(doc.get("start_time")),
        "end_time": parse_datetime_value(doc.get("end_time")),
        "duration_seconds": int(doc.get("duration_seconds")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "platform": doc.get("platform"),
    }

# TODO: Aggregate pipeline? ....
async def _window_minutes(collection, user_id: str, start_utc: datetime, end_utc: datetime) -> Tuple[float, int]:
    total = 0.0
    sessions = 0
    cursor = collection.find(
        {
            "user_id": user_id,
            "end_time": {"$gt": start_utc},
            "start_time": {"$lt": end_utc},
        }
    )
    async for doc in cursor:
        st = ensure_utc(doc.get("start_time"))
        et = ensure_utc(doc.get("end_time"))
        if not isinstance(st, datetime) or not isinstance(et, datetime):
            continue
        overlap_start = max(st, start_utc)
        overlap_end = min(et, end_utc)
        if overlap_end <= overlap_start:
            continue
        total += (overlap_end - overlap_start).total_seconds() / 60
        sessions += 1
    return total, sessions

@router.post("", response_model=ScreenTimeEntry)
async def create_screen_time_entry(
    payload: ScreenTimeCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    now = datetime.now(timezone.utc)
    start = ensure_utc(payload.start_time)
    end = ensure_utc(payload.end_time)
    if end <= start:
        raise HTTPException(status_code=400, detail="end_time must be after start_time")

    duration = int((end - start).total_seconds())
    if duration <= 0:
        raise HTTPException(status_code=400, detail="duration must be positive")

    doc = {
        "user_id": user_id,
        "start_time": start,
        "end_time": end,
        "duration_seconds": duration,
        "platform": payload.platform,
        "created_at": now,
    }
    result = await db[SCREEN_COLLECTION].insert_one(doc)
    doc["_id"] = result.inserted_id

    await db["users"].update_one(
        {"user_id": user_id},
        {"$set": {"last_active_at": now}},
    )
    return _serialize_entry(doc)


# TODO: 앱에 쓰지 말고 플랫폼팀에 넘길까용 그 '스크린타임 보러 가기' 버튼만 빼고 router 경로 바꾸면 될거같은데
@router.get("", response_model=list[ScreenTimeEntry])
async def list_screen_time_entries(
    limit: int = Query(20, ge=1, le=200),
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    cursor = (
        db[SCREEN_COLLECTION]
        .find({"user_id": user_id})
        .sort("end_time", -1)
        .limit(limit)
    )
    entries = []
    async for doc in cursor:
        entries.append(_serialize_entry(doc))
    return entries

# TODO: 플랫폼팀에 넘겨야 함
@router.get("/summary", response_model=ScreenTimeSummary)
async def get_screen_time_summary(
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    collection = db[SCREEN_COLLECTION]
    now_utc = datetime.now(timezone.utc)
    today_start_kst = kst_midnight(now_utc)
    today_end_kst = today_start_kst + timedelta(days=1)
    week_start_kst = today_start_kst - timedelta(days=6)

    today_start_utc = today_start_kst.astimezone(timezone.utc)
    today_end_utc = today_end_kst.astimezone(timezone.utc)
    week_start_utc = week_start_kst.astimezone(timezone.utc)

    today_minutes, _ = await _window_minutes(collection, user_id, today_start_utc, today_end_utc)
    week_minutes, week_sessions = await _window_minutes(collection, user_id, week_start_utc, today_end_utc)

    total_pipeline = [
        {"$match": {"user_id": user_id}},
        {"$group": {"_id": None, "sum": {"$sum": "$duration_seconds"}}},
    ]
    total_docs = await collection.aggregate(total_pipeline).to_list(length=1)
    total_minutes = total_docs[0]["sum"] / 60 if total_docs else 0.0

    last_entry = await collection.find_one({"user_id": user_id}, sort=[("end_time", -1)])
    last_entry_at = ensure_utc(last_entry.get("end_time")) if last_entry else None

    return ScreenTimeSummary(
        totalMinutes=round(total_minutes, 2),
        todayMinutes=round(today_minutes, 2),
        weekMinutes=round(week_minutes, 2),
        sessions=week_sessions,
        lastEntryAt=last_entry_at,
    )
