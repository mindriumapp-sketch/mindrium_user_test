#!/usr/bin/env python3
"""Rebuild final comprehensive chart PNGs only.

This wrapper keeps the existing final report/tables untouched. It reuses the
current comprehensive-analysis plotting functions, then applies the latest
presentation rule that school, Sungkyunkwan University, and lab contexts are
shown as one "학교/연구실" location group.
"""

from __future__ import annotations

import importlib.util
import os
import shutil
import sys
from collections import Counter, defaultdict
from pathlib import Path


os.environ.setdefault("MPLCONFIGDIR", "/private/tmp/mindrium_matplotlib_cache")

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "build_final_comprehensive_analysis.py"
LAB_ROOT = Path("/Users/ubdbd/Desktop/연구실/범불안장애 DTx/Lab_test")
DATA_DIR = LAB_ROOT / "lab_8week_location_context_backup"
OUT_DIR = Path(os.environ.get("MINDRIUM_FINAL_CHART_OUT", "/private/tmp/mindrium_final_comprehensive_charts"))
REPORT_DIR = LAB_ROOT / "analytics_report" / "final_comprehensive"


def load_analysis_module():
    spec = importlib.util.spec_from_file_location("mindrium_final_analysis", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load analysis module: {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def canonical_location(label: str | None) -> str | None:
    if not label:
        return None
    if label in {"학교", "성균관대학교", "연구실", "직장"}:
        return "학교/연구실"
    if label == "병원/상담센터":
        return "병원"
    if label in {"헬스장", "이동 중"}:
        return None
    return label


def merge_location_summary(raw: dict) -> dict:
    merged = defaultdict(lambda: {"count": 0, "sud": [], "users": set(), "auto": 0})
    for label, row in raw.items():
        mapped = canonical_location(label)
        if mapped is None:
            continue
        merged[mapped]["count"] += int(row.get("count", 0))
        merged[mapped]["sud"].extend(row.get("sud", []))
        merged[mapped]["users"].update(row.get("users", set()))
        merged[mapped]["auto"] += int(row.get("auto", 0))
    return dict(merged)


def merge_pair_counter(raw: Counter) -> Counter:
    merged = Counter()
    for (label, other), count in raw.items():
        mapped = canonical_location(label)
        if mapped is not None:
            merged[(mapped, other)] += count
    return merged


def merge_pair_lists(raw: dict) -> dict:
    merged = defaultdict(list)
    for (label, other), values in raw.items():
        mapped = canonical_location(label)
        if mapped is not None:
            merged[(mapped, other)].extend(values)
    return dict(merged)


def merge_topic_counter(raw: Counter) -> Counter:
    merged = Counter()
    for (label, topic), count in raw.items():
        mapped = canonical_location(label)
        if mapped is not None:
            merged[(mapped, topic)] += count
    return merged


def merge_location_hour(raw: Counter) -> Counter:
    merged = Counter()
    for (label, hour), count in raw.items():
        mapped = canonical_location(label)
        if mapped is not None:
            merged[(mapped, hour)] += count
    return merged


def apply_final_location_grouping(derived: dict) -> dict:
    derived = dict(derived)
    derived["location_summary"] = merge_location_summary(derived["location_summary"])
    derived["location_period"] = merge_pair_counter(derived["location_period"])
    derived["location_period_sud"] = merge_pair_lists(derived["location_period_sud"])
    derived["location_hour"] = merge_location_hour(derived["location_hour"])
    derived["location_topic"] = merge_topic_counter(derived["location_topic"])
    derived["location_activity"] = merge_topic_counter(derived["location_activity"])

    mapped_diaries = []
    for row in derived["diary_rows"]:
        copied = dict(row)
        mapped = canonical_location(copied.get("location"))
        copied["location"] = mapped or ""
        if not mapped:
            copied["period"] = ""
            copied["hour"] = ""
        mapped_diaries.append(copied)
    derived["diary_rows"] = mapped_diaries
    derived["missing_location"] = sum(1 for row in mapped_diaries if not row.get("location"))
    derived["auto_location"] = sum(int(row.get("auto", 0)) for row in derived["location_summary"].values())

    mapped_sud = []
    for row in derived["sud_records"]:
        copied = dict(row)
        if copied.get("location") != "위치 없음":
            copied["location"] = canonical_location(copied.get("location")) or "위치 없음"
        mapped_sud.append(copied)
    derived["sud_records"] = mapped_sud
    return derived


def build_chart_tables(module, derived: dict) -> dict:
    user_rows = derived["user_rows"]
    weekly_sud = module.weekly_sud_rows(derived["sud_records"])

    weekly_adherence = []
    weekly_burden = []
    for week in range(1, 9):
        task_count = derived["weekly_diary_counts"][week] + derived["weekly_relax_counts"][week]
        weekly_adherence.append(
            {
                "주차": week,
                "일기 수": derived["weekly_diary_counts"][week],
                "이완 수": derived["weekly_relax_counts"][week],
                "평균 사용 시간(분)": round(derived["weekly_screen_minutes"][week] / len(user_rows), 1),
                "앱 세션 수": derived["weekly_screen_sessions"][week],
            }
        )
        weekly_burden.append(
            {
                "주차": week,
                "평균 사용 시간(분)": round(derived["weekly_screen_minutes"][week] / len(user_rows), 1),
                "평균 교육 시간(분)": round(derived["weekly_edu_minutes"][week] / len(user_rows), 1),
                "평균 과제 수": round(task_count / len(user_rows), 1),
                "앱 세션 수": derived["weekly_screen_sessions"][week],
            }
        )

    worsening_week, worsening_topic, worsening_context = module.build_worsening_rows(derived["sud_records"])
    return {
        "weekly_sud": weekly_sud,
        "weekly_adherence": weekly_adherence,
        "weekly_burden": weekly_burden,
        "early_signal_rows": module.build_early_signal_rows(user_rows),
        "notification_alignment_rows": module.build_notification_alignment_rows(derived),
        "context_topic_rows": module.build_context_topic_rows(derived["diary_rows"]),
        "worsening_week_rows": worsening_week,
        "worsening_topic_rows": worsening_topic,
        "worsening_context_rows": worsening_context,
        "archetype_rows": module.classify_user_archetypes(user_rows),
    }


def rebuild_charts(module, derived: dict, tables: dict, chart_dir: Path) -> None:
    if chart_dir.exists():
        shutil.rmtree(chart_dir)
    chart_dir.mkdir(parents=True, exist_ok=True)

    module.plot_gad_outcomes(derived["user_rows"], chart_dir / "01_gad7_outcome_and_response.png")
    module.plot_gad_transition(derived["user_rows"], chart_dir / "02_gad7_severity_transition.png")
    module.plot_phq_baseline(derived["user_rows"], chart_dir / "03_phq9_baseline_distribution.png")
    module.plot_weekly_sud(tables["weekly_sud"], chart_dir / "04_weekly_sud_trajectory.png")
    module.plot_sud_delta_safety(tables["weekly_sud"], chart_dir / "05_sud_delta_and_nonworsening.png")
    module.plot_adherence_weekly(tables["weekly_adherence"], chart_dir / "06_weekly_adherence_and_screen_time.png")
    module.plot_dose_response(derived["user_rows"], chart_dir / "07_dose_response_active_tasks.png")
    module.plot_mechanism(
        derived["sud_records"],
        derived["user_rows"],
        derived["behavior_counts"],
        derived["eval_total"],
        derived["eval_effective"],
        derived["continue_total"],
        derived["will_continue"],
        chart_dir / "08_mechanism_and_week8_evaluation.png",
    )
    module.plot_worry_bubble(derived["topic_counts"], derived["topic_sud"], chart_dir / "09_worry_topic_frequency_burden.png")
    module.plot_location_count_sud(derived["location_summary"], chart_dir / "10_location_count_and_sud.png")
    module.plot_location_period_heatmap(
        derived["location_period_sud"],
        derived["location_period"],
        derived["location_summary"],
        chart_dir / "11_location_period_sud_heatmap.png",
    )
    module.plot_hourly_diary_screen(derived["location_hour"], derived["screen_hours"], chart_dir / "12_hourly_diary_and_app_sessions.png")
    module.plot_user_segments(derived["user_rows"], chart_dir / "13_response_segment_usage_patterns.png")
    module.plot_user_trajectories(derived["user_rows"], derived["sud_records"], chart_dir / "14_user_sud_trajectories.png")
    module.plot_early_signal(tables["early_signal_rows"], derived["user_rows"], chart_dir / "15_early_signal_predictors.png")
    module.plot_notification_alignment(tables["notification_alignment_rows"], derived["user_rows"], chart_dir / "16_notification_alignment.png")
    module.plot_context_topic_burden(tables["context_topic_rows"], chart_dir / "17_context_topic_burden.png")
    module.plot_worsening_context(
        tables["worsening_week_rows"],
        tables["worsening_topic_rows"],
        tables["worsening_context_rows"],
        chart_dir / "18_sud_worsening_context.png",
    )
    module.plot_user_archetypes(tables["archetype_rows"], chart_dir / "19_user_archetypes.png")
    module.plot_weekly_ux_burden(tables["weekly_burden"], chart_dir / "20_weekly_ux_burden.png")


def update_report_outputs(module, derived: dict, chart_dir: Path) -> None:
    table_dir = REPORT_DIR / "tables"
    table_dir.mkdir(parents=True, exist_ok=True)
    table_data = module.build_tables(derived, table_dir)
    metrics = module.build_key_metrics(derived, table_data)
    module.build_report(derived, table_data, metrics, REPORT_DIR, chart_dir)

    replacements = {
        "병원/상담센터": "병원",
        "핵심 위치(집, 학교, 연구실, 성균관대학교)": "핵심 위치(집, 학교/연구실)",
        "집, 학교, 연구실, 성균관대학교": "집, 학교/연구실",
        "집·학교·연구실·성균관대학교": "집·학교/연구실",
    }
    for rel in [
        "mindrium_final_comprehensive_report.html",
        "mindrium_final_comprehensive_insights.md",
        "final_comprehensive_validation.md",
    ]:
        path = REPORT_DIR / rel
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for before, after in replacements.items():
            text = text.replace(before, after)
        path.write_text(text, encoding="utf-8")


def main() -> None:
    update_report = "--update-report" in sys.argv
    module = load_analysis_module()
    module.LOCATION_ORDER = ["집", "학교/연구실", "병원", "카페/모임 장소"]
    module.CORE_LOCATIONS = {"집", "학교/연구실"}
    module.setup_font()

    data = {name: module.read_json(DATA_DIR / f"{name}.json") for name in module.COLLECTIONS}
    derived = apply_final_location_grouping(module.build_derived(data))
    tables = build_chart_tables(module, derived)
    rebuild_charts(module, derived, tables, OUT_DIR)
    if update_report:
        update_report_outputs(module, derived, REPORT_DIR / "charts")

    chart_files = sorted(OUT_DIR.glob("*.png"))
    location_labels = sorted(derived["location_summary"].keys())
    print(f"OUT_DIR={OUT_DIR}")
    print(f"CHARTS={len(chart_files)}")
    print(f"LOCATION_LABELS={', '.join(location_labels)}")
    if update_report:
        print(f"UPDATED_REPORT_DIR={REPORT_DIR}")


if __name__ == "__main__":
    main()
