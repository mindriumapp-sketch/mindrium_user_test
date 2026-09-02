#!/usr/bin/env python3
"""Build charts for resolved worry-group analysis.

In the Mindrium data model used for this lab-test export, archived worry groups
mean "resolved". For resolved groups, updated_at is treated as the resolution
timestamp. Group-level diary/SUD metrics therefore only use records at or before
updated_at.
"""

from __future__ import annotations

import csv
import json
import math
import statistics
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager


DATA_DIR = Path("/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test/lab_8week_location_context_backup")
OUT_DIR = Path("/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test/analytics_report/final_comprehensive")
CHART_DIR = OUT_DIR / "charts"
PANEL_DIR = CHART_DIR / "resolution_panels"
TABLE_DIR = OUT_DIR / "tables"

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


def parse_date(raw) -> datetime | None:
    if isinstance(raw, dict) and "$date" in raw:
        raw = raw["$date"]
    if not raw:
        return None
    return datetime.fromisoformat(str(raw).replace("Z", "+00:00"))


def mean(values) -> float | None:
    vals = [float(v) for v in values if v is not None]
    return statistics.mean(vals) if vals else None


def median(values) -> float | None:
    vals = [float(v) for v in values if v is not None]
    return statistics.median(vals) if vals else None


def pct(part: float, whole: float) -> float:
    return part / whole * 100 if whole else 0.0


def fmt(value: float | None, digits: int = 1) -> str:
    if value is None:
        return "-"
    return f"{value:.{digits}f}"


def week_from_start(start: datetime | None, timestamp: datetime | None) -> int | None:
    if not start or not timestamp:
        return None
    return max(1, min(8, math.floor((timestamp - start).days / 7) + 1))


def user_scores(user: dict) -> tuple[int | None, int | None, int | None]:
    gad_pre = gad_post = phq_pre = None
    for survey in user.get("surveys") or []:
        answers = survey.get("answers") or {}
        if survey.get("type") == "before_survey":
            gad_pre = answers.get("gad7_score")
            phq_pre = answers.get("phq9_score")
        elif survey.get("type") == "after_survey":
            gad_post = answers.get("gad7_score")
    return gad_pre, gad_post, phq_pre


def style_ax(ax) -> None:
    ax.grid(axis="y", alpha=0.16)
    ax.set_axisbelow(True)
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.tick_params(colors=COLORS["muted"])


def savefig(fig, path: Path) -> None:
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def write_csv(path: Path, rows: list[dict]) -> None:
    keys: list[str] = []
    for row in rows:
        for key in row:
            if key not in keys:
                keys.append(key)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)


