#!/usr/bin/env python3
"""Build final comprehensive analysis and visualizations for the Mindrium lab-test data."""

from __future__ import annotations

import csv
import json
import math
import shutil
import statistics
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

COLORS = {
    "ink": "#24323A",
    "muted": "#667680",
    "blue": "#376F95",
    "teal": "#2F9B91",
    "coral": "#E86F56",
    "gold": "#E6A93F",
    "green": "#638F58",
    "purple": "#8C5FBF",
    "gray": "#EEF3F5",
    "line": "#D8E0E4",
}

LOCATION_ORDER = ["집", "학교", "성균관대학교", "연구실", "병원/상담센터", "이동 중", "카페/모임 장소"]
CORE_LOCATIONS = {"집", "학교", "연구실", "성균관대학교"}
PERIOD_ORDER = ["심야", "오전", "오후", "저녁", "밤"]


def find_lab_root() -> Path:
    candidates = sorted(Path("/Users/ubdbd/Desktop").rglob("Lab_test/lab_8week_location_context_backup"))
    if not candidates:
        raise FileNotFoundError("Lab_test/lab_8week_location_context_backup not found")
    return candidates[0].parent


def setup_font() -> None:
    candidates = ["Apple SD Gothic Neo", "AppleGothic", "NanumGothic", "Malgun Gothic"]
    available = {font.name for font in font_manager.fontManager.ttflist}
    for name in candidates:
        if name in available:
            plt.rcParams["font.family"] = name
            break
    plt.rcParams["axes.unicode_minus"] = False


