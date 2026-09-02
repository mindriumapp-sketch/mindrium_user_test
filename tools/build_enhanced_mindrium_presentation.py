#!/usr/bin/env python3
"""Build an enhanced Mindrium presentation with outcome and product-use insights."""

from __future__ import annotations

import importlib.util
import json
import math
import sys
import zipfile
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


LAB_ROOT = Path("/Users/ubdbd/Desktop/Lab_test")
BASE_SCRIPT = LAB_ROOT / "tools" / "build_presentation_deck.py"
BACKUP_ZIP = LAB_ROOT / "lab_8week_backup.zip"
OUT = LAB_ROOT / "analytics_report" / "mindrium_8week_results_enhanced.pptx"


def load_base_module():
    spec = importlib.util.spec_from_file_location("mindrium_base_ppt", BASE_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {BASE_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def dt(value):
    if isinstance(value, dict) and "$date" in value:
        value = value["$date"]
    if not value:
        return None
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def score(answers: dict, key: str) -> int:
    return sum(int(v) for v in answers.get(key) or [])


def gad_level(value: int) -> str:
    if value <= 4:
        return "거의 없음"
    if value <= 9:
        return "경도"
    if value <= 14:
        return "중등도"
    return "높음"


def diary_week(diary: dict) -> int | None:
    parts = str(diary.get("diary_id", "")).split("_")
    if len(parts) >= 4 and parts[0] == "diary" and parts[1] == "syn":
        try:
            return int(parts[3])
        except ValueError:
            return None
    return None


def mean(values):
    return sum(values) / len(values) if values else 0.0


def corr(xs, ys) -> float:
    if len(xs) < 2:
        return float("nan")
    mx = mean(xs)
    my = mean(ys)
    vx = sum((x - mx) ** 2 for x in xs)
    vy = sum((y - my) ** 2 for y in ys)
    if vx == 0 or vy == 0:
        return float("nan")
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / math.sqrt(vx * vy)


def load_data() -> dict[str, list[dict]]:
    names = [
        "users",
        "diaries",
        "relaxation_tasks",
        "screen_time",
        "treatment_progress",
        "edu_sessions",
        "notification_settings",
        "worry_groups",
    ]
    with zipfile.ZipFile(BACKUP_ZIP) as zf:
        return {name: json.loads(zf.read(f"lab_8week_backup/{name}.json")) for name in names}


def compute_stats() -> dict:
    data = load_data()
    users = data["users"]
    diaries = data["diaries"]
    progress = data["treatment_progress"]
    screen = data["screen_time"]
    edu = data["edu_sessions"]
    notifications = data["notification_settings"]
    worry_groups = data["worry_groups"]

    user_metrics = {}
    pre_levels = Counter()
    post_levels = Counter()
    transitions = Counter()
    for user in users:
        uid = user["user_id"]
        before = next(s for s in user["surveys"] if s["type"] == "before_survey")
        after = next(s for s in user["surveys"] if s["type"] == "after_survey")
        gad_pre = score(before["answers"], "gad7_answers")
        gad_post = score(after["answers"], "gad7_answers")
        user_metrics[uid] = {
            "gad_pre": gad_pre,
            "gad_post": gad_post,
            "gad_drop": gad_pre - gad_post,
        }
        pre_levels[gad_level(gad_pre)] += 1
        post_levels[gad_level(gad_post)] += 1
        transitions[(gad_level(gad_pre), gad_level(gad_post))] += 1

    sud_by_user_week = defaultdict(list)
    immediate_delta_by_week = defaultdict(list)
    diary_count = Counter()
    alt_count = Counter()
    total_sud = 0
    worsened_sud = 0
    loc_count = 0
    auto_loc_count = 0
    for diary in diaries:
        uid = diary["user_id"]
        week = diary_week(diary)
        diary_count[uid] += 1
        if diary.get("loc_time"):
            loc_count += 1
        if diary.get("loc_auto_filled"):
            auto_loc_count += 1
        if diary.get("alternative_thoughts"):
            alt_count[uid] += len(diary["alternative_thoughts"])
        for sud in diary.get("sud_scores") or []:
            before = int(sud["before_sud"])
            after = int(sud["after_sud"])
            delta = before - after
            total_sud += 1
            worsened_sud += int(after > before)
            if week:
                sud_by_user_week[(uid, week)].append(after)
                immediate_delta_by_week[week].append(delta)

    for uid in user_metrics:
        if sud_by_user_week[(uid, 3)] and sud_by_user_week[(uid, 8)]:
            user_metrics[uid]["sud_drop"] = mean(sud_by_user_week[(uid, 3)]) - mean(sud_by_user_week[(uid, 8)])
        else:
            user_metrics[uid]["sud_drop"] = 0.0
        user_metrics[uid]["diaries"] = diary_count[uid]
        user_metrics[uid]["alt_total"] = alt_count[uid]

    intervals = defaultdict(list)
    for item in progress:
        intervals[item["user_id"]].append((item["week_number"], dt(item["started_at"]), dt(item["ends_at"])))
    weekly_screen = defaultdict(float)
    active_days = defaultdict(set)
    hour_counts = Counter()
    session_minutes = []
    for item in screen:
        uid = item["user_id"]
        start = dt(item["start_time"])
        minutes = item.get("duration_seconds", 0) / 60
        session_minutes.append(minutes)
        if start:
            active_days[uid].add(start.date())
            hour_counts[start.hour] += 1
            for week, started_at, ends_at in intervals[uid]:
                if started_at <= start <= ends_at:
                    weekly_screen[week] += minutes
                    break

    edu_duration_by_week = defaultdict(list)
    for item in edu:
        edu_duration_by_week[item["week_number"]].append((dt(item["end_time"]) - dt(item["start_time"])).total_seconds() / 60)

    topic_stats = defaultdict(lambda: [0, 0.0])
    for group in worry_groups:
        topic_stats[group["group_title"]][0] += int(group.get("diary_count") or 0)
        topic_stats[group["group_title"]][1] += float(group.get("sud_sum") or 0)

    diary_values = sorted((m["diaries"], uid) for uid, m in user_metrics.items())
    alt_values = sorted((m["alt_total"], uid) for uid, m in user_metrics.items())
    low_diary = [user_metrics[uid] for _, uid in diary_values[:10]]
    high_diary = [user_metrics[uid] for _, uid in diary_values[-10:]]
    low_alt = [user_metrics[uid] for _, uid in alt_values[:10]]
    high_alt = [user_metrics[uid] for _, uid in alt_values[-10:]]

    gad_drops = [m["gad_drop"] for m in user_metrics.values()]
    severe_start = [m for m in user_metrics.values() if gad_level(m["gad_pre"]) == "높음"]
    severe_to_lower = sum(1 for m in severe_start if gad_level(m["gad_post"]) in {"거의 없음", "경도", "중등도"})

    pre_module = [v for week in (3, 4) for v in immediate_delta_by_week[week]]
    post_module = [v for week in (5, 6, 7, 8) for v in immediate_delta_by_week[week]]
    top_hours = [hour for hour, _ in hour_counts.most_common(4)]
    top_topics_by_count = sorted(topic_stats.items(), key=lambda kv: kv[1][0], reverse=True)[:3]
    top_topics_by_sud = sorted(topic_stats.items(), key=lambda kv: kv[1][1] / kv[1][0], reverse=True)[:3]

    return {
        "n": len(users),
        "responder_4": sum(1 for v in gad_drops if v >= 4),
        "responder_3": sum(1 for v in gad_drops if v >= 3),
        "severe_start": len(severe_start),
        "severe_to_lower": severe_to_lower,
        "pre_levels": pre_levels,
        "post_levels": post_levels,
        "transitions": transitions,
        "low_diary_gad": mean([m["gad_drop"] for m in low_diary]),
        "high_diary_gad": mean([m["gad_drop"] for m in high_diary]),
        "low_diary_sud": mean([m["sud_drop"] for m in low_diary]),
        "high_diary_sud": mean([m["sud_drop"] for m in high_diary]),
        "low_alt_sud": mean([m["sud_drop"] for m in low_alt]),
        "high_alt_sud": mean([m["sud_drop"] for m in high_alt]),
        "diary_corr_sud": corr([m["diaries"] for m in user_metrics.values()], [m["sud_drop"] for m in user_metrics.values()]),
        "alt_corr_sud": corr([m["alt_total"] for m in user_metrics.values()], [m["sud_drop"] for m in user_metrics.values()]),
        "pre_module_delta": mean(pre_module),
        "post_module_delta": mean(post_module),
        "post_module_lift": mean(post_module) - mean(pre_module),
        "total_sud": total_sud,
        "worsened_sud": worsened_sud,
        "nonworsened_rate": 1 - worsened_sud / total_sud,
        "weekly_screen": {week: weekly_screen[week] / len(users) for week in range(1, 9)},
        "week2_edu": mean(edu_duration_by_week[2]),
        "session_mean": mean(session_minutes),
        "session_median": sorted(session_minutes)[len(session_minutes) // 2],
        "top_hours": top_hours,
        "notification_users": len(set(n["user_id"] for n in notifications)),
        "notification_dist": Counter(Counter(n["user_id"] for n in notifications).values()),
        "location_rate": loc_count / len(diaries),
        "auto_location_rate": auto_loc_count / len(diaries),
        "top_topics_by_count": top_topics_by_count,
        "top_topics_by_sud": top_topics_by_sud,
    }


def bar(module, slide, x, y, w, h, value, max_value, color, label, value_text):
    slide.text(x, y - 0.33, w, 0.25, [label], 900, module.INK, True)
    slide.rect(x, y, w, h, "EEF1F3", None, radius=True)
    slide.rect(x, y, w * max(0, min(value / max_value, 1)), h, color, None, radius=True)
    slide.text(x + w + 0.18, y - 0.02, 1.6, h + 0.05, [value_text], 1050, module.INK, True)


def vbar(module, slide, x, baseline, w, max_h, value, max_value, color, label, value_text):
    height = max_h * max(0, min(value / max_value, 1))
    slide.rect(x, baseline - max_h, w, max_h, "EEF1F3", None)
    slide.rect(x, baseline - height, w, height, color, None)
    slide.text(x - 0.1, baseline + 0.1, w + 0.2, 0.3, [label], 850, module.MUTED, True, align="c")
    slide.text(x - 0.12, baseline - height - 0.38, w + 0.24, 0.3, [value_text], 900, module.INK, True, align="c")


def add_insight_slides(module, deck, stats):
    # 1. Responder slide
    s = deck.new_slide()
    module.add_title(
        s,
        "RESPONDER",
        "평균 변화보다 반응자 비율이 더 강한 메시지다",
        "GAD-7 감소폭을 기준으로 의미 있는 개선을 보인 사용자 비율을 분리했다.",
    )
    module.metric(s, 0.78, 2.35, 2.65, f"{stats['responder_4']}/40명", "4점 이상 감소", "52.5%", module.PALE_TEAL)
    module.metric(s, 3.72, 2.35, 2.65, f"{stats['responder_3']}/40명", "3점 이상 감소", "72.5%", module.PALE_BLUE)
    module.metric(s, 6.66, 2.35, 2.65, f"{stats['severe_to_lower']}/{stats['severe_start']}명", "높은 불안군 이동", "중등도 이하", module.PALE_CORAL)
    bar(module, s, 1.0, 4.35, 6.8, 0.42, stats["responder_4"], 40, module.TEAL, "GAD-7 4점 이상 감소", "52.5%")
    bar(module, s, 1.0, 5.25, 6.8, 0.42, stats["responder_3"], 40, module.BLUE, "GAD-7 3점 이상 감소", "72.5%")
    s.text(8.35, 4.18, 3.85, 1.45, ["핵심 해석", "평균 -3.88점보다, 절반 이상이 4점 이상 감소했다는 메시지가 발표에서 더 직접적이다."], 1160, module.INK)
    s.text(0.9, 6.64, 11.6, 0.34, ["주의: 반응자 기준은 발표용 보조 지표이며, 임계값은 분석 목적에 맞춰 명시해야 한다."], 840, module.MUTED)

    # 2. Severity transition slide
    s = deck.new_slide()
    module.add_title(
        s,
        "SEVERITY SHIFT",
        "높은 불안군 대부분이 더 낮은 위험 구간으로 이동했다",
        "GAD-7 중증도 분포를 시작 시점과 8주 후로 나누어 비교했다.",
    )
    levels = ["경도", "중등도", "높음"]
    colors = {"경도": module.TEAL, "중등도": module.BLUE, "높음": module.CORAL}
    max_count = 30
    for i, level in enumerate(levels):
        x = 1.25 + i * 1.25
        vbar(module, s, x, 5.65, 0.58, 3.1, stats["pre_levels"].get(level, 0), max_count, colors[level], level, str(stats["pre_levels"].get(level, 0)))
        x2 = 6.35 + i * 1.25
        vbar(module, s, x2, 5.65, 0.58, 3.1, stats["post_levels"].get(level, 0), max_count, colors[level], level, str(stats["post_levels"].get(level, 0)))
    s.text(1.05, 2.28, 3.9, 0.35, ["시작 시점"], 1450, module.INK, True, align="c")
    s.text(6.15, 2.28, 3.9, 0.35, ["8주 후"], 1450, module.INK, True, align="c")
    module.metric(s, 9.9, 2.62, 2.35, "22명", "높음 -> 중등도 이하", "24명 중", module.PALE_CORAL)
    module.metric(s, 9.9, 4.08, 2.35, "2명", "높음 유지", "8주 후", "EEF1F3")
    s.text(1.0, 6.6, 11.2, 0.34, ["전이표 관점에서는 평균 변화보다 위험 구간 이동이 더 직관적으로 전달된다."], 860, module.MUTED)

    # 3. Dose-response slide
    s = deck.new_slide()
    module.add_title(
        s,
        "DOSE RESPONSE",
        "단순 접속보다 능동 과제가 결과와 더 가까이 연결된다",
        "일기 작성량과 대안적 생각 사용량을 상·하위 10명으로 나누어 결과 차이를 비교했다.",
    )
    module.small_table(
        s,
        0.85,
        2.45,
        ["비교", "하위 10명", "상위 10명", "차이"],
        [
            ["일기 수 vs GAD-7 감소", f"{stats['low_diary_gad']:.1f}점", f"{stats['high_diary_gad']:.1f}점", f"+{stats['high_diary_gad'] - stats['low_diary_gad']:.1f}점"],
            ["일기 수 vs SUD 감소", f"{stats['low_diary_sud']:.2f}점", f"{stats['high_diary_sud']:.2f}점", f"+{stats['high_diary_sud'] - stats['low_diary_sud']:.2f}점"],
            ["대안적 생각 vs SUD 감소", f"{stats['low_alt_sud']:.2f}점", f"{stats['high_alt_sud']:.2f}점", f"+{stats['high_alt_sud'] - stats['low_alt_sud']:.2f}점"],
        ],
        [2.35, 1.3, 1.3, 1.0],
    )
    vbar(module, s, 8.0, 5.75, 0.72, 2.6, stats["low_diary_sud"], 2.8, module.CORAL, "하위", f"{stats['low_diary_sud']:.2f}")
    vbar(module, s, 9.15, 5.75, 0.72, 2.6, stats["high_diary_sud"], 2.8, module.TEAL, "상위", f"{stats['high_diary_sud']:.2f}")
    s.text(7.75, 2.45, 2.55, 0.42, ["일기량별 SUD 감소"], 1150, module.INK, True, align="c")
    module.metric(s, 10.55, 3.0, 1.85, f"r={stats['diary_corr_sud']:.2f}", "일기-SUD 관계", "사용자 단위", module.PALE_BLUE)
    module.metric(s, 10.55, 4.45, 1.85, f"r={stats['alt_corr_sud']:.2f}", "대안생각-SUD 관계", "사용자 단위", module.PALE_TEAL)
    s.text(0.9, 6.57, 11.4, 0.38, ["해석: 체류시간 자체보다 기록·재평가처럼 사용자가 직접 수행하는 과제가 더 좋은 제품 KPI 후보다."], 880, module.MUTED)

    # 4. Mechanism and burden slide
    s = deck.new_slide()
    module.add_title(
        s,
        "MECHANISM",
        "5주차 이후 수행 직후 SUD 감소폭이 커졌다",
        "대안적 생각 기능 해금 전후의 즉시 SUD 감소폭과 악화 없음 비율을 함께 제시했다.",
    )
    vbar(module, s, 1.25, 5.65, 0.95, 2.9, stats["pre_module_delta"], 1.2, module.BLUE, "3~4주차", f"{stats['pre_module_delta']:.2f}")
    vbar(module, s, 2.75, 5.65, 0.95, 2.9, stats["post_module_delta"], 1.2, module.TEAL, "5~8주차", f"{stats['post_module_delta']:.2f}")
    module.metric(s, 4.45, 3.2, 2.2, f"+{stats['post_module_lift']:.2f}점", "즉시 감소폭 차이", "기능 해금 전후", module.PALE_TEAL)
    module.metric(s, 7.05, 3.2, 2.2, f"{stats['nonworsened_rate'] * 100:.1f}%", "악화 없음", f"{stats['total_sud']:,}개 SUD 기록", module.PALE_BLUE)
    module.metric(s, 9.65, 3.2, 2.2, f"{stats['worsened_sud']}개", "악화 기록", "9.9%", module.PALE_CORAL)
    s.text(1.0, 6.42, 11.1, 0.5, ["인과 효과가 아니라, 기능 해금 이후 더 구조화된 기록과 SUD 감소가 함께 나타난 사용 패턴으로 해석한다."], 900, module.MUTED)

    # 5. Software-use context slide
    s = deck.new_slide()
    module.add_title(
        s,
        "USE CONTEXT",
        "Mindrium은 짧은 야간 반복 과제형 사용에 가깝다",
        "사용 시간, 세션 길이, 알림, 위치 기록을 제품 운영 지표로 재해석했다.",
    )
    module.metric(s, 0.8, 2.42, 2.2, f"{stats['weekly_screen'][1]:.0f}분", "1주차 사용시간", "주차 평균", module.PALE_BLUE)
    module.metric(s, 3.25, 2.42, 2.2, f"{stats['weekly_screen'][2]:.0f}분", "2주차 사용시간", "가장 높음", "FFF4E7")
    module.metric(s, 5.7, 2.42, 2.2, f"{stats['week2_edu']:.0f}분", "2주차 교육시간", "평균", module.PALE_CORAL)
    module.metric(s, 8.15, 2.42, 2.2, f"{stats['session_median']:.0f}분", "세션 중앙값", f"평균 {stats['session_mean']:.1f}분", module.PALE_TEAL)
    module.metric(s, 10.6, 2.42, 1.85, "40/40명", "알림 사용", "루틴 보조", "EEF1F3")
    module.small_table(
        s,
        0.9,
        4.45,
        ["관점", "핵심 수치", "해석"],
        [
            ["야간 루틴", ", ".join(f"{h}시" for h in stats["top_hours"]), "하루 종료 후 정리/이완 맥락"],
            ["위치 기록", f"{stats['location_rate'] * 100:.1f}%", "상황 기반 개인화 가능"],
            ["자동 위치", f"{stats['auto_location_rate'] * 100:.1f}%", "자동화 여지는 아직 제한적"],
        ],
        [1.35, 1.85, 4.1],
    )
    s.text(8.5, 4.55, 3.5, 1.1, ["운영 관점", "초반 온보딩 부담을 줄이고, 야간 루틴과 알림 최적화를 제품 실험 축으로 둘 수 있다."], 1050, module.INK)

    # 6. Content personalization slide
    s = deck.new_slide()
    module.add_title(
        s,
        "CONTENT",
        "많이 기록되는 주제와 부담이 큰 주제는 분리해서 봐야 한다",
        "콘텐츠 추천은 빈도 기준과 평균 SUD 기준을 함께 사용하는 편이 적합하다.",
    )
    freq_rows = [[title, str(values[0]), f"{values[1] / values[0]:.2f}"] for title, values in stats["top_topics_by_count"]]
    burden_rows = [[title, str(values[0]), f"{values[1] / values[0]:.2f}"] for title, values in stats["top_topics_by_sud"]]
    module.small_table(s, 0.95, 2.55, ["일기 수 상위", "일기", "평균 SUD"], freq_rows, [1.9, 0.8, 0.9])
    module.small_table(s, 5.4, 2.55, ["부담 상위", "일기", "평균 SUD"], burden_rows, [1.9, 0.8, 0.9])
    module.metric(s, 9.9, 2.75, 2.2, "2축 추천", "빈도 + 부담", "콘텐츠 개인화", module.PALE_TEAL)
    module.bullets(
        s,
        [
            "빈도 기준은 자주 반복되는 사용 맥락을 찾는 데 유리하다.",
            "평균 SUD 기준은 우선 개입할 부담 주제를 찾는 데 유리하다.",
            "두 기준을 분리하면 추천 콘텐츠와 리포트 메시지가 더 명확해진다.",
        ],
        9.55,
        4.45,
        2.9,
        1.35,
        920,
    )


def main() -> None:
    module = load_base_module()
    stats = compute_stats()
    deck = module.build_deck()
    add_insight_slides(module, deck, stats)
    module.write_deck(deck, OUT)
    print(f"PPTX: {OUT}")
    print(f"slides: {len(deck.slides)}")
    print(f"bytes: {OUT.stat().st_size}")


if __name__ == "__main__":
    main()
