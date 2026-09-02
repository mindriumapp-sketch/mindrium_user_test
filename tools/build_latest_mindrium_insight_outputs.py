#!/usr/bin/env python3
"""Build updated Mindrium insight report assets from the latest JSON backup."""

from __future__ import annotations

import csv
import json
import math
import statistics
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


LAB_ROOT = Path("/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test")
DATA_DIR = LAB_ROOT / "lab_8week_location_context_backup"
REPORT_DIR = LAB_ROOT / "analytics_report" / "final_comprehensive"
TABLE_DIR = REPORT_DIR / "tables"
CHART_DIR = REPORT_DIR / "charts"
INSIGHT_JSON = REPORT_DIR / "latest_insights.json"
REPORT_HTML = REPORT_DIR / "mindrium_final_comprehensive_report.html"

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

GAD_ORDER = ["거의 없음", "경도", "중등도", "높음"]
PHQ_ORDER = ["거의 없음", "경도", "중등도", "중등도-높음", "높음"]
PERIOD_ORDER = ["심야", "오전", "오후", "저녁", "밤"]
LOCATION_ORDER = ["집", "학교/연구실", "병원", "카페/모임 장소"]


def read_json(name: str) -> list[dict]:
    return json.loads((DATA_DIR / f"{name}.json").read_text(encoding="utf-8"))


