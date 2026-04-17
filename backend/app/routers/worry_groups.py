from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pymongo import ReturnDocument

from core.security import get_current_user_id
from core.utils import parse_datetime_value, ensure_utc
from db.mongo import get_db
from schemas.worry_group import (
    WorryGroupCreate,
    WorryGroupUpdate,
    WorryGroupDelete,
    WorryGroupResponse,
)

router = APIRouter(prefix="/worry-groups", tags=["worry_groups"])

WORRY_GROUP_COLLECTION = "worry_groups"
DEFAULT_GROUP_ID = "group_example"  # 🔵 고정 기본 그룹 ID

async def ensure_default_worry_group(db, user_id: str) -> None:
    """
    각 user별로 기본 걱정 그룹(삭제/아카이브 불가)을 1개 보장한다.
    - 스키마는 기존 worry_groups 문서 스키마 그대로 사용
    - 기본 그룹 여부는 group_id == DEFAULT_GROUP_ID 로만 판단
    """
    collection = db[WORRY_GROUP_COLLECTION]
    now_utc = datetime.now(timezone.utc)

    # 이미 있으면 아무 것도 안 함
    exists = await collection.find_one(
        {"user_id": user_id, "group_id": DEFAULT_GROUP_ID}
    )
    if exists:
        return

    doc = {
        "user_id": user_id,
        "group_id": DEFAULT_GROUP_ID,           # 🔵 고정 ID
        "group_title": "기본 그룹",
        "group_contents": "걱정 그룹을 추가하지 않으면 이 그룹에 포함됩니다.",
        "character_id": 1,                      # 1번 캐릭터 고정
        "created_at": now_utc,
        "updated_at": now_utc,
        "archived": False,
        "diary_count": 0,
        "sud_sum": 0.0,
    }

    await collection.insert_one(doc)

# =========================================================
# 헬퍼: 그룹 메트릭 조정 (일기/점수 라우터에서 사용)
# =========================================================
async def adjust_group_metrics(
    db,
    user_id: str,
    group_id: Optional[str],
    *,
    diary_delta: int = 0,
    sud_delta: float = 0.0,
) -> None:
    """
    worry_group의 diary_count / sud_sum을 동시에 조정하는 헬퍼.

    - diary_delta: 일기 개수 증감 (예: 생성 +1, 삭제 -1)
    - sud_delta: 그룹 전체 SUD 합계 증감 (예: latest_sud 변화량)

    group_id가 None이거나, 변경할 값이 없으면 아무 것도 안 함.

    ⚠️ 호출하는 쪽 계약:
    - diary 생성/삭제/이동: diary_delta ±1 + sud_delta = 해당 diary.latest_sud
    - SUD 추가/수정: diary_delta=0, sud_delta=latest_sud_new - latest_sud_old
    """
    if not group_id:
        return

    inc: Dict[str, float] = {}
    if diary_delta:
        inc["diary_count"] = diary_delta
    if sud_delta:
        inc["sud_sum"] = float(sud_delta)

    if not inc:
        return

    await db[WORRY_GROUP_COLLECTION].update_one(
        {"user_id": user_id, "group_id": group_id},
        {"$inc": inc},
    )


# =========================================================
# 헬퍼: 공통 변환/조회
# =========================================================
def _serialize_group(doc: dict) -> dict:
    """
    DB 도큐먼트를 WorryGroupResponse에 맞게 정리.
    avg_sud는 diary_count > 0인 경우에만 계산.
    """
    diary_count = int(doc.get("diary_count") or 0)
    sud_sum = float(doc.get("sud_sum") or 0.0)

    avg_sud: Optional[float] = None
    if diary_count > 0:
        avg_sud = sud_sum / diary_count

    return {
        "group_id": doc.get("group_id"),
        "group_title": doc.get("group_title"),
        "group_contents": doc.get("group_contents") or "",
        "character_id": int(doc.get("character_id")),
        "created_at": parse_datetime_value(doc.get("created_at")),
        "updated_at": parse_datetime_value(doc.get("updated_at")),
        "archived": doc.get("archived", False),
        "diary_count": diary_count,
        "avg_sud": avg_sud,
    }