def read_json(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_csv(path: Path, rows: list[dict], fieldnames: list[str] | None = None) -> None:
    if fieldnames is None:
        keys: list[str] = []
        for row in rows:
            for key in row:
                if key not in keys:
                    keys.append(key)
        fieldnames = keys
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


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


def mean(values) -> float | None:
    vals = [float(v) for v in values if v is not None and not math.isnan(float(v))]
    return statistics.mean(vals) if vals else None


def median(values) -> float | None:
    vals = [float(v) for v in values if v is not None and not math.isnan(float(v))]
    return statistics.median(vals) if vals else None


def stdev(values) -> float | None:
    vals = [float(v) for v in values if v is not None and not math.isnan(float(v))]
    return statistics.stdev(vals) if len(vals) >= 2 else None


def pct(part: float, whole: float) -> float:
    return part / whole * 100 if whole else 0.0


def fmt(value, digits: int = 2) -> str:
    if value is None:
        return ""
    if isinstance(value, int):
        return f"{value:,}"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def pearson(xs: list[float], ys: list[float]) -> float | None:
    pairs = [(float(x), float(y)) for x, y in zip(xs, ys) if x is not None and y is not None]
    if len(pairs) < 3:
        return None
    xvals, yvals = zip(*pairs)
    mx = statistics.mean(xvals)
    my = statistics.mean(yvals)
    sx = sum((x - mx) ** 2 for x in xvals)
    sy = sum((y - my) ** 2 for y in yvals)
    if sx == 0 or sy == 0:
        return None
    return sum((x - mx) * (y - my) for x, y in pairs) / math.sqrt(sx * sy)


def rankdata(values: list[float]) -> list[float]:
    pairs = sorted((value, idx) for idx, value in enumerate(values))
    ranks = [0.0] * len(values)
    i = 0
    while i < len(pairs):
        j = i + 1
        while j < len(pairs) and pairs[j][0] == pairs[i][0]:
            j += 1
        rank = (i + j - 1) / 2 + 1
        for _, idx in pairs[i:j]:
            ranks[idx] = rank
        i = j
    return ranks


def spearman(xs: list[float], ys: list[float]) -> float | None:
    pairs = [(float(x), float(y)) for x, y in zip(xs, ys) if x is not None and y is not None]
    if len(pairs) < 3:
        return None
    xvals, yvals = zip(*pairs)
    return pearson(rankdata(list(xvals)), rankdata(list(yvals)))


def linear_slope(xs: list[float], ys: list[float]) -> float | None:
    pairs = [(float(x), float(y)) for x, y in zip(xs, ys) if x is not None and y is not None]
    if len(pairs) < 2:
        return None
    xvals, yvals = zip(*pairs)
    mx = statistics.mean(xvals)
    my = statistics.mean(yvals)
    denom = sum((x - mx) ** 2 for x in xvals)
    if denom == 0:
        return None
    return sum((x - mx) * (y - my) for x, y in pairs) / denom


def severity_gad(score: float) -> str:
    if score <= 4:
        return "거의 없음"
    if score <= 9:
        return "경도"
    if score <= 14:
        return "중등도"
    return "높음"


def severity_phq(score: float) -> str:
    if score <= 4:
        return "거의 없음"
    if score <= 9:
        return "경도"
    if score <= 14:
        return "중등도"
    if score <= 19:
        return "중등도-높음"
    return "높음"


def participant_label(user_id: str) -> str:
    try:
        return f"P{int(user_id.split('_')[-1]):03d}"
    except Exception:
        return user_id


def loc_hour(loc: dict | None, fallback: datetime | None) -> int | None:
    if isinstance(loc, dict):
        raw = loc.get("time")
        if isinstance(raw, str) and ":" in raw:
            try:
                return int(raw.split(":", 1)[0]) % 24
            except ValueError:
                pass
    return fallback.hour if fallback else None


def period_for_hour(hour: int | None) -> str:
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


def chip_labels(value) -> list[str]:
    if isinstance(value, dict):
        return [str(value.get("label") or "")]
    if isinstance(value, list):
        out = []
        for item in value:
            if isinstance(item, dict):
                out.append(str(item.get("label") or ""))
            elif item:
                out.append(str(item))
        return out
    return []


def infer_activity(text: str) -> str:
    mapping = {
        "연구실 메신저": "업무/연구",
        "회의": "업무/연구",
        "팀 프로젝트": "업무/연구",
        "수업": "수업/학업",
        "시험 공부": "수업/학업",
        "과제 제출": "수업/학업",
        "발표 준비": "발표/평가",
        "연구 발표": "발표/평가",
        "운동": "운동/이완",
        "가족 통화": "가정/대화",
        "상담": "건강/상담",
        "병원": "건강/상담",
        "연구실 가는 길": "이동",
        "지하철": "이동",
        "모임": "대인관계",
    }
    for key, value in mapping.items():
        if key in text:
            return value
    return "일상 기록"


def extract_surveys(users: list[dict]) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for user in users:
        user_id = user["user_id"]
        row = {
            "user_id": user_id,
            "participant": participant_label(user_id),
            "gad_pre": None,
            "gad_post": None,
            "phq_pre": None,
            "last_completed_week": user.get("last_completed_week"),
        }
        for survey in user.get("surveys", []):
            answers = survey.get("answers") or {}
            if survey.get("type") == "before_survey":
                row["gad_pre"] = answers.get("gad7_score")
                row["phq_pre"] = answers.get("phq9_score")
            elif survey.get("type") == "after_survey":
                row["gad_post"] = answers.get("gad7_score")
        if row["gad_pre"] is not None and row["gad_post"] is not None:
            row["gad_drop"] = row["gad_pre"] - row["gad_post"]
            row["gad_pre_severity"] = severity_gad(row["gad_pre"])
            row["gad_post_severity"] = severity_gad(row["gad_post"])
        if row["phq_pre"] is not None:
            row["phq_pre_severity"] = severity_phq(row["phq_pre"])
        out[user_id] = row
    return out


def build_week_intervals(progress: list[dict]) -> dict[str, list[tuple[int, datetime, datetime]]]:
    intervals: dict[str, list[tuple[int, datetime, datetime]]] = defaultdict(list)
    for item in progress:
        start = parse_date(item.get("started_at"))
        end = parse_date(item.get("ends_at"))
        if start and end:
            intervals[item["user_id"]].append((int(item["week_number"]), start, end))
    for user_id in intervals:
        intervals[user_id].sort()
    return intervals


def assign_week(user_id: str, at: datetime | None, intervals: dict[str, list[tuple[int, datetime, datetime]]]) -> int | None:
    if at is None:
        return None
    for week, start, end in intervals.get(user_id, []):
        if start <= at <= end:
            return week
    candidates = [(abs((at - start).total_seconds()), week) for week, start, _ in intervals.get(user_id, [])]
    return min(candidates)[1] if candidates else None


def build_derived(data: dict[str, list[dict]]) -> dict[str, object]:
    users = data["users"]
    progress = data["treatment_progress"]
    diaries = data["diaries"]
    relax = data["relaxation_tasks"]
    screen = data["screen_time"]
    tags = data["custom_tags"]
    groups = data["worry_groups"]
    edu = data["edu_sessions"]
    notifications = data["notification_settings"]
    labels = data["location_label"]

    survey = extract_surveys(users)
    intervals = build_week_intervals(progress)
    group_lookup = {(g.get("user_id"), g.get("group_id")): g for g in groups}

    sud_records = []
    diary_rows = []
    weekly_diary_counts = Counter()
    user_diary_counts = Counter()
    user_alt_counts = Counter()
    user_week_diary_counts = Counter()
    user_location_counts: dict[str, Counter] = defaultdict(Counter)
    user_period_counts: dict[str, Counter] = defaultdict(Counter)
    location_topic = Counter()
    location_activity = Counter()
    location_period = Counter()
    location_period_sud: dict[tuple[str, str], list[float]] = defaultdict(list)
    location_hour = Counter()
    location_summary = defaultdict(lambda: {"count": 0, "sud": [], "users": set(), "auto": 0})
    topic_counts = Counter()
    topic_sud = defaultdict(list)
    activity_counts = Counter()
    missing_location = 0
    auto_location = 0

    for diary in diaries:
        user_id = diary["user_id"]
        created = parse_date(diary.get("created_at"))
        week = assign_week(user_id, created, intervals)
        group = group_lookup.get((user_id, diary.get("group_id")), {})
        topic = group.get("group_title") or "기본 그룹"
        text = " ".join(
            chip
            for key in ["activation", "belief", "consequence_action", "consequence_physical", "consequence_emotion", "alternative_thoughts"]
            for chip in chip_labels(diary.get(key))
        )
        activity = infer_activity(f"{text} {topic}")
        alt_count = len(diary.get("alternative_thoughts") or [])
        loc = diary.get("loc_time")
        loc_name = loc.get("location") if isinstance(loc, dict) else None
        hour = loc_hour(loc, created)
        period = period_for_hour(hour)
        user_diary_counts[user_id] += 1
        user_alt_counts[user_id] += alt_count
        if week and diary.get("route") == "today_task":
            weekly_diary_counts[week] += 1
            user_week_diary_counts[(user_id, week)] += 1
        if loc_name:
            user_location_counts[user_id][loc_name] += 1
            user_period_counts[user_id][period] += 1
            location_summary[loc_name]["count"] += 1
            location_summary[loc_name]["users"].add(user_id)
            location_period[(loc_name, period)] += 1
            location_hour[(loc_name, hour)] += 1
            location_topic[(loc_name, topic)] += 1
            location_activity[(loc_name, activity)] += 1
            if diary.get("loc_auto_filled") is True:
                location_summary[loc_name]["auto"] += 1
                auto_location += 1
        else:
            missing_location += 1

        scores = diary.get("sud_scores") or []
        after_values = []
        for score in scores:
            before = score.get("before_sud")
            after = score.get("after_sud")
            if before is None or after is None:
                continue
            record = {
                "user_id": user_id,
                "week": week,
                "before": float(before),
                "after": float(after),
                "delta": float(before) - float(after),
                "worse": float(after) > float(before),
                "location": loc_name or "위치 없음",
                "period": period,
                "topic": topic,
                "activity": activity,
            }
            sud_records.append(record)
            after_values.append(float(after))
            if loc_name:
                location_summary[loc_name]["sud"].append(float(after))
                location_period_sud[(loc_name, period)].append(float(after))
            topic_sud[topic].append(float(after))
        topic_counts[topic] += 1
        activity_counts[activity] += 1
        diary_rows.append(
            {
                "user_id": user_id,
                "participant": participant_label(user_id),
                "week": week,
                "location": loc_name or "",
                "period": period if loc_name else "",
                "hour": hour if loc_name else "",
                "topic": topic,
                "activity": activity,
                "alternative_thought_count": alt_count,
                "after_sud_mean": mean(after_values),
            }
        )

    relax_by_user = Counter()
    weekly_relax_counts = Counter()
    relax_minutes_by_user = Counter()
    user_week_relax_counts = Counter()
    user_week_relax_minutes = Counter()
    for item in relax:
        user_id = item["user_id"]
        relax_by_user[user_id] += 1
        week = int(item.get("week_number") or 0)
        if item.get("task_id") == "daily_review" and week:
            weekly_relax_counts[week] += 1
            user_week_relax_counts[(user_id, week)] += 1
        minutes = (item.get("duration_seconds") or 0) / 60
        relax_minutes_by_user[user_id] += minutes
        if week:
            user_week_relax_minutes[(user_id, week)] += minutes

    screen_minutes_by_user = Counter()
    weekly_screen_minutes = Counter()
    weekly_screen_sessions = Counter()
    screen_hours = Counter()
    active_days: dict[str, set[str]] = defaultdict(set)
    user_week_screen_minutes = Counter()
    user_week_screen_sessions = Counter()
    user_week_active_days: dict[tuple[str, int], set[str]] = defaultdict(set)
    screen_session_rows = []
    session_minutes = []
    for item in screen:
        user_id = item["user_id"]
        start = parse_date(item.get("start_time"))
        end = parse_date(item.get("end_time"))
        week = assign_week(user_id, start, intervals)
        minutes = None
        if start and end:
            minutes = (end - start).total_seconds() / 60
        if minutes is None and item.get("duration_seconds") is not None:
            minutes = item["duration_seconds"] / 60
        if minutes is None:
            continue
        screen_minutes_by_user[user_id] += minutes
        session_minutes.append(minutes)
        if week:
            weekly_screen_minutes[week] += minutes
            weekly_screen_sessions[week] += 1
            user_week_screen_minutes[(user_id, week)] += minutes
            user_week_screen_sessions[(user_id, week)] += 1
        if start:
            screen_hours[start.hour] += 1
            active_days[user_id].add(start.date().isoformat())
            if week:
                user_week_active_days[(user_id, week)].add(start.date().isoformat())
            screen_session_rows.append(
                {
                    "user_id": user_id,
                    "week": week,
                    "started_at": start,
                    "hour": start.hour,
                    "minutes": minutes,
                }
            )

    real_oddness_by_user = Counter()
    category_logs_by_user = Counter()
    category_counts = Counter()
    for tag in tags:
        user_id = tag.get("user_id")
        logs = tag.get("real_oddness_logs") or []
        real_oddness_by_user[user_id] += len(logs) if isinstance(logs, list) else 0
        cats = tag.get("category_logs") or []
        if isinstance(cats, list):
            category_logs_by_user[user_id] += len(cats)
            for cat in cats:
                if isinstance(cat, dict):
                    value = cat.get("category") or cat.get("type") or cat.get("behavior_type")
                    if value:
                        category_counts[value] += 1

    behavior_counts = Counter()
    behavior_by_user = defaultdict(Counter)
    eval_total = eval_effective = continue_total = will_continue = 0
    user_week_edu_minutes = Counter()
    weekly_edu_minutes = Counter()
    for session in edu:
        week = int(session.get("week_number") or 0)
        user_id = session.get("user_id")
        start = parse_date(session.get("start_time"))
        end = parse_date(session.get("end_time"))
        if user_id and week and start and end:
            minutes = max(0, (end - start).total_seconds() / 60)
            user_week_edu_minutes[(user_id, week)] += minutes
            weekly_edu_minutes[week] += minutes
        if week == 7:
            for item in session.get("behavior_items") or []:
                if isinstance(item, dict):
                    value = item.get("behavior_type") or item.get("category") or item.get("type") or item.get("classification")
                    if value:
                        behavior_counts[value] += 1
                        behavior_by_user[user_id][value] += 1
        if week == 8:
            for item in session.get("effectiveness_evaluations") or []:
                if isinstance(item, dict):
                    eval_total += 1
                    eval_effective += 1 if item.get("was_effective") is True or item.get("effective") is True else 0
                    if "will_continue" in item:
                        continue_total += 1
                        will_continue += 1 if item.get("will_continue") is True else 0

    notif_by_user = Counter(item.get("user_id") for item in notifications)
    notification_rows = []
    label_by_user = defaultdict(set)
    for item in notifications:
        schedule = item.get("schedule") if isinstance(item.get("schedule"), dict) else {}
        user_id = item.get("user_id")
        hour = schedule.get("hour")
        minute = schedule.get("minute")
        if user_id and isinstance(hour, int):
            notification_rows.append(
                {
                    "user_id": user_id,
                    "alarm_id": item.get("alarm_id"),
                    "label": item.get("label") or "",
                    "enabled": bool(item.get("enabled", True)),
                    "hour": int(hour) % 24,
                    "minute": int(minute or 0),
                    "has_location": item.get("location") is not None,
                }
            )
    for item in labels:
        label_by_user[item.get("user_id")].add(item.get("label"))

    user_week_after = defaultdict(list)
    user_week_delta = defaultdict(list)
    for record in sud_records:
        if record["week"]:
            user_week_after[(record["user_id"], record["week"])].append(record["after"])
            user_week_delta[(record["user_id"], record["week"])].append(record["delta"])

    user_rows = []
    for user in users:
        user_id = user["user_id"]
        weeks = []
        after_means = []
        delta_means = []
        for week in range(3, 9):
            after_vals = user_week_after.get((user_id, week), [])
            delta_vals = user_week_delta.get((user_id, week), [])
            if after_vals:
                weeks.append(week)
                after_means.append(statistics.mean(after_vals))
            if delta_vals:
                delta_means.append(statistics.mean(delta_vals))
        sud_drop = after_means[0] - after_means[-1] if len(after_means) >= 2 else None
        sud_slope = linear_slope(weeks, after_means) if len(weeks) >= 2 else None
        loc_total = sum(user_location_counts[user_id].values())
        core_count = sum(count for loc, count in user_location_counts[user_id].items() if loc in CORE_LOCATIONS)
        night_count = user_period_counts[user_id]["밤"] + user_period_counts[user_id]["심야"]
        early_weeks = (1, 2)
        early_diaries = sum(user_week_diary_counts[(user_id, week)] for week in early_weeks)
        early_relax = sum(user_week_relax_counts[(user_id, week)] for week in early_weeks)
        early_screen = sum(user_week_screen_minutes[(user_id, week)] for week in early_weeks)
        early_sessions = sum(user_week_screen_sessions[(user_id, week)] for week in early_weeks)
        early_active = len(set().union(*(user_week_active_days.get((user_id, week), set()) for week in early_weeks)))
        user_sud = [record for record in sud_records if record["user_id"] == user_id]
        user_after_sud = [record["after"] for record in user_sud]
        user_delta = [record["delta"] for record in user_sud]
        user_worse = sum(1 for record in user_sud if record["worse"])
        row = {
            **survey[user_id],
            "diary_count": user_diary_counts[user_id],
            "relax_count": relax_by_user[user_id],
            "relax_minutes": round(relax_minutes_by_user[user_id], 1),
            "screen_minutes": round(screen_minutes_by_user[user_id], 1),
            "active_days": len(active_days[user_id]),
            "screen_session_count": sum(user_week_screen_sessions[(user_id, week)] for week in range(1, 9)),
            "early_diary_count_w1_w2": early_diaries,
            "early_relax_count_w1_w2": early_relax,
            "early_screen_minutes_w1_w2": round(early_screen, 1),
            "early_screen_sessions_w1_w2": early_sessions,
            "early_active_days_w1_w2": early_active,
            "education_minutes": round(sum(user_week_edu_minutes[(user_id, week)] for week in range(1, 9)), 1),
            "alternative_thought_count": user_alt_counts[user_id],
            "real_oddness_logs": real_oddness_by_user[user_id],
            "category_logs": category_logs_by_user[user_id],
            "sud_drop_week3_to_week8": sud_drop,
            "after_sud_slope": sud_slope,
            "sud_record_count": len(user_sud),
            "sud_worse_rate": user_worse / len(user_sud) if user_sud else None,
            "after_sud_mean": mean(user_after_sud),
            "after_sud_sd": stdev(user_after_sud),
            "immediate_sud_delta_mean": mean(user_delta),
            "location_record_count": loc_total,
            "location_label_count": len(label_by_user[user_id]),
            "core_location_ratio": core_count / loc_total if loc_total else None,
            "night_record_ratio": night_count / loc_total if loc_total else None,
            "notification_count": notif_by_user[user_id],
            "confront_behavior_count": behavior_by_user[user_id].get("confront", 0),
            "avoid_behavior_count": behavior_by_user[user_id].get("avoid", 0),
        }
        gad_drop = row.get("gad_drop")
        if gad_drop is None:
            segment = "미분류"
        elif gad_drop >= 4:
            segment = "4점 이상 개선"
        elif gad_drop >= 3:
            segment = "3점 이상 개선"
        else:
            segment = "3점 미만 개선"
        row["response_segment"] = segment
        user_rows.append(row)

    return {
        "survey": survey,
        "user_rows": user_rows,
        "diary_rows": diary_rows,
        "sud_records": sud_records,
        "weekly_diary_counts": weekly_diary_counts,
        "weekly_relax_counts": weekly_relax_counts,
        "weekly_screen_minutes": weekly_screen_minutes,
        "weekly_screen_sessions": weekly_screen_sessions,
        "weekly_edu_minutes": weekly_edu_minutes,
        "screen_hours": screen_hours,
        "screen_session_rows": screen_session_rows,
        "notification_rows": notification_rows,
        "user_week_diary_counts": user_week_diary_counts,
        "user_week_relax_counts": user_week_relax_counts,
        "user_week_screen_minutes": user_week_screen_minutes,
        "user_week_screen_sessions": user_week_screen_sessions,
        "user_week_active_days": user_week_active_days,
        "user_week_edu_minutes": user_week_edu_minutes,
        "session_minutes": session_minutes,
        "topic_counts": topic_counts,
        "topic_sud": topic_sud,
        "activity_counts": activity_counts,
        "location_summary": location_summary,
        "location_period": location_period,
        "location_period_sud": location_period_sud,
        "location_hour": location_hour,
        "location_topic": location_topic,
        "location_activity": location_activity,
        "missing_location": missing_location,
        "auto_location": auto_location,
        "behavior_counts": behavior_counts,
        "category_counts": category_counts,
        "eval_total": eval_total,
        "eval_effective": eval_effective,
        "continue_total": continue_total,
        "will_continue": will_continue,
        "notif_by_user": notif_by_user,
        "active_days": active_days,
    }


def clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def savefig(fig, path: Path) -> None:
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def style_ax(ax) -> None:
    ax.grid(alpha=0.16)
    for spine in ax.spines.values():
        spine.set_visible(False)


def plot_gad_outcomes(user_rows: list[dict], path: Path) -> None:
    pre = [r["gad_pre"] for r in user_rows]
    post = [r["gad_post"] for r in user_rows]
    drops = [r["gad_drop"] for r in user_rows]
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), dpi=180)
    axes[0].bar(["시작", "8주 후"], [mean(pre), mean(post)], color=[COLORS["blue"], COLORS["teal"]], width=0.55)
    axes[0].set_title("GAD-7 평균 변화")
    axes[0].set_ylabel("평균 점수")
    for idx, value in enumerate([mean(pre), mean(post)]):
        axes[0].text(idx, value + 0.25, f"{value:.2f}", ha="center", color=COLORS["ink"])
    style_ax(axes[0])
    labels = ["4점 이상 개선", "3점 이상 개선", "3점 미만 개선"]
    values = [sum(d >= 4 for d in drops), sum(3 <= d < 4 for d in drops), sum(d < 3 for d in drops)]
    axes[1].bar(labels, values, color=[COLORS["teal"], COLORS["gold"], COLORS["coral"]])
    axes[1].set_title("GAD-7 개선자 분포")
    axes[1].set_ylabel("사용자 수")
    axes[1].tick_params(axis="x", rotation=15)
    for idx, value in enumerate(values):
        axes[1].text(idx, value + 0.3, f"{value}명", ha="center")
    style_ax(axes[1])
    savefig(fig, path)


