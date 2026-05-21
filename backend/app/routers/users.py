from datetime import datetime, timezone, date
from bson import ObjectId
from pymongo import ReturnDocument

from core.security import get_user_obj_id, get_current_user, require_role
from core.audit import audit_log
from core.utils import parse_datetime_value, get_week_range_kst

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
        "patient_id": user.get("patient_id"),
        "email": user["email"],
        "name": user["name"],
        "gender": user.get("gender"),
        "address": user.get("address"),
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
        # 사용자가 실제 변경한 필드 목록 (timestamp 추가 전에 보존)
        changed_field_names = list(update_fields.keys())
        update_fields["updated_at"] = datetime.now(timezone.utc)
        updated_user = await collection.find_one_and_update(
            {"_id": user_obj_id},
            {"$set": update_fields},
            return_document=ReturnDocument.AFTER,
        )
        user = updated_user

        # 식별정보관리 STEP 3: PII 변경 감사 기록
        if user:
            audit_log(
                "pii_update",
                user_id=user.get("user_id") or str(user_obj_id),
                fields_changed=changed_field_names,
            )
    else:
        user = await collection.find_one({"_id": user_obj_id})

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "user_id": user["user_id"],
        "patient_id": user.get("patient_id"),
        "email": user["email"],
        "name": user["name"],
        "gender": user.get("gender"),
        "address": user.get("address"),
        "survey_completed": user.get("survey_completed", False),
        "email_verified": user.get("email_verified", False),
        "last_active_at": parse_datetime_value(user.get("last_active_at")),
        "created_at": parse_datetime_value(user.get("created_at")),
        "updated_at": parse_datetime_value(user.get("updated_at")),
    }


@router.get("/stats/week", response_model=WeeklyUserStats)
async def get_weekly_user_stats(
        week_date: date | None = Query(None),
        _=Depends(require_role("staff")),
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