def collect_metrics() -> dict:
    users = read_json(DATA_DIR / "users.json")
    groups = read_json(DATA_DIR / "worry_groups.json")
    diaries = read_json(DATA_DIR / "diaries.json")

    users_by_id = {u["user_id"]: u for u in users}
    start_by_user = {u["user_id"]: parse_date(u.get("created_at")) for u in users}
    diaries_by_group: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for diary in diaries:
        diaries_by_group[(diary["user_id"], diary["group_id"])].append(diary)
    for bucket in diaries_by_group.values():
        bucket.sort(key=lambda d: parse_date(d.get("created_at")) or datetime.max.replace(tzinfo=None))

    group_rows: list[dict] = []
    qc_rows: list[dict] = []
    relative_sud: dict[int, list[dict]] = defaultdict(list)

    for group in groups:
        user_id = group["user_id"]
        group_id = group["group_id"]
        is_default = group_id == "group_example"
        resolved = bool(group.get("archived"))
        resolved_at = parse_date(group.get("updated_at")) if resolved else None
        all_diaries = diaries_by_group.get((user_id, group_id), [])
        diaries_after_resolved = [
            d for d in all_diaries
            if resolved_at and parse_date(d.get("created_at")) and parse_date(d.get("created_at")) > resolved_at
        ]
        used_diaries = [
            d for d in all_diaries
            if not resolved_at or not parse_date(d.get("created_at")) or parse_date(d.get("created_at")) <= resolved_at
        ]

        before_scores: list[float] = []
        after_scores: list[float] = []
        deltas: list[float] = []
        worsened = 0
        non_worsened = 0
        sud_records: list[dict] = []

        for diary in used_diaries:
            created_at = parse_date(diary.get("created_at"))
            for sud in diary.get("sud_scores") or []:
                before = sud.get("before_sud")
                after = sud.get("after_sud")
                if before is None or after is None:
                    continue
                before_scores.append(before)
                after_scores.append(after)
                deltas.append(before - after)
                if after > before:
                    worsened += 1
                else:
                    non_worsened += 1
                sud_records.append({"created_at": created_at, "before": before, "after": after, "delta": before - after})

        if resolved and sud_records:
            sud_records.sort(key=lambda r: r["created_at"] or datetime.max.replace(tzinfo=None))
            n = len(sud_records)
            for idx, record in enumerate(sud_records):
                bucket = min(4, int(idx / n * 4) + 1)
                relative_sud[bucket].append(record)

        row = {
            "user_id": user_id,
            "group_id": group_id,
            "걱정 주제": group.get("group_title"),
            "기본 그룹 여부": is_default,
            "해결 여부": resolved,
            "해결 시점": resolved_at.isoformat() if resolved_at else "",
            "해결 주차": week_from_start(start_by_user.get(user_id), resolved_at) if resolved else None,
            "전체 일기 수": len(all_diaries),
            "분석 반영 일기 수": len(used_diaries),
            "해결 이후 일기 수": len(diaries_after_resolved),
            "평균 수행 전 SUD": mean(before_scores),
            "평균 수행 후 SUD": mean(after_scores),
            "평균 SUD 감소": mean(deltas),
            "악화 없음 비율": pct(non_worsened, non_worsened + worsened),
            "SUD 기록 수": len(deltas),
        }
        group_rows.append(row)

        if resolved:
            qc_rows.append({
                "user_id": user_id,
                "group_id": group_id,
                "걱정 주제": group.get("group_title"),
                "해결 시점": row["해결 시점"],
                "해결 주차": row["해결 주차"],
                "전체 일기 수": len(all_diaries),
                "분석 반영 일기 수": len(used_diaries),
                "해결 이후 일기 수": len(diaries_after_resolved),
            })

    personal_rows = [r for r in group_rows if not r["기본 그룹 여부"]]
    resolved_rows = [r for r in personal_rows if r["해결 여부"]]
    active_rows = [r for r in personal_rows if not r["해결 여부"]]

    user_rows: list[dict] = []
    resolved_users = {r["user_id"] for r in resolved_rows}
    for user in users:
        gad_pre, gad_post, phq_pre = user_scores(user)
        user_rows.append({
            "user_id": user["user_id"],
            "해결 경험": user["user_id"] in resolved_users,
            "GAD-7 시작": gad_pre,
            "GAD-7 8주 후": gad_post,
            "GAD-7 감소": gad_pre - gad_post if gad_pre is not None and gad_post is not None else None,
            "PHQ-9 시작": phq_pre,
        })

    topic_rows: list[dict] = []
    by_topic: dict[str, list[dict]] = defaultdict(list)
    for row in personal_rows:
        by_topic[row["걱정 주제"]].append(row)
    for topic, rows in by_topic.items():
        resolved_count = sum(1 for r in rows if r["해결 여부"])
        active_count = len(rows) - resolved_count
        topic_rows.append({
            "걱정 주제": topic,
            "전체 그룹 수": len(rows),
            "해결 그룹 수": resolved_count,
            "활성 그룹 수": active_count,
            "해결률": pct(resolved_count, len(rows)),
            "해결 그룹 평균 수행 후 SUD": mean([r["평균 수행 후 SUD"] for r in rows if r["해결 여부"]]),
            "활성 그룹 평균 수행 후 SUD": mean([r["평균 수행 후 SUD"] for r in rows if not r["해결 여부"]]),
        })
    topic_rows.sort(key=lambda r: (r["해결 그룹 수"], r["해결률"], r["걱정 주제"]), reverse=True)

    status_rows = [
        {
            "구분": "해결 그룹",
            "그룹 수": len(resolved_rows),
            "사용자 수": len({r["user_id"] for r in resolved_rows}),
            "평균 일기 수": mean([r["분석 반영 일기 수"] for r in resolved_rows]),
            "평균 수행 전 SUD": mean([r["평균 수행 전 SUD"] for r in resolved_rows]),
            "평균 수행 후 SUD": mean([r["평균 수행 후 SUD"] for r in resolved_rows]),
            "평균 SUD 감소": mean([r["평균 SUD 감소"] for r in resolved_rows]),
            "악화 없음 비율": mean([r["악화 없음 비율"] for r in resolved_rows]),
        },
        {
            "구분": "활성 개인 그룹",
            "그룹 수": len(active_rows),
            "사용자 수": len({r["user_id"] for r in active_rows}),
            "평균 일기 수": mean([r["분석 반영 일기 수"] for r in active_rows]),
            "평균 수행 전 SUD": mean([r["평균 수행 전 SUD"] for r in active_rows]),
            "평균 수행 후 SUD": mean([r["평균 수행 후 SUD"] for r in active_rows]),
            "평균 SUD 감소": mean([r["평균 SUD 감소"] for r in active_rows]),
            "악화 없음 비율": mean([r["악화 없음 비율"] for r in active_rows]),
        },
    ]

    user_status_rows: list[dict] = []
    for label, flag in [("해결 경험 있음", True), ("해결 경험 없음", False)]:
        subset = [r for r in user_rows if r["해결 경험"] is flag]
        user_status_rows.append({
            "구분": label,
            "사용자 수": len(subset),
            "GAD-7 시작 평균": mean([r["GAD-7 시작"] for r in subset]),
            "GAD-7 8주 후 평균": mean([r["GAD-7 8주 후"] for r in subset]),
            "GAD-7 평균 감소": mean([r["GAD-7 감소"] for r in subset]),
            "4점 이상 개선 사용자 수": sum(1 for r in subset if r["GAD-7 감소"] is not None and r["GAD-7 감소"] >= 4),
            "3점 이상 개선 사용자 수": sum(1 for r in subset if r["GAD-7 감소"] is not None and r["GAD-7 감소"] >= 3),
        })

    trajectory_rows: list[dict] = []
    labels = {1: "초기", 2: "중기 1", 3: "중기 2", 4: "해결 직전"}
    for bucket in [1, 2, 3, 4]:
        records = relative_sud[bucket]
        trajectory_rows.append({
            "해결 전 기록 구간": labels[bucket],
            "평균 수행 전 SUD": mean([r["before"] for r in records]),
            "평균 수행 후 SUD": mean([r["after"] for r in records]),
            "평균 SUD 감소": mean([r["delta"] for r in records]),
            "SUD 기록 수": len(records),
        })

    timing_rows: list[dict] = []
    week_counts = Counter(r["해결 주차"] for r in resolved_rows)
    for week in range(1, 9):
        timing_rows.append({"주차": week, "해결 그룹 수": week_counts.get(week, 0)})

    return {
        "topic_rows": topic_rows,
        "status_rows": status_rows,
        "user_status_rows": user_status_rows,
        "trajectory_rows": trajectory_rows,
        "timing_rows": timing_rows,
        "qc_rows": qc_rows,
        "summary": {
            "users": len(users),
            "personal_groups": len(personal_rows),
            "resolved_groups": len(resolved_rows),
            "resolved_users": len({r["user_id"] for r in resolved_rows}),
            "after_resolution_diary_groups": sum(1 for r in qc_rows if r["해결 이후 일기 수"] > 0),
            "after_resolution_diaries": sum(r["해결 이후 일기 수"] for r in qc_rows),
        },
    }