def plot_gad_transition(user_rows: list[dict], path: Path) -> None:
    order = ["거의 없음", "경도", "중등도", "높음"]
    matrix = [[0 for _ in order] for _ in order]
    for row in user_rows:
        matrix[order.index(row["gad_pre_severity"])][order.index(row["gad_post_severity"])] += 1
    fig, ax = plt.subplots(figsize=(6.8, 5.2), dpi=180)
    image = ax.imshow(matrix, cmap="Blues")
    ax.set_title("GAD-7 중증도 이동")
    ax.set_xlabel("8주 후")
    ax.set_ylabel("시작")
    ax.set_xticks(range(len(order)))
    ax.set_xticklabels(order)
    ax.set_yticks(range(len(order)))
    ax.set_yticklabels(order)
    for y, row in enumerate(matrix):
        for x, value in enumerate(row):
            if value:
                ax.text(x, y, str(value), ha="center", va="center", fontsize=12, color=COLORS["ink"])
    fig.colorbar(image, ax=ax, fraction=0.04, pad=0.03, label="사용자 수")
    savefig(fig, path)


def plot_phq_baseline(user_rows: list[dict], path: Path) -> None:
    order = ["거의 없음", "경도", "중등도", "중등도-높음", "높음"]
    counts = Counter(r.get("phq_pre_severity") for r in user_rows)
    values = [counts[label] for label in order]
    fig, ax = plt.subplots(figsize=(8, 4.6), dpi=180)
    ax.bar(order, values, color=[COLORS["green"], COLORS["teal"], COLORS["gold"], COLORS["coral"], COLORS["purple"]])
    ax.set_title("PHQ-9 시작 시점 분포")
    ax.set_ylabel("사용자 수")
    ax.tick_params(axis="x", rotation=15)
    for idx, value in enumerate(values):
        if value:
            ax.text(idx, value + 0.2, f"{value}명", ha="center")
    style_ax(ax)
    savefig(fig, path)


def weekly_sud_rows(sud_records: list[dict]) -> list[dict]:
    rows = []
    for week in range(3, 9):
        records = [r for r in sud_records if r["week"] == week]
        before = [r["before"] for r in records]
        after = [r["after"] for r in records]
        delta = [r["delta"] for r in records]
        worse = sum(1 for r in records if r["worse"])
        rows.append(
            {
                "주차": week,
                "기록 수": len(records),
                "평균 수행 전 SUD": round(mean(before) or 0, 2),
                "평균 수행 후 SUD": round(mean(after) or 0, 2),
                "평균 SUD 감소량": round(mean(delta) or 0, 2),
                "악화 기록 수": worse,
                "악화 없음 비율": round(pct(len(records) - worse, len(records)), 1),
            }
        )
    return rows


def plot_weekly_sud(rows: list[dict], path: Path) -> None:
    weeks = [r["주차"] for r in rows]
    before = [r["평균 수행 전 SUD"] for r in rows]
    after = [r["평균 수행 후 SUD"] for r in rows]
    fig, ax = plt.subplots(figsize=(9, 4.8), dpi=180)
    ax.plot(weeks, before, marker="o", linewidth=2.4, color=COLORS["coral"], label="수행 전")
    ax.plot(weeks, after, marker="o", linewidth=2.4, color=COLORS["teal"], label="수행 후")
    ax.fill_between(weeks, after, before, color=COLORS["teal"], alpha=0.12)
    ax.set_title("주차별 평균 SUD 변화")
    ax.set_xlabel("주차")
    ax.set_ylabel("평균 SUD")
    ax.set_xticks(weeks)
    ax.legend(frameon=False)
    style_ax(ax)
    savefig(fig, path)


def plot_sud_delta_safety(rows: list[dict], path: Path) -> None:
    weeks = [r["주차"] for r in rows]
    delta = [r["평균 SUD 감소량"] for r in rows]
    safe = [r["악화 없음 비율"] for r in rows]
    fig, ax1 = plt.subplots(figsize=(9, 4.8), dpi=180)
    ax1.bar(weeks, delta, color=COLORS["blue"], alpha=0.82)
    ax1.set_ylabel("평균 SUD 감소량")
    ax1.set_xlabel("주차")
    ax1.set_xticks(weeks)
    ax2 = ax1.twinx()
    ax2.plot(weeks, safe, marker="o", color=COLORS["coral"], linewidth=2.2, label="악화 없음 비율")
    ax2.set_ylim(80, 100)
    ax2.set_ylabel("악화 없음 비율(%)")
    ax1.set_title("즉시 SUD 감소량과 악화 없음 비율")
    style_ax(ax1)
    for spine in ax2.spines.values():
        spine.set_visible(False)
    savefig(fig, path)


def plot_adherence_weekly(weekly_rows: list[dict], path: Path) -> None:
    weeks = [r["주차"] for r in weekly_rows]
    diaries = [r["일기 수"] for r in weekly_rows]
    relax = [r["이완 수"] for r in weekly_rows]
    screen = [r["평균 사용 시간(분)"] for r in weekly_rows]
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.6), dpi=180)
    axes[0].bar([w - 0.18 for w in weeks], diaries, width=0.36, color=COLORS["blue"], label="일기")
    axes[0].bar([w + 0.18 for w in weeks], relax, width=0.36, color=COLORS["green"], label="이완")
    axes[0].set_title("주차별 과제 수행량")
    axes[0].set_xlabel("주차")
    axes[0].set_ylabel("기록 수")
    axes[0].set_xticks(weeks)
    axes[0].legend(frameon=False)
    style_ax(axes[0])
    axes[1].plot(weeks, screen, marker="o", linewidth=2.4, color=COLORS["purple"])
    axes[1].set_title("주차별 평균 앱 사용 시간")
    axes[1].set_xlabel("주차")
    axes[1].set_ylabel("분/사용자")
    axes[1].set_xticks(weeks)
    style_ax(axes[1])
    savefig(fig, path)


def plot_dose_response(user_rows: list[dict], path: Path) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(11.5, 4.8), dpi=180)
    xs = [r["diary_count"] for r in user_rows]
    ys = [r["gad_drop"] for r in user_rows]
    axes[0].scatter(xs, ys, s=48, color=COLORS["blue"], alpha=0.82)
    axes[0].set_title("일기 작성량과 GAD-7 감소량")
    axes[0].set_xlabel("사용자별 일기 수")
    axes[0].set_ylabel("GAD-7 감소량")
    style_ax(axes[0])
    xs2 = [r["alternative_thought_count"] for r in user_rows]
    ys2 = [r["sud_drop_week3_to_week8"] for r in user_rows]
    axes[1].scatter(xs2, ys2, s=48, color=COLORS["teal"], alpha=0.82)
    axes[1].set_title("대안적 생각 수와 SUD 감소")
    axes[1].set_xlabel("대안적 생각 수")
    axes[1].set_ylabel("3주차→8주차 수행 후 SUD 감소")
    style_ax(axes[1])
    savefig(fig, path)


def plot_mechanism(sud_records: list[dict], user_rows: list[dict], behavior_counts: Counter, eval_total: int, eval_effective: int, continue_total: int, will_continue: int, path: Path) -> None:
    pre = [r["delta"] for r in sud_records if r["week"] in {3, 4}]
    post = [r["delta"] for r in sud_records if r["week"] in {5, 6, 7, 8}]
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.6), dpi=180)
    axes[0].bar(["3~4주차", "5~8주차"], [mean(pre), mean(post)], color=[COLORS["gold"], COLORS["teal"]])
    axes[0].set_title("5주차 이후 즉시 SUD 감소")
    axes[0].set_ylabel("평균 감소량")
    style_ax(axes[0])
    labels = ["직면 행동", "회피 행동"]
    values = [behavior_counts.get("confront", 0), behavior_counts.get("avoid", 0)]
    axes[1].bar(labels, values, color=[COLORS["green"], COLORS["coral"]])
    axes[1].set_title("7주차 행동 분류")
    axes[1].set_ylabel("기록 수")
    style_ax(axes[1])
    eval_rate = pct(eval_effective, eval_total)
    cont_rate = pct(will_continue, continue_total)
    axes[2].bar(["효과 있음", "유지 의도"], [eval_rate, cont_rate], color=[COLORS["teal"], COLORS["blue"]])
    axes[2].set_title("8주차 평가")
    axes[2].set_ylim(0, 105)
    axes[2].set_ylabel("%")
    for idx, value in enumerate([eval_rate, cont_rate]):
        axes[2].text(idx, value + 2, f"{value:.1f}%", ha="center")
    style_ax(axes[2])
    savefig(fig, path)


def plot_worry_bubble(topic_counts: Counter, topic_sud: dict, path: Path) -> None:
    rows = []
    for topic, count in topic_counts.items():
        avg = mean(topic_sud.get(topic, []))
        if avg is not None:
            rows.append((topic, count, avg))
    rows = sorted(rows, key=lambda row: row[1], reverse=True)[:10]
    fig, ax = plt.subplots(figsize=(10.5, 5.4), dpi=180)
    xs = [r[1] for r in rows]
    ys = [r[2] for r in rows]
    sizes = [max(90, r[1] * 0.55) for r in rows]
    ax.scatter(xs, ys, s=sizes, color=COLORS["purple"], alpha=0.58)
    for topic, count, avg in rows:
        ax.text(count, avg + 0.03, topic, fontsize=8, ha="center")
    ax.set_title("걱정 주제별 빈도와 평균 SUD")
    ax.set_xlabel("일기 수")
    ax.set_ylabel("평균 수행 후 SUD")
    style_ax(ax)
    savefig(fig, path)


def plot_location_count_sud(location_summary: dict, path: Path) -> None:
    rows = []
    for label in LOCATION_ORDER:
        row = location_summary.get(label)
        if row:
            rows.append((label, int(row["count"]), mean(row["sud"])))
    fig, ax1 = plt.subplots(figsize=(11, 5.2), dpi=180)
    labels = [r[0] for r in rows]
    counts = [r[1] for r in rows]
    sud = [r[2] or 0 for r in rows]
    ax1.bar(labels, counts, color=COLORS["blue"], alpha=0.82)
    ax1.set_ylabel("일기 수")
    ax1.tick_params(axis="x", rotation=25)
    ax2 = ax1.twinx()
    ax2.plot(labels, sud, color=COLORS["coral"], marker="o", linewidth=2.3)
    ax2.set_ylabel("평균 수행 후 SUD")
    ax1.set_title("위치별 기록량과 부담")
    style_ax(ax1)
    for spine in ax2.spines.values():
        spine.set_visible(False)
    savefig(fig, path)


