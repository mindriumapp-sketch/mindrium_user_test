#!/usr/bin/env python3
"""Create a location-context version of the 8-week Mindrium data and analysis."""

from __future__ import annotations

import csv
import hashlib
import json
import math
import shutil
import zipfile
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager


COLLECTIONS = [
    "users",
    "treatment_progress",
    "edu_sessions",
    "relaxation_tasks",
    "diaries",
    "custom_tags",
    "worry_groups",
    "screen_time",
    "notification_settings",
    "location_label",
]

LOCATION_PROFILES = {
    "집": {
        "desc": "집",
        "lat": 37.5665,
        "lng": 126.9780,
        "keywords": ["가족", "통화", "불면", "하루 계획", "전화 안 받기", "메시지", "회복"],
    },
    "학교": {
        "desc": "학교",
        "lat": 37.2940,
        "lng": 126.9760,
        "keywords": ["수업", "결석", "질문", "모임", "사람들이", "평가", "운동", "산책"],
    },
    "성균관대학교": {
        "desc": "성균관대학교 캠퍼스",
        "lat": 37.2939,
        "lng": 126.9746,
        "keywords": ["시험 공부", "과제 제출", "발표 준비", "팀 프로젝트", "학업", "발표 리허설"],
    },
    "연구실": {
        "desc": "연구실",
        "lat": 37.2946,
        "lng": 126.9754,
        "keywords": [
            "회의",
            "팀 프로젝트",
            "연구실 메신저",
            "업무 메신저",
            "도움 요청",
            "먼저 질문",
            "준비가 부족",
            "연구실 가는 길",
            "연구 업무",
            "비난받을까",
        ],
    },
    "병원/상담센터": {
        "desc": "병원 또는 상담센터",
        "lat": 37.5030,
        "lng": 126.9100,
        "keywords": ["병원", "상담", "건강", "다시 불안"],
    },
    "이동 중": {
        "desc": "대중교통 또는 이동 중",
        "lat": 37.4979,
        "lng": 127.0276,
        "keywords": ["지하철", "이동", "출근길"],
    },
    "카페/모임 장소": {
        "desc": "카페 또는 모임 장소",
        "lat": 37.2990,
        "lng": 126.9700,
        "keywords": ["모임", "약속", "거절", "시선 피하기"],
    },
}

LOCATION_ORDER = [
    "집",
    "학교",
    "성균관대학교",
    "연구실",
    "병원/상담센터",
    "이동 중",
    "카페/모임 장소",
]

LOCATION_COLORS = {
    "집": "#6F8FAF",
    "학교": "#D99152",
    "성균관대학교": "#8C5FBF",
    "연구실": "#4F8F6F",
    "병원/상담센터": "#8A8F45",
    "이동 중": "#6E7C87",
    "카페/모임 장소": "#B66B8C",
}

ACTIVITY_LABELS = {
    "회의": "업무/연구",
    "연구실 메신저": "업무/연구",
    "업무 메신저": "업무/연구",
    "팀 프로젝트": "업무/연구",
    "수업": "수업/학업",
    "시험 공부": "수업/학업",
    "과제 제출": "수업/학업",
    "발표 준비": "발표/평가",
    "연구 발표": "발표/평가",
    "취업 면접": "발표/평가",
    "운동 모임": "운동/이완",
    "가족 통화": "가정/대화",
    "상담 예약": "건강/상담",
    "병원 대기": "건강/상담",
    "연구실 가는 길": "이동",
    "출근길": "이동",
    "지하철 이동": "이동",
    "모임": "대인관계",
}


def find_lab_root() -> Path:
    candidates = sorted(Path("/Users/ubdbd/Desktop").rglob("Lab_test/lab_8week_backup"))
    if not candidates:
        raise FileNotFoundError("Lab_test/lab_8week_backup not found")
    return candidates[0].parent


def parse_date(raw) -> datetime | None:
    if isinstance(raw, dict) and "$date" in raw:
        text = raw["$date"]
    elif isinstance(raw, str):
        text = raw
    else:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None


def date_text(value) -> str:
    if isinstance(value, dict) and "$date" in value:
        return value["$date"]
    if isinstance(value, str):
        return value
    return "2026-03-18T00:00:00.000Z"