def plot_topic_resolution(topic_rows: list[dict], path: Path) -> None:
    rows = list(reversed(topic_rows))
    topics = [r["걱정 주제"] for r in rows]
    resolved = [r["해결 그룹 수"] for r in rows]
    active = [r["활성 그룹 수"] for r in rows]
    rates = [r["해결률"] for r in rows]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5.2), dpi=180, gridspec_kw={"width_ratios": [1.25, 1]})
    y = range(len(rows))
    ax1.barh(y, active, color="#DDE7E8", label="활성")
    ax1.barh(y, resolved, left=active, color=COLORS["teal"], label="해결")
    ax1.set_yticks(y)
    ax1.set_yticklabels(topics)
    ax1.set_xlabel("그룹 수")
    ax1.set_title("걱정 주제별 해결 그룹 수")
    ax1.legend(frameon=False, loc="lower right")
    for idx, (a, r) in enumerate(zip(active, resolved)):
        if r:
            ax1.text(a + r + 0.25, idx, f"{r}개", va="center", color=COLORS["teal"], fontsize=10)
    style_ax(ax1)

    ax2.scatter(rates, y, s=[90 + r * 40 for r in resolved], color=COLORS["coral"], alpha=0.9)
    for idx, rate in enumerate(rates):
        ax2.text(rate + 1.3, idx, f"{rate:.0f}%", va="center", color=COLORS["ink"], fontsize=10)
    ax2.set_yticks(y)
    ax2.set_yticklabels([])
    ax2.set_xlim(0, max(35, max(rates) + 8))
    ax2.set_xlabel("해결률")
    ax2.set_title("개인 걱정 그룹 중 해결 비율")
    style_ax(ax2)
    fig.suptitle("걱정 주제별 해결 상태", fontsize=15, fontweight="bold", color=COLORS["ink"], x=0.05, ha="left")
    savefig(fig, path)