def plot_location_period_heatmap(location_period_sud: dict, location_period: Counter, location_summary: dict, path: Path) -> None:
    labels = [loc for loc in LOCATION_ORDER if loc in location_summary]
    matrix = []
    for loc in labels:
        row = []
        for period in PERIOD_ORDER:
            values = location_period_sud.get((loc, period), [])
            row.append(mean(values) if values else float("nan"))
        matrix.append(row)
    fig, ax = plt.subplots(figsize=(9.5, 5.7), dpi=180)
    image = ax.imshow(matrix, aspect="auto", cmap="YlOrRd", vmin=4.2, vmax=6.7)
    ax.set_title("위치 x 시간대 평균 수행 후 SUD")
    ax.set_xticks(range(len(PERIOD_ORDER)))
    ax.set_xticklabels(PERIOD_ORDER)
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels)
    for y, row in enumerate(matrix):
        for x, value in enumerate(row):
            if not math.isnan(value):
                n = location_period[(labels[y], PERIOD_ORDER[x])]
                ax.text(x, y, f"{value:.1f}\n{n}", ha="center", va="center", fontsize=8, color=COLORS["ink"])
    fig.colorbar(image, ax=ax, fraction=0.03, pad=0.02, label="평균 SUD")
    savefig(fig, path)


def plot_hourly_diary_screen(location_hour: Counter, screen_hours: Counter, path: Path) -> None:
    hours = list(range(24))
    diary_values = [sum(location_hour[(loc, hour)] for loc in LOCATION_ORDER) for hour in hours]
    screen_values = [screen_hours[hour] for hour in hours]
    fig, ax = plt.subplots(figsize=(10.5, 4.8), dpi=180)
    ax.plot(hours, diary_values, marker="o", color=COLORS["teal"], linewidth=2.3, label="위치 연결 일기")
    ax.plot(hours, screen_values, marker="o", color=COLORS["purple"], linewidth=2.3, label="앱 세션")
    ax.set_title("시간대별 일기 기록과 앱 세션")
    ax.set_xlabel("시간")
    ax.set_ylabel("기록 수")
    ax.set_xticks(range(0, 24, 2))
    ax.legend(frameon=False)
    style_ax(ax)
    savefig(fig, path)


def plot_user_segments(user_rows: list[dict], path: Path) -> None:
    segments = ["4점 이상 개선", "3점 이상 개선", "3점 미만 개선"]
    metrics = [
        ("diary_count", "일기 수"),
        ("alternative_thought_count", "대안적 생각 수"),
        ("sud_drop_week3_to_week8", "SUD 감소"),
        ("night_record_ratio", "밤/심야 기록 비율"),
    ]
    fig, axes = plt.subplots(1, len(metrics), figsize=(14, 4.6), dpi=180)
    for ax, (key, title) in zip(axes, metrics):
        values = []
        for segment in segments:
            vals = [r[key] for r in user_rows if r["response_segment"] == segment and r.get(key) is not None]
            values.append(mean(vals) or 0)
        ax.bar(segments, values, color=[COLORS["teal"], COLORS["gold"], COLORS["coral"]])
        ax.set_title(title)
        ax.tick_params(axis="x", rotation=25)
        style_ax(ax)
    fig.suptitle("GAD-7 개선 수준별 사용 패턴", y=1.03, fontsize=14)
    savefig(fig, path)


def plot_user_trajectories(user_rows: list[dict], sud_records: list[dict], path: Path) -> None:
    user_week_after = defaultdict(list)
    for record in sud_records:
        if record["week"]:
            user_week_after[(record["user_id"], record["week"])].append(record["after"])
    fig, axes = plt.subplots(5, 8, figsize=(14, 8), dpi=180, sharex=True, sharey=True)
    axes_flat = axes.flatten()
    for ax, user in zip(axes_flat, user_rows):
        weeks = []
        values = []
        for week in range(3, 9):
            vals = user_week_after.get((user["user_id"], week), [])
            if vals:
                weeks.append(week)
                values.append(mean(vals))
        color = COLORS["teal"] if user["gad_drop"] >= 4 else COLORS["gold"] if user["gad_drop"] >= 3 else COLORS["coral"]
        ax.plot(weeks, values, marker="o", linewidth=1.4, color=color)
        ax.set_title(user["participant"], fontsize=8)
        ax.set_xticks([3, 5, 8])
        ax.set_ylim(3, 8)
        ax.grid(alpha=0.12)
        for spine in ax.spines.values():
            spine.set_visible(False)
    for ax in axes_flat[len(user_rows):]:
        ax.axis("off")
    fig.suptitle("사용자별 수행 후 SUD 궤적", y=1.01, fontsize=14)
    savefig(fig, path)


def percentile(values: list[float], q: float) -> float | None:
    vals = sorted(float(v) for v in values if v is not None)
    if not vals:
        return None
    if len(vals) == 1:
        return vals[0]
    pos = (len(vals) - 1) * q
    lo = math.floor(pos)
    hi = math.ceil(pos)
    if lo == hi:
        return vals[lo]
    return vals[lo] + (vals[hi] - vals[lo]) * (pos - lo)


def circular_hour_distance(a: int, b: int) -> int:
    diff = abs((int(a) % 24) - (int(b) % 24))
    return min(diff, 24 - diff)


def classify_user_archetypes(user_rows: list[dict]) -> list[dict]:
    active_scores = [r["diary_count"] + r["alternative_thought_count"] for r in user_rows]
    active_median = median(active_scores) or 0
    worse_cut = percentile([r.get("sud_worse_rate") for r in user_rows if r.get("sud_worse_rate") is not None], 0.75) or 0
    sd_cut = percentile([r.get("after_sud_sd") for r in user_rows if r.get("after_sud_sd") is not None], 0.75) or 0
    screen_median = median([r["screen_minutes"] for r in user_rows]) or 0
    rows = []
    for row in user_rows:
        active_score = row["diary_count"] + row["alternative_thought_count"]
        if row.get("gad_drop", 0) >= 4 and active_score >= active_median:
            archetype = "능동 과제 고반응형"
            priority = "현재 과제 루틴 유지와 고급 과제 추천"
        elif row.get("gad_drop", 0) >= 4:
            archetype = "저강도 안정 개선형"
            priority = "짧은 과제와 유지 계획 중심 지원"
        elif active_score >= active_median and row.get("gad_drop", 0) < 3:
            archetype = "수행량 대비 정체형"
            priority = "일기 품질, 대안적 생각 구체성, 행동 계획 점검"
        elif (row.get("sud_worse_rate") or 0) >= worse_cut or (row.get("after_sud_sd") or 0) >= sd_cut:
            archetype = "SUD 변동성 관리형"
            priority = "고부담 상황 탐지와 즉시 안정화 과제"
        elif row["screen_minutes"] >= screen_median:
            archetype = "체류시간 중심 완료형"
            priority = "체류시간보다 능동 과제 전환 유도"
        else:
            archetype = "기본 완료형"
            priority = "완료 루틴 유지와 알림 최적화"
        rows.append(
            {
                "participant": row["participant"],
                "user_id": row["user_id"],
                "사용자 유형": archetype,
                "우선 개입 방향": priority,
                "GAD-7 감소": round(row.get("gad_drop") or 0, 2),
                "일기 수": row["diary_count"],
                "대안적 생각 수": row["alternative_thought_count"],
                "앱 사용 시간(분)": round(row["screen_minutes"], 1),
                "SUD 악화 비율": round((row.get("sud_worse_rate") or 0) * 100, 1),
                "SUD 표준편차": round(row.get("after_sud_sd") or 0, 2),
            }
        )
    return rows


def build_early_signal_rows(user_rows: list[dict]) -> list[dict]:
    metrics = [
        ("1~2주차 활성일", "early_active_days_w1_w2"),
        ("1~2주차 일기 수", "early_diary_count_w1_w2"),
        ("1~2주차 이완 수", "early_relax_count_w1_w2"),
        ("1~2주차 앱 세션 수", "early_screen_sessions_w1_w2"),
        ("1~2주차 앱 사용 시간", "early_screen_minutes_w1_w2"),
    ]
    rows = []
    for label, key in metrics:
        xs = [r[key] for r in user_rows if r.get(key) is not None]
        gad = [r["gad_drop"] for r in user_rows if r.get(key) is not None]
        sud = [r["sud_drop_week3_to_week8"] for r in user_rows if r.get(key) is not None]
        sorted_rows = sorted([r for r in user_rows if r.get(key) is not None], key=lambda r: r[key])
        low = sorted_rows[:10]
        high = sorted_rows[-10:]
        rows.append(
            {
                "초반 지표": label,
                "GAD-7 감소 Pearson r": round(pearson(xs, gad) or 0, 2),
                "GAD-7 감소 Spearman rho": round(spearman(xs, gad) or 0, 2),
                "SUD 감소 Pearson r": round(pearson(xs, sud) or 0, 2),
                "SUD 감소 Spearman rho": round(spearman(xs, sud) or 0, 2),
                "상위 10명 GAD-7 감소": round(mean([r["gad_drop"] for r in high]) or 0, 2),
                "하위 10명 GAD-7 감소": round(mean([r["gad_drop"] for r in low]) or 0, 2),
                "상위-하위 차이": round((mean([r["gad_drop"] for r in high]) or 0) - (mean([r["gad_drop"] for r in low]) or 0), 2),
            }
        )
    return rows


def build_notification_alignment_rows(derived: dict[str, object]) -> list[dict]:
    alarms_by_user: dict[str, list[dict]] = defaultdict(list)
    for alarm in derived["notification_rows"]:
        if alarm.get("enabled"):
            alarms_by_user[alarm["user_id"]].append(alarm)
    sessions_by_user: dict[str, list[dict]] = defaultdict(list)
    for session in derived["screen_session_rows"]:
        sessions_by_user[session["user_id"]].append(session)
    rows = []
    for user_id in sorted({*alarms_by_user.keys(), *sessions_by_user.keys()}):
        sessions = sessions_by_user.get(user_id, [])
        alarms = alarms_by_user.get(user_id, [])
        near1 = 0
        near2 = 0
        for session in sessions:
            if not alarms or session.get("hour") is None:
                continue
            distances = [circular_hour_distance(session["hour"], alarm["hour"]) for alarm in alarms]
            if min(distances) <= 1:
                near1 += 1
            if min(distances) <= 2:
                near2 += 1
        rows.append(
            {
                "user_id": user_id,
                "participant": participant_label(user_id),
                "알림 수": len(alarms),
                "앱 세션 수": len(sessions),
                "알림 1시간 내 세션 수": near1,
                "알림 2시간 내 세션 수": near2,
                "알림 1시간 내 세션 비율": round(pct(near1, len(sessions)), 1),
                "알림 2시간 내 세션 비율": round(pct(near2, len(sessions)), 1),
            }
        )
    return rows


def build_context_topic_rows(diary_rows: list[dict]) -> list[dict]:
    agg: dict[tuple[str, str, str], dict[str, object]] = defaultdict(lambda: {"count": 0, "sud": [], "users": set()})
    for row in diary_rows:
        if not row.get("location") or not row.get("period") or row.get("after_sud_mean") is None:
            continue
        key = (row["location"], row["period"], row["topic"])
        agg[key]["count"] += 1
        agg[key]["sud"].append(row["after_sud_mean"])
        agg[key]["users"].add(row["user_id"])
    rows = []
    for (loc, period, topic), values in agg.items():
        count = int(values["count"])
        if count < 12:
            continue
        rows.append(
            {
                "위치": loc,
                "시간대": period,
                "걱정 주제": topic,
                "일기 수": count,
                "사용자 수": len(values["users"]),
                "평균 수행 후 SUD": round(mean(values["sud"]) or 0, 2),
            }
        )
    rows.sort(key=lambda row: (float(row["평균 수행 후 SUD"]), int(row["일기 수"])), reverse=True)
    return rows