def read_json(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: list[dict]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def chip_text(value) -> list[str]:
    if isinstance(value, dict):
        return [str(value.get("label") or "")]
    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            if isinstance(item, dict):
                out.append(str(item.get("label") or ""))
            elif item is not None:
                out.append(str(item))
        return out
    if value is None:
        return []
    return [str(value)]


def diary_text(diary: dict, group_title: str | None) -> str:
    parts: list[str] = []
    for key in [
        "activation",
        "belief",
        "consequence_physical",
        "consequence_emotion",
        "consequence_action",
        "alternative_thoughts",
    ]:
        parts.extend(chip_text(diary.get(key)))
    if group_title:
        parts.append(group_title)
    return " ".join(parts)


def infer_activity(text: str) -> str:
    for keyword, label in ACTIVITY_LABELS.items():
        if keyword in text:
            return label
    return "일상 기록"


def infer_location(text: str, hour: int | None, existing: str | None = None) -> str:
    scores: dict[str, int] = {label: 0 for label in LOCATION_ORDER}
    for label in LOCATION_ORDER:
        for keyword in LOCATION_PROFILES[label]["keywords"]:
            if keyword in text:
                scores[label] += 3

    if hour is not None:
        if 0 <= hour <= 6 or 20 <= hour <= 23:
            scores["집"] += 2
            scores["카페/모임 장소"] += 1
        if 8 <= hour <= 10:
            scores["이동 중"] += 2
            scores["연구실"] += 1
        if 11 <= hour <= 18:
            scores["성균관대학교"] += 1
            scores["연구실"] += 1

    if existing in scores:
        scores[existing] += 1

    if "운동" in text or "산책" in text:
        return "집" if hour is not None and (hour >= 20 or hour <= 7) else "학교"
    if "병원" in text or "상담" in text:
        return "병원/상담센터"
    if "지하철" in text:
        return "이동 중"

    best_score = max(scores.values())
    best = [label for label in LOCATION_ORDER if scores[label] == best_score]
    return best[0] if best_score > 0 else "집"


def concentrate_research_locations(label: str, text: str, hour: int | None, diary_id: str) -> str:
    """Keep secondary locations, but concentrate records around campus/lab/home."""
    if label in {"집", "학교", "연구실", "성균관대학교"}:
        return label

    code = stable_bucket(diary_id)
    keep_thresholds = {
        "병원/상담센터": 46,
        "이동 중": 40,
        "카페/모임 장소": 45,
    }
    if code < keep_thresholds.get(label, 35):
        return label

    if "병원" in text or "상담" in text or "건강" in text:
        return "집" if hour is not None and (hour >= 20 or hour <= 7) else "성균관대학교"
    if "운동" in text or "산책" in text:
        return "집" if hour is not None and hour >= 20 else "학교"
    if "지하철" in text or "이동" in text or "연구실 가는 길" in text:
        return "연구실" if hour is not None and 9 <= hour <= 18 else "집"
    if "모임" in text or "약속" in text:
        if hour is not None and 10 <= hour <= 18:
            return "학교" if code % 2 == 0 else "성균관대학교"
        return "집"
    return ["집", "학교", "연구실", "성균관대학교"][code % 4]


def stable_int(text: str) -> int:
    digest = hashlib.sha1(text.encode("utf-8")).hexdigest()
    return int(digest[:12], 16)


def stable_bucket(text: str) -> int:
    return stable_int(text) % 100


def shift_coordinate(lat: float, lng: float, meters: float, angle_deg: float) -> tuple[float, float]:
    angle = math.radians(angle_deg)
    delta_lat = (meters * math.cos(angle)) / 111_000
    lng_scale = 111_000 * math.cos(math.radians(lat))
    delta_lng = (meters * math.sin(angle)) / lng_scale if lng_scale else 0
    return lat + delta_lat, lng + delta_lng


def noisy_coordinates(label: str, user_id: str, diary_id: str) -> tuple[float, float]:
    profile = LOCATION_PROFILES[label]
    base_lat = float(profile["lat"])
    base_lng = float(profile["lng"])

    user_seed = stable_int(f"{user_id}:{label}:base")
    diary_seed = stable_int(f"{diary_id}:{label}:jitter")

    if label == "집":
        base_radius = 500 + (user_seed % 2600)
        jitter_radius = 20 + (diary_seed % 80)
    elif label in {"학교", "성균관대학교", "연구실"}:
        base_radius = user_seed % 140
        jitter_radius = 10 + (diary_seed % 55)
    else:
        base_radius = user_seed % 450
        jitter_radius = 15 + (diary_seed % 90)

    base_lat, base_lng = shift_coordinate(base_lat, base_lng, base_radius, (user_seed // 10) % 360)
    lat, lng = shift_coordinate(base_lat, base_lng, jitter_radius, (diary_seed // 100) % 360)
    return round(lat, 6), round(lng, 6)


def noisy_context_time(created_at: datetime | None, label: str, diary_id: str) -> str:
    if created_at is None:
        base_hour, base_minute = 21, 0
    else:
        base_hour, base_minute = created_at.hour, created_at.minute

    seed = stable_int(f"{diary_id}:{label}:time")
    if seed % 100 < 4:
        atypical = {
            "집": [10, 14, 18],
            "학교": [19, 20, 22],
            "성균관대학교": [9, 18, 21],
            "연구실": [10, 19, 22],
            "병원/상담센터": [9, 18, 21],
            "이동 중": [8, 12, 18],
            "카페/모임 장소": [14, 17, 23],
        }
        hours = atypical.get(label, [base_hour])
        base_hour = hours[(seed // 100) % len(hours)]
    elif label == "집" and not (base_hour >= 20 or base_hour <= 1) and seed % 100 < 42:
        base_hour = [20, 21, 22, 23, 0][(seed // 100) % 5]
    elif label in {"학교", "성균관대학교", "연구실"} and not (11 <= base_hour <= 18) and seed % 100 < 45:
        base_hour = [12, 13, 14, 15, 16, 17][(seed // 100) % 6]
    elif label == "이동 중" and seed % 100 < 75:
        base_hour = [8, 9, 10, 17, 18, 19][(seed // 100) % 6]

    magnitude = 5 + ((seed // 1000) % 21)
    sign = -1 if (seed // 100_000) % 2 == 0 else 1
    total_minutes = (base_hour * 60 + base_minute + sign * magnitude) % (24 * 60)
    return f"{total_minutes // 60:02d}:{total_minutes % 60:02d}"


def loc_time_hour(loc: dict, created_at: datetime | None) -> int | None:
    raw = loc.get("time") if isinstance(loc, dict) else None
    if isinstance(raw, str) and ":" in raw:
        try:
            return int(raw.split(":", 1)[0]) % 24
        except ValueError:
            pass
    return created_at.hour if created_at else None


def time_period(hour: int | None) -> str:
    if hour is None:
        return "미상"
    if 0 <= hour <= 5:
        return "심야"
    if 6 <= hour <= 10:
        return "오전"
    if 11 <= hour <= 17:
        return "오후"
    if 18 <= hour <= 21:
        return "저녁"
    return "밤"


def approximate_distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    mean_lat = math.radians((lat1 + lat2) / 2)
    dy = (lat1 - lat2) * 111_000
    dx = (lng1 - lng2) * 111_000 * math.cos(mean_lat)
    return math.hypot(dx, dy)


def should_keep_location_missing(diary_id: str) -> bool:
    digits = sum(ord(ch) for ch in diary_id)
    return digits % 17 in {0, 1}


def ensure_dir_clean(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def clone_backup(src: Path, dst: Path) -> dict[str, list[dict]]:
    ensure_dir_clean(dst)
    data: dict[str, list[dict]] = {}
    for name in COLLECTIONS:
        items = read_json(src / f"{name}.json")
        data[name] = items
        write_json(dst / f"{name}.json", items)
    return data


def replace_research_context_terms(value):
    replacements = {
        "직장과 업무": "연구실 업무",
        "직장 근처": "연구실 근처",
        "직장": "연구실",
        "업무 메신저": "연구실 메신저",
        "출근길": "연구실 가는 길",
        "취업 면접": "연구 발표",
    }
    if isinstance(value, str):
        out = value
        for old, new in replacements.items():
            out = out.replace(old, new)
        return out
    if isinstance(value, list):
        return [replace_research_context_terms(item) for item in value]
    if isinstance(value, dict):
        return {key: replace_research_context_terms(item) for key, item in value.items()}
    return value


def normalize_research_context(data: dict[str, list[dict]]) -> None:
    for name, items in list(data.items()):
        data[name] = replace_research_context_terms(items)


def build_group_lookup(worry_groups: list[dict]) -> dict[tuple[str, str], str]:
    lookup: dict[tuple[str, str], str] = {}
    for group in worry_groups:
        lookup[(group.get("user_id"), group.get("group_id"))] = group.get("group_title") or ""
    return lookup


def update_locations(data: dict[str, list[dict]]) -> tuple[list[dict], Counter, Counter]:
    normalize_research_context(data)
    group_lookup = build_group_lookup(data["worry_groups"])
    used_locations_by_user: dict[str, set[str]] = defaultdict(set)
    location_counts: Counter = Counter()
    activity_counts: Counter = Counter()

    for diary in data["diaries"]:
        diary_id = str(diary.get("diary_id") or "")
        created_at = parse_date(diary.get("created_at"))
        hour = created_at.hour if created_at else None
        current_loc = diary.get("loc_time")
        existing_label = None
        if isinstance(current_loc, dict):
            existing_label = current_loc.get("location") or current_loc.get("location_desc")
        if existing_label == "직장":
            existing_label = "연구실"

        group_title = group_lookup.get((diary.get("user_id"), diary.get("group_id")))
        text = diary_text(diary, group_title)
        activity = infer_activity(text)
        activity_counts[activity] += 1

        if should_keep_location_missing(diary_id):
            diary["loc_time"] = None
            diary["loc_auto_filled"] = False
            continue

        label = infer_location(text, hour, existing_label)
        label = concentrate_research_locations(label, text, hour, diary_id)
        profile = LOCATION_PROFILES[label]
        time_value = noisy_context_time(created_at, label, diary_id)
        latitude, longitude = noisy_coordinates(label, str(diary.get("user_id") or ""), diary_id)
        diary["loc_time"] = {
            "id": (
                current_loc.get("id")
                if isinstance(current_loc, dict) and current_loc.get("id")
                else f"loc_time_ctx_{stable_int(diary_id) % 1000000:06d}"
            ),
            "time": time_value,
            "location": label,
            "location_desc": profile["desc"],
            "latitude": latitude,
            "longitude": longitude,
        }
        was_missing = not isinstance(current_loc, dict)
        diary["loc_auto_filled"] = bool(was_missing and (sum(ord(ch) for ch in diary_id) % 5 in {0, 1, 2}))
        used_locations_by_user[diary.get("user_id")].add(label)
        location_counts[label] += 1

    users_by_id = {user["user_id"]: user for user in data["users"]}
    new_labels: list[dict] = []
    oid_base = int("760000000000000000000000", 16)
    idx = 0
    for user_id in sorted(users_by_id):
        labels = set(used_locations_by_user.get(user_id, set()))
        labels.add("집")
        ordered_labels = [label for label in LOCATION_ORDER if label in labels]
        created_at = date_text(users_by_id[user_id].get("created_at"))
        for local_idx, label in enumerate(ordered_labels, start=1):
            idx += 1
            new_labels.append(
                {
                    "_id": {"$oid": f"{oid_base + idx:024x}"},
                    "user_id": user_id,
                    "location_id": f"loc_ctx_{user_id.split('_')[-1]}_{local_idx:02d}",
                    "label": label,
                    "created_at": {"$date": created_at},
                    "updated_at": {"$date": created_at},
                    "client_timestamp": {"$date": created_at},
                }
            )
    data["location_label"] = new_labels
    return new_labels, location_counts, activity_counts


def zip_dir(src: Path, zip_path: Path) -> None:
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(src.glob("*.json")):
            zf.write(file, arcname=f"{src.name}/{file.name}")


def setup_font() -> None:
    candidates = ["Apple SD Gothic Neo", "AppleGothic", "NanumGothic", "Malgun Gothic"]
    available = {font.name for font in font_manager.fontManager.ttflist}
    for name in candidates:
        if name in available:
            plt.rcParams["font.family"] = name
            break
    plt.rcParams["axes.unicode_minus"] = False


def sud_after_values(diary: dict) -> list[float]:
    values = []
    for score in diary.get("sud_scores") or []:
        value = score.get("after_sud")
        if isinstance(value, (int, float)):
            values.append(float(value))
    return values


def build_analysis(data: dict[str, list[dict]], out_dir: Path) -> dict[str, object]:
    setup_font()
    charts_dir = out_dir / "charts"
    tables_dir = out_dir / "tables"
    ensure_dir_clean(out_dir)
    charts_dir.mkdir(parents=True, exist_ok=True)
    tables_dir.mkdir(parents=True, exist_ok=True)

    group_lookup = build_group_lookup(data["worry_groups"])
    location_summary: dict[str, dict[str, object]] = {}
    location_hour: Counter = Counter()
    hour_activity: Counter = Counter()
    location_period: Counter = Counter()
    location_period_sud: dict[tuple[str, str], list[float]] = defaultdict(list)
    location_topic: Counter = Counter()
    location_activity: Counter = Counter()
    location_coords: dict[str, list[tuple[float, float]]] = defaultdict(list)
    missing_count = 0
    auto_count = 0

    for diary in data["diaries"]:
        loc = diary.get("loc_time")
        if not isinstance(loc, dict) or not loc.get("location"):
            missing_count += 1
            continue
        label = loc["location"]
        created_at = parse_date(diary.get("created_at"))
        hour = loc_time_hour(loc, created_at)
        period = time_period(hour)
        group_title = group_lookup.get((diary.get("user_id"), diary.get("group_id"))) or "기본 그룹"
        activity = infer_activity(diary_text(diary, group_title))
        values = sud_after_values(diary)

        row = location_summary.setdefault(
            label,
            {
                "location": label,
                "diary_count": 0,
                "sud_values": [],
                "auto_count": 0,
                "users": set(),
            },
        )
        row["diary_count"] = int(row["diary_count"]) + 1
        row["sud_values"].extend(values)
        if diary.get("loc_auto_filled") is True:
            row["auto_count"] = int(row["auto_count"]) + 1
            auto_count += 1
        row["users"].add(diary.get("user_id"))
        if hour is not None:
            location_hour[(label, hour)] += 1
            hour_activity[hour] += 1
        location_period[(label, period)] += 1
        location_period_sud[(label, period)].extend(values)
        location_topic[(label, group_title)] += 1
        location_activity[(label, activity)] += 1
        lat = loc.get("latitude")
        lng = loc.get("longitude")
        if isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
            location_coords[label].append((float(lat), float(lng)))

    summary_rows = []
    for label in LOCATION_ORDER:
        row = location_summary.get(label)
        if not row:
            continue
        sud_values = row["sud_values"]
        summary_rows.append(
            {
                "위치": label,
                "일기 수": int(row["diary_count"]),
                "기록 사용자 수": len(row["users"]),
                "평균 수행 후 SUD": round(sum(sud_values) / len(sud_values), 2) if sud_values else "",
                "위치 자동 입력 수": int(row["auto_count"]),
            }
        )

    with (tables_dir / "location_activity_summary.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["위치", "일기 수", "기록 사용자 수", "평균 수행 후 SUD", "위치 자동 입력 수"])
        writer.writeheader()
        writer.writerows(summary_rows)

    label_rows = []
    labels_by_user = defaultdict(list)
    for item in data["location_label"]:
        labels_by_user[item["user_id"]].append(item["label"])
    for user_id, labels in sorted(labels_by_user.items()):
        label_rows.append({"사용자": user_id, "위치 라벨 수": len(labels), "위치 라벨": ", ".join(labels)})
    with (tables_dir / "location_labels_by_user.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["사용자", "위치 라벨 수", "위치 라벨"])
        writer.writeheader()
        writer.writerows(label_rows)

    with (tables_dir / "location_hour_matrix.csv").open("w", encoding="utf-8-sig", newline="") as f:
        fieldnames = ["위치"] + [f"{hour:02d}시" for hour in range(24)]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for label in LOCATION_ORDER:
            if label not in location_summary:
                continue
            writer.writerow({"위치": label, **{f"{hour:02d}시": location_hour[(label, hour)] for hour in range(24)}})

    with (tables_dir / "location_topic_summary.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["위치", "걱정 주제", "일기 수"])
        writer.writeheader()
        for (label, topic), count in sorted(location_topic.items(), key=lambda item: (-item[1], item[0][0], item[0][1])):
            writer.writerow({"위치": label, "걱정 주제": topic, "일기 수": count})

    with (tables_dir / "location_activity_type_summary.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["위치", "활동 유형", "일기 수"])
        writer.writeheader()
        for (label, activity), count in sorted(location_activity.items(), key=lambda item: (-item[1], item[0][0], item[0][1])):
            writer.writerow({"위치": label, "활동 유형": activity, "일기 수": count})

    period_order = ["심야", "오전", "오후", "저녁", "밤", "미상"]
    with (tables_dir / "location_period_summary.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["위치", "시간대", "일기 수", "평균 수행 후 SUD"])
        writer.writeheader()
        for label in LOCATION_ORDER:
            for period in period_order:
                count = location_period[(label, period)]
                if count == 0:
                    continue
                sud_values = location_period_sud[(label, period)]
                writer.writerow(
                    {
                        "위치": label,
                        "시간대": period,
                        "일기 수": count,
                        "평균 수행 후 SUD": round(sum(sud_values) / len(sud_values), 2) if sud_values else "",
                    }
                )

    high_burden_rows = []
    for (label, period), count in location_period.items():
        sud_values = location_period_sud[(label, period)]
        if count >= 20 and sud_values:
            high_burden_rows.append(
                {
                    "위치": label,
                    "시간대": period,
                    "일기 수": count,
                    "평균 수행 후 SUD": round(sum(sud_values) / len(sud_values), 2),
                }
            )
    high_burden_rows.sort(key=lambda row: (float(row["평균 수행 후 SUD"]), int(row["일기 수"])), reverse=True)
    with (tables_dir / "location_high_burden_windows.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["위치", "시간대", "일기 수", "평균 수행 후 SUD"])
        writer.writeheader()
        writer.writerows(high_burden_rows)

    coordinate_rows = []
    for label in LOCATION_ORDER:
        points = location_coords.get(label, [])
        if not points:
            continue
        center_lat = sum(lat for lat, _ in points) / len(points)
        center_lng = sum(lng for _, lng in points) / len(points)
        distances = [approximate_distance_m(lat, lng, center_lat, center_lng) for lat, lng in points]
        coordinate_rows.append(
            {
                "위치": label,
                "좌표 기록 수": len(points),
                "중심 위도": round(center_lat, 6),
                "중심 경도": round(center_lng, 6),
                "평균 반경(m)": round(sum(distances) / len(distances), 1),
                "최대 반경(m)": round(max(distances), 1),
            }
        )
    with (tables_dir / "location_coordinate_spread.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["위치", "좌표 기록 수", "중심 위도", "중심 경도", "평균 반경(m)", "최대 반경(m)"])
        writer.writeheader()
        writer.writerows(coordinate_rows)

    plot_location_counts(summary_rows, charts_dir / "location_diary_counts.png")
    plot_location_sud(summary_rows, charts_dir / "location_mean_sud.png")
    plot_location_hour_heatmap(location_hour, location_summary, charts_dir / "location_hour_heatmap.png")
    plot_location_period_sud(location_period_sud, location_period, location_summary, charts_dir / "location_period_sud_heatmap.png")
    plot_hour_pattern(hour_activity, charts_dir / "hourly_diary_pattern.png")
    plot_location_topic(location_topic, charts_dir / "location_topic_stacked.png")

    total_diaries = len(data["diaries"])
    located_diaries = sum(int(row["일기 수"]) for row in summary_rows)
    top_locations = sorted(summary_rows, key=lambda row: int(row["일기 수"]), reverse=True)[:5]
    top_sud = sorted(
        [row for row in summary_rows if row["평균 수행 후 SUD"] != ""],
        key=lambda row: float(row["평균 수행 후 SUD"]),
        reverse=True,
    )[:5]
    top_hours = hour_activity.most_common(5)
    avg_label_count = sum(len(labels) for labels in labels_by_user.values()) / max(len(labels_by_user), 1)
    core_locations = {"집", "학교", "연구실", "성균관대학교"}
    core_diaries = sum(int(row["일기 수"]) for row in summary_rows if row["위치"] in core_locations)
    peripheral_diaries = located_diaries - core_diaries
    core_ratio = core_diaries / located_diaries if located_diaries else 0
    peripheral_ratio = peripheral_diaries / located_diaries if located_diaries else 0
    period_totals = Counter()
    for (_, period), count in location_period.items():
        period_totals[period] += count
    high_burden_top = high_burden_rows[:5]

    insight_rows = [
        {
            "지표": "핵심 위치 집중도",
            "값": f"{core_diaries:,}/{located_diaries:,}건 ({core_ratio * 100:.1f}%)",
            "해석": "Lab test 환경에 맞게 집, 학교, 연구실, 성균관대학교에 사용 맥락이 집중됨",
        },
        {
            "지표": "보조 위치 비율",
            "값": f"{peripheral_diaries:,}/{located_diaries:,}건 ({peripheral_ratio * 100:.1f}%)",
            "해석": "병원/상담센터, 이동 중, 카페/모임 장소가 생활 노이즈 역할을 함",
        },
        {
            "지표": "위치 미입력 비율",
            "값": f"{missing_count:,}/{total_diaries:,}건 ({missing_count / total_diaries * 100:.1f}%)",
            "해석": "모든 기록이 위치를 갖지 않는 실제 사용 상황을 일부 반영함",
        },
        {
            "지표": "위치 자동 입력 비율",
            "값": f"{auto_count:,}/{total_diaries:,}건 ({auto_count / total_diaries * 100:.1f}%)",
            "해석": "직접 입력과 자동 입력이 섞인 사용 맥락으로 구성됨",
        },
        {
            "지표": "최다 시간대",
            "값": ", ".join(f"{hour:02d}시 {count}건" for hour, count in top_hours[:3]),
            "해석": "오후 연구/학업 중 기록과 밤 시간대 정리 기록이 함께 나타남",
        },
    ]
    with (tables_dir / "location_time_insights.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["지표", "값", "해석"])
        writer.writeheader()
        writer.writerows(insight_rows)

    md_lines = [
        "# 위치/시간 기반 사용자 활동 분석",
        "",
        "## 데이터 갱신 요약",
        "",
        f"- 전체 일기 수: {total_diaries:,}건",
        f"- 위치가 연결된 일기 수: {located_diaries:,}건 ({located_diaries / total_diaries * 100:.1f}%)",
        f"- 위치가 없는 일기 수: {missing_count:,}건 ({missing_count / total_diaries * 100:.1f}%)",
        f"- 위치 자동 입력 일기 수: {auto_count:,}건 ({auto_count / total_diaries * 100:.1f}%)",
        f"- 위치 라벨 수: {len(data['location_label']):,}개",
        f"- 사용자당 평균 위치 라벨 수: {avg_label_count:.1f}개",
        f"- 핵심 위치 집중도: {core_diaries:,}/{located_diaries:,}건 ({core_ratio * 100:.1f}%)",
        f"- 보조 위치 비율: {peripheral_diaries:,}/{located_diaries:,}건 ({peripheral_ratio * 100:.1f}%)",
        "",
        "## 위치별 활동량",
        "",
    ]
    for row in top_locations:
        md_lines.append(
            f"- {row['위치']}: {row['일기 수']:,}건, 평균 수행 후 SUD {row['평균 수행 후 SUD']}"
        )
    md_lines.extend(["", "## 부담이 큰 위치", ""])
    for row in top_sud:
        md_lines.append(
            f"- {row['위치']}: 평균 수행 후 SUD {row['평균 수행 후 SUD']}, 일기 {row['일기 수']:,}건"
        )
    md_lines.extend(["", "## 시간대 패턴", ""])
    for hour, count in top_hours:
        md_lines.append(f"- {hour:02d}시: {count:,}건")
    md_lines.extend(["", "## 시간대별 부담이 큰 조합", ""])
    for row in high_burden_top:
        md_lines.append(
            f"- {row['위치']} · {row['시간대']}: 평균 수행 후 SUD {row['평균 수행 후 SUD']}, 일기 {row['일기 수']:,}건"
        )
    md_lines.extend(["", "## 시간대별 기록 비중", ""])
    for period, count in period_totals.most_common():
        md_lines.append(f"- {period}: {count:,}건 ({count / located_diaries * 100:.1f}%)")
    md_lines.extend(
        [
            "",
            "## 사용 인사이트",
            "",
            f"- 전체 위치 연결 기록의 {core_ratio * 100:.1f}%가 집, 학교, 연구실, 성균관대학교에 집중되어 Lab test 대상자의 생활 반경이 비교적 통제된 형태로 나타난다.",
            "- 오후 시간대 기록이 가장 많아 수업, 연구실 업무, 발표/평가 준비 중간에 불안을 기록하는 사용 흐름이 강하다.",
            "- 집에서는 밤과 심야 기록이 두드러져 하루가 끝난 뒤 불안을 정리하거나 회고하는 사용 맥락으로 해석할 수 있다.",
            "- 연구실과 학교는 기록량과 평균 SUD가 모두 높은 편이라 핵심 생활 공간이면서 주요 부담 공간으로 볼 수 있다.",
            "- 이동 중, 병원/상담센터, 카페/모임 장소는 기록 수는 적지만 평균 SUD가 상대적으로 높아 빈도 기반 지표와 부담 기반 지표를 분리해 볼 필요가 있다.",
            "- 위치 미입력과 보조 위치 기록이 남아 있어 완전히 정제된 실험 로그보다는 통제된 실험 환경 안의 생활 노이즈가 포함된 데이터로 볼 수 있다.",
        ]
    )
    md_lines.extend(
        [
            "",
            "## 해석",
            "",
            f"- 위치 라벨은 {', '.join(LOCATION_ORDER)}로 확장했다.",
            "- 위치 배정은 일기의 사건, 생각, 행동, 걱정 주제, 작성 시간대를 함께 사용했다.",
            "- Lab test 특성을 반영해 핵심 위치에 기록이 몰리도록 유지하되, 일부 보조 위치와 위치 미입력, 시간/좌표 흔들림을 남겼다.",
            "- 위치가 있는 기록과 없는 기록을 구분해 분석할 수 있도록 일부 일기는 위치 미입력 상태로 남겼다.",
            "- 위치별 일기 수와 평균 SUD를 함께 보면 자주 기록되는 장소와 부담이 큰 장소를 분리해서 해석할 수 있다.",
        ]
    )
    (out_dir / "location_context_analysis.md").write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    return {
        "total_diaries": total_diaries,
        "located_diaries": located_diaries,
        "missing_count": missing_count,
        "auto_count": auto_count,
        "location_label_count": len(data["location_label"]),
        "avg_label_count": avg_label_count,
        "top_locations": top_locations,
        "top_sud": top_sud,
        "top_hours": top_hours,
    }


def plot_location_counts(rows: list[dict], path: Path) -> None:
    rows = sorted(rows, key=lambda row: int(row["일기 수"]), reverse=True)
    labels = [row["위치"] for row in rows]
    values = [int(row["일기 수"]) for row in rows]
    colors = [LOCATION_COLORS.get(label, "#6E7C87") for label in labels]
    fig, ax = plt.subplots(figsize=(10, 5.6), dpi=180)
    ax.barh(labels[::-1], values[::-1], color=colors[::-1])
    ax.set_title("위치별 일기 기록 수")
    ax.set_xlabel("일기 수")
    ax.grid(axis="x", alpha=0.18)
    for spine in ax.spines.values():
        spine.set_visible(False)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def plot_location_sud(rows: list[dict], path: Path) -> None:
    rows = [row for row in rows if row["평균 수행 후 SUD"] != ""]
    rows = sorted(rows, key=lambda row: float(row["평균 수행 후 SUD"]), reverse=True)
    labels = [row["위치"] for row in rows]
    values = [float(row["평균 수행 후 SUD"]) for row in rows]
    colors = [LOCATION_COLORS.get(label, "#6E7C87") for label in labels]
    fig, ax = plt.subplots(figsize=(10, 5.6), dpi=180)
    ax.bar(labels, values, color=colors)
    ax.set_title("위치별 평균 수행 후 SUD")
    ax.set_ylabel("평균 SUD")
    ax.set_ylim(0, max(values) + 1)
    ax.grid(axis="y", alpha=0.18)
    ax.tick_params(axis="x", rotation=25)
    for spine in ax.spines.values():
        spine.set_visible(False)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def plot_location_hour_heatmap(location_hour: Counter, location_summary: dict, path: Path) -> None:
    labels = [label for label in LOCATION_ORDER if label in location_summary]
    matrix = [[location_hour[(label, hour)] for hour in range(24)] for label in labels]
    fig, ax = plt.subplots(figsize=(12, 5.8), dpi=180)
    image = ax.imshow(matrix, aspect="auto", cmap="YlGnBu")
    ax.set_title("위치 x 시간대 일기 기록 히트맵")
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels)
    ax.set_xticks(range(0, 24, 2))
    ax.set_xticklabels([f"{hour:02d}시" for hour in range(0, 24, 2)])
    fig.colorbar(image, ax=ax, fraction=0.025, pad=0.02, label="일기 수")
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def plot_location_period_sud(location_period_sud: dict, location_period: Counter, location_summary: dict, path: Path) -> None:
    labels = [label for label in LOCATION_ORDER if label in location_summary]
    periods = ["심야", "오전", "오후", "저녁", "밤"]
    matrix: list[list[float]] = []
    annotations: list[list[str]] = []
    for label in labels:
        row: list[float] = []
        ann_row: list[str] = []
        for period in periods:
            values = location_period_sud.get((label, period), [])
            if values:
                row.append(sum(values) / len(values))
                ann_row.append(str(location_period[(label, period)]))
            else:
                row.append(float("nan"))
                ann_row.append("")
        matrix.append(row)
        annotations.append(ann_row)

    fig, ax = plt.subplots(figsize=(9.5, 5.8), dpi=180)
    image = ax.imshow(matrix, aspect="auto", cmap="YlOrRd", vmin=4.0, vmax=6.7)
    ax.set_title("위치 x 시간대 평균 수행 후 SUD")
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels)
    ax.set_xticks(range(len(periods)))
    ax.set_xticklabels(periods)
    for y, row in enumerate(matrix):
        for x, value in enumerate(row):
            if not math.isnan(value):
                ax.text(x, y, f"{value:.1f}\n(n={annotations[y][x]})", ha="center", va="center", fontsize=8, color="#24323a")
    fig.colorbar(image, ax=ax, fraction=0.03, pad=0.02, label="평균 SUD")
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def plot_hour_pattern(hour_activity: Counter, path: Path) -> None:
    hours = list(range(24))
    values = [hour_activity[hour] for hour in hours]
    fig, ax = plt.subplots(figsize=(11, 4.8), dpi=180)
    ax.plot(hours, values, color="#2F6F9F", linewidth=2.5, marker="o", markersize=4)
    ax.fill_between(hours, values, color="#2F6F9F", alpha=0.12)
    ax.set_title("시간대별 일기 기록 패턴")
    ax.set_xlabel("시간대")
    ax.set_ylabel("일기 수")
    ax.set_xticks(range(0, 24, 2))
    ax.grid(alpha=0.18)
    for spine in ax.spines.values():
        spine.set_visible(False)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def plot_location_topic(location_topic: Counter, path: Path) -> None:
    location_totals = Counter()
    topic_totals = Counter()
    for (label, topic), count in location_topic.items():
        location_totals[label] += count
        topic_totals[topic] += count
    labels = [label for label, _ in location_totals.most_common(7)]
    topics = [topic for topic, _ in topic_totals.most_common(5)]
    fig, ax = plt.subplots(figsize=(11, 5.8), dpi=180)
    bottoms = [0] * len(labels)
    palette = ["#376F95", "#2F9B91", "#E86F56", "#E6A93F", "#638F58"]
    for idx, topic in enumerate(topics):
        values = [location_topic[(label, topic)] for label in labels]
        ax.bar(labels, values, bottom=bottoms, label=topic, color=palette[idx % len(palette)])
        bottoms = [bottoms[i] + values[i] for i in range(len(values))]
    ax.set_title("위치별 주요 걱정 주제 구성")
    ax.set_ylabel("일기 수")
    ax.tick_params(axis="x", rotation=25)
    ax.legend(frameon=False, ncol=2)
    ax.grid(axis="y", alpha=0.15)
    for spine in ax.spines.values():
        spine.set_visible(False)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def validate_location_context(data_dir: Path) -> list[str]:
    errors: list[str] = []
    labels = read_json(data_dir / "location_label.json")
    diaries = read_json(data_dir / "diaries.json")
    users = read_json(data_dir / "users.json")
    label_by_user = defaultdict(set)
    for item in labels:
        label_by_user[item.get("user_id")].add(item.get("label"))
    for user in users:
        user_id = user.get("user_id")
        if not label_by_user[user_id]:
            errors.append(f"{user_id}: no location labels")
    for diary in diaries:
        loc = diary.get("loc_time")
        if isinstance(loc, dict) and loc.get("location"):
            if loc["location"] not in label_by_user[diary.get("user_id")]:
                errors.append(f"{diary.get('diary_id')}: location label not registered")
            if not loc.get("time"):
                errors.append(f"{diary.get('diary_id')}: location time missing")
            else:
                try:
                    hour_text, minute_text = str(loc.get("time")).split(":", 1)
                    hour = int(hour_text)
                    minute = int(minute_text)
                    if not (0 <= hour <= 23 and 0 <= minute <= 59):
                        errors.append(f"{diary.get('diary_id')}: invalid location time")
                except Exception:
                    errors.append(f"{diary.get('diary_id')}: invalid location time")
            lat = loc.get("latitude")
            lng = loc.get("longitude")
            if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
                errors.append(f"{diary.get('diary_id')}: missing location coordinates")
            elif not (-90 <= float(lat) <= 90 and -180 <= float(lng) <= 180):
                errors.append(f"{diary.get('diary_id')}: invalid location coordinates")
    return errors


def main() -> None:
    lab_root = find_lab_root()
    src_dir = lab_root / "lab_8week_backup"
    out_dir = lab_root / "lab_8week_location_context_backup"
    zip_path = lab_root / "lab_8week_location_context_backup.zip"
    analysis_dir = lab_root / "analytics_report" / "location_context"

    data = clone_backup(src_dir, out_dir)
    update_locations(data)
    for name, items in data.items():
        write_json(out_dir / f"{name}.json", items)
    zip_dir(out_dir, zip_path)

    metrics = build_analysis(data, analysis_dir)
    errors = validate_location_context(out_dir)
    validation_md = [
        "# 위치/시간 데이터 정합성 검토",
        "",
        f"- 사용자 수: {len(data['users'])}",
        f"- 일기 수: {len(data['diaries'])}",
        f"- 위치 라벨 수: {len(data['location_label'])}",
        f"- 위치 연결 일기 수: {metrics['located_diaries']}",
        f"- 위치 미입력 일기 수: {metrics['missing_count']}",
        f"- 검증 오류 수: {len(errors)}",
    ]
    if errors:
        validation_md.extend(["", "## 오류", *[f"- {err}" for err in errors[:50]]])
    else:
        validation_md.extend(
            [
                "",
                "## 결과",
                "",
                "- 모든 위치 연결 일기는 동일 사용자에게 등록된 위치 라벨을 참조한다.",
                "- 위치 시간이 비어 있는 연결 일기는 없다.",
                "- 기존 사용자, 주차 진행, 설문, SUD, 일기 문서 수는 유지했다.",
            ]
        )
    (analysis_dir / "location_context_validation.md").write_text("\n".join(validation_md) + "\n", encoding="utf-8")

    print(f"DATA_DIR={out_dir}")
    print(f"ZIP={zip_path}")
    print(f"ANALYSIS_DIR={analysis_dir}")
    print(f"LOCATION_LABELS={len(data['location_label'])}")
    print(f"LOCATED_DIARIES={metrics['located_diaries']}")
    print(f"MISSING_DIARIES={metrics['missing_count']}")
    print(f"VALIDATION_ERRORS={len(errors)}")


if __name__ == "__main__":
    main()
