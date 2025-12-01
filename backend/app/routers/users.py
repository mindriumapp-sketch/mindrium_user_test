from datetime import datetime, timedelta, timezone, date
from bson import ObjectId
from pymongo import ReturnDocument

from core.security import get_user_obj_id, get_current_user
from core.utils import parse_datetime_value, KST

from fastapi import APIRouter, Depends, HTTPException, Query
from db.mongo import get_db
from schemas.user import UserMe, UpdateUser, WeeklyUserStats

router = APIRouter(prefix="/users", tags=["users"])
USER_COLLECTION = "users"


@router.get("/me", response_model=UserMe)
async def get_me(
    db=Depends(get_db),
    user_obj_id: ObjectId = Depends(get_user_obj_id),
):
    collection = db[USER_COLLECTION]

    user = await collection.find_one({"_id": user_obj_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "user_id": user["user_id"],
        "email": user["email"],
        "name": user["name"],
        "gender": user.get("gender"),
        "survey_completed": user.get("survey_completed", False),
        "email_verified": user.get("email_verified", False),
        "last_active_at": parse_datetime_value(user.get("last_active_at")),
        "created_at": parse_datetime_value(user.get("created_at")),
        "updated_at": parse_datetime_value(user.get("updated_at")),
    }


@router.put("/me", response_model=UserMe)
async def update_me(
    payload: UpdateUser,
    db=Depends(get_db),
    user_obj_id: ObjectId = Depends(get_user_obj_id),
):
    collection = db[USER_COLLECTION]

    update_fields = payload.model_dump(exclude_unset=True)
    if update_fields:
        update_fields["updated_at"] = datetime.now(timezone.utc)
        updated_user = await collection.find_one_and_update(
            {"_id": user_obj_id},
            {"$set": update_fields},
            return_document=ReturnDocument.AFTER,  # 업데이트된 최신 문서를 반환하도록 설정
        )
        user = updated_user
    else:
        user = await collection.find_one({"_id": user_obj_id})

    # 사용자가 없는 경우를 대비한 체크 (find_one_and_update 사용 시도 후 체크)
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",  # TODO: User not found 숨기기
        )

    return {
        "user_id": user["user_id"],
        "email": user["email"],
        "name": user["name"],
        "gender": user.get("gender"),
        "survey_completed": user.get("survey_completed", False),
        "email_verified": user.get("email_verified", False),
        "last_active_at": parse_datetime_value(user.get("last_active_at")),
        "created_at": parse_datetime_value(user.get("created_at")),
        "updated_at": parse_datetime_value(user.get("updated_at")),
    }


def _get_week_range_kst(target: date | None = None):
    if target is None:
        target = datetime.now(KST).date()
    weekday = target.weekday()  # 0=월
    week_start_kst = datetime(
        target.year,
        target.month,
        target.day,
        tzinfo=KST,
    ) - timedelta(days=weekday)
    week_end_kst = week_start_kst + timedelta(days=7)
    return week_start_kst, week_end_kst


@router.get("/stats/week", response_model=WeeklyUserStats)
async def get_weekly_user_stats(
    week_date: date | None = Query(None),
    _=Depends(get_current_user),  # 단순 인증용
    db=Depends(get_db),
):
    collection = db[USER_COLLECTION]

    week_start_kst, week_end_kst = _get_week_range_kst(week_date)
    week_start_utc = week_start_kst.astimezone(timezone.utc)
    week_end_utc = week_end_kst.astimezone(timezone.utc)

    # 해당 주 기준 "그 주까지 존재하는 전체 유저 수"
    total_users = await collection.count_documents(
        {"created_at": {"$lt": week_end_utc}}
    )

    # 그 주에 새로 가입한 유저 수
    new_users = await collection.count_documents(
        {
            "created_at": {
                "$gte": week_start_utc,
                "$lt": week_end_utc,
            }
        }
    )

    # 그 주에 last_active_at 찍힌 유저 수
    active_users = await collection.count_documents(
        {
            "last_active_at": {
                "$gte": week_start_utc,
                "$lt": week_end_utc,
            }
        }
    )

    return WeeklyUserStats(
        weekStart=week_start_kst.date(),
        totalUsers=total_users,
        activeUsers=active_users,
        newUsers=new_users,
    )