def plot_sud_comparison(status_rows: list[dict], path: Path) -> None:
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4.8), dpi=180, gridspec_kw={"width_ratios": [1.2, 1]})
    labels = [r["구분"] for r in status_rows]
    y_positions = range(len(labels))
    for y, row, color in zip(y_positions, status_rows, [COLORS["teal"], COLORS["blue"]]):
        before = row["평균 수행 전 SUD"]
        after = row["평균 수행 후 SUD"]
        ax1.plot([before, after], [y, y], color=color, linewidth=4, alpha=0.55)
        ax1.scatter([before], [y], s=120, color=COLORS["gold"], zorder=3, label="수행 전" if y == 0 else None)
        ax1.scatter([after], [y], s=120, color=color, zorder=3, label="수행 후" if y == 0 else None)
        ax1.text(before + 0.08, y + 0.1, f"{before:.2f}", color=COLORS["gold"], fontsize=10)
        ax1.text(after - 0.55, y - 0.18, f"{after:.2f}", color=color, fontsize=10)
    ax1.set_yticks(list(y_positions))
    ax1.set_yticklabels(labels)
    ax1.invert_yaxis()
    ax1.set_xlim(0, 10)
    ax1.set_xlabel("평균 SUD")
    ax1.set_title("수행 전후 SUD")
    ax1.legend(frameon=False, loc="lower right")
    style_ax(ax1)

    x = range(len(labels))
    deltas = [r["평균 SUD 감소"] for r in status_rows]
    non_worse = [r["악화 없음 비율"] for r in status_rows]
    bars = ax2.bar(x, deltas, color=[COLORS["teal"], COLORS["blue"]], width=0.52)
    ax2.set_xticks(list(x))
    ax2.set_xticklabels(labels, rotation=0)
    ax2.set_ylabel("평균 SUD 감소")
    ax2.set_title("즉시 안정화 폭")
    for bar, delta, nw in zip(bars, deltas, non_worse):
        ax2.text(bar.get_x() + bar.get_width() / 2, delta + 0.03, f"{delta:.2f}점", ha="center", fontsize=10)
        ax2.text(bar.get_x() + bar.get_width() / 2, 0.08, f"악화 없음\n{nw:.1f}%", ha="center", va="bottom", fontsize=9, color="white", fontweight="bold")
    ax2.set_ylim(0, max(deltas) + 0.35)
    style_ax(ax2)
    fig.suptitle("해결 그룹은 활성 그룹보다 수행 직후 안정화 폭이 크다", fontsize=15, fontweight="bold", color=COLORS["ink"], x=0.05, ha="left")
    savefig(fig, path)


def plot_user_gad(user_status_rows: list[dict], path: Path) -> None:
    rows = user_status_rows
    labels = [r["구분"] for r in rows]
    drops = [r["GAD-7 평균 감소"] for r in rows]
    users = [r["사용자 수"] for r in rows]
    responder4 = [pct(r["4점 이상 개선 사용자 수"], r["사용자 수"]) for r in rows]
    responder3 = [pct(r["3점 이상 개선 사용자 수"], r["사용자 수"]) for r in rows]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11.5, 4.8), dpi=180)
    x = range(len(labels))
    bars = ax1.bar(x, drops, color=[COLORS["teal"], COLORS["blue"]], width=0.5)
    ax1.set_xticks(list(x))
    ax1.set_xticklabels([f"{label}\n(n={n})" for label, n in zip(labels, users)])
    ax1.set_ylabel("GAD-7 평균 감소점수")
    ax1.set_title("해결 경험 유무별 GAD-7 변화")
    for bar, value in zip(bars, drops):
        ax1.text(bar.get_x() + bar.get_width() / 2, value + 0.08, f"{value:.2f}점", ha="center", fontsize=11)
    ax1.set_ylim(0, max(drops) + 0.8)
    style_ax(ax1)

    width = 0.34
    ax2.bar([i - width / 2 for i in x], responder4, width=width, color=COLORS["teal"], label="4점 이상 개선")
    ax2.bar([i + width / 2 for i in x], responder3, width=width, color=COLORS["gold"], label="3점 이상 개선")
    ax2.set_xticks(list(x))
    ax2.set_xticklabels(labels)
    ax2.set_ylim(0, 100)
    ax2.set_ylabel("사용자 비율")
    ax2.set_title("개선자 비율")
    for i, value in enumerate(responder4):
        ax2.text(i - width / 2, value + 2, f"{value:.1f}%", ha="center", fontsize=9)
    for i, value in enumerate(responder3):
        ax2.text(i + width / 2, value + 2, f"{value:.1f}%", ha="center", fontsize=9)
    ax2.legend(frameon=False, loc="lower right")
    style_ax(ax2)
    fig.suptitle("걱정 해결 경험이 있는 사용자군에서 전반적 개선폭이 더 크다", fontsize=15, fontweight="bold", color=COLORS["ink"], x=0.05, ha="left")
    savefig(fig, path)