def build_worsening_rows(sud_records: list[dict]) -> tuple[list[dict], list[dict], list[dict]]:
    by_week = []
    for week in range(3, 9):
        records = [r for r in sud_records if r["week"] == week]
        by_week.append(
            {
                "주차": week,
                "SUD 기록 수": len(records),
                "악화 기록 수": sum(1 for r in records if r["worse"]),
                "악화 비율": round(pct(sum(1 for r in records if r["worse"]), len(records)), 1),
            }
        )
    topic_map: dict[str, list[dict]] = defaultdict(list)
    context_map: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in sud_records:
        topic_map[r["topic"]].append(r)
        context_map[(r["location"], r["period"])].append(r)
    topic_rows = []
    for topic, records in topic_map.items():
        if len(records) < 30:
            continue
        topic_rows.append(
            {
                "걱정 주제": topic,
                "SUD 기록 수": len(records),
                "악화 기록 수": sum(1 for r in records if r["worse"]),
                "악화 비율": round(pct(sum(1 for r in records if r["worse"]), len(records)), 1),
                "평균 수행 후 SUD": round(mean([r["after"] for r in records]) or 0, 2),
            }
        )
    topic_rows.sort(key=lambda row: (float(row["악화 비율"]), int(row["SUD 기록 수"])), reverse=True)
    context_rows = []
    for (loc, period), records in context_map.items():
        if loc == "위치 없음" or len(records) < 20:
            continue
        context_rows.append(
            {
                "위치": loc,
                "시간대": period,
                "SUD 기록 수": len(records),
                "악화 기록 수": sum(1 for r in records if r["worse"]),
                "악화 비율": round(pct(sum(1 for r in records if r["worse"]), len(records)), 1),
                "평균 수행 후 SUD": round(mean([r["after"] for r in records]) or 0, 2),
            }
        )
    context_rows.sort(key=lambda row: (float(row["악화 비율"]), float(row["평균 수행 후 SUD"])), reverse=True)
    return by_week, topic_rows, context_rows


def plot_early_signal(early_rows: list[dict], user_rows: list[dict], path: Path) -> None:
    labels = [row["초반 지표"].replace("1~2주차 ", "") for row in early_rows]
    cors = [row["GAD-7 감소 Spearman rho"] for row in early_rows]
    diffs = [row["상위-하위 차이"] for row in early_rows]
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), dpi=180)
    axes[0].barh(labels, cors, color=COLORS["teal"])
    axes[0].axvline(0, color=COLORS["line"], linewidth=1)
    axes[0].set_title("초반 지표와 GAD-7 감소의 순위상관")
    axes[0].set_xlabel("Spearman rho")
    style_ax(axes[0])
    axes[1].barh(labels, diffs, color=COLORS["blue"])
    axes[1].axvline(0, color=COLORS["line"], linewidth=1)
    axes[1].set_title("초반 지표 상위-하위 10명 차이")
    axes[1].set_xlabel("GAD-7 감소량 차이")
    style_ax(axes[1])
    savefig(fig, path)


def plot_notification_alignment(notification_rows: list[dict], user_rows: list[dict], path: Path) -> None:
    user_lookup = {r["user_id"]: r for r in user_rows}
    rows = [row for row in notification_rows if row["앱 세션 수"] > 0]
    labels = ["1개", "2개", "3개"]
    fig, axes = plt.subplots(1, 2, figsize=(11.5, 4.8), dpi=180)
    rates = []
    gad = []
    for label in labels:
        count = int(label[0])
        part = [r for r in rows if r["알림 수"] == count]
        rates.append(mean([r["알림 2시간 내 세션 비율"] for r in part]) or 0)
        gad.append(mean([user_lookup[r["user_id"]]["gad_drop"] for r in part if r["user_id"] in user_lookup]) or 0)
    axes[0].bar(labels, rates, color=COLORS["purple"])
    axes[0].set_title("알림 수별 세션 근접도")
    axes[0].set_ylabel("알림 2시간 내 앱 세션 비율(%)")
    style_ax(axes[0])
    axes[1].bar(labels, gad, color=COLORS["teal"])
    axes[1].set_title("알림 수별 GAD-7 감소")
    axes[1].set_ylabel("평균 감소량")
    style_ax(axes[1])
    savefig(fig, path)


def plot_context_topic_burden(rows: list[dict], path: Path) -> None:
    top = rows[:12]
    labels = [f"{r['위치']}·{r['시간대']}\n{r['걱정 주제']}" for r in top][::-1]
    values = [r["평균 수행 후 SUD"] for r in top][::-1]
    counts = [r["일기 수"] for r in top][::-1]
    fig, ax = plt.subplots(figsize=(10, 6.4), dpi=180)
    colors = [COLORS["coral"] if v >= 5.7 else COLORS["gold"] if v >= 5.3 else COLORS["teal"] for v in values]
    ax.barh(labels, values, color=colors)
    for idx, (value, count) in enumerate(zip(values, counts)):
        ax.text(value + 0.03, idx, f"{value:.2f} / {count}건", va="center", fontsize=8)
    ax.set_title("고부담 위치·시간·걱정 주제 조합")
    ax.set_xlabel("평균 수행 후 SUD")
    ax.set_xlim(3.8, max(values + [6.4]) + 0.4)
    style_ax(ax)
    savefig(fig, path)


def plot_worsening_context(week_rows: list[dict], topic_rows: list[dict], context_rows: list[dict], path: Path) -> None:
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.8), dpi=180)
    weeks = [r["주차"] for r in week_rows]
    rates = [r["악화 비율"] for r in week_rows]
    axes[0].plot(weeks, rates, marker="o", linewidth=2.3, color=COLORS["coral"])
    axes[0].set_title("주차별 SUD 악화 비율")
    axes[0].set_xlabel("주차")
    axes[0].set_ylabel("%")
    axes[0].set_xticks(weeks)
    style_ax(axes[0])
    top_topics = topic_rows[:6][::-1]
    axes[1].barh([r["걱정 주제"] for r in top_topics], [r["악화 비율"] for r in top_topics], color=COLORS["gold"])
    axes[1].set_title("악화 비율이 높은 걱정 주제")
    axes[1].set_xlabel("%")
    style_ax(axes[1])
    top_context = context_rows[:6][::-1]
    axes[2].barh([f"{r['위치']}·{r['시간대']}" for r in top_context], [r["악화 비율"] for r in top_context], color=COLORS["purple"])
    axes[2].set_title("악화 비율이 높은 맥락")
    axes[2].set_xlabel("%")
    style_ax(axes[2])
    savefig(fig, path)


def plot_user_archetypes(archetype_rows: list[dict], path: Path) -> None:
    counts = Counter(row["사용자 유형"] for row in archetype_rows)
    order = [label for label, _ in counts.most_common()]
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), dpi=180)
    axes[0].barh(order[::-1], [counts[label] for label in order][::-1], color=COLORS["teal"])
    axes[0].set_title("사용자 유형 분포")
    axes[0].set_xlabel("사용자 수")
    style_ax(axes[0])
    avg_gad = []
    for label in order:
        vals = [row["GAD-7 감소"] for row in archetype_rows if row["사용자 유형"] == label]
        avg_gad.append(mean(vals) or 0)
    axes[1].barh(order[::-1], avg_gad[::-1], color=COLORS["blue"])
    axes[1].set_title("사용자 유형별 평균 GAD-7 감소")
    axes[1].set_xlabel("평균 감소량")
    style_ax(axes[1])
    savefig(fig, path)


def plot_weekly_ux_burden(weekly_rows: list[dict], path: Path) -> None:
    weeks = [r["주차"] for r in weekly_rows]
    edu = [r["평균 교육 시간(분)"] for r in weekly_rows]
    app = [r["평균 사용 시간(분)"] for r in weekly_rows]
    tasks = [r["평균 과제 수"] for r in weekly_rows]
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), dpi=180)
    axes[0].plot(weeks, app, marker="o", color=COLORS["purple"], linewidth=2.3, label="앱 사용")
    axes[0].plot(weeks, edu, marker="o", color=COLORS["coral"], linewidth=2.3, label="교육")
    axes[0].set_title("주차별 시간 부담")
    axes[0].set_xlabel("주차")
    axes[0].set_ylabel("분/사용자")
    axes[0].set_xticks(weeks)
    axes[0].legend(frameon=False)
    style_ax(axes[0])
    axes[1].bar(weeks, tasks, color=COLORS["green"])
    axes[1].set_title("주차별 평균 과제 수")
    axes[1].set_xlabel("주차")
    axes[1].set_ylabel("개/사용자")
    axes[1].set_xticks(weeks)
    style_ax(axes[1])
    savefig(fig, path)


def build_tables(derived: dict[str, object], table_dir: Path) -> dict[str, list[dict]]:
    user_rows = derived["user_rows"]
    sud_records = derived["sud_records"]
    weekly_rows = weekly_sud_rows(sud_records)
    write_csv(table_dir / "user_level_metrics.csv", user_rows)
    write_csv(table_dir / "weekly_sud_summary.csv", weekly_rows)

    weekly_adherence = []
    for week in range(1, 9):
        weekly_adherence.append(
            {
                "주차": week,
                "일기 수": derived["weekly_diary_counts"][week],
                "이완 수": derived["weekly_relax_counts"][week],
                "평균 사용 시간(분)": round(derived["weekly_screen_minutes"][week] / len(user_rows), 1),
                "앱 세션 수": derived["weekly_screen_sessions"][week],
            }
        )
    write_csv(table_dir / "weekly_adherence_summary.csv", weekly_adherence)

    weekly_burden = []
    for week in range(1, 9):
        task_count = derived["weekly_diary_counts"][week] + derived["weekly_relax_counts"][week]
        weekly_burden.append(
            {
                "주차": week,
                "평균 사용 시간(분)": round(derived["weekly_screen_minutes"][week] / len(user_rows), 1),
                "평균 교육 시간(분)": round(derived["weekly_edu_minutes"][week] / len(user_rows), 1),
                "평균 과제 수": round(task_count / len(user_rows), 1),
                "앱 세션 수": derived["weekly_screen_sessions"][week],
            }
        )
    write_csv(table_dir / "weekly_ux_burden_summary.csv", weekly_burden)

    topic_rows = []
    for topic, count in derived["topic_counts"].most_common():
        topic_rows.append(
            {
                "걱정 주제": topic,
                "일기 수": count,
                "평균 수행 후 SUD": round(mean(derived["topic_sud"].get(topic, [])) or 0, 2),
            }
        )
    write_csv(table_dir / "worry_topic_summary.csv", topic_rows)

    loc_rows = []
    for loc in LOCATION_ORDER:
        row = derived["location_summary"].get(loc)
        if row:
            loc_rows.append(
                {
                    "위치": loc,
                    "일기 수": int(row["count"]),
                    "기록 사용자 수": len(row["users"]),
                    "평균 수행 후 SUD": round(mean(row["sud"]) or 0, 2),
                    "위치 자동 입력 수": int(row["auto"]),
                }
            )
    write_csv(table_dir / "location_summary.csv", loc_rows)

    location_period_rows = []
    for loc in LOCATION_ORDER:
        for period in PERIOD_ORDER:
            count = derived["location_period"][(loc, period)]
            if count:
                location_period_rows.append(
                    {
                        "위치": loc,
                        "시간대": period,
                        "일기 수": count,
                        "평균 수행 후 SUD": round(mean(derived["location_period_sud"].get((loc, period), [])) or 0, 2),
                    }
                )
    write_csv(table_dir / "location_period_summary.csv", location_period_rows)

    high_burden_rows = [
        row
        for row in location_period_rows
        if int(row["일기 수"]) >= 20 and row["평균 수행 후 SUD"] != ""
    ]
    high_burden_rows.sort(key=lambda row: (float(row["평균 수행 후 SUD"]), int(row["일기 수"])), reverse=True)
    write_csv(table_dir / "high_burden_context_windows.csv", high_burden_rows)

    dose_rows = build_dose_rows(user_rows)
    write_csv(table_dir / "dose_response_summary.csv", dose_rows)

    segment_rows = []
    for segment in ["4점 이상 개선", "3점 이상 개선", "3점 미만 개선"]:
        rows = [r for r in user_rows if r["response_segment"] == segment]
        segment_rows.append(
            {
                "개선 그룹": segment,
                "사용자 수": len(rows),
                "평균 GAD-7 감소": round(mean([r["gad_drop"] for r in rows]) or 0, 2),
                "평균 일기 수": round(mean([r["diary_count"] for r in rows]) or 0, 1),
                "평균 대안적 생각 수": round(mean([r["alternative_thought_count"] for r in rows]) or 0, 1),
                "평균 SUD 감소": round(mean([r["sud_drop_week3_to_week8"] for r in rows]) or 0, 2),
                "평균 밤/심야 기록 비율": round(mean([r["night_record_ratio"] for r in rows if r["night_record_ratio"] is not None]) or 0, 3),
            }
        )
    write_csv(table_dir / "response_segment_summary.csv", segment_rows)

    early_signal_rows = build_early_signal_rows(user_rows)
    write_csv(table_dir / "early_signal_summary.csv", early_signal_rows)

    notification_alignment_rows = build_notification_alignment_rows(derived)
    write_csv(table_dir / "notification_alignment_summary.csv", notification_alignment_rows)

    context_topic_rows = build_context_topic_rows(derived["diary_rows"])
    write_csv(table_dir / "high_burden_context_topic_summary.csv", context_topic_rows)

    worsening_week_rows, worsening_topic_rows, worsening_context_rows = build_worsening_rows(sud_records)
    write_csv(table_dir / "sud_worsening_by_week.csv", worsening_week_rows)
    write_csv(table_dir / "sud_worsening_by_topic.csv", worsening_topic_rows)
    write_csv(table_dir / "sud_worsening_by_context.csv", worsening_context_rows)

    archetype_rows = classify_user_archetypes(user_rows)
    write_csv(table_dir / "user_archetype_summary.csv", archetype_rows)

    return {
        "weekly_sud": weekly_rows,
        "weekly_adherence": weekly_adherence,
        "weekly_burden": weekly_burden,
        "topic_rows": topic_rows,
        "location_rows": loc_rows,
        "location_period_rows": location_period_rows,
        "high_burden_rows": high_burden_rows,
        "dose_rows": dose_rows,
        "segment_rows": segment_rows,
        "early_signal_rows": early_signal_rows,
        "notification_alignment_rows": notification_alignment_rows,
        "context_topic_rows": context_topic_rows,
        "worsening_week_rows": worsening_week_rows,
        "worsening_topic_rows": worsening_topic_rows,
        "worsening_context_rows": worsening_context_rows,
        "archetype_rows": archetype_rows,
    }


