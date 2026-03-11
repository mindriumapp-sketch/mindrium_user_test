from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status

from core.location_store import (
    list_recent_location_labels,
    upsert_manual_location_label,
)
from core.security import get_current_user_id
from db.mongo import get_db
from schemas.notification_location import (
    LocationLabelCreate,
    LocationLabelResponse,
)

router = APIRouter(prefix="/notification-locations", tags=["notification-locations"])


@router.get("/labels", response_model=List[LocationLabelResponse])
async def list_location_labels(
    limit: int = Query(
        default=20,
        ge=1,
        le=50,
        description="최근 사용한 위치 라벨 조회 개수",
    ),
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    rows = await list_recent_location_labels(
        db=db,
        user_id=user_id,
        limit=limit,
    )
    return [LocationLabelResponse(**row) for row in rows]


@router.post(
    "/labels",
    response_model=LocationLabelResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_or_touch_location_label(
    payload: LocationLabelCreate,
    db=Depends(get_db),
    user_id: str = Depends(get_current_user_id),
):
    try:
        saved = await upsert_manual_location_label(
            db=db,
            user_id=user_id,
            label=payload.label,
            client_timestamp=payload.client_timestamp,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return LocationLabelResponse(**saved)