def plot_resolution_trajectory(trajectory_rows: list[dict], path: Path) -> None:
    labels = [r["해결 전 기록 구간"] for r in trajectory_rows]
    before = [r["평균 수행 전 SUD"] for r in trajectory_rows]
    after = [r["평균 수행 후 SUD"] for r in trajectory_rows]
    delta = [r["평균 SUD 감소"] for r in trajectory_rows]
    x = range(len(labels))

    fig, ax1 = plt.subplots(figsize=(10, 5), dpi=180)
    ax1.plot(x, before, marker="o", linewidth=2.8, color=COLORS["gold"], label="수행 전 SUD")
    ax1.plot(x, after, marker="o", linewidth=2.8, color=COLORS["teal"], label="수행 후 SUD")
    ax1.fill_between(x, before, after, color=COLORS["teal"], alpha=0.12)
    ax1.set_xticks(list(x))
    ax1.set_xticklabels(labels)
    ax1.set_ylim(0, 10)
    ax1.set_ylabel("평균 SUD")
    ax1.set_title("해결 전 기록 흐름")
    ax1.legend(frameon=False, loc="upper right")
    style_ax(ax1)

    ax2 = ax1.twinx()
    ax2.bar(x, delta, width=0.32, color=COLORS["coral"], alpha=0.75, label="SUD 감소")
    ax2.set_ylim(0, max(delta) + 0.8)
    ax2.set_ylabel("평균 SUD 감소", color=COLORS["coral"])
    ax2.tick_params(axis="y", colors=COLORS["coral"])
    for idx, value in enumerate(delta):
        ax2.text(idx, value + 0.04, f"{value:.2f}", ha="center", fontsize=9, color=COLORS["coral"])
    for spine in ax2.spines.values():
        spine.set_visible(False)
    fig.suptitle("해결된 걱정 그룹은 해결 직전까지 안정화 패턴이 유지된다", fontsize=15, fontweight="bold", color=COLORS["ink"], x=0.05, ha="left")
    savefig(fig, path)


def plot_timing_qc(timing_rows: list[dict], qc_rows: list[dict], path: Path) -> None:
    weeks = [r["주차"] for r in timing_rows]
    values = [r["해결 그룹 수"] for r in timing_rows]
    after_groups = sum(1 for r in qc_rows if r["해결 이후 일기 수"] > 0)
    after_diaries = sum(r["해결 이후 일기 수"] for r in qc_rows)

    fig, ax = plt.subplots(figsize=(9, 4.8), dpi=180)
    bars = ax.bar(weeks, values, color=[COLORS["gray"] if v == 0 else COLORS["teal"] for v in values], width=0.62)
    ax.set_xticks(weeks)
    ax.set_xlabel("해결 처리 주차")
    ax.set_ylabel("해결 그룹 수")
    ax.set_title("해결 처리 시점 분포")
    for bar, value in zip(bars, values):
        if value:
            ax.text(bar.get_x() + bar.get_width() / 2, value + 0.25, f"{value}개", ha="center", fontsize=10)
    note = f"정합성 점검: 해결 이후 동일 그룹 일기 {after_diaries}건 / {after_groups}개 그룹"
    ax.text(0.98, 0.86, note, transform=ax.transAxes, ha="right", va="center", fontsize=10, color=COLORS["coral"], bbox={"boxstyle": "round,pad=0.45", "fc": "#FFF4EF", "ec": "#F3C2B5"})
    style_ax(ax)
    savefig(fig, path)


def plot_topic_count_panel(topic_rows: list[dict], path: Path) -> None:
    rows = list(reversed(topic_rows))
    topics = [r["걱정 주제"] for r in rows]
    resolved = [r["해결 그룹 수"] for r in rows]
    active = [r["활성 그룹 수"] for r in rows]
    y = range(len(rows))

    fig, ax = plt.subplots(figsize=(7.2, 5.2), dpi=180)
    ax.barh(y, active, color="#DDE7E8", label="활성")
    ax.barh(y, resolved, left=active, color=COLORS["teal"], label="해결")
    ax.set_yticks(y)
    ax.set_yticklabels(topics)
    ax.set_xlabel("그룹 수")
    ax.set_title("걱정 주제별 해결 그룹 수")
    ax.legend(frameon=False, loc="lower right")
    for idx, (a, r) in enumerate(zip(active, resolved)):
        if r:
            ax.text(a + r + 0.25, idx, f"{r}개", va="center", color=COLORS["teal"], fontsize=10)
    style_ax(ax)
    savefig(fig, path)


