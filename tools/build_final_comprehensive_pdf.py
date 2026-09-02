#!/usr/bin/env python3
"""Create a polished PDF report from the final comprehensive Mindrium analysis."""

from __future__ import annotations

import csv
import textwrap
from datetime import datetime
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib import font_manager
from matplotlib.patches import FancyBboxPatch, Rectangle
from PIL import Image


FONT_PATH = "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
PAGE_W = 13.333
PAGE_H = 7.5
BG = "#F7FAFB"
INK = "#24323A"
MUTED = "#65757F"
LINE = "#D8E0E4"
BLUE = "#376F95"
TEAL = "#2F9B91"
CORAL = "#E86F56"
GOLD = "#E6A93F"
GREEN = "#638F58"
PURPLE = "#8C5FBF"
WHITE = "#FFFFFF"


def find_report_root() -> Path:
    candidates = sorted(Path("/Users/ubdbd/Desktop").rglob("Lab_test/analytics_report/final_comprehensive"))
    if not candidates:
        raise FileNotFoundError("final_comprehensive report folder not found")
    return candidates[0]


def setup_font():
    font_manager.fontManager.addfont(FONT_PATH)
    prop = font_manager.FontProperties(fname=FONT_PATH)
    plt.rcParams["font.family"] = prop.get_name()
    plt.rcParams["axes.unicode_minus"] = False
    plt.rcParams["pdf.fonttype"] = 42
    return prop


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def page(pdf: PdfPages, title: str | None = None, subtitle: str | None = None):
    fig = plt.figure(figsize=(PAGE_W, PAGE_H), dpi=160)
    fig.patch.set_facecolor(BG)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    if title:
        ax.text(0.055, 0.93, title, fontsize=22, fontweight="bold", color=INK, va="top")
    if subtitle:
        ax.text(0.055, 0.885, subtitle, fontsize=10.5, color=MUTED, va="top")
    return fig, ax


def close_page(pdf: PdfPages, fig, page_no: int):
    ax = fig.axes[0]
    ax.text(0.945, 0.035, f"{page_no:02d}", fontsize=9, color=MUTED, ha="right", va="center")
    pdf.savefig(fig, facecolor=fig.get_facecolor())
    plt.close(fig)


def card(ax, x, y, w, h, title, value, note="", color=BLUE):
    ax.add_patch(
        FancyBboxPatch(
            (x, y),
            w,
            h,
            boxstyle="round,pad=0.012,rounding_size=0.018",
            linewidth=0.8,
            edgecolor=LINE,
            facecolor=WHITE,
        )
    )
    ax.add_patch(Rectangle((x, y + h - 0.012), w, 0.012, color=color, linewidth=0))
    title_size = 8.4 if h >= 0.12 else 7.2
    value_size = 18.5 if h >= 0.12 else 13.5
    note_size = 7.8 if h >= 0.12 else 6.7
    title_y = y + h - (0.038 if h >= 0.12 else 0.03)
    value_y = y + h * (0.48 if h >= 0.12 else 0.47)
    note_y = y + (0.028 if h >= 0.12 else 0.022)
    ax.text(x + 0.025, title_y, title, fontsize=title_size, color=MUTED, va="top")
    ax.text(x + 0.025, value_y, value, fontsize=value_size, color=INK, fontweight="bold", va="center")
    if note:
        ax.text(x + 0.025, note_y, note, fontsize=note_size, color=MUTED, va="bottom")


def bullet_list(ax, x, y, items, width_chars=58, line_gap=0.04, size=10.2):
    cursor = y
    for item in items:
        lines = textwrap.wrap(item, width=width_chars)
        if not lines:
            continue
        ax.text(x, cursor, "- " + lines[0], fontsize=size, color=INK, va="top")
        cursor -= line_gap
        for extra in lines[1:]:
            ax.text(x + 0.018, cursor, extra, fontsize=size, color=INK, va="top")
            cursor -= line_gap
        cursor -= 0.008
    return cursor


def add_image(fig, path: Path, box):
    ax = fig.add_axes(box)
    ax.axis("off")
    img = Image.open(path)
    ax.imshow(img)
    return ax


