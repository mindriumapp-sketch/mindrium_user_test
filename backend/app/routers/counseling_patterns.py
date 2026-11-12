from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends
from core.security import get_current_user_id
from core.counseling_patterns import WINDOW_DAYS, analyze_patterns
from db.mongo import get_db
from routers.alarm_settings import list_alarm_settings
from routers.diaries import _build_diary_query

router = APIRouter(prefix='/counseling', tags=['counseling_patterns'])


@router.get('/patterns')
async def counseling_patterns(user_id: str = Depends(get_current_user_id), db=Depends(get_db)):
    now = datetime.now(timezone.utc)
    query = _build_diary_query(user_id, exclude_auto=True, include_drafts=False)
    query['created_at'] = {'$gte': now - timedelta(days=WINDOW_DAYS), '$lte': now}
    projection = {'created_at': 1, 'loc_time': 1, 'alarms': 1, 'activation': 1, 'latest_sud': 1}
    diaries = [doc async for doc in db['diaries'].find(query, projection).sort('created_at', -1)]
    alarms = await list_alarm_settings(db=db, user_id=user_id)
    return analyze_patterns(diaries, alarms, now)