def build_dose_rows(user_rows: list[dict]) -> list[dict]:
    def high_low(metric: str, outcome: str) -> tuple[float, float]:
        rows = [r for r in user_rows if r.get(metric) is not None and r.get(outcome) is not None]
        rows.sort(key=lambda row: row[metric])
        low = rows[:10]
        high = rows[-10:]
        return mean([r[outcome] for r in low]) or 0, mean([r[outcome] for r in high]) or 0

    pairs = [
        ("일기 작성량", "diary_count", "gad_drop", "GAD-7 감소량"),
        ("일기 작성량", "diary_count", "sud_drop_week3_to_week8", "SUD 감소량"),
        ("대안적 생각 수", "alternative_thought_count", "sud_drop_week3_to_week8", "SUD 감소량"),
        ("앱 사용 시간", "screen_minutes", "gad_drop", "GAD-7 감소량"),
        ("이완 수행 수", "relax_count", "sud_drop_week3_to_week8", "SUD 감소량"),
    ]
    rows = []
    for label, metric, outcome, outcome_label in pairs:
        low, high = high_low(metric, outcome)
        xs = [r[metric] for r in user_rows if r.get(metric) is not None and r.get(outcome) is not None]
        ys = [r[outcome] for r in user_rows if r.get(metric) is not None and r.get(outcome) is not None]
        rows.append(
            {
                "사용 지표": label,
                "결과 지표": outcome_label,
                "하위 10명 평균": round(low, 2),
                "상위 10명 평균": round(high, 2),
                "상위-하위 차이": round(high - low, 2),
                "Pearson r": round(pearson(xs, ys) or 0, 2),
                "Spearman rho": round(spearman(xs, ys) or 0, 2),
            }
        )
    return rows


def build_key_metrics(derived: dict[str, object], table_data: dict[str, list[dict]]) -> dict[str, object]:
    user_rows = derived["user_rows"]
    sud_records = derived["sud_records"]
    gad_drops = [r["gad_drop"] for r in user_rows]
    pre = [r["gad_pre"] for r in user_rows]
    post = [r["gad_post"] for r in user_rows]
    phq = [r["phq_pre"] for r in user_rows]
    high_pre = [r for r in user_rows if r["gad_pre"] >= 15]
    high_to_mod = [r for r in high_pre if r["gad_post"] <= 14]
    weekly_sud = table_data["weekly_sud"]
    week3_after = weekly_sud[0]["평균 수행 후 SUD"]
    week8_after = weekly_sud[-1]["평균 수행 후 SUD"]
    pre34 = [r["delta"] for r in sud_records if r["week"] in {3, 4}]
    post58 = [r["delta"] for r in sud_records if r["week"] in {5, 6, 7, 8}]
    total_diaries = len(derived["diary_rows"])
    located = sum(row["일기 수"] for row in table_data["location_rows"])
    core = sum(row["일기 수"] for row in table_data["location_rows"] if row["위치"] in CORE_LOCATIONS)
    early_best = max(table_data.get("early_signal_rows", []), key=lambda row: row["상위-하위 차이"], default={})
    notif_rates = [row["알림 2시간 내 세션 비율"] for row in table_data.get("notification_alignment_rows", []) if row["앱 세션 수"]]
    top_context_topic = table_data.get("context_topic_rows", [{}])[0] if table_data.get("context_topic_rows") else {}
    top_worse_topic = table_data.get("worsening_topic_rows", [{}])[0] if table_data.get("worsening_topic_rows") else {}
    top_worse_context = table_data.get("worsening_context_rows", [{}])[0] if table_data.get("worsening_context_rows") else {}
    peak_usage = max(table_data.get("weekly_burden", []), key=lambda row: row["평균 사용 시간(분)"], default={})
    peak_edu = max(table_data.get("weekly_burden", []), key=lambda row: row["평균 교육 시간(분)"], default={})
    archetype_counts = Counter(row["사용자 유형"] for row in table_data.get("archetype_rows", []))
    return {
        "n_users": len(user_rows),
        "gad_pre_mean": mean(pre),
        "gad_post_mean": mean(post),
        "gad_drop_mean": mean(gad_drops),
        "gad_drop_sd": stdev(gad_drops),
        "gad_response_4": sum(d >= 4 for d in gad_drops),
        "gad_response_3": sum(d >= 3 for d in gad_drops),
        "high_pre_count": len(high_pre),
        "high_to_mod_count": len(high_to_mod),
        "phq_pre_mean": mean(phq),
        "phq_minimal": sum(r.get("phq_pre_severity") == "거의 없음" for r in user_rows),
        "phq_mild": sum(r.get("phq_pre_severity") == "경도" for r in user_rows),
        "sud_total": len(sud_records),
        "sud_worse": sum(1 for r in sud_records if r["worse"]),
        "sud_non_worse_rate": pct(sum(1 for r in sud_records if not r["worse"]), len(sud_records)),
        "week3_after": week3_after,
        "week8_after": week8_after,
        "sud_after_drop": week3_after - week8_after,
        "module_pre34": mean(pre34),
        "module_post58": mean(post58),
        "module_lift": (mean(post58) or 0) - (mean(pre34) or 0),
        "total_diaries": total_diaries,
        "located_diaries": located,
        "location_missing": derived["missing_location"],
        "location_auto": derived["auto_location"],
        "core_location_ratio": pct(core, located),
        "effective_rate": pct(derived["eval_effective"], derived["eval_total"]),
        "continue_rate": pct(derived["will_continue"], derived["continue_total"]),
        "screen_session_median": median(derived["session_minutes"]),
        "screen_session_mean": mean(derived["session_minutes"]),
        "active_days_mean": mean([len(days) for days in derived["active_days"].values()]),
        "early_best_label": early_best.get("초반 지표", ""),
        "early_best_diff": early_best.get("상위-하위 차이", 0),
        "early_best_rho": early_best.get("GAD-7 감소 Spearman rho", 0),
        "notification_2h_rate_mean": mean(notif_rates),
        "top_context_topic": top_context_topic,
        "top_worse_topic": top_worse_topic,
        "top_worse_context": top_worse_context,
        "peak_usage_week": peak_usage.get("주차"),
        "peak_usage_minutes": peak_usage.get("평균 사용 시간(분)"),
        "peak_edu_week": peak_edu.get("주차"),
        "peak_edu_minutes": peak_edu.get("평균 교육 시간(분)"),
        "archetype_counts": archetype_counts,
    }