def write_csv(path: Path, rows: list[dict], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if fieldnames is None:
        fieldnames = []
        for row in rows:
            for key in row:
                if key not in fieldnames:
                    fieldnames.append(key)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def parse_date(raw) -> datetime | None:
    if isinstance(raw, dict):
        raw = raw.get("$date")
    if not isinstance(raw, str):
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00"))
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


def round_or_none(value, digits: int = 2):
    if value is None:
        return None
    return round(float(value), digits)


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
    return f"P{int(user_id.split('_')[-1]):03d}"


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


def loc_hour(loc: dict | None, fallback: datetime | None) -> int | None:
    if isinstance(loc, dict):
        raw = loc.get("time")
        if isinstance(raw, str) and ":" in raw:
            try:
                return int(raw.split(":", 1)[0]) % 24
            except ValueError:
                pass
    return fallback.hour if fallback else None


def extract_text_values(value) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [str(value.get("label") or "")]
    if isinstance(value, list):
        out = []
        for item in value:
            if isinstance(item, str):
                out.append(item)
            elif isinstance(item, dict):
                out.append(str(item.get("label") or ""))
        return [v for v in out if v]
    return []


def infer_activity(text: str, topic: str) -> str:
    text = f"{text} {topic}"
    mapping = {
        "발표": "발표/평가",
        "평가": "발표/평가",
        "시험": "수업/학업",
        "과제": "수업/학업",
        "수업": "수업/학업",
        "연구": "업무/연구",
        "메신저": "업무/연구",
        "회의": "업무/연구",
        "가족": "가정/대화",
        "병원": "건강/상담",
        "상담": "건강/상담",
        "카페": "대인관계",
        "모임": "대인관계",
        "약속": "대인관계",
        "이완": "이완/정리",
    }
    for key, label in mapping.items():
        if key in text:
            return label
    return "일상 기록"


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


def survey_rows(users: list[dict]) -> dict[str, dict]:
    rows = {}
    for user in users:
        row = {
            "user_id": user["user_id"],
            "participant": participant_label(user["user_id"]),
            "created_at": parse_date(user.get("created_at")),
            "last_completed_at": parse_date(user.get("last_completed_at")),
            "last_completed_week": user.get("last_completed_week"),
            "gad_pre": None,
            "gad_post": None,
            "phq_pre": None,
        }
        for survey in user.get("surveys", []):
            answers = survey.get("answers") or {}
            if survey.get("type") == "before_survey":
                row["gad_pre"] = answers.get("gad7_score")
                row["phq_pre"] = answers.get("phq9_score")
            elif survey.get("type") == "after_survey":
                row["gad_post"] = answers.get("gad7_score")
        row["gad_drop"] = row["gad_pre"] - row["gad_post"]
        row["gad_pre_severity"] = severity_gad(row["gad_pre"])
        row["gad_post_severity"] = severity_gad(row["gad_post"])
        row["phq_pre_severity"] = severity_phq(row["phq_pre"])
        if row["created_at"] and row["last_completed_at"]:
            row["completion_days"] = (row["last_completed_at"] - row["created_at"]).total_seconds() / 86400
        else:
            row["completion_days"] = None
        rows[row["user_id"]] = row
    return rows


def circular_hour_distance(a: int, b: int) -> int:
    diff = abs((int(a) % 24) - (int(b) % 24))
    return min(diff, 24 - diff)


def build_analysis() -> dict:
    data = {name: read_json(name) for name in COLLECTIONS}
    users = data["users"]
    progress = data["treatment_progress"]
    diaries = data["diaries"]
    groups = data["worry_groups"]
    screen_time = data["screen_time"]
    relax = data["relaxation_tasks"]
    edu = data["edu_sessions"]
    notifications = data["notification_settings"]
    custom_tags = data["custom_tags"]
    location_labels = data["location_label"]

    intervals = build_week_intervals(progress)
    surveys = survey_rows(users)
    group_lookup = {(g.get("user_id"), g.get("group_id")): g for g in groups}

    sud_records = []
    diary_rows = []
    user_diary_counts = Counter()
    user_week_diaries = Counter()
    user_alt_counts = Counter()
    topic_counts = Counter()
    topic_sud = defaultdict(list)
    activity_counts = Counter()
    activity_sud = defaultdict(list)
    location_counts = Counter()
    location_sud = defaultdict(list)
    location_period_counts = Counter()
    location_period_sud = defaultdict(list)
    location_topic_counts = Counter()
    location_topic_sud = defaultdict(list)
    location_missing = 0
    location_auto = 0
    diary_hour_counts = Counter()
    period_counts = Counter()
    active_diary_days: dict[str, set[str]] = defaultdict(set)

    for diary in diaries:
        user_id = diary["user_id"]
        created = parse_date(diary.get("created_at"))
        week = assign_week(user_id, created, intervals)
        topic = group_lookup.get((user_id, diary.get("group_id")), {}).get("group_title") or "기본 그룹"
        text = " ".join(
            value
            for key in ["activation", "belief", "consequence_action", "consequence_physical", "consequence_emotion", "alternative_thoughts"]
            for value in extract_text_values(diary.get(key))
        )
        activity = infer_activity(text, topic)
        alt_count = len(diary.get("alternative_thoughts") or [])
        loc = diary.get("loc_time")
        loc_name = loc.get("location") if isinstance(loc, dict) else None
        hour = loc_hour(loc, created)
        period = period_for_hour(hour)
        if created:
            active_diary_days[user_id].add(created.date().isoformat())
        user_diary_counts[user_id] += 1
        if week:
            user_week_diaries[(user_id, week)] += 1
        user_alt_counts[user_id] += alt_count
        topic_counts[topic] += 1
        activity_counts[activity] += 1
        if hour is not None:
            diary_hour_counts[hour] += 1
            period_counts[period] += 1
        if loc_name:
            location_counts[loc_name] += 1
            location_period_counts[(loc_name, period)] += 1
            location_topic_counts[(loc_name, period, topic)] += 1
            if diary.get("loc_auto_filled") is True:
                location_auto += 1
        else:
            location_missing += 1

        after_values = []
        for score in diary.get("sud_scores") or []:
            before = score.get("before_sud")
            after = score.get("after_sud")
            if before is None or after is None:
                continue
            before = float(before)
            after = float(after)
            record = {
                "user_id": user_id,
                "week": week,
                "before": before,
                "after": after,
                "delta": before - after,
                "worse": after > before,
                "location": loc_name or "위치 없음",
                "period": period,
                "topic": topic,
                "activity": activity,
            }
            sud_records.append(record)
            after_values.append(after)
            topic_sud[topic].append(after)
            activity_sud[activity].append(after)
            if loc_name:
                location_sud[loc_name].append(after)
                location_period_sud[(loc_name, period)].append(after)
                location_topic_sud[(loc_name, period, topic)].append(after)
        diary_rows.append(
            {
                "user_id": user_id,
                "participant": participant_label(user_id),
                "week": week,
                "topic": topic,
                "activity": activity,
                "location": loc_name,
                "period": period if loc_name else None,
                "hour": hour if loc_name else None,
                "alternative_thought_count": alt_count,
                "after_sud_mean": mean(after_values),
            }
        )

    user_relax_counts = Counter()
    user_week_relax = Counter()
    user_relax_minutes = Counter()
    weekly_relax = Counter()
    for item in relax:
        user_id = item["user_id"]
        week = int(item.get("week_number") or 0)
        minutes = (item.get("duration_seconds") or 0) / 60
        user_relax_counts[user_id] += 1
        user_relax_minutes[user_id] += minutes
        if item.get("task_id") == "daily_review" and week:
            user_week_relax[(user_id, week)] += 1
            weekly_relax[week] += 1

    user_screen_minutes = Counter()
    user_screen_sessions = Counter()
    user_week_screen_minutes = Counter()
    user_week_screen_sessions = Counter()
    user_active_days: dict[str, set[str]] = defaultdict(set)
    user_week_active_days: dict[tuple[str, int], set[str]] = defaultdict(set)
    screen_hours = Counter()
    session_minutes = []
    session_rows = []
    for item in screen_time:
        user_id = item["user_id"]
        start = parse_date(item.get("start_time"))
        end = parse_date(item.get("end_time"))
        week = assign_week(user_id, start, intervals)
        if start and end:
            minutes = max(0, (end - start).total_seconds() / 60)
        else:
            minutes = (item.get("duration_seconds") or 0) / 60
        user_screen_minutes[user_id] += minutes
        user_screen_sessions[user_id] += 1
        session_minutes.append(minutes)
        if start:
            screen_hours[start.hour] += 1
            user_active_days[user_id].add(start.date().isoformat())
            if week:
                user_week_active_days[(user_id, week)].add(start.date().isoformat())
            session_rows.append({"user_id": user_id, "week": week, "hour": start.hour, "minutes": minutes})
        if week:
            user_week_screen_minutes[(user_id, week)] += minutes
            user_week_screen_sessions[(user_id, week)] += 1

    weekly_edu_minutes = Counter()
    user_edu_minutes = Counter()
    behavior_counts = Counter()
    behavior_by_user = defaultdict(Counter)
    eval_total = eval_effective = continue_total = will_continue = 0
    for session in edu:
        user_id = session.get("user_id")
        week = int(session.get("week_number") or 0)
        start = parse_date(session.get("start_time"))
        end = parse_date(session.get("end_time"))
        if start and end:
            minutes = max(0, (end - start).total_seconds() / 60)
            weekly_edu_minutes[week] += minutes
            user_edu_minutes[user_id] += minutes
        if week == 7:
            for item in session.get("behavior_items") or []:
                label = item.get("category") or item.get("behavior_type") or item.get("type")
                if label:
                    behavior_counts[label] += 1
                    behavior_by_user[user_id][label] += 1
        if week == 8:
            for item in session.get("effectiveness_evaluations") or []:
                eval_total += 1
                if item.get("was_effective") is True or item.get("effective") is True:
                    eval_effective += 1
                if "will_continue" in item:
                    continue_total += 1
                    if item.get("will_continue") is True:
                        will_continue += 1

    notification_by_user = Counter(item.get("user_id") for item in notifications)
    notification_rows = []
    alarms_by_user = defaultdict(list)
    for item in notifications:
        schedule = item.get("schedule") if isinstance(item.get("schedule"), dict) else {}
        hour = schedule.get("hour")
        user_id = item.get("user_id")
        if user_id and isinstance(hour, int):
            alarm = {
                "user_id": user_id,
                "hour": hour % 24,
                "has_location": isinstance(item.get("location"), dict),
            }
            notification_rows.append(alarm)
            alarms_by_user[user_id].append(alarm)

    notification_alignment = []
    sessions_by_user = defaultdict(list)
    for row in session_rows:
        sessions_by_user[row["user_id"]].append(row)
    for user_id in sorted(surveys):
        sessions = sessions_by_user.get(user_id, [])
        alarms = alarms_by_user.get(user_id, [])
        near2 = 0
        for session in sessions:
            if not alarms:
                continue
            if min(circular_hour_distance(session["hour"], alarm["hour"]) for alarm in alarms) <= 2:
                near2 += 1
        notification_alignment.append(
            {
                "user_id": user_id,
                "participant": participant_label(user_id),
                "알림 수": len(alarms),
                "앱 세션 수": len(sessions),
                "알림 2시간 내 세션 수": near2,
                "알림 2시간 내 세션 비율": round(pct(near2, len(sessions)), 1),
            }
        )

    tag_logs = defaultdict(lambda: {"real_oddness": 0, "category": 0})
    for tag in custom_tags:
        user_id = tag.get("user_id")
        if not user_id:
            continue
        tag_logs[user_id]["real_oddness"] += len(tag.get("real_oddness_logs") or [])
        tag_logs[user_id]["category"] += len(tag.get("category_logs") or [])

    user_week_after = defaultdict(list)
    user_week_delta = defaultdict(list)
    for record in sud_records:
        if record["week"]:
            user_week_after[(record["user_id"], record["week"])].append(record["after"])
            user_week_delta[(record["user_id"], record["week"])].append(record["delta"])

    label_counts_by_user = Counter(item.get("user_id") for item in location_labels)
    user_rows = []
    for user_id, row in surveys.items():
        after_by_week = []
        weeks = []
        for week in range(3, 9):
            vals = user_week_after.get((user_id, week), [])
            if vals:
                weeks.append(week)
                after_by_week.append(mean(vals))
        sud_drop = after_by_week[0] - after_by_week[-1] if len(after_by_week) >= 2 else None
        user_sud = [r for r in sud_records if r["user_id"] == user_id]
        user_after = [r["after"] for r in user_sud]
        user_delta = [r["delta"] for r in user_sud]
        user_worse = sum(1 for r in user_sud if r["worse"])
        early_active = len(set().union(*(user_week_active_days.get((user_id, week), set()) for week in [1, 2])))
        all_active = len(user_active_days[user_id])
        screen_minutes = user_screen_minutes[user_id]
        active_task_count = user_diary_counts[user_id] + user_alt_counts[user_id]
        segment = "4점 이상 개선" if row["gad_drop"] >= 4 else "3점 이상 개선" if row["gad_drop"] >= 3 else "3점 미만 개선"
        row = {
            **row,
            "diary_count": user_diary_counts[user_id],
            "relax_count": user_relax_counts[user_id],
            "relax_minutes": user_relax_minutes[user_id],
            "screen_minutes": screen_minutes,
            "screen_session_count": user_screen_sessions[user_id],
            "session_median": median([s["minutes"] for s in sessions_by_user[user_id]]),
            "active_days": all_active,
            "early_active_days": early_active,
            "early_diary_count": sum(user_week_diaries[(user_id, week)] for week in [1, 2]),
            "early_screen_sessions": sum(user_week_screen_sessions[(user_id, week)] for week in [1, 2]),
            "education_minutes": user_edu_minutes[user_id],
            "alternative_thought_count": user_alt_counts[user_id],
            "active_task_count": active_task_count,
            "sud_drop_week3_to_week8": sud_drop,
            "sud_record_count": len(user_sud),
            "sud_worse_rate": user_worse / len(user_sud) if user_sud else None,
            "after_sud_mean": mean(user_after),
            "after_sud_sd": stdev(user_after),
            "immediate_sud_delta_mean": mean(user_delta),
            "location_label_count": label_counts_by_user[user_id],
            "notification_count": notification_by_user[user_id],
            "notification_near2_rate": next((r["알림 2시간 내 세션 비율"] for r in notification_alignment if r["user_id"] == user_id), 0),
            "confront_behavior_count": behavior_by_user[user_id].get("confront", 0),
            "avoid_behavior_count": behavior_by_user[user_id].get("avoid", 0),
            "real_oddness_logs": tag_logs[user_id]["real_oddness"],
            "category_logs": tag_logs[user_id]["category"],
            "response_segment": segment,
        }
        row["task_efficiency"] = row["gad_drop"] / (active_task_count / 10) if active_task_count else None
        row["screen_efficiency"] = row["gad_drop"] / (screen_minutes / 100) if screen_minutes else None
        user_rows.append(row)

    weekly_rows = []
    for week in range(1, 9):
        weekly_diary = sum(user_week_diaries[(user_id, week)] for user_id in surveys)
        weekly_screen = sum(user_week_screen_minutes[(user_id, week)] for user_id in surveys)
        weekly_sessions = sum(user_week_screen_sessions[(user_id, week)] for user_id in surveys)
        active_users = sum(1 for user_id in surveys if user_week_diaries[(user_id, week)] or user_week_screen_sessions[(user_id, week)])
        weekly_rows.append(
            {
                "주차": week,
                "활성 사용자 수": active_users,
                "일기 수": weekly_diary,
                "이완 수": weekly_relax[week],
                "앱 세션 수": weekly_sessions,
                "평균 사용 시간": round(weekly_screen / len(surveys), 1),
                "평균 교육 시간": round(weekly_edu_minutes[week] / len(surveys), 1),
                "평균 과제 수": round((weekly_diary + weekly_relax[week]) / len(surveys), 1),
            }
        )

    weekly_sud = []
    for week in range(3, 9):
        records = [r for r in sud_records if r["week"] == week]
        worse = sum(1 for r in records if r["worse"])
        weekly_sud.append(
            {
                "주차": week,
                "기록 수": len(records),
                "수행 전 SUD": round(mean([r["before"] for r in records]) or 0, 2),
                "수행 후 SUD": round(mean([r["after"] for r in records]) or 0, 2),
                "즉시 감소": round(mean([r["delta"] for r in records]) or 0, 2),
                "악화 없음 비율": round(pct(len(records) - worse, len(records)), 1),
            }
        )

    location_summary = []
    for loc in LOCATION_ORDER:
        count = location_counts[loc]
        location_summary.append(
            {
                "위치": loc,
                "일기 수": count,
                "기록 비율": round(pct(count, sum(location_counts.values())), 1),
                "평균 수행 후 SUD": round(mean(location_sud[loc]) or 0, 2),
            }
        )

    high_contexts = []
    for key, values in location_topic_sud.items():
        loc, period, topic = key
        count = location_topic_counts[key]
        if count < 10:
            continue
        high_contexts.append(
            {
                "위치": loc,
                "시간대": period,
                "걱정 주제": topic,
                "일기 수": count,
                "평균 수행 후 SUD": round(mean(values) or 0, 2),
            }
        )
    high_contexts.sort(key=lambda r: (r["평균 수행 후 SUD"], r["일기 수"]), reverse=True)

    worsening_by_context = []
    context_records = defaultdict(list)
    topic_records = defaultdict(list)
    for record in sud_records:
        if record["location"] != "위치 없음":
            context_records[(record["location"], record["period"])].append(record)
        topic_records[record["topic"]].append(record)
    for (loc, period), records in context_records.items():
        if len(records) < 20:
            continue
        worsening_by_context.append(
            {
                "위치": loc,
                "시간대": period,
                "SUD 기록 수": len(records),
                "악화 기록 수": sum(r["worse"] for r in records),
                "악화 비율": round(pct(sum(r["worse"] for r in records), len(records)), 1),
                "평균 수행 후 SUD": round(mean([r["after"] for r in records]) or 0, 2),
            }
        )
    worsening_by_context.sort(key=lambda r: (r["악화 비율"], r["평균 수행 후 SUD"]), reverse=True)

    topic_summary = []
    for topic, count in topic_counts.most_common():
        topic_summary.append(
            {
                "걱정 주제": topic,
                "일기 수": count,
                "평균 수행 후 SUD": round(mean(topic_sud[topic]) or 0, 2),
                "악화 비율": round(pct(sum(r["worse"] for r in topic_records[topic]), len(topic_records[topic])), 1) if topic_records[topic] else 0,
            }
        )

    activity_summary = []
    for activity, count in activity_counts.most_common():
        activity_summary.append(
            {
                "활동 유형": activity,
                "일기 수": count,
                "평균 수행 후 SUD": round(mean(activity_sud[activity]) or 0, 2),
            }
        )

    segment_rows = []
    for segment in ["4점 이상 개선", "3점 이상 개선", "3점 미만 개선"]:
        rows = [r for r in user_rows if r["response_segment"] == segment]
        segment_rows.append(
            {
                "개선 그룹": segment,
                "사용자 수": len(rows),
                "평균 GAD-7 감소": round(mean([r["gad_drop"] for r in rows]) or 0, 2),
                "평균 SUD 감소": round(mean([r["sud_drop_week3_to_week8"] for r in rows]) or 0, 2),
                "평균 일기 수": round(mean([r["diary_count"] for r in rows]) or 0, 1),
                "평균 대안적 생각 수": round(mean([r["alternative_thought_count"] for r in rows]) or 0, 1),
                "평균 앱 사용 시간": round(mean([r["screen_minutes"] for r in rows]) or 0, 1),
                "평균 악화 비율": round(mean([(r["sud_worse_rate"] or 0) * 100 for r in rows]) or 0, 1),
            }
        )

    dose_pairs = [
        ("일기 작성량", "diary_count", "gad_drop", "GAD-7 감소"),
        ("일기 작성량", "diary_count", "sud_drop_week3_to_week8", "SUD 감소"),
        ("대안적 생각 수", "alternative_thought_count", "sud_drop_week3_to_week8", "SUD 감소"),
        ("능동 과제 수", "active_task_count", "gad_drop", "GAD-7 감소"),
        ("앱 사용 시간", "screen_minutes", "gad_drop", "GAD-7 감소"),
        ("이완 수행 수", "relax_count", "sud_drop_week3_to_week8", "SUD 감소"),
        ("알림 근접 세션", "notification_near2_rate", "gad_drop", "GAD-7 감소"),
        ("초반 일기 수", "early_diary_count", "gad_drop", "GAD-7 감소"),
    ]
    dose_rows = []
    for label, metric, outcome, outcome_label in dose_pairs:
        rows = [r for r in user_rows if r.get(metric) is not None and r.get(outcome) is not None]
        rows.sort(key=lambda r: r[metric])
        low = rows[:10]
        high = rows[-10:]
        low_mean = mean([r[outcome] for r in low]) or 0
        high_mean = mean([r[outcome] for r in high]) or 0
        xs = [r[metric] for r in rows]
        ys = [r[outcome] for r in rows]
        dose_rows.append(
            {
                "사용 지표": label,
                "결과 지표": outcome_label,
                "하위 10명 평균": round(low_mean, 2),
                "상위 10명 평균": round(high_mean, 2),
                "상위-하위 차이": round(high_mean - low_mean, 2),
                "Pearson r": round(pearson(xs, ys) or 0, 2),
                "Spearman rho": round(spearman(xs, ys) or 0, 2),
            }
        )

    archetype_rows = []
    active_scores = [r["active_task_count"] for r in user_rows]
    active_med = median(active_scores) or 0
    screen_med = median([r["screen_minutes"] for r in user_rows]) or 0
    worse_cut = percentile([(r["sud_worse_rate"] or 0) for r in user_rows], 0.75) or 0
    sd_cut = percentile([r["after_sud_sd"] for r in user_rows if r["after_sud_sd"] is not None], 0.75) or 0
    for r in user_rows:
        if r["gad_drop"] >= 4 and r["active_task_count"] >= active_med:
            archetype = "능동 과제 고반응형"
            action = "일기와 대안적 생각 루틴을 유지하고 고급 과제를 추천"
        elif r["gad_drop"] >= 4:
            archetype = "저강도 안정 개선형"
            action = "짧은 반복 과제와 유지 계획 중심으로 지원"
        elif r["active_task_count"] >= active_med and r["gad_drop"] < 3:
            archetype = "수행량 대비 정체형"
            action = "일기 품질과 대안적 생각 구체성을 점검"
        elif (r["sud_worse_rate"] or 0) >= worse_cut or (r["after_sud_sd"] or 0) >= sd_cut:
            archetype = "SUD 변동성 관리형"
            action = "고부담 상황 탐지와 즉시 안정화 과제를 우선"
        elif r["screen_minutes"] >= screen_med:
            archetype = "체류시간 중심 완료형"
            action = "체류시간을 능동 입력으로 전환하도록 유도"
        else:
            archetype = "기본 완료형"
            action = "완료 루틴 유지와 알림 시간을 조정"
        archetype_rows.append(
            {
                "participant": r["participant"],
                "사용자 유형": archetype,
                "우선 운영 방향": action,
                "GAD-7 감소": r["gad_drop"],
                "SUD 감소": round(r["sud_drop_week3_to_week8"] or 0, 2),
                "일기 수": r["diary_count"],
                "대안적 생각 수": r["alternative_thought_count"],
                "악화 비율": round((r["sud_worse_rate"] or 0) * 100, 1),
            }
        )

    start_counts = Counter(r["gad_pre_severity"] for r in user_rows)
    post_counts = Counter(r["gad_post_severity"] for r in user_rows)
    transition_matrix = []
    for pre in GAD_ORDER:
        for post in GAD_ORDER:
            count = sum(1 for r in user_rows if r["gad_pre_severity"] == pre and r["gad_post_severity"] == post)
            if count:
                transition_matrix.append({"시작": pre, "8주 후": post, "사용자 수": count})

    pre34 = [r["delta"] for r in sud_records if r["week"] in {3, 4}]
    post58 = [r["delta"] for r in sud_records if r["week"] in {5, 6, 7, 8}]
    gad_drops = [r["gad_drop"] for r in user_rows]
    high_pre = [r for r in user_rows if r["gad_pre"] >= 15]
    high_to_mod = [r for r in high_pre if r["gad_post"] <= 14]
    total_sud = len(sud_records)
    worse_sud = sum(1 for r in sud_records if r["worse"])
    located = sum(location_counts.values())
    missing = location_missing
    session_peak_hours = [f"{hour}시" for hour, _ in screen_hours.most_common(4)]
    diary_peak_hours = [f"{hour}시" for hour, _ in diary_hour_counts.most_common(4)]
    top_context = high_contexts[0] if high_contexts else {}
    top_worse_context = worsening_by_context[0] if worsening_by_context else {}
    peak_usage_week = max(weekly_rows, key=lambda r: r["평균 사용 시간"])
    peak_edu_week = max(weekly_rows, key=lambda r: r["평균 교육 시간"])

    summary = {
        "user_count": len(user_rows),
        "completed_week8": sum(r["last_completed_week"] == 8 for r in user_rows),
        "gad_pre_mean": round(mean([r["gad_pre"] for r in user_rows]) or 0, 2),
        "gad_post_mean": round(mean([r["gad_post"] for r in user_rows]) or 0, 2),
        "gad_drop_mean": round(mean(gad_drops) or 0, 2),
        "gad_drop_median": round(median(gad_drops) or 0, 2),
        "gad_drop_sd": round(stdev(gad_drops) or 0, 2),
        "gad_response_4": sum(r["gad_drop"] >= 4 for r in user_rows),
        "gad_response_3": sum(r["gad_drop"] >= 3 for r in user_rows),
        "high_pre_count": len(high_pre),
        "high_to_mod_count": len(high_to_mod),
        "phq_pre_mean": round(mean([r["phq_pre"] for r in user_rows]) or 0, 2),
        "phq_counts": dict(Counter(r["phq_pre_severity"] for r in user_rows)),
        "sud_total": total_sud,
        "sud_worse": worse_sud,
        "sud_non_worse_rate": round(pct(total_sud - worse_sud, total_sud), 1),
        "week3_after": weekly_sud[0]["수행 후 SUD"],
        "week8_after": weekly_sud[-1]["수행 후 SUD"],
        "week3_to_8_after_drop": round(weekly_sud[0]["수행 후 SUD"] - weekly_sud[-1]["수행 후 SUD"], 2),
        "module_pre34_delta": round(mean(pre34) or 0, 2),
        "module_post58_delta": round(mean(post58) or 0, 2),
        "module_lift": round((mean(post58) or 0) - (mean(pre34) or 0), 2),
        "total_diaries": len(diaries),
        "total_alt_thoughts": sum(user_alt_counts.values()),
        "alt_per_user": round(mean([r["alternative_thought_count"] for r in user_rows]) or 0, 1),
        "screen_session_count": len(session_minutes),
        "screen_session_median": round(median(session_minutes) or 0, 1),
        "screen_session_mean": round(mean(session_minutes) or 0, 1),
        "active_days_mean": round(mean([r["active_days"] for r in user_rows]) or 0, 1),
        "completion_days_mean": round(mean([r["completion_days"] for r in user_rows]) or 0, 1),
        "completion_days_median": round(median([r["completion_days"] for r in user_rows]) or 0, 1),
        "located_diaries": located,
        "missing_location_diaries": missing,
        "location_coverage_rate": round(pct(located, len(diaries)), 1),
        "location_missing_rate": round(pct(missing, len(diaries)), 1),
        "location_auto_rate": round(pct(location_auto, len(diaries)), 1),
        "peak_session_hours": session_peak_hours,
        "peak_diary_hours": diary_peak_hours,
        "notification_user_count": sum(1 for r in user_rows if r["notification_count"] > 0),
        "notification_location_count": sum(1 for n in notifications if isinstance(n.get("location"), dict)),
        "notification_2h_rate_mean": round(mean([r["알림 2시간 내 세션 비율"] for r in notification_alignment]) or 0, 1),
        "behavior_confront": behavior_counts.get("confront", 0),
        "behavior_avoid": behavior_counts.get("avoid", 0),
        "effectiveness_rate": round(pct(eval_effective, eval_total), 1),
        "continue_rate": round(pct(will_continue, continue_total), 1),
        "peak_usage_week": peak_usage_week["주차"],
        "peak_usage_minutes": peak_usage_week["평균 사용 시간"],
        "peak_edu_week": peak_edu_week["주차"],
        "peak_edu_minutes": peak_edu_week["평균 교육 시간"],
        "top_context": top_context,
        "top_worse_context": top_worse_context,
    }

    narratives = [
        {
            "title": "평균보다 개선자 비율이 더 강한 결과 메시지다",
            "evidence": f"GAD-7 4점 이상 개선 {summary['gad_response_4']}/{summary['user_count']}명, 3점 이상 개선 {summary['gad_response_3']}/{summary['user_count']}명",
            "meaning": "완료 사용자 전체 평균 감소만 제시하는 것보다 실제로 의미 있는 변화가 있었던 사용자 비율을 보여주는 편이 설득력이 높다.",
        },
        {
            "title": "능동 과제는 체류시간보다 결과와 더 가까운 신호다",
            "evidence": f"일기 상위 10명의 SUD 감소는 하위 10명보다 {next(r for r in dose_rows if r['사용 지표']=='일기 작성량' and r['결과 지표']=='SUD 감소')['상위-하위 차이']}점 높다",
            "meaning": "앱을 오래 켜두는 것보다 일기와 대안적 생각처럼 사용자가 직접 입력하는 과제가 핵심 운영 지표가 된다.",
        },
        {
            "title": "5주차 이후에는 수행 직후 안정화 폭이 커진다",
            "evidence": f"3~4주차 즉시 SUD 감소 {summary['module_pre34_delta']}점, 5~8주차 {summary['module_post58_delta']}점",
            "meaning": "대안적 생각과 행동 계획이 열린 뒤 불안을 구조화해 낮추는 사용 패턴이 강화된다.",
        },
        {
            "title": "고부담 순간은 장소와 시간, 걱정 주제를 함께 봐야 보인다",
            "evidence": f"상위 조합: {top_context.get('위치')} · {top_context.get('시간대')} · {top_context.get('걱정 주제')} / 평균 SUD {top_context.get('평균 수행 후 SUD')}",
            "meaning": "단순 위치 빈도보다 맥락 조합이 맞춤 알림과 과제 추천에 더 직접적인 기준을 제공한다.",
        },
        {
            "title": "대부분의 수행은 악화 없이 종료되지만 예외 관리가 필요하다",
            "evidence": f"SUD 악화 없음 {summary['sud_non_worse_rate']}%, 악화 기록 {summary['sud_worse']:,}건",
            "meaning": "전체 흐름은 안정적이지만 특정 시간대와 걱정 주제에서 악화되는 기록을 별도 관리해야 한다.",
        },
        {
            "title": "초반 부담은 운영 설계의 병목이다",
            "evidence": f"사용 시간은 {summary['peak_usage_week']}주차 {summary['peak_usage_minutes']}분, 교육 시간은 {summary['peak_edu_week']}주차 {summary['peak_edu_minutes']}분이 최고",
            "meaning": "초반 교육과 적응 비용을 낮추면 완료까지의 루틴 형성 가능성이 커진다.",
        },
    ]

    return {
        "summary": summary,
        "narratives": narratives,
        "user_rows": user_rows,
        "weekly_rows": weekly_rows,
        "weekly_sud": weekly_sud,
        "location_summary": location_summary,
        "high_contexts": high_contexts,
        "worsening_by_context": worsening_by_context,
        "topic_summary": topic_summary,
        "activity_summary": activity_summary,
        "segment_rows": segment_rows,
        "dose_rows": dose_rows,
        "archetype_rows": archetype_rows,
        "notification_alignment": notification_alignment,
        "transition_matrix": transition_matrix,
        "archetype_counts": Counter(r["사용자 유형"] for r in archetype_rows),
        "start_counts": start_counts,
        "post_counts": post_counts,
    }


def table_html(rows: list[dict], columns: list[str], max_rows: int = 8) -> str:
    body = []
    for row in rows[:max_rows]:
        body.append("<tr>" + "".join(f"<td>{row.get(col, '')}</td>" for col in columns) + "</tr>")
    return "<table><thead><tr>" + "".join(f"<th>{col}</th>" for col in columns) + "</tr></thead><tbody>" + "".join(body) + "</tbody></table>"


def metric_card(label: str, value: str, note: str = "") -> str:
    return f"<div class='metric'><span>{label}</span><b>{value}</b><em>{note}</em></div>"


def bar_list(rows: list[dict], label_key: str, value_key: str, max_rows: int = 6) -> str:
    values = [float(r[value_key]) for r in rows[:max_rows]]
    max_value = max(values) if values else 1
    parts = []
    for row in rows[:max_rows]:
        value = float(row[value_key])
        width = pct(value, max_value)
        parts.append(
            f"<div class='bar-row'><span>{row[label_key]}</span><div><i style='width:{width:.1f}%'></i></div><b>{value:g}</b></div>"
        )
    return "<div class='bar-list'>" + "".join(parts) + "</div>"


def write_outputs(analysis: dict) -> None:
    TABLE_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    write_csv(TABLE_DIR / "latest_insight_narratives.csv", analysis["narratives"], ["title", "evidence", "meaning"])
    write_csv(TABLE_DIR / "latest_segment_action_summary.csv", analysis["segment_rows"])
    write_csv(TABLE_DIR / "latest_context_priority_summary.csv", analysis["high_contexts"][:12])
    write_csv(TABLE_DIR / "latest_activity_summary.csv", analysis["activity_summary"])
    write_csv(TABLE_DIR / "latest_dose_response_expanded.csv", analysis["dose_rows"])
    write_csv(TABLE_DIR / "latest_notification_alignment.csv", analysis["notification_alignment"])
    write_csv(TABLE_DIR / "latest_archetype_summary.csv", analysis["archetype_rows"])

    export = dict(analysis)
    export["archetype_counts"] = dict(analysis["archetype_counts"])
    export["start_counts"] = dict(analysis["start_counts"])
    export["post_counts"] = dict(analysis["post_counts"])
    INSIGHT_JSON.write_text(json.dumps(export, ensure_ascii=False, indent=2, default=str) + "\n", encoding="utf-8")

    s = analysis["summary"]
    n = analysis["narratives"]
    dose = analysis["dose_rows"]
    segments = analysis["segment_rows"]
    contexts = analysis["high_contexts"]
    worsening = analysis["worsening_by_context"]
    topics = analysis["topic_summary"]
    locations = analysis["location_summary"]
    weekly = analysis["weekly_rows"]
    weekly_sud = analysis["weekly_sud"]
    archetypes = analysis["archetype_counts"]

    chart_cards = [
        ("01_gad7_outcome_and_response.png", "GAD-7 결과 변화", "평균 감소와 개선자 비율을 함께 보면 결과 메시지가 더 명확해진다."),
        ("02_gad7_severity_transition.png", "GAD-7 구간 이동", "높은 불안 구간에서 낮은 위험 구간으로 이동한 사용자를 확인한다."),
        ("04_weekly_sud_trajectory.png", "주차별 SUD 변화", "3주차 이후 수행 전후 SUD가 동시에 낮아지는 흐름을 보여준다."),
        ("07_dose_response_active_tasks.png", "능동 과제와 결과", "일기와 대안적 생각이 결과 변화와 더 가까운 사용 지표로 보인다."),
        ("10_location_count_and_sud.png", "위치별 기록량과 부담", "많이 기록된 장소와 부담이 큰 장소를 분리해서 해석한다."),
        ("11_location_period_sud_heatmap.png", "위치와 시간대", "같은 장소라도 시간대에 따라 부담 수준이 달라진다."),
        ("17_context_topic_burden.png", "고부담 맥락 조합", "위치, 시간대, 걱정 주제를 결합해 맞춤 지원 후보를 찾는다."),
        ("18_sud_worsening_context.png", "악화 기록 분포", "악화 기록이 몰리는 주차, 주제, 맥락을 별도 관리 대상으로 본다."),
        ("19_user_archetypes.png", "사용자 유형", "동일한 8주 완료자 안에서도 운영 전략이 다른 사용자군이 존재한다."),
        ("20_weekly_ux_burden.png", "주차별 부담", "초반 교육과 앱 사용 부담이 루틴 설계의 주요 병목이다."),
    ]

    html = [
        "<!doctype html><html lang='ko'><head><meta charset='utf-8'>",
        "<title>Mindrium 8주 데이터 인사이트 리포트</title>",
        "<style>",
        ":root{--ink:#24323a;--muted:#667680;--green:#0e6a43;--teal:#2f9b91;--blue:#376f95;--coral:#e86f56;--gold:#e6a93f;--bg:#f6faf9;--line:#d8e0e4;--soft:#eef6f2;}",
        "body{margin:0;background:var(--bg);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Noto Sans KR',sans-serif;line-height:1.55;}main{max-width:1280px;margin:0 auto;padding:42px 36px 72px;}header{background:#18312e;color:white;padding:42px;border-radius:0 0 22px 22px;margin:-42px -36px 34px;}h1{font-size:36px;margin:0 0 10px;}h2{font-size:24px;margin:38px 0 14px;border-left:6px solid var(--green);padding-left:12px;}h3{font-size:18px;margin:0 0 8px;color:var(--green);}p{margin:0 0 10px}.lead{color:#dfecea;max-width:760px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:24px 0}.metric,.card,.insight,.chart-card{background:white;border:1px solid var(--line);border-radius:12px;padding:16px;box-shadow:0 4px 16px rgba(25,49,46,.04)}.metric span{display:block;color:var(--muted);font-size:13px}.metric b{display:block;color:var(--green);font-size:27px;margin-top:4px}.metric em{font-style:normal;color:var(--muted);font-size:12px}.insights{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.insight b{display:block;font-size:16px;margin-bottom:8px}.insight .evidence{color:var(--green);font-weight:700}.insight .meaning{color:var(--muted);font-size:14px}.chart-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}.chart-card img{width:100%;height:auto;border-radius:8px;background:white}.caption{font-size:13px;color:var(--muted)}table{width:100%;border-collapse:collapse;background:white;border-radius:10px;overflow:hidden}th,td{border-bottom:1px solid var(--line);padding:9px;text-align:left;font-size:13px}th{color:var(--green);background:#f1f7f4}.bar-row{display:grid;grid-template-columns:135px 1fr 56px;gap:10px;align-items:center;margin:8px 0}.bar-row div{height:10px;background:#edf2f3;border-radius:999px;overflow:hidden}.bar-row i{display:block;height:100%;background:linear-gradient(90deg,var(--teal),var(--blue));border-radius:999px}.bar-row b{text-align:right}.note{font-size:13px;color:var(--muted)}.pill{display:inline-block;background:#e8f5ef;color:#0e6a43;border-radius:999px;padding:4px 10px;font-size:12px;margin-right:6px}.wide{grid-column:1/-1}@media(max-width:900px){.metrics,.grid,.insights,.chart-grid{grid-template-columns:1fr}}",
        "</style></head><body><main>",
        "<header><h1>Mindrium 8주 데이터 인사이트 리포트</h1>",
        "<p class='lead'>최신 JSON 기준으로 8주 완료 사용자 40명의 결과 변화, 과제 수행, 앱 사용 루틴, 위치·시간 맥락, 알림, 부담 관리 지표를 연결해 해석했다.</p></header>",
        "<section class='metrics'>",
        metric_card("분석 사용자", f"{s['user_count']}명", f"8주 완료 {s['completed_week8']}명"),
        metric_card("GAD-7 평균 감소", f"{s['gad_drop_mean']}점", f"시작 {s['gad_pre_mean']} → 8주 후 {s['gad_post_mean']}"),
        metric_card("4점 이상 개선", f"{s['gad_response_4']}/{s['user_count']}명", f"{pct(s['gad_response_4'], s['user_count']):.1f}%"),
        metric_card("SUD 악화 없음", f"{s['sud_non_worse_rate']}%", f"전체 SUD {s['sud_total']:,}건"),
        metric_card("대안적 생각", f"{s['total_alt_thoughts']:,}개", f"사용자당 평균 {s['alt_per_user']}개"),
        metric_card("세션 중앙값", f"{s['screen_session_median']}분", f"총 세션 {s['screen_session_count']:,}개"),
        metric_card("위치 연결", f"{s['location_coverage_rate']}%", f"미입력 {s['location_missing_rate']}%"),
        metric_card("완료 기간 중앙값", f"{s['completion_days_median']}일", "시작일부터 8주 완료까지"),
        "</section>",
        "<h2>핵심 인사이트</h2><section class='insights'>",
    ]
    for item in n:
        html.append(
            f"<div class='insight'><b>{item['title']}</b><p class='evidence'>{item['evidence']}</p><p class='meaning'>{item['meaning']}</p></div>"
        )
    html.extend(
        [
            "</section>",
            "<h2>결과 변화와 사용자 이동</h2>",
            "<div class='grid'>",
            f"<div class='card'><h3>GAD-7 반응자 관점</h3><p>평균 감소량은 {s['gad_drop_mean']}점이지만, 발표에서는 4점 이상 개선 {s['gad_response_4']}명과 3점 이상 개선 {s['gad_response_3']}명을 함께 보여주는 편이 더 강하다. 시작 시점 높은 불안군 {s['high_pre_count']}명 중 {s['high_to_mod_count']}명은 8주 후 중등도 이하로 이동했다.</p></div>",
            f"<div class='card'><h3>PHQ-9 기저 특성</h3><p>PHQ-9은 사후 측정이 없으므로 변화 분석보다는 시작 시점 사용자 특성으로 해석한다. 시작 평균은 {s['phq_pre_mean']}점이며, 거의 없음/경도 사용자가 다수를 차지한다.</p></div>",
            "</div>",
            "<h2>사용량과 결과의 관계</h2>",
            "<div class='grid'>",
            "<div class='card'><h3>사용 지표별 상위-하위 차이</h3>"
            + table_html(dose, ["사용 지표", "결과 지표", "하위 10명 평균", "상위 10명 평균", "상위-하위 차이", "Spearman rho"], 8)
            + "</div>",
            "<div class='card'><h3>개선 그룹별 사용 패턴</h3>"
            + table_html(segments, ["개선 그룹", "사용자 수", "평균 GAD-7 감소", "평균 SUD 감소", "평균 일기 수", "평균 대안적 생각 수", "평균 악화 비율"], 3)
            + "</div>",
            "</div>",
            "<h2>주차별 작동 패턴</h2>",
            "<div class='grid'>",
            "<div class='card'><h3>주차별 SUD</h3>" + table_html(weekly_sud, ["주차", "기록 수", "수행 전 SUD", "수행 후 SUD", "즉시 감소", "악화 없음 비율"], 6) + "</div>",
            f"<div class='card'><h3>5주차 이후 작동 패턴</h3><p>3~4주차 즉시 SUD 감소는 {s['module_pre34_delta']}점, 5~8주차는 {s['module_post58_delta']}점으로 {s['module_lift']}점 커졌다. 이는 대안적 생각 기능이 열린 뒤 사용자가 불안을 더 구조화해 다루는 패턴으로 해석할 수 있다.</p></div>",
            "</div>",
            "<h2>위치·시간·걱정 주제 맥락</h2>",
            "<div class='grid'>",
            "<div class='card'><h3>위치별 기록량</h3>" + table_html(locations, ["위치", "일기 수", "기록 비율", "평균 수행 후 SUD"], 4) + "</div>",
            "<div class='card'><h3>고부담 맥락 조합</h3>" + table_html(contexts, ["위치", "시간대", "걱정 주제", "일기 수", "평균 수행 후 SUD"], 8) + "</div>",
            "<div class='card'><h3>걱정 주제별 부담</h3>" + table_html(topics, ["걱정 주제", "일기 수", "평균 수행 후 SUD", "악화 비율"], 8) + "</div>",
            "<div class='card'><h3>악화 비율이 높은 맥락</h3>" + table_html(worsening, ["위치", "시간대", "SUD 기록 수", "악화 비율", "평균 수행 후 SUD"], 8) + "</div>",
            "</div>",
            "<h2>운영 관점 인사이트</h2>",
            "<div class='grid'>",
            f"<div class='card'><h3>사용 루틴</h3><p>앱 세션은 중앙값 {s['screen_session_median']}분으로 짧고 반복적인 구조다. 앱 세션 상위 시간대는 {', '.join(s['peak_session_hours'])}, 일기 기록 상위 시간대는 {', '.join(s['peak_diary_hours'])}이다.</p></div>",
            f"<div class='card'><h3>알림 활용</h3><p>알림을 가진 사용자는 {s['notification_user_count']}명이며, 위치 기반 알림은 {s['notification_location_count']}개다. 알림 전후 2시간 내 세션 비율은 평균 {s['notification_2h_rate_mean']}%로 개인별 최적화 여지가 있다.</p></div>",
            f"<div class='card'><h3>행동 계획</h3><p>7주차 행동 분류는 직면 {s['behavior_confront']}개, 회피 {s['behavior_avoid']}개다. 8주차 평가에서 효과 있음 {s['effectiveness_rate']}%, 유지 의도 {s['continue_rate']}%로 나타난다.</p></div>",
            f"<div class='card'><h3>초반 부담</h3><p>사용 시간은 {s['peak_usage_week']}주차 {s['peak_usage_minutes']}분, 교육 시간은 {s['peak_edu_week']}주차 {s['peak_edu_minutes']}분이 가장 높다. 초반 콘텐츠 분할과 알림 설계가 완료 루틴 형성에 중요하다.</p></div>",
            "</div>",
            "<h2>사용자 유형과 대응 방향</h2>",
            "<div class='grid'>",
            "<div class='card'><h3>유형 분포</h3>"
            + "".join(f"<span class='pill'>{label}: {count}명</span>" for label, count in archetypes.most_common())
            + "</div>",
            "<div class='card'><h3>활동 유형별 기록량</h3>" + bar_list(analysis["activity_summary"], "활동 유형", "일기 수", 6) + "</div>",
            "</div>",
            "<h2>핵심 차트</h2><section class='chart-grid'>",
        ]
    )
    for file_name, title, caption in chart_cards:
        if (CHART_DIR / file_name).exists():
            html.append(f"<figure class='chart-card'><img src='charts/{file_name}' alt='{title}'><figcaption><b>{title}</b><br><span class='caption'>{caption}</span></figcaption></figure>")
    html.extend(
        [
            "</section>",
            "<h2>해석상 주의</h2>",
            "<div class='card'><p>이 리포트는 앱 사용 중 쌓인 관찰 데이터를 기반으로 한 분석이다. 결과와 사용량의 관계는 인과 효과가 아니라 운영 지표와 작동 가설을 세우기 위한 근거로 해석한다.</p></div>",
            "</main></body></html>",
        ]
    )
    REPORT_HTML.write_text("\n".join(html), encoding="utf-8")


def main() -> None:
    analysis = build_analysis()
    write_outputs(analysis)
    s = analysis["summary"]
    print(f"REPORT={REPORT_HTML}")
    print(f"INSIGHT_JSON={INSIGHT_JSON}")
    print(f"USERS={s['user_count']}")
    print(f"GAD_DROP={s['gad_drop_mean']}")
    print(f"SUD_NON_WORSE={s['sud_non_worse_rate']}")
    print(f"LOCATION_CATEGORIES={', '.join(row['위치'] for row in analysis['location_summary'])}")


if __name__ == "__main__":
    main()
