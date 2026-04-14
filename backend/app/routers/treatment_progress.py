from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from core.utils import ensure_utc, parse_datetime_value
from core.security import get_current_user_id
from db.mongo import get_db
from pymongo import ReturnDocument
from schemas.treatment_progress import TreatmentProgressResponse

router = APIRouter(prefix="/treatment-progress", tags=["treatment_progress"])

TREATMENT_PROGRESS_COLLECTION = "treatment_progress"


def _serialize_progress(doc: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "progress_id": doc.get("progress_id"),
        "user_id": doc.get("user_id"),
        "week_number": doc.get("week_number"),
        "started_at": parse_datetime_value(doc.get("started_at")),
        "ends_at": parse_datetime_value(doc.get("ends_at")),
        "edu_session_id": doc.get("edu_session_id"),
        "relaxation_task_id": doc.get("relaxation_task_id"),
        "main_completed": bool(doc.get("main_completed", False)),
        "main_completed_at": parse_datetime_value(doc.get("main_completed_at")),
        "daily_relax_count": int(doc.get("daily_relax_count") or 0),
        "daily_diary_count": int(doc.get("daily_diary_count") or 0),
        "requirements_met": bool(doc.get("requirements_met", False)),
        "completed_at": parse_datetime_value(doc.get("completed_at")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
    }


async def ensure_week1_progress(
    db,
    user_id: str,
) -> None:
    collection = db[TREATMENT_PROGRESS_COLLECTION]
    existing = await collection.find_one({"user_id": user_id})

    if existing is not None:
        return

    now_utc = datetime.now(timezone.utc)
    await collection.insert_one(
        {
            "progress_id": f"tp_{uuid.uuid4().hex[:8]}",
            "user_id": user_id,
            "week_number": 1,
            "started_at": now_utc,
            "ends_at": now_utc + timedelta(days=7),
            "edu_session_id": None,
            "relaxation_task_id": None,
            "main_completed": False,
            "main_completed_at": None,
            "daily_relax_count": 0,
            "daily_diary_count": 0,
            "requirements_met": False,
            "completed_at": None,
            "created_at": now_utc,
            "updated_at": now_utc,
        }
    )


async def _find_active_progress(
    *,
    collection,
    user_id: str,
    week_number: int | None = None,
    projection: Dict[str, Any] | None = None,
) -> Dict[str, Any] | None:
    now_utc = datetime.now(timezone.utc)
    query: Dict[str, Any] = {
        "user_id": user_id,
        "completed_at": None,
        "started_at": {"$lte": now_utc},
    }
    if week_number is not None:
        query["week_number"] = week_number

    return await collection.find_one(
        query,
        projection,
        sort=[("week_number", -1)],
    )


async def _refresh_requirements_met(
    *,
    db,
    collection,
    progress_doc: Dict[str, Any],
    synced_at: datetime,
) -> Dict[str, Any]:
    if progress_doc.get("completed_at") is not None:
        return progress_doc

    main_completed = bool(progress_doc.get("main_completed", False))
    daily_relax_count = int(progress_doc.get("daily_relax_count") or 0)
    daily_diary_count = int(progress_doc.get("daily_diary_count") or 0)
    requirements_met = (
        main_completed
        and daily_relax_count >= 3
        and daily_diary_count >= 3
    )
    if not requirements_met:
        return progress_doc

    synced_utc = ensure_utc(synced_at) or synced_at
    updated_doc = await collection.find_one_and_update(
        {
            "user_id": progress_doc["user_id"],
            "week_number": int(progress_doc["week_number"]),
        },
        {
            "$set": {
                "requirements_met": True,
                "completed_at": synced_utc,
                "updated_at": datetime.now(timezone.utc),
            }
        },
        return_document=ReturnDocument.AFTER,
    )
    if updated_doc is not None:
        current_week = int(updated_doc["week_number"])
        await db["users"].update_one(
            {"user_id": updated_doc["user_id"]},
            {
                "$set": {
                    "last_completed_week": current_week,
                    "last_completed_at": synced_utc,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
        )
        if current_week < 8:
            next_week = current_week + 1
            next_exists = await collection.find_one(
                {"user_id": updated_doc["user_id"], "week_number": next_week}
            )
            if next_exists is None:
                now_utc = datetime.now(timezone.utc)
                await collection.insert_one(
                    {
                        "progress_id": f"tp_{uuid.uuid4().hex[:8]}",
                        "user_id": updated_doc["user_id"],
                        "week_number": next_week,
                        "started_at": synced_utc + timedelta(days=1),
                        "ends_at": synced_utc + timedelta(days=8),
                        "edu_session_id": None,
                        "relaxation_task_id": None,
                        "main_completed": False,
                        "main_completed_at": None,
                        "daily_relax_count": 0,
                        "daily_diary_count": 0,
                        "requirements_met": False,
                        "completed_at": None,
                        "created_at": now_utc,
                        "updated_at": now_utc,
                    }
                )
        return updated_doc

    progress_doc["requirements_met"] = True
    progress_doc["completed_at"] = synced_utc
    return progress_doc


@router.get(
    "",
    response_model=List[TreatmentProgressResponse],
    summary="치료 진행 상태 목록 조회",
)
async def list_treatment_progress(
    week_number: Optional[int] = Query(default=None, ge=1, le=8),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    collection = db[TREATMENT_PROGRESS_COLLECTION]

    query: Dict[str, Any] = {"user_id": user_id}
    if week_number is not None:
        query["week_number"] = week_number

    cursor = collection.find(query).sort([("week_number", 1), ("started_at", 1)])

    docs: List[TreatmentProgressResponse] = []
    async for doc in cursor:
        docs.append(TreatmentProgressResponse(**_serialize_progress(doc)))
    return docs


@router.get(
    "/active",
    response_model=Optional[TreatmentProgressResponse],
    summary="현재 진행 중인 치료 진행 상태 조회",
)
async def get_active_treatment_progress(
    week_number: Optional[int] = Query(default=None, ge=1, le=8),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    collection = db[TREATMENT_PROGRESS_COLLECTION]
    progress = await _find_active_progress(
        collection=collection,
        user_id=user_id,
        week_number=week_number,
    )
    if not progress:
        return None

    return TreatmentProgressResponse(**_serialize_progress(progress))


@router.get(
    "/{week_number}",
    response_model=TreatmentProgressResponse,
    summary="특정 주차 치료 진행 상태 조회",
)
async def get_treatment_progress(
    week_number: int = Path(..., ge=1, le=8),
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    collection = db[TREATMENT_PROGRESS_COLLECTION]
    progress = await collection.find_one(
        {"user_id": user_id, "week_number": week_number},
        sort=[("started_at", -1)],
    )
    if not progress:
        raise HTTPException(status_code=404, detail="Treatment progress not found")

    return TreatmentProgressResponse(**_serialize_progress(progress))
