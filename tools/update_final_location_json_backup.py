#!/usr/bin/env python3
"""Normalize final location categories in the importable JSON backup."""

from __future__ import annotations

import json
import zipfile
from collections import Counter, defaultdict
from pathlib import Path


LAB_ROOT = Path("/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test")
DATA_DIR = LAB_ROOT / "lab_8week_location_context_backup"
ZIP_PATH = LAB_ROOT / "lab_8week_location_context_backup.zip"

LOCATION_DESCRIPTIONS = {
    "집": "집",
    "학교/연구실": "학교 또는 연구실",
    "병원": "병원",
    "카페/모임 장소": "카페 또는 모임 장소",
}


def read_json(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: list[dict]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def canonical_location(label: str | None) -> str | None:
    if not label:
        return None
    if label in {"학교", "성균관대학교", "연구실", "직장"}:
        return "학교/연구실"
    if label == "병원/상담센터":
        return "병원"
    if label in {"이동 중", "헬스장"}:
        return None
    return label


def normalize_diaries(diaries: list[dict]) -> dict[str, int]:
    stats = Counter()
    for diary in diaries:
        loc = diary.get("loc_time")
        if not isinstance(loc, dict) or not loc.get("location"):
            stats["already_missing"] += 1
            continue

        old_label = loc.get("location")
        new_label = canonical_location(old_label)
        stats[f"old:{old_label}"] += 1
        if new_label is None:
            diary["loc_time"] = None
            diary["loc_auto_filled"] = False
            diary["created_loc"] = None
            stats["removed_to_missing"] += 1
            continue

        loc["location"] = new_label
        loc["location_desc"] = LOCATION_DESCRIPTIONS.get(new_label, new_label)
        stats[f"new:{new_label}"] += 1
    return dict(stats)


def normalize_location_labels(labels: list[dict]) -> tuple[list[dict], dict[str, int]]:
    stats = Counter()
    seen: set[tuple[str, str]] = set()
    normalized = []
    for item in labels:
        old_label = item.get("label")
        new_label = canonical_location(old_label)
        stats[f"old:{old_label}"] += 1
        if new_label is None:
            stats["removed"] += 1
            continue
        key = (item.get("user_id"), new_label)
        if key in seen:
            stats["deduped"] += 1
            continue
        copied = dict(item)
        copied["label"] = new_label
        normalized.append(copied)
        seen.add(key)
        stats[f"new:{new_label}"] += 1
    return normalized, dict(stats)


def normalize_notification_settings(settings: list[dict]) -> dict[str, int]:
    stats = Counter()
    for item in settings:
        loc = item.get("location")
        if not isinstance(loc, dict):
            stats["missing_location"] += 1
            continue
        old_label = loc.get("location")
        new_label = canonical_location(old_label)
        stats[f"old:{old_label}"] += 1
        if new_label is None:
            item["location"] = None
            stats["removed_to_null"] += 1
            continue
        loc["location"] = new_label
        loc["address"] = f"Synthetic {new_label} area"
        stats[f"new:{new_label}"] += 1
    return dict(stats)


def validate(diaries: list[dict], labels: list[dict], notifications: list[dict]) -> list[str]:
    errors = []
    banned_labels = {"이동 중", "병원/상담센터", "헬스장", "직장", "학교", "성균관대학교", "연구실"}
    final_labels = {"집", "학교/연구실", "병원", "카페/모임 장소"}

    label_by_user: dict[str, set[str]] = defaultdict(set)
    for item in labels:
        label = item.get("label")
        user_id = item.get("user_id")
        if label in banned_labels:
            errors.append(f"location_label banned label remains: {label}")
        if label not in final_labels:
            errors.append(f"location_label unexpected label: {label}")
        label_by_user[user_id].add(label)

    diary_counts = Counter()
    for diary in diaries:
        loc = diary.get("loc_time")
        if not isinstance(loc, dict) or not loc.get("location"):
            continue
        label = loc.get("location")
        user_id = diary.get("user_id")
        diary_counts[label] += 1
        if label in banned_labels:
            errors.append(f"{diary.get('diary_id')}: banned diary label remains: {label}")
        if label not in final_labels:
            errors.append(f"{diary.get('diary_id')}: unexpected diary label: {label}")
        if label not in label_by_user[user_id]:
            errors.append(f"{diary.get('diary_id')}: location label not registered for user: {label}")
        if label == "병원" and loc.get("location_desc") != "병원":
            errors.append(f"{diary.get('diary_id')}: hospital desc not normalized")

    for item in notifications:
        loc = item.get("location")
        if not isinstance(loc, dict):
            continue
        label = loc.get("location")
        if label in banned_labels:
            errors.append(f"{item.get('alarm_id')}: banned notification label remains: {label}")
        if label not in final_labels:
            errors.append(f"{item.get('alarm_id')}: unexpected notification label: {label}")
    return errors


def rebuild_zip() -> None:
    json_files = sorted(DATA_DIR.glob("*.json"))
    with zipfile.ZipFile(ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in json_files:
            zf.write(path, arcname=f"{DATA_DIR.name}/{path.name}")


def main() -> None:
    diaries_path = DATA_DIR / "diaries.json"
    labels_path = DATA_DIR / "location_label.json"
    notifications_path = DATA_DIR / "notification_settings.json"
    diaries = read_json(diaries_path)
    labels = read_json(labels_path)
    notifications = read_json(notifications_path)

    diary_stats = normalize_diaries(diaries)
    labels, label_stats = normalize_location_labels(labels)
    notification_stats = normalize_notification_settings(notifications)
    errors = validate(diaries, labels, notifications)
    if errors:
        raise SystemExit("\n".join(errors[:50]))

    write_json(diaries_path, diaries)
    write_json(labels_path, labels)
    write_json(notifications_path, notifications)
    rebuild_zip()

    diary_location_counts = Counter()
    missing = 0
    for diary in diaries:
        loc = diary.get("loc_time")
        if isinstance(loc, dict) and loc.get("location"):
            diary_location_counts[loc["location"]] += 1
        else:
            missing += 1
    label_counts = Counter(item.get("label") for item in labels)

    print(f"DATA_DIR={DATA_DIR}")
    print(f"ZIP_PATH={ZIP_PATH}")
    print(f"DIARY_LOCATION_COUNTS={dict(diary_location_counts)}")
    print(f"MISSING_LOCATION_DIARIES={missing}")
    print(f"LOCATION_LABEL_COUNTS={dict(label_counts)}")
    print(f"LOCATION_LABEL_TOTAL={len(labels)}")
    print(f"DIARY_STATS={diary_stats}")
    print(f"LABEL_STATS={label_stats}")
    print(f"NOTIFICATION_STATS={notification_stats}")
    print("VALIDATION_ERRORS=0")


if __name__ == "__main__":
    main()