def table(ax, x, y, w, rows, columns, widths=None, row_h=0.045, header_color=BLUE, max_rows=10):
    if widths is None:
        widths = [1 / len(columns)] * len(columns)
    total_w = sum(widths)
    widths = [width / total_w * w for width in widths]
    ax.add_patch(FancyBboxPatch((x, y - row_h), w, row_h, boxstyle="round,pad=0.004,rounding_size=0.008", facecolor=header_color, edgecolor=header_color))
    xx = x
    for col, ww in zip(columns, widths):
        ax.text(xx + 0.008, y - row_h / 2, col, fontsize=8.8, color=WHITE, va="center", fontweight="bold")
        xx += ww
    cursor = y - row_h
    for idx, row in enumerate(rows[:max_rows]):
        cursor -= row_h
        fill = WHITE if idx % 2 == 0 else "#F1F6F8"
        ax.add_patch(Rectangle((x, cursor), w, row_h, facecolor=fill, edgecolor=LINE, linewidth=0.4))
        xx = x
        for col, ww in zip(columns, widths):
            ax.text(xx + 0.008, cursor + row_h / 2, str(row.get(col, "")), fontsize=8.4, color=INK, va="center")
            xx += ww


def section_label(ax, x, y, label, color=TEAL):
    ax.text(x, y, label, fontsize=11, color=color, fontweight="bold", va="top")
    ax.plot([x, x + 0.12], [y - 0.014, y - 0.014], color=color, linewidth=2)


