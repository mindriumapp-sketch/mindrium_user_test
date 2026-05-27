from datetime import datetime, timezone, date
from bson import ObjectId
from pymongo import ReturnDocument

from core.security import get_user_obj_id, get_current_user, verify_password
from core.utils import parse_datetime_value, get_week_range_kst

from fastapi import APIRouter, Depends, HTTPException, Query
from db.mongo import get_db
from schemas.user import UserMe, UpdateUser, WeeklyUserStats, AccountDeleteRequest

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
        "patient_id": user.get("patient_id"),
        "email": user["email"],
        "name": user["name"],
        "survey_completed": user.get("survey_completed", False),
        "email_verified": user.get("email_verified", False),
        "last_active_at": parse_datetime_value(user.get("last_active_at")),
        "created_at": parse_datetime_value(user.get("created_at")),
        "updated_at": parse_datetime_value(user.get("updated_at")),
    }


@router.delete("/me")
async def delete_me(
    payload: AccountDeleteRequest,
    db=Depends(get_db),
    user_obj_id: ObjectId = Depends(get_user_obj_id),
):
    collection = db[USER_COLLECTION]
    user = await collection.find_one({"_id": user_obj_id})
    if not user or user.get("is_deleted"):
        raise HTTPException(status_code=400, detail="Account not found or already deleted")

    stored_hash = user.get("password_hash")
    if not stored_hash or not verify_password(payload.password, stored_hash):
        raise HTTPException(status_code=401, detail="Current password is incorrect")

    now = datetime.now(timezone.utc)
    user_id = user.get("user_id") or str(user_obj_id)
    tombstone_email = f"deleted_{user_id}@invalid.local"

    await collection.update_one(
        {"_id": user_obj_id},
        {
            "$set": {
                "is_deleted": True,
                "deleted_at": now,
                "email": tombstone_email,
                "name": "탈퇴회원",
                "phone": "",
                "updated_at": now,
            },
            "$unset": {
                "refresh_hash": "",
                "refresh_issued_at": "",
                "password_reset_hash": "",
                "password_reset_requested_at": "",
            },
        },
    )
    return {"success": True, "message": "Account deleted"}


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
            return_document=ReturnDocument.AFTER,
        )
        user = updated_user
    else:
        user = await collection.find_one({"_id": user_obj_id})

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "user_id": user["user_id"],
        "patient_id": user.get("patient_id"),
        "email": user["email"],
        "name": user["name"],
        "survey_completed": user.get("survey_completed", False),
        "email_verified": user.get("email_verified", False),
        "last_active_at": parse_datetime_value(user.get("last_active_at")),
        "created_at": parse_datetime_value(user.get("created_at")),
        "updated_at": parse_datetime_value(user.get("updated_at")),
    }


@router.get("/stats/week", response_model=WeeklyUserStats)
async def get_weekly_user_stats(
        week_date: date | None = Query(None),
        _=Depends(get_current_user),
        db=Depends(get_db),
):
    collection = db[USER_COLLECTION]

    week_start_kst, week_end_kst = get_week_range_kst(week_date)
    week_start_utc = week_start_kst.astimezone(timezone.utc)
    week_end_utc = week_end_kst.astimezone(timezone.utc)

    total_users = await collection.count_documents(
        {"created_at": {"$lt": week_end_utc}}
    )

    new_users = await collection.count_documents(
        {
            "created_at": {
                "$gte": week_start_utc,
                "$lt": week_end_utc,
            }
        }
    )

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