def build_report(derived: dict[str, object], table_data: dict[str, list[dict]], metrics: dict[str, object], out_dir: Path, chart_dir: Path) -> None:
    dose = table_data["dose_rows"]
    high_burden = table_data["high_burden_rows"][:6]
    location_rows = table_data["location_rows"]
    topic_rows = table_data["topic_rows"][:8]
    segment_rows = table_data["segment_rows"]
    early_rows = table_data["early_signal_rows"]
    context_topic_rows = table_data["context_topic_rows"][:8]
    worsening_topics = table_data["worsening_topic_rows"][:5]
    worsening_contexts = table_data["worsening_context_rows"][:5]
    archetype_counts = metrics["archetype_counts"]
    chart_captions = {
        "01_gad7_outcome_and_response.png": "GAD-7 평균 변화와 개선자 비율을 함께 보여준다. 평균 감소보다 4점 이상 개선자 비율이 발표 메시지로 더 직관적이다.",
        "02_gad7_severity_transition.png": "시작 시점 높은 불안군이 8주 후 어느 위험 구간으로 이동했는지 보여준다.",
        "03_phq9_baseline_distribution.png": "PHQ-9은 사후 측정이 없으므로 시작 시점 사용자 특성을 설명하는 기저 지표로 사용한다.",
        "04_weekly_sud_trajectory.png": "2주차 이후 가능해진 SUD 기록에서 수행 전후 점수가 주차별로 어떻게 낮아지는지 보여준다.",
        "05_sud_delta_and_nonworsening.png": "수행 직후 SUD 감소량과 악화 없음 비율을 함께 보여 안전성과 부담을 동시에 확인한다.",
        "06_weekly_adherence_and_screen_time.png": "주차별 일기, 이완, 앱 사용 시간을 비교해 사용 루틴이 유지되는지 확인한다.",
        "07_dose_response_active_tasks.png": "일기와 대안적 생각 같은 능동 과제가 결과 변화와 얼마나 가까운지 보여준다.",
        "08_mechanism_and_week8_evaluation.png": "5주차 이후 대안적 생각 기능, 7주차 행동 분류, 8주차 평가를 작동 패턴으로 연결한다.",
        "09_worry_topic_frequency_burden.png": "자주 기록된 걱정 주제와 평균 SUD가 높은 주제가 반드시 같지 않다는 점을 보여준다.",
        "10_location_count_and_sud.png": "어디서 많이 기록되는지와 어디서 부담이 높은지를 분리해 보여준다.",
        "11_location_period_sud_heatmap.png": "위치와 시간대를 함께 보아 부담이 커지는 생활 맥락을 식별한다.",
        "12_hourly_diary_and_app_sessions.png": "사용자가 앱을 여는 시간대와 일기를 남기는 시간대를 비교한다.",
        "13_response_segment_usage_patterns.png": "GAD-7 개선 수준별 사용 패턴 차이를 보여준다.",
        "14_user_sud_trajectories.png": "40명 개별 사용자의 SUD 변화 궤적을 small multiples로 확인한다.",
        "15_early_signal_predictors.png": "1~2주차 사용 패턴이 8주 후 변화와 어느 정도 연결되는지 탐색한다.",
        "16_notification_alignment.png": "알림 설정과 실제 앱 세션 시간의 근접도를 비교해 알림 최적화 가능성을 본다.",
        "17_context_topic_burden.png": "위치, 시간대, 걱정 주제를 결합해 가장 부담이 큰 상황 조합을 찾는다.",
        "18_sud_worsening_context.png": "수행 후 SUD가 높아진 기록이 어느 주차, 주제, 맥락에서 많이 발생하는지 보여준다.",
        "19_user_archetypes.png": "완료 사용자 40명을 사용 패턴과 변화 양상에 따라 운영 가능한 유형으로 나눈다.",
        "20_weekly_ux_burden.png": "교육 시간, 사용 시간, 과제 수를 함께 보아 어느 주차가 사용자 부담이 큰지 확인한다.",
    }

    top_context = metrics["top_context_topic"]
    top_worse_topic = metrics["top_worse_topic"]
    top_worse_context = metrics["top_worse_context"]
    top_archetype = archetype_counts.most_common(1)[0] if archetype_counts else ("", 0)

    lines = [
        "# Mindrium 최종 데이터 통합 분석",
        "",
        "## 1. 핵심 요약",
        "",
        f"- 분석 대상은 8주 완료 사용자 {metrics['n_users']}명이다.",
        f"- GAD-7 평균은 {metrics['gad_pre_mean']:.2f}점에서 {metrics['gad_post_mean']:.2f}점으로 변화했으며 평균 감소량은 {metrics['gad_drop_mean']:.2f}점이다.",
        f"- GAD-7 4점 이상 개선자는 {metrics['gad_response_4']}/{metrics['n_users']}명({pct(metrics['gad_response_4'], metrics['n_users']):.1f}%), 3점 이상 개선자는 {metrics['gad_response_3']}/{metrics['n_users']}명({pct(metrics['gad_response_3'], metrics['n_users']):.1f}%)이다.",
        f"- 시작 시점 높은 불안군 {metrics['high_pre_count']}명 중 {metrics['high_to_mod_count']}명이 8주 후 중등도 이하로 이동했다.",
        f"- PHQ-9은 시작 시점 평균 {metrics['phq_pre_mean']:.2f}점이며, 거의 없음/경도 사용자가 {metrics['phq_minimal'] + metrics['phq_mild']}명으로 다수를 차지한다.",
        f"- SUD 기록 {metrics['sud_total']:,}건 중 수행 후 악화되지 않은 비율은 {metrics['sud_non_worse_rate']:.1f}%이다.",
        f"- 수행 후 SUD는 3주차 {metrics['week3_after']:.2f}점에서 8주차 {metrics['week8_after']:.2f}점으로 {metrics['sud_after_drop']:.2f}점 낮아졌다.",
        f"- 1~2주차 초반 신호 중 `{metrics['early_best_label']}`의 상위-하위 10명 GAD-7 감소량 차이가 {metrics['early_best_diff']:.2f}점으로 가장 컸다.",
        f"- 알림 설정 시간 전후 2시간 안에 발생한 앱 세션 비율은 평균 {metrics['notification_2h_rate_mean']:.1f}%이다.",
        "",
        "## 2. 의사결정용 인사이트",
        "",
        "- 결과 보고는 평균 변화보다 개선자 비율과 중증도 이동을 앞세우는 편이 더 설득력 있다.",
        "- 단순 접속 시간보다 일기 작성과 대안적 생각 같은 능동 과제가 결과 변화와 더 가깝다.",
        "- 초반 1~2주 사용 패턴은 단독 예측력은 제한적이지만, 조기 지원 대상을 찾는 운영 지표 후보가 된다.",
        "- 알림은 단순 부가 기능이 아니라 루틴 유지 장치로 해석할 수 있으며, 실제 사용 시간과의 근접도를 기준으로 개인별 최적화할 수 있다.",
        "- 위치·시간·걱정 주제 조합은 개인화 과제 추천과 고부담 상황 대응 전략의 근거가 된다.",
        "- SUD 악화 기록은 비율이 낮더라도 사용자 부담 관리와 안전한 과제 종료 흐름을 설계하는 데 필요하다.",
        "",
        "## 3. 결과와 작동 기전",
        "",
        f"- 3~4주차 평균 즉시 SUD 감소량은 {metrics['module_pre34']:.2f}점, 5~8주차는 {metrics['module_post58']:.2f}점이다. 5주차 이후 감소폭이 {metrics['module_lift']:.2f}점 커졌다.",
        f"- 8주차 평가에서 효과 있음 비율은 {metrics['effective_rate']:.1f}%, 유지 의도는 {metrics['continue_rate']:.1f}%이다.",
        "- 이는 인과 효과를 단정하기보다는, 대안적 생각과 행동 계획이 열린 뒤 사용자가 더 구조화된 방식으로 불안을 낮추는 패턴으로 해석하는 것이 적절하다.",
        "",
        "## 4. 사용량과 결과의 관계",
        "",
    ]
    for row in dose:
        lines.append(
            f"- {row['사용 지표']} 상위 10명의 {row['결과 지표']}은 하위 10명보다 {row['상위-하위 차이']}점 높다. "
            f"(Pearson r={row['Pearson r']}, Spearman rho={row['Spearman rho']})"
        )
    lines.extend(
        [
            "",
            "## 5. 초반 신호와 알림 활용",
            "",
        ]
    )
    for row in early_rows:
        lines.append(
            f"- {row['초반 지표']}: GAD-7 감소 Spearman rho={row['GAD-7 감소 Spearman rho']}, "
            f"상위-하위 10명 차이={row['상위-하위 차이']}점"
        )
    lines.extend(
        [
            f"- 알림 2시간 내 앱 세션 비율은 평균 {metrics['notification_2h_rate_mean']:.1f}%이다. 일부 사용자는 알림 시간대와 앱 사용이 강하게 맞물리지만, 전체 평균 기준으로는 개인별 조정 여지가 크다.",
            "",
            "## 6. 위치/시간 기반 사용 맥락",
            "",
            f"- 위치가 연결된 일기는 {metrics['located_diaries']:,}/{metrics['total_diaries']:,}건({pct(metrics['located_diaries'], metrics['total_diaries']):.1f}%)이다.",
            f"- 핵심 위치(집, 학교, 연구실, 성균관대학교) 집중도는 {metrics['core_location_ratio']:.1f}%로, Lab test 환경의 통제된 생활 반경이 반영되어 있다.",
            f"- 위치 자동 입력 비율은 {pct(metrics['location_auto'], metrics['total_diaries']):.1f}%, 위치 미입력 비율은 {pct(metrics['location_missing'], metrics['total_diaries']):.1f}%이다.",
            f"- 앱 세션 중앙값은 {metrics['screen_session_median']:.1f}분, 평균 활성일은 사용자당 {metrics['active_days_mean']:.1f}일이다.",
            f"- 사용 시간 부담은 {metrics['peak_usage_week']}주차가 가장 높고({metrics['peak_usage_minutes']}분/사용자), 교육 시간 부담은 {metrics['peak_edu_week']}주차가 가장 높다({metrics['peak_edu_minutes']}분/사용자).",
            "",
            "### 위치별 기록량과 부담",
            "",
        ]
    )
    for row in location_rows:
        lines.append(f"- {row['위치']}: 일기 {row['일기 수']}건, 평균 수행 후 SUD {row['평균 수행 후 SUD']}")
    lines.extend(["", "### 고부담 위치·시간 조합", ""])
    for row in high_burden:
        lines.append(f"- {row['위치']} · {row['시간대']}: 평균 수행 후 SUD {row['평균 수행 후 SUD']}, 일기 {row['일기 수']}건")
    lines.extend(["", "### 고부담 위치·시간·걱정 주제 조합", ""])
    for row in context_topic_rows:
        lines.append(
            f"- {row['위치']} · {row['시간대']} · {row['걱정 주제']}: 평균 수행 후 SUD {row['평균 수행 후 SUD']}, 일기 {row['일기 수']}건"
        )
    if top_context:
        lines.append(
            f"- 최상위 고부담 조합은 {top_context.get('위치')} · {top_context.get('시간대')} · {top_context.get('걱정 주제')}이다."
        )
    lines.extend(["", "## 7. 걱정 주제 인사이트", ""])
    for row in topic_rows:
        lines.append(f"- {row['걱정 주제']}: 일기 {row['일기 수']}건, 평균 수행 후 SUD {row['평균 수행 후 SUD']}")
    lines.extend(["", "## 8. 악화 기록과 부담 관리", ""])
    lines.append(f"- 전체 SUD 기록 중 수행 후 악화된 기록은 {metrics['sud_worse']:,}건이며, 악화 없음 비율은 {metrics['sud_non_worse_rate']:.1f}%이다.")
    if top_worse_topic:
        lines.append(
            f"- 악화 비율이 가장 높은 주요 걱정 주제는 {top_worse_topic.get('걱정 주제')}이며, 악화 비율은 {top_worse_topic.get('악화 비율')}%이다."
        )
    if top_worse_context:
        lines.append(
            f"- 악화 비율이 높은 맥락은 {top_worse_context.get('위치')} · {top_worse_context.get('시간대')}이며, 악화 비율은 {top_worse_context.get('악화 비율')}%이다."
        )
    for row in worsening_topics:
        lines.append(f"- {row['걱정 주제']}: 악화 비율 {row['악화 비율']}%, SUD 기록 {row['SUD 기록 수']}건")
    lines.extend(["", "## 9. 사용자군별 차이와 운영 유형", ""])
    for row in segment_rows:
        lines.append(
            f"- {row['개선 그룹']}: {row['사용자 수']}명, 평균 일기 {row['평균 일기 수']}건, "
            f"평균 대안적 생각 {row['평균 대안적 생각 수']}건, 평균 SUD 감소 {row['평균 SUD 감소']}점"
        )
    lines.append(f"- 가장 많은 운영 유형은 `{top_archetype[0]}`이며 {top_archetype[1]}명이다.")
    for label, count in archetype_counts.most_common():
        priorities = [row["우선 개입 방향"] for row in table_data["archetype_rows"] if row["사용자 유형"] == label]
        priority = priorities[0] if priorities else ""
        lines.append(f"- {label}: {count}명, 우선 개입 방향: {priority}")
    lines.extend(
        [
            "",
            "## 10. 발표에서 강조할 메시지",
            "",
            "- 평균 변화보다 개선자 비율과 중증도 이동을 먼저 제시하는 것이 설득력이 높다.",
            "- 단순 체류 시간보다 일기, 대안적 생각, 행동 계획 같은 능동 과제가 결과와 더 가까이 연결된다.",
            "- 위치/시간/주제 결합 분석은 `언제, 어디서, 무엇 때문에 부담이 커지는가`를 보여주므로 개인화 알림과 맞춤 과제 추천의 근거로 사용할 수 있다.",
            "- 악화 기록 분석은 수행 후 부담이 커지는 예외 상황을 찾아 안전한 사용 흐름을 설계하는 데 필요하다.",
            "- 초반 1~2주 지표는 단독 예측보다는 완료 후 결과를 기다리지 않고 조기 지원 대상을 찾는 보조 운영 지표로 쓰는 것이 적절하다.",
            "",
            "## 11. 생성된 주요 시각화",
            "",
        ]
    )
    for chart in sorted(chart_dir.glob("*.png")):
        lines.append(f"- `charts/{chart.name}`: {chart_captions.get(chart.name, chart.stem)}")
    (out_dir / "mindrium_final_comprehensive_insights.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    html = [
        "<!doctype html><html><head><meta charset='utf-8'>",
        "<title>Mindrium Final Comprehensive Analysis</title>",
        "<style>body{font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo',sans-serif;margin:0;color:#24323a;background:#f7fafb;} main{max-width:1240px;margin:0 auto;padding:38px;} h1{font-size:34px;margin:0 0 8px;} h2{margin-top:34px;border-left:6px solid #0e6a43;padding-left:12px;} h3{margin-top:22px;color:#0e6a43;} .lead{color:#667680;margin-bottom:22px;} .metric{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:18px 0;} .metric div,.panel,.card{background:#fff;border:1px solid #d8e0e4;border-radius:8px;padding:16px;} .metric b{font-size:24px;display:block;margin-top:4px;color:#0e6a43;} .grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px;} .takeaways{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;} .takeaways div{background:#eef8f2;border:1px solid #d8e8de;border-radius:8px;padding:14px;} img{width:100%;height:auto;border-radius:6px;} li{margin:6px 0;} table{width:100%;border-collapse:collapse;background:#fff;} th,td{border-bottom:1px solid #d8e0e4;padding:8px;text-align:left;font-size:14px;} th{color:#0e6a43;} .caption{color:#667680;font-size:14px;line-height:1.5;} .small{font-size:13px;color:#667680;} @media(max-width:900px){.metric,.grid,.takeaways{grid-template-columns:1fr;}}</style>",
        "</head><body>",
        "<main>",
        "<h1>Mindrium 최종 데이터 통합 분석</h1>",
        "<p class='lead'>8주 완료 사용자 데이터에서 결과 변화, 사용량, 알림, 위치·시간 맥락, 고부담 상황, 사용자 유형까지 연결한 보고용 리포트</p>",
        "<div class='metric'>",
        f"<div><span>사용자</span><b>{metrics['n_users']}명</b></div>",
        f"<div><span>GAD-7 평균 감소</span><b>{metrics['gad_drop_mean']:.2f}점</b></div>",
        f"<div><span>4점 이상 개선</span><b>{pct(metrics['gad_response_4'], metrics['n_users']):.1f}%</b></div>",
        f"<div><span>SUD 악화 없음</span><b>{metrics['sud_non_worse_rate']:.1f}%</b></div>",
        "</div>",
        "<h2>핵심 판단</h2>",
        "<div class='takeaways'>",
        f"<div><b>결과 메시지</b><p>GAD-7 4점 이상 개선자는 {metrics['gad_response_4']}명이며, 높은 불안군 {metrics['high_pre_count']}명 중 {metrics['high_to_mod_count']}명이 중등도 이하로 이동했다.</p></div>",
        f"<div><b>운영 메시지</b><p>초반 지표 중 {metrics['early_best_label']}의 사용자군 차이가 가장 커서 조기 지원 지표 후보로 볼 수 있다.</p></div>",
        f"<div><b>개인화 메시지</b><p>위치·시간·주제 조합을 보면 고부담 상황을 찾아 알림과 과제 추천을 세분화할 수 있다.</p></div>",
        "</div>",
        "<h2>인사이트 요약</h2>",
        "<div class='panel'><ul>",
    ]
    for line in lines:
        if line.startswith("- "):
            html.append(f"<li>{line[2:]}</li>")
    html.extend(["</ul></div>"])

    html.extend(["<h2>핵심 표</h2>", "<div class='grid'>"])
    summary_tables = [
        ("초반 신호", early_rows[:5], ["초반 지표", "GAD-7 감소 Spearman rho", "상위-하위 차이"]),
        ("고부담 상황 조합", context_topic_rows[:6], ["위치", "시간대", "걱정 주제", "일기 수", "평균 수행 후 SUD"]),
        ("SUD 악화 주제", worsening_topics[:6], ["걱정 주제", "SUD 기록 수", "악화 비율", "평균 수행 후 SUD"]),
        ("사용자 유형", [{"사용자 유형": k, "사용자 수": v} for k, v in archetype_counts.most_common()], ["사용자 유형", "사용자 수"]),
    ]
    for title, rows, columns in summary_tables:
        html.append(f"<div class='card'><h3>{title}</h3><table><thead><tr>{''.join(f'<th>{col}</th>' for col in columns)}</tr></thead><tbody>")
        for row in rows:
            html.append("<tr>" + "".join(f"<td>{row.get(col, '')}</td>" for col in columns) + "</tr>")
        html.append("</tbody></table></div>")
    html.append("</div>")

    html.extend(["<h2>핵심 차트</h2><div class='grid'>"])
    for chart in sorted(chart_dir.glob("*.png")):
        caption = chart_captions.get(chart.name, chart.stem)
        html.append(f"<div class='card'><img src='charts/{chart.name}'><p><b>{chart.stem}</b></p><p class='caption'>{caption}</p></div>")
    html.extend(["</div>", "<p class='small'>해석은 관찰 데이터 기반의 사용 패턴으로 제한하며, 인과 효과를 단정하지 않는다.</p>", "</main></body></html>"])
    (out_dir / "mindrium_final_comprehensive_report.html").write_text("\n".join(html), encoding="utf-8")