def build_pdf():
    setup_font()
    root = find_report_root()
    chart_dir = root / "charts"
    table_dir = root / "tables"
    out_pdf = root / "mindrium_final_comprehensive_report.pdf"

    weekly = read_csv(table_dir / "weekly_sud_summary.csv")
    dose = read_csv(table_dir / "dose_response_summary.csv")
    loc = read_csv(table_dir / "location_summary.csv")
    burden = read_csv(table_dir / "high_burden_context_windows.csv")
    segment = read_csv(table_dir / "response_segment_summary.csv")
    topics = read_csv(table_dir / "worry_topic_summary.csv")

    page_no = 1
    with PdfPages(out_pdf) as pdf:
        fig, ax = page(pdf)
        ax.add_patch(Rectangle((0, 0), 1, 1, color=BG))
        ax.add_patch(Rectangle((0, 0.78), 1, 0.22, color="#E8F2F6"))
        ax.text(0.06, 0.89, "Mindrium 8주 Lab Test", fontsize=26, fontweight="bold", color=INK, va="center")
        ax.text(0.06, 0.83, "최종 데이터 통합 분석 리포트", fontsize=17, color=BLUE, va="center")
        ax.text(0.06, 0.755, "결과 변화, 사용 패턴, 위치/시간 맥락을 함께 해석한 요약본", fontsize=11, color=MUTED)
        cards = [
            ("분석 대상", "40명", "8주 완료 사용자", BLUE),
            ("GAD-7 평균 감소", "3.88점", "15.10 -> 11.22", TEAL),
            ("4점 이상 개선", "52.5%", "21/40명", GREEN),
            ("SUD 악화 없음", "90.1%", "2,214개 기록 기준", CORAL),
            ("위치 연결", "84.2%", "2,521/2,994건", PURPLE),
            ("핵심 위치 집중도", "86.9%", "집/학교/연구실/성균관대", GOLD),
        ]
        for i, (t, v, n, c) in enumerate(cards):
            card(ax, 0.06 + (i % 3) * 0.305, 0.48 - (i // 3) * 0.19, 0.27, 0.13, t, v, n, c)
        bullet_list(
            ax,
            0.06,
            0.205,
            [
                "평균 변화보다 개선자 비율과 중증도 이동을 먼저 제시하는 것이 설득력이 높다.",
                "능동 과제인 일기와 대안적 생각은 결과 변화와 더 가까운 관계를 보인다.",
                "위치/시간 분석은 언제, 어디서 부담이 커지는지 보여주며 맞춤 알림과 과제 추천 근거가 된다.",
            ],
            width_chars=78,
            size=10.5,
        )
        ax.text(0.06, 0.055, f"생성일: {datetime.now().strftime('%Y-%m-%d')}", fontsize=8.5, color=MUTED)
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "1. 핵심 결과", "GAD-7 변화, 개선자 비율, 중증도 이동")
        add_image(fig, chart_dir / "01_gad7_outcome_and_response.png", [0.055, 0.24, 0.43, 0.54])
        add_image(fig, chart_dir / "02_gad7_severity_transition.png", [0.53, 0.24, 0.36, 0.54])
        section_label(ax, 0.055, 0.2, "해석")
        bullet_list(
            ax,
            0.055,
            0.16,
            [
                "GAD-7 평균은 15.10점에서 11.22점으로 낮아졌고, 평균 감소량은 3.88점이다.",
                "4점 이상 개선자는 21명, 3점 이상 개선자는 29명이다.",
                "시작 시점 높은 불안군 24명 중 22명이 8주 후 중등도 이하로 이동했다.",
            ],
            width_chars=110,
            line_gap=0.035,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "2. 시작 시점 상태", "PHQ-9은 시작 시점 분포로만 해석")
        add_image(fig, chart_dir / "03_phq9_baseline_distribution.png", [0.055, 0.27, 0.48, 0.5])
        card(ax, 0.59, 0.6, 0.3, 0.12, "PHQ-9 평균", "6.83점", "사후 PHQ-9 미수집", BLUE)
        card(ax, 0.59, 0.43, 0.3, 0.12, "거의 없음/경도", "31명", "시작 시점 기준", TEAL)
        bullet_list(
            ax,
            0.59,
            0.29,
            [
                "PHQ-9은 변화량이 아니라 시작 시점 배경 특성으로 제시하는 것이 정확하다.",
                "전체적으로 우울 증상은 거의 없음 또는 경도에 많이 분포한다.",
            ],
            width_chars=42,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "3. SUD 변화와 안정성", "3주차 이후 수행 전후 SUD 기록 기반")
        add_image(fig, chart_dir / "04_weekly_sud_trajectory.png", [0.055, 0.31, 0.42, 0.47])
        add_image(fig, chart_dir / "05_sud_delta_and_nonworsening.png", [0.525, 0.31, 0.42, 0.47])
        table(
            ax,
            0.065,
            0.24,
            0.86,
            weekly,
            ["주차", "기록 수", "평균 수행 후 SUD", "평균 SUD 감소량", "악화 없음 비율"],
            widths=[0.1, 0.16, 0.24, 0.24, 0.18],
            row_h=0.034,
            max_rows=6,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "4. 사용량과 결과의 관계", "단순 사용 시간보다 능동 과제의 설명력이 더 큼")
        add_image(fig, chart_dir / "06_weekly_adherence_and_screen_time.png", [0.055, 0.47, 0.42, 0.31])
        add_image(fig, chart_dir / "07_dose_response_active_tasks.png", [0.53, 0.47, 0.42, 0.31])
        table(
            ax,
            0.055,
            0.38,
            0.89,
            dose,
            ["사용 지표", "결과 지표", "하위 10명 평균", "상위 10명 평균", "상위-하위 차이"],
            widths=[0.22, 0.19, 0.19, 0.19, 0.16],
            row_h=0.04,
            max_rows=5,
            header_color=TEAL,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "5. 작동 기전과 8주차 평가", "5주차 이후 대안적 생각과 행동 계획의 사용 패턴")
        add_image(fig, chart_dir / "08_mechanism_and_week8_evaluation.png", [0.06, 0.34, 0.72, 0.43])
        card(ax, 0.81, 0.61, 0.13, 0.11, "5주차 이후", "+0.32점", "즉시 SUD 감소폭", TEAL)
        card(ax, 0.81, 0.46, 0.13, 0.11, "효과 있음", "98.1%", "8주차 평가", GREEN)
        card(ax, 0.81, 0.31, 0.13, 0.11, "유지 의도", "75.0%", "8주차 평가", BLUE)
        bullet_list(
            ax,
            0.06,
            0.24,
            [
                "5주차 이후 즉시 SUD 감소폭이 커져 구조화된 불안 조절 패턴이 관찰된다.",
                "직면 행동과 유지 의도는 후반부 과제의 지속 가능성을 설명하는 보조 지표다.",
            ],
            width_chars=92,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "6. 걱정 주제별 부담", "자주 기록되는 주제와 부담이 큰 주제를 분리")
        add_image(fig, chart_dir / "09_worry_topic_frequency_burden.png", [0.055, 0.32, 0.54, 0.46])
        table(
            ax,
            0.65,
            0.75,
            0.29,
            topics,
            ["걱정 주제", "일기 수", "평균 수행 후 SUD"],
            widths=[0.45, 0.22, 0.3],
            row_h=0.043,
            max_rows=8,
            header_color=PURPLE,
        )
        bullet_list(
            ax,
            0.055,
            0.24,
            [
                "발표와 평가, 미래 계획, 건강 염려는 평균 SUD가 상대적으로 높다.",
                "기본 그룹은 빈도가 가장 높지만, 부담 기준의 우선순위와는 다르게 해석해야 한다.",
            ],
            width_chars=96,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "7. 위치 기반 사용 맥락", "Lab test 환경의 생활 반경과 부담 장소")
        add_image(fig, chart_dir / "10_location_count_and_sud.png", [0.055, 0.36, 0.5, 0.42])
        table(
            ax,
            0.61,
            0.75,
            0.33,
            loc,
            ["위치", "일기 수", "평균 수행 후 SUD"],
            widths=[0.42, 0.22, 0.33],
            row_h=0.043,
            max_rows=8,
            header_color=BLUE,
        )
        bullet_list(
            ax,
            0.055,
            0.27,
            [
                "집, 학교, 연구실, 성균관대학교가 위치 연결 기록의 86.9%를 차지한다.",
                "이동 중과 병원/상담센터는 빈도는 낮지만 평균 SUD가 높아 개인화 개입 후보로 볼 수 있다.",
            ],
            width_chars=100,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "8. 위치 x 시간대 부담", "어디서, 어느 시간대에 부담이 높아지는가")
        add_image(fig, chart_dir / "11_location_period_sud_heatmap.png", [0.055, 0.25, 0.45, 0.53])
        table(
            ax,
            0.56,
            0.74,
            0.38,
            burden,
            ["위치", "시간대", "일기 수", "평균 수행 후 SUD"],
            widths=[0.28, 0.18, 0.18, 0.3],
            row_h=0.043,
            max_rows=8,
            header_color=CORAL,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "9. 시간대별 앱 사용 맥락", "일기 기록과 앱 세션의 시간대 패턴")
        add_image(fig, chart_dir / "12_hourly_diary_and_app_sessions.png", [0.055, 0.31, 0.55, 0.47])
        bullet_list(
            ax,
            0.66,
            0.68,
            [
                "오후에는 수업, 연구실 업무, 발표 준비 중간에 일기 기록이 집중된다.",
                "밤과 심야에는 집에서 회고하거나 불안을 정리하는 기록이 늘어난다.",
                "앱 세션은 짧고 반복적이며, 과제 완료율과 능동 입력을 KPI로 보는 편이 적절하다.",
            ],
            width_chars=40,
            line_gap=0.044,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "10. 개선 그룹별 사용 패턴", "개선 정도에 따라 사용 행동이 다르게 나타남")
        add_image(fig, chart_dir / "13_response_segment_usage_patterns.png", [0.055, 0.36, 0.63, 0.42])
        table(
            ax,
            0.72,
            0.75,
            0.23,
            segment,
            ["개선 그룹", "사용자 수", "평균 SUD 감소"],
            widths=[0.48, 0.22, 0.28],
            row_h=0.052,
            max_rows=3,
            header_color=TEAL,
        )
        bullet_list(
            ax,
            0.055,
            0.27,
            [
                "4점 이상 개선군은 평균 일기 수와 대안적 생각 수가 높고, SUD 감소폭도 크다.",
                "이완 수행 수 자체보다 일기와 대안적 생각 같은 능동 입력이 결과와 더 가까운 지표로 보인다.",
            ],
            width_chars=100,
        )
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "11. 사용자별 SUD 궤적", "동일 완료군 안에서도 개인별 변화 양상은 다름")
        add_image(fig, chart_dir / "14_user_sud_trajectories.png", [0.055, 0.13, 0.89, 0.72])
        close_page(pdf, fig, page_no); page_no += 1

        fig, ax = page(pdf, "12. 결론", "발표에서 가져갈 핵심 메시지")
        bullet_list(
            ax,
            0.08,
            0.76,
            [
                "평균 감소만 보여주기보다 개선자 비율과 중증도 이동을 함께 제시하면 결과 해석이 더 직관적이다.",
                "일기와 대안적 생각은 결과 변화와 연결되는 핵심 능동 과제로 보인다.",
                "SUD는 3주차 이후 꾸준히 낮아졌고, 대부분의 수행 기록에서 즉시 악화 없이 과제가 종료됐다.",
                "위치/시간 분석은 연구실 기반 Lab test의 통제된 생활 반경과 생활 노이즈를 함께 보여준다.",
                "연구실 심야, 집 심야, 학교 오후는 부담이 커지는 주요 맥락으로 볼 수 있다.",
                "다음 분석 단계에서는 위치/시간 기반 맞춤 알림, 고부담 맥락별 추천 과제, 사용자군별 유지 전략을 설계할 수 있다.",
            ],
            width_chars=105,
            line_gap=0.052,
            size=11.2,
        )
        close_page(pdf, fig, page_no)

    print(out_pdf)


if __name__ == "__main__":
    build_pdf()