def plot_topic_rate_panel(topic_rows: list[dict], path: Path) -> None:
    rows = list(reversed(topic_rows))
    topics = [r["걱정 주제"] for r in rows]
    resolved = [r["해결 그룹 수"] for r in rows]
    rates = [r["해결률"] for r in rows]
    y = range(len(rows))

    fig, ax = plt.subplots(figsize=(6.8, 5.2), dpi=180)
    ax.scatter(rates, y, s=[110 + r * 50 for r in resolved], color=COLORS["coral"], alpha=0.9)
    for idx, rate in enumerate(rates):
        ax.text(rate + 1.3, idx, f"{rate:.0f}%", va="center", color=COLORS["ink"], fontsize=10)
    ax.set_yticks(y)
    ax.set_yticklabels(topics)
    ax.set_xlim(0, max(35, max(rates) + 8))
    ax.set_xlabel("해결률")
    ax.set_title("개인 걱정 그룹 중 해결 비율")
    style_ax(ax)
    savefig(fig, path)


def plot_sud_prepost_panel(status_rows: list[dict], path: Path) -> None:
    fig, ax = plt.subplots(figsize=(7.2, 4.8), dpi=180)
    labels = [r["구분"] for r in status_rows]
    y_positions = range(len(labels))
    for y, row, color in zip(y_positions, status_rows, [COLORS["teal"], COLORS["blue"]]):
        before = row["평균 수행 전 SUD"]
        after = row["평균 수행 후 SUD"]
        ax.plot([before, after], [y, y], color=color, linewidth=4, alpha=0.55)
        ax.scatter([before], [y], s=120, color=COLORS["gold"], zorder=3, label="수행 전" if y == 0 else None)
        ax.scatter([after], [y], s=120, color=color, zorder=3, label="수행 후" if y == 0 else None)
        ax.text(before + 0.08, y + 0.1, f"{before:.2f}", color=COLORS["gold"], fontsize=10)
        ax.text(after - 0.55, y - 0.18, f"{after:.2f}", color=color, fontsize=10)
    ax.set_yticks(list(y_positions))
    ax.set_yticklabels(labels)
    ax.invert_yaxis()
    ax.set_xlim(0, 10)
    ax.set_xlabel("평균 SUD")
    ax.set_title("해결 그룹과 활성 그룹의 수행 전후 SUD")
    ax.legend(frameon=False, loc="lower right")
    style_ax(ax)
    savefig(fig, path)


def plot_sud_delta_panel(status_rows: list[dict], path: Path) -> None:
    fig, ax = plt.subplots(figsize=(6.2, 4.8), dpi=180)
    labels = [r["구분"] for r in status_rows]
    deltas = [r["평균 SUD 감소"] for r in status_rows]
    non_worse = [r["악화 없음 비율"] for r in status_rows]
    x = range(len(labels))
    bars = ax.bar(x, deltas, color=[COLORS["teal"], COLORS["blue"]], width=0.52)
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels)
    ax.set_ylabel("평균 SUD 감소")
    ax.set_title("해결 그룹과 활성 그룹의 즉시 안정화 폭")
    for bar, delta, nw in zip(bars, deltas, non_worse):
        ax.text(bar.get_x() + bar.get_width() / 2, delta + 0.03, f"{delta:.2f}점", ha="center", fontsize=10)
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            0.08,
            f"악화 없음\n{nw:.1f}%",
            ha="center",
            va="bottom",
            fontsize=9,
            color="white",
            fontweight="bold",
        )
    ax.set_ylim(0, max(deltas) + 0.35)
    style_ax(ax)
    savefig(fig, path)


def plot_gad_drop_panel(user_status_rows: list[dict], path: Path) -> None:
    rows = user_status_rows
    labels = [r["구분"] for r in rows]
    drops = [r["GAD-7 평균 감소"] for r in rows]
    users = [r["사용자 수"] for r in rows]
    x = range(len(labels))

    fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=180)
    bars = ax.bar(x, drops, color=[COLORS["teal"], COLORS["blue"]], width=0.5)
    ax.set_xticks(list(x))
    ax.set_xticklabels([f"{label}\n(n={n})" for label, n in zip(labels, users)])
    ax.set_ylabel("GAD-7 평균 감소점수")
    ax.set_title("해결 경험 유무별 GAD-7 변화")
    for bar, value in zip(bars, drops):
        ax.text(bar.get_x() + bar.get_width() / 2, value + 0.08, f"{value:.2f}점", ha="center", fontsize=11)
    ax.set_ylim(0, max(drops) + 0.8)
    style_ax(ax)
    savefig(fig, path)