def validate_outputs(data: dict[str, list[dict]], derived: dict[str, object], out_dir: Path) -> list[str]:
    errors = []
    if len(data["users"]) != 40:
        errors.append("user count is not 40")
    if any(user.get("last_completed_week") != 8 for user in data["users"]):
        errors.append("not all users completed week 8")
    if len(derived["sud_records"]) != 2214:
        errors.append(f"SUD count changed: {len(derived['sud_records'])}")
    if not (out_dir / "mindrium_final_comprehensive_insights.md").exists():
        errors.append("missing insights markdown")
    charts = list((out_dir / "charts").glob("*.png"))
    if len(charts) < 20:
        errors.append(f"chart count too small: {len(charts)}")
    tables = list((out_dir / "tables").glob("*.csv"))
    if len(tables) < 16:
        errors.append(f"table count too small: {len(tables)}")
    for chart in charts:
        if chart.stat().st_size < 5_000:
            errors.append(f"chart looks too small: {chart.name}")
    forbidden = ["synthetic", "clinical", "헬스장", "직장", "임상"]
    for rel in ["mindrium_final_comprehensive_report.html", "mindrium_final_comprehensive_insights.md"]:
        text = (out_dir / rel).read_text(encoding="utf-8")
        for token in forbidden:
            if token in text:
                errors.append(f"forbidden expression remains in {rel}: {token}")
    return errors


def main() -> None:
    setup_font()
    lab_root = find_lab_root()
    data_dir = lab_root / "lab_8week_location_context_backup"
    out_dir = lab_root / "analytics_report" / "final_comprehensive"
    chart_dir = out_dir / "charts"
    table_dir = out_dir / "tables"
    clean_dir(out_dir)
    chart_dir.mkdir(parents=True, exist_ok=True)
    table_dir.mkdir(parents=True, exist_ok=True)

    data = {name: read_json(data_dir / f"{name}.json") for name in COLLECTIONS}
    derived = build_derived(data)
    table_data = build_tables(derived, table_dir)
    metrics = build_key_metrics(derived, table_data)

    plot_gad_outcomes(derived["user_rows"], chart_dir / "01_gad7_outcome_and_response.png")
    plot_gad_transition(derived["user_rows"], chart_dir / "02_gad7_severity_transition.png")
    plot_phq_baseline(derived["user_rows"], chart_dir / "03_phq9_baseline_distribution.png")
    plot_weekly_sud(table_data["weekly_sud"], chart_dir / "04_weekly_sud_trajectory.png")
    plot_sud_delta_safety(table_data["weekly_sud"], chart_dir / "05_sud_delta_and_nonworsening.png")
    plot_adherence_weekly(table_data["weekly_adherence"], chart_dir / "06_weekly_adherence_and_screen_time.png")
    plot_dose_response(derived["user_rows"], chart_dir / "07_dose_response_active_tasks.png")
    plot_mechanism(
        derived["sud_records"],
        derived["user_rows"],
        derived["behavior_counts"],
        derived["eval_total"],
        derived["eval_effective"],
        derived["continue_total"],
        derived["will_continue"],
        chart_dir / "08_mechanism_and_week8_evaluation.png",
    )
    plot_worry_bubble(derived["topic_counts"], derived["topic_sud"], chart_dir / "09_worry_topic_frequency_burden.png")
    plot_location_count_sud(derived["location_summary"], chart_dir / "10_location_count_and_sud.png")
    plot_location_period_heatmap(
        derived["location_period_sud"],
        derived["location_period"],
        derived["location_summary"],
        chart_dir / "11_location_period_sud_heatmap.png",
    )
    plot_hourly_diary_screen(derived["location_hour"], derived["screen_hours"], chart_dir / "12_hourly_diary_and_app_sessions.png")
    plot_user_segments(derived["user_rows"], chart_dir / "13_response_segment_usage_patterns.png")
    plot_user_trajectories(derived["user_rows"], derived["sud_records"], chart_dir / "14_user_sud_trajectories.png")
    plot_early_signal(table_data["early_signal_rows"], derived["user_rows"], chart_dir / "15_early_signal_predictors.png")
    plot_notification_alignment(table_data["notification_alignment_rows"], derived["user_rows"], chart_dir / "16_notification_alignment.png")
    plot_context_topic_burden(table_data["context_topic_rows"], chart_dir / "17_context_topic_burden.png")
    plot_worsening_context(
        table_data["worsening_week_rows"],
        table_data["worsening_topic_rows"],
        table_data["worsening_context_rows"],
        chart_dir / "18_sud_worsening_context.png",
    )
    plot_user_archetypes(table_data["archetype_rows"], chart_dir / "19_user_archetypes.png")
    plot_weekly_ux_burden(table_data["weekly_burden"], chart_dir / "20_weekly_ux_burden.png")

    build_report(derived, table_data, metrics, out_dir, chart_dir)
    errors = validate_outputs(data, derived, out_dir)
    validation = [
        "# 최종 통합 분석 산출물 검증",
        "",
        f"- 사용자 수: {len(data['users'])}",
        f"- 일기 수: {len(data['diaries'])}",
        f"- SUD 기록 수: {len(derived['sud_records'])}",
        f"- 차트 수: {len(list(chart_dir.glob('*.png')))}",
        f"- 표 수: {len(list(table_dir.glob('*.csv')))}",
        f"- 검증 오류 수: {len(errors)}",
    ]
    if errors:
        validation.extend(["", "## 오류", *[f"- {err}" for err in errors]])
    else:
        validation.extend(["", "## 결과", "", "- 최종 데이터 기준 통합 분석 산출물이 정상 생성됐다."])
    (out_dir / "final_comprehensive_validation.md").write_text("\n".join(validation) + "\n", encoding="utf-8")

    print(f"OUT_DIR={out_dir}")
    print(f"CHARTS={len(list(chart_dir.glob('*.png')))}")
    print(f"TABLES={len(list(table_dir.glob('*.csv')))}")
    print(f"VALIDATION_ERRORS={len(errors)}")
    print(f"GAD_DROP={metrics['gad_drop_mean']:.2f}")
    print(f"SUD_NON_WORSE={metrics['sud_non_worse_rate']:.1f}")
    print(f"CORE_LOCATION_RATIO={metrics['core_location_ratio']:.1f}")


if __name__ == "__main__":
    main()
