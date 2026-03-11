import re
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from pymongo.errors import DuplicateKeyError

from core.utils import ensure_utc, parse_datetime_value

NOTIFICATION_LOCATIONS_COLLECTION = "location_label"


def _clean_text(raw: Any) -> Optional[str]:
    if raw is None:
        return None
    text = str(raw).strip()
    return text or None


def _canonicalize_label(raw: Any) -> Optional[str]:
    text = _clean_text(raw)
    if text is None:
        return None
    return re.sub(r"\s+", " ", text)


def _normalize_label(raw: Any) -> Optional[str]:
    canonical = _canonicalize_label(raw)
    if canonical is None:
        return None
    return canonical.lower()


async def list_recent_location_labels(
    db,
    user_id: str,
    limit: int = 20,
) -> List[Dict[str, Any]]:
    safe_limit = max(1, min(limit, 50))
    collection = db[NOTIFICATION_LOCATIONS_COLLECTION]

    pipeline = [
        {
            "$match": {
                "user_id": user_id,
                "label": {"$exists": True, "$type": "string"},
            }
        },
        {
            "$project": {
                "label": "$label",
                "updated_at": "$updated_at",
                "label_norm": {
                    "$toLower": {
                        "$trim": {"input": "$label"},
                    }
                },
            }
        },
        {"$match": {"label_norm": {"$ne": ""}}},
        {"$sort": {"updated_at": -1}},
        {
            "$group": {
                "_id": "$label_norm",
                "label": {"$first": "$label"},
                "last_used_at": {"$first": "$updated_at"},
            }
        },
        {"$sort": {"last_used_at": -1}},
        {"$limit": safe_limit},
    ]

    rows = await collection.aggregate(pipeline).to_list(length=safe_limit)
    now_utc = datetime.now(timezone.utc)
    result: List[Dict[str, Any]] = []
    for row in rows:
        label = _canonicalize_label(row.get("label"))
        if label is None:
            continue
        last_used_at = parse_datetime_value(row.get("last_used_at"), fallback=now_utc)
        result.append(
            {
                "label": label,
                "last_used_at": last_used_at or now_utc,
            }
        )
    return result


async def upsert_manual_location_label(
    db,
    user_id: str,
    label: str,
    client_timestamp: Optional[datetime] = None,
) -> Dict[str, Any]:
    canonical_label = _canonicalize_label(label)
    if canonical_label is None:
        raise ValueError("label is empty")
    normalized_target = _normalize_label(canonical_label)
    if normalized_target is None:
        raise ValueError("label is empty")

    now_utc = datetime.now(timezone.utc)
    client_ts_utc = ensure_utc(client_timestamp) or now_utc
    collection = db[NOTIFICATION_LOCATIONS_COLLECTION]

    primary_doc_id = None
    duplicate_doc_ids = []

    async for doc in collection.find(
        {"user_id": user_id, "label": {"$exists": True, "$type": "string"}},
        {"_id": 1, "label": 1},
    ):
        normalized = _normalize_label(doc.get("label"))
        if normalized != normalized_target:
            continue
        if primary_doc_id is None:
            primary_doc_id = doc.get("_id")
        else:
            duplicate_doc_ids.append(doc.get("_id"))

    if primary_doc_id is None:
        try:
            await collection.insert_one(
                {
                    "location_id": f"loc_{uuid.uuid4().hex[:10]}",
                    "user_id": user_id,
                    "label": canonical_label,
                    "created_at": now_utc,
                    "updated_at": now_utc,
                    "client_timestamp": client_ts_utc,
                }
            )
        except DuplicateKeyError:
            await collection.update_one(
                {"user_id": user_id, "label": canonical_label},
                {
                    "$set": {
                        "updated_at": now_utc,
                        "client_timestamp": client_ts_utc,
                    },
                    "$unset": {
                        "source": "",
                        "source_ref_id": "",
                        "label_key": "",
                        "address": "",
                        "alarm_id": "",
                        "diary_id": "",
                        "latitude": "",
                        "longitude": "",
                    },
                },
                collation={"locale": "ko", "strength": 2},
            )
    else:
        await collection.update_one(
            {"_id": primary_doc_id},
            {
                "$set": {
                    "label": canonical_label,
                    "updated_at": now_utc,
                    "client_timestamp": client_ts_utc,
                },
                "$unset": {
                    "source": "",
                    "source_ref_id": "",
                    "label_key": "",
                    "address": "",
                    "alarm_id": "",
                    "diary_id": "",
                    "latitude": "",
                    "longitude": "",
                },
            },
        )

    cleaned_duplicate_ids = [doc_id for doc_id in duplicate_doc_ids if doc_id is not None]
    if cleaned_duplicate_ids:
        await collection.delete_many({"_id": {"$in": cleaned_duplicate_ids}})

    return {
        "label": canonical_label,
        "last_used_at": now_utc,
    }