def plot_gad_responder_panel(user_status_rows: list[dict], path: Path) -> None:
    rows = user_status_rows
    labels = [r["구분"] for r in rows]
    responder4 = [pct(r["4점 이상 개선 사용자 수"], r["사용자 수"]) for r in rows]
    responder3 = [pct(r["3점 이상 개선 사용자 수"], r["사용자 수"]) for r in rows]
    x = range(len(labels))
    width = 0.34

    fig, ax = plt.subplots(figsize=(6.8, 4.8), dpi=180)
    ax.bar([i - width / 2 for i in x], responder4, width=width, color=COLORS["teal"], label="4점 이상 개선")
    ax.bar([i + width / 2 for i in x], responder3, width=width, color=COLORS["gold"], label="3점 이상 개선")
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels)
    ax.set_ylim(0, 100)
    ax.set_ylabel("사용자 비율")
    ax.set_title("해결 경험 유무별 개선자 비율")
    for i, value in enumerate(responder4):
        ax.text(i - width / 2, value + 2, f"{value:.1f}%", ha="center", fontsize=9)
    for i, value in enumerate(responder3):
        ax.text(i + width / 2, value + 2, f"{value:.1f}%", ha="center", fontsize=9)
    ax.legend(frameon=False, loc="lower right")
    style_ax(ax)
    savefig(fig, path)


def plot_resolution_prepost_trajectory_panel(trajectory_rows: list[dict], path: Path) -> None:
    labels = [r["해결 전 기록 구간"] for r in trajectory_rows]
    before = [r["평균 수행 전 SUD"] for r in trajectory_rows]
    after = [r["평균 수행 후 SUD"] for r in trajectory_rows]
    x = range(len(labels))

    fig, ax = plt.subplots(figsize=(7.2, 4.8), dpi=180)
    ax.plot(x, before, marker="o", linewidth=2.8, color=COLORS["gold"], label="수행 전 SUD")
    ax.plot(x, after, marker="o", linewidth=2.8, color=COLORS["teal"], label="수행 후 SUD")
    ax.fill_between(x, before, after, color=COLORS["teal"], alpha=0.12)
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels)
    ax.set_ylim(0, 10)
    ax.set_ylabel("평균 SUD")
    ax.set_title("해결 전 수행 전후 SUD 흐름")
    ax.legend(frameon=False, loc="upper right")
    style_ax(ax)
    savefig(fig, path)


def plot_resolution_delta_trajectory_panel(trajectory_rows: list[dict], path: Path) -> None:
    labels = [r["해결 전 기록 구간"] for r in trajectory_rows]
    delta = [r["평균 SUD 감소"] for r in trajectory_rows]
    x = range(len(labels))

    fig, ax = plt.subplots(figsize=(6.8, 4.8), dpi=180)
    bars = ax.bar(x, delta, width=0.48, color=COLORS["coral"], alpha=0.82)
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels)
    ax.set_ylim(0, max(delta) + 0.45)
    ax.set_ylabel("평균 SUD 감소")
    ax.set_title("해결 전 구간별 즉시 안정화 폭")
    for bar, value in zip(bars, delta):
        ax.text(bar.get_x() + bar.get_width() / 2, value + 0.04, f"{value:.2f}", ha="center", fontsize=10, color=COLORS["coral"])
    style_ax(ax)
    savefig(fig, path)


def plot_timing_panel(timing_rows: list[dict], path: Path) -> None:
    weeks = [r["주차"] for r in timing_rows]
    values = [r["해결 그룹 수"] for r in timing_rows]

    fig, ax = plt.subplots(figsize=(7, 4.8), dpi=180)
    bars = ax.bar(weeks, values, color=[COLORS["gray"] if v == 0 else COLORS["teal"] for v in values], width=0.62)
    ax.set_xticks(weeks)
    ax.set_xlabel("해결 처리 주차")
    ax.set_ylabel("해결 그룹 수")
    ax.set_title("해결 처리 시점 분포")
    for bar, value in zip(bars, values):
        if value:
            ax.text(bar.get_x() + bar.get_width() / 2, value + 0.25, f"{value}개", ha="center", fontsize=10)
    style_ax(ax)
    savefig(fig, path)