async def _get_group_or_404(db, user_id: str, group_id: str) -> dict:
    doc = await db[WORRY_GROUP_COLLECTION].find_one(
        {"group_id": group_id, "user_id": user_id}
    )
    if not doc:
        raise HTTPException(status_code=404, detail="그룹을 찾을 수 없습니다")
    return doc


async def _list_groups(
    db,
    user_id: str,
    *,
    include_archived: bool = False,
    only_archived: bool = False,
) -> List[WorryGroupResponse]:
    """
    - include_archived=True: 전체 + archived 포함
    - only_archived=True: archived만
    - 둘 다 False: archived != True 만 (기본)
    """
    collection = db[WORRY_GROUP_COLLECTION]

    query: Dict[str, Any] = {"user_id": user_id}
    if only_archived:
        query["archived"] = True
    elif not include_archived:
        query["archived"] = {"$ne": True}

    cursor = collection.find(query).sort("created_at", 1)

    groups: List[WorryGroupResponse] = []
    async for doc in cursor:
        groups.append(WorryGroupResponse(**_serialize_group(doc)))
    return groups


# =========================================================
# Endpoints
# =========================================================
@router.get(
    "",
    response_model=List[WorryGroupResponse],
    summary="걱정 그룹 목록 조회",
)
async def get_worry_groups(
    include_archived: bool = False,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    사용자의 걱정 그룹 목록을 반환합니다.
    - include_archived=True: 아카이브된 그룹까지 모두 포함
    - False(기본): archived != True 인 그룹만
    """
    return await _list_groups(
        db=db,
        user_id=user_id,
        include_archived=include_archived,
        only_archived=False,
    )


@router.get(
    "/archived",
    response_model=List[WorryGroupResponse],
    summary="아카이브된 걱정 그룹 조회",
)
async def get_archived_worry_groups(
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    사용자가 아카이브한 걱정(ABC) 그룹 목록을 반환합니다.
    """
    return await _list_groups(
        db=db,
        user_id=user_id,
        include_archived=False,
        only_archived=True,
    )


@router.get(
    "/{group_id}",
    response_model=WorryGroupResponse,
    summary="특정 걱정 그룹 조회",
)
async def get_worry_group(
    group_id: str,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    특정 걱정 그룹의 상세 정보를 반환합니다.
    """
    group = await _get_group_or_404(db, user_id, group_id)
    return WorryGroupResponse(**_serialize_group(group))


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=WorryGroupResponse,
    summary="걱정 그룹 생성",
)
async def create_worry_group(
    payload: WorryGroupCreate,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    새로운 걱정 그룹을 생성합니다.
    - diary_count / sud_sum은 0으로 초기화
    - avg_sud는 응답 시 계산
    """
    collection = db[WORRY_GROUP_COLLECTION]

    now_utc = datetime.now(timezone.utc)
    group_id = f"group_{uuid.uuid4().hex[:8]}"

    new_group = {
        "user_id": user_id,
        "group_id": group_id,
        "group_title": payload.group_title,
        "group_contents": payload.group_contents,
        "character_id": payload.character_id,
        "created_at": now_utc,
        "updated_at": now_utc,
        "archived": False,
        "diary_count": 0,
        "sud_sum": 0.0,
    }

    await collection.insert_one(new_group)

    return WorryGroupResponse(**_serialize_group(new_group))


@router.put(
    "/{group_id}",
    response_model=WorryGroupResponse,
    summary="걱정 그룹 수정",
)
async def update_worry_group(
    group_id: str,
    payload: WorryGroupUpdate,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    걱정 그룹 정보를 수정합니다.
    - group_title / group_contents / character_id 등 일부 필드만 갱신
    """
    collection = db[WORRY_GROUP_COLLECTION]

    update_data = payload.model_dump(
        exclude_unset=True,
        by_alias=True,
    )
    if not update_data:
        raise HTTPException(status_code=400, detail="수정할 필드가 없습니다")

    now_utc = datetime.now(timezone.utc)
    update_data["updated_at"] = now_utc

    doc = await collection.find_one_and_update(
        {"group_id": group_id, "user_id": user_id},
        {
            "$set": {
                **update_data,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    if not doc:
        raise HTTPException(status_code=404, detail="그룹을 찾을 수 없습니다")

    return WorryGroupResponse(**_serialize_group(doc))


@router.post(
    "/{group_id}/archive",
    response_model=WorryGroupResponse,
    summary="걱정 그룹 아카이브",
)
async def archive_worry_group(
    group_id: str,
    payload: WorryGroupDelete,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    걱정 그룹을 아카이브합니다 (소프트 삭제).
    """
    collection = db[WORRY_GROUP_COLLECTION]

    now_utc = datetime.now(timezone.utc)
    doc = await collection.find_one_and_update(
        {"group_id": group_id, "user_id": user_id},
        {
            "$set": {
                "archived": True,
                "updated_at": now_utc,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    if not doc:
        raise HTTPException(status_code=404, detail="그룹을 찾을 수 없습니다")

    return WorryGroupResponse(**_serialize_group(doc))


@router.delete(
    "/{group_id}",
    status_code=status.HTTP_200_OK,
    summary="걱정 그룹 삭제",
)
async def delete_worry_group(
    group_id: str,
    payload: WorryGroupDelete,
    user_id: str = Depends(get_current_user_id),
    db=Depends(get_db),
):
    """
    걱정 그룹을 완전히 삭제합니다 (하드 삭제).
    - 기존 일기(diaries)는 그대로 남고 group_id만 고아 상태가 될 수 있음.
      (필요하면 별도 마이그레이션/정리 루틴에서 처리)
    """
    # 🔴 기본 그룹은 삭제 불가
    if group_id == DEFAULT_GROUP_ID:
        raise HTTPException(
            status_code=400,
            detail="기본 걱정 그룹은 삭제할 수 없습니다.",
        )

    collection = db[WORRY_GROUP_COLLECTION]

    result = await collection.delete_one({"group_id": group_id, "user_id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="그룹을 찾을 수 없습니다")

    return {
        "deleted_at": datetime.now(timezone.utc),
    }


# =========================================================
# 관리자용: group stats 재계산 (diaries 쪽 구조와 호환)
# =========================================================
from datetime import datetime, timezone
from typing import Dict, Any

WORRY_GROUP_COLLECTION = "worry_groups"

# =========================================================
# 관리자용: group stats 재계산 (diaries 쪽 구조와 호환)
# =========================================================
async def recompute_group_stats(
        db,
        user_id: str,
        group_id: str,
) -> Dict[str, Any]:
    """
    diaries 컬렉션을 풀스캔(aggregation)해서
    - 해당 group_id의 일기 개수(diary_count)
    - latest_sud 합(sud_sum)
    을 다시 계산해서 worry_groups에 반영.

    👉 '자동 생성' 일기는 activation.label에 이 문구가 들어간 애로 판단해서 제외.

    avg_sud는 sud_sum / diary_count 기준으로 맞춤.
    """
    diary_coll = db["diaries"]

    pipeline = [
        {
            "$match": {
                "user_id": user_id,
                "group_id": group_id,
                # activation.label 에 "자동 생성" 포함된 건 제외
                "activation.label": {
                    "$not": {"$regex": "자동 생성"}
                },
            }
        },
        {
            "$group": {
                "_id": None,
                "diary_count": {"$sum": 1},
                "sud_sum": {
                    "$sum": {
                        "$cond": [
                            {"$ne": ["$latest_sud", None]},
                            {
                                "$min": [
                                    10,
                                    {"$max": [0, "$latest_sud"]},
                                ]
                            },
                            0,
                        ]
                    }
                },
            }
        },
    ]

    agg_list = await diary_coll.aggregate(pipeline).to_list(length=1)

    diary_count = 0
    sud_sum = 0.0

    if agg_list:
        agg = agg_list[0]
        diary_count = int(agg.get("diary_count", 0) or 0)
        sud_sum = float(agg.get("sud_sum", 0.0) or 0.0)

    now_utc = datetime.now(timezone.utc)

    await db[WORRY_GROUP_COLLECTION].update_one(
        {"user_id": user_id, "group_id": group_id},
        {
            "$set": {
                "diary_count": diary_count,
                "sud_sum": sud_sum,
                "updated_at": now_utc,
            }
        },
    )

    avg_sud = sud_sum / diary_count if diary_count > 0 else None

    return {
        "diary_count": diary_count,
        "sud_sum": sud_sum,
        "avg_sud": avg_sud,
    }