def plot_qc_panel(qc_rows: list[dict], path: Path) -> None:
    rows = sorted(qc_rows, key=lambda r: r["해결 이후 일기 수"], reverse=True)
    labels = [f"{r['user_id']}\n{r['걱정 주제']}" for r in rows if r["해결 이후 일기 수"] > 0]
    values = [r["해결 이후 일기 수"] for r in rows if r["해결 이후 일기 수"] > 0]

    fig, ax = plt.subplots(figsize=(8.2, 4.8), dpi=180)
    if values:
        y = range(len(values))
        ax.barh(y, values, color=COLORS["coral"], alpha=0.82)
        ax.set_yticks(y)
        ax.set_yticklabels(labels, fontsize=8)
        ax.invert_yaxis()
        for idx, value in enumerate(values):
            ax.text(value + 0.04, idx, f"{value}건", va="center", fontsize=9)
        ax.set_xlim(0, max(values) + 0.8)
    else:
        ax.text(0.5, 0.5, "해결 이후 동일 그룹 일기 없음", ha="center", va="center", transform=ax.transAxes, fontsize=14, color=COLORS["teal"])
        ax.set_xticks([])
        ax.set_yticks([])
    ax.set_xlabel("해결 이후 일기 수")
    ax.set_title("해결 이후 동일 그룹 기록 점검")
    style_ax(ax)
    savefig(fig, path)


def plot_individual_panels(metrics: dict) -> None:
    PANEL_DIR.mkdir(parents=True, exist_ok=True)
    plot_topic_count_panel(metrics["topic_rows"], PANEL_DIR / "21a_resolution_topic_counts.png")
    plot_topic_rate_panel(metrics["topic_rows"], PANEL_DIR / "21b_resolution_topic_rates.png")
    plot_sud_prepost_panel(metrics["status_rows"], PANEL_DIR / "22a_resolution_sud_prepost.png")
    plot_sud_delta_panel(metrics["status_rows"], PANEL_DIR / "22b_resolution_sud_delta_nonworse.png")
    plot_gad_drop_panel(metrics["user_status_rows"], PANEL_DIR / "23a_resolution_gad7_drop.png")
    plot_gad_responder_panel(metrics["user_status_rows"], PANEL_DIR / "23b_resolution_gad7_responder_rate.png")
    plot_resolution_prepost_trajectory_panel(metrics["trajectory_rows"], PANEL_DIR / "24a_resolution_sud_prepost_trajectory.png")
    plot_resolution_delta_trajectory_panel(metrics["trajectory_rows"], PANEL_DIR / "24b_resolution_sud_delta_trajectory.png")
    plot_timing_panel(metrics["timing_rows"], PANEL_DIR / "25a_resolution_timing.png")
    plot_qc_panel(metrics["qc_rows"], PANEL_DIR / "25b_resolution_qc_after_diaries.png")


def main() -> None:
    setup_font()
    CHART_DIR.mkdir(parents=True, exist_ok=True)
    TABLE_DIR.mkdir(parents=True, exist_ok=True)
    metrics = collect_metrics()

    write_csv(TABLE_DIR / "resolution_topic_summary.csv", metrics["topic_rows"])
    write_csv(TABLE_DIR / "resolution_group_status_summary.csv", metrics["status_rows"])
    write_csv(TABLE_DIR / "resolution_user_status_summary.csv", metrics["user_status_rows"])
    write_csv(TABLE_DIR / "resolution_sud_trajectory.csv", metrics["trajectory_rows"])
    write_csv(TABLE_DIR / "resolution_timing_summary.csv", metrics["timing_rows"])
    write_csv(TABLE_DIR / "resolution_archive_qc.csv", metrics["qc_rows"])

    plot_topic_resolution(metrics["topic_rows"], CHART_DIR / "21_resolution_topic_rate.png")
    plot_sud_comparison(metrics["status_rows"], CHART_DIR / "22_resolution_vs_active_sud.png")
    plot_user_gad(metrics["user_status_rows"], CHART_DIR / "23_resolution_experience_gad7.png")
    plot_resolution_trajectory(metrics["trajectory_rows"], CHART_DIR / "24_resolution_sud_trajectory.png")
    plot_timing_qc(metrics["timing_rows"], metrics["qc_rows"], CHART_DIR / "25_resolution_timing_qc.png")
    plot_individual_panels(metrics)

    print(json.dumps(metrics["summary"], ensure_ascii=False, indent=2))
    print("charts:")
    for name in [
        "21_resolution_topic_rate.png",
        "22_resolution_vs_active_sud.png",
        "23_resolution_experience_gad7.png",
        "24_resolution_sud_trajectory.png",
        "25_resolution_timing_qc.png",
    ]:
        print(CHART_DIR / name)
    print("panels:")
    for path in sorted(PANEL_DIR.glob("*.png")):
        print(path)


if __name__ == "__main__":
    main()
