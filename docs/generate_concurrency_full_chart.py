"""Generate SVG charts for the full concurrency performance metrics dataset.

Reads `concurrency_full_metrics.csv` and writes `concurrency_full_chart.svg`
in the same folder. No external dependencies required. You can open the CSV
directly in Excel and insert the generated SVG as an image, or recreate the
same charts inside Excel using the columns provided.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import List


DATA_FILE = Path(__file__).with_name("concurrency_full_metrics.csv")
SVG_FILE = Path(__file__).with_name("concurrency_full_chart.svg")


@dataclass
class Series:
    name: str
    color: str
    values: List[float]


def read_data(csv_path: Path) -> List[dict]:
    rows: List[dict] = []
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({k: float(v) for k, v in row.items()})
    return rows


def make_path(xs: List[float], ys: List[float]) -> str:
    points = ["M", f"{xs[0]:.2f}", f"{ys[0]:.2f}"]
    for x, y in zip(xs[1:], ys[1:]):
        points.extend(["L", f"{x:.2f}", f"{y:.2f}"])
    return " ".join(points)


def linspace(start: float, end: float, n: int) -> List[float]:
    if n == 1:
        return [start]
    step = (end - start) / (n - 1)
    return [start + step * i for i in range(n)]


def normalize(values: List[float], height: float, top: float, pad_ratio: float = 0.1) -> tuple[List[float], float, float]:
    v_max = max(values)
    v_min = min(values)
    pad = (v_max - v_min) * pad_ratio or 1.0
    upper = v_max + pad
    lower = max(0.0, v_min - pad)
    scale = height / (upper - lower)
    return [top + (upper - v) * scale for v in values], lower, upper


def render_chart(
    x_labels: List[int],
    series_list: List[Series],
    title: str,
    y_label: str,
    origin_x: float,
    origin_y: float,
    plot_w: float,
    plot_h: float,
    grid_lines: int = 4,
) -> str:
    svg_parts: List[str] = []
    margin_left = origin_x
    margin_top = origin_y

    xs = linspace(margin_left + 40, margin_left + plot_w - 20, len(x_labels))
    y_positions_by_series = []
    y_min = 0.0
    y_max = 0.0

    for s in series_list:
        ys, ymin, ymax = normalize(s.values, plot_h - 40, margin_top + 10)
        y_positions_by_series.append((s, ys))
        y_min = min(y_min, ymin)
        y_max = max(y_max, ymax)

    x_axis = margin_top + plot_h
    svg_parts.append(f'<line x1="{margin_left}" y1="{x_axis}" x2="{margin_left + plot_w}" y2="{x_axis}" stroke="#444" stroke-width="1"/>')
    svg_parts.append(f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{x_axis}" stroke="#444" stroke-width="1"/>')

    for i in range(grid_lines + 1):
        y = margin_top + 10 + (plot_h - 40) * i / grid_lines
        val = y_max - (y_max - y_min) * i / grid_lines
        svg_parts.append(f'<line x1="{margin_left}" y1="{y}" x2="{margin_left + plot_w}" y2="{y}" stroke="#ddd" stroke-width="1"/>')
        svg_parts.append(f'<text x="{margin_left - 8}" y="{y + 4}" font-size="11" text-anchor="end" fill="#666">{val:.1f}</text>')

    for x, label in zip(xs, x_labels):
        svg_parts.append(f'<text x="{x}" y="{x_axis + 16}" font-size="11" text-anchor="middle" fill="#666">{int(label)}</text>')

    for (s, ys) in y_positions_by_series:
        svg_parts.append(f'<path d="{make_path(xs, ys)}" fill="none" stroke="{s.color}" stroke-width="2.2"/>')
        for x, y, v in zip(xs, ys, s.values):
            svg_parts.append(f'<circle cx="{x}" cy="{y}" r="3" fill="{s.color}"/>')
            svg_parts.append(f'<text x="{x}" y="{y - 8}" font-size="10" text-anchor="middle" fill="{s.color}">{v:.1f}</text>')

    svg_parts.append(f'<text x="{margin_left}" y="{margin_top - 12}" font-size="14" font-weight="600" fill="#222">{title}</text>')
    svg_parts.append(
        f'<text x="{margin_left - 30}" y="{margin_top + plot_h / 2}" font-size="12" text-anchor="middle" fill="#444" transform="rotate(-90 {margin_left - 30},{margin_top + plot_h / 2})">{y_label}</text>'
    )

    legend_x = margin_left + plot_w - 160
    legend_y = margin_top + 8
    for idx, s in enumerate(series_list):
        y = legend_y + idx * 18
        svg_parts.append(f'<rect x="{legend_x}" y="{y - 10}" width="14" height="4" fill="{s.color}"/>')
        svg_parts.append(f'<text x="{legend_x + 20}" y="{y}" font-size="11" fill="#333">{s.name}</text>')

    return "\n".join(svg_parts)


def build_svg(data: List[dict]) -> str:
    width = 1100
    chart_height = 220
    padding = 60
    charts_gap = 30
    charts_def = [
        ("응답시간 분포(ms)", "ms", [
            Series("p50", "#4c72b0", [row["p50_ms"] for row in data]),
            Series("p90", "#8172b2", [row["p90_ms"] for row in data]),
            Series("p95", "#dd8452", [row["p95_ms"] for row in data]),
            Series("p99", "#55a868", [row["p99_ms"] for row in data]),
            Series("max", "#c44e52", [row["max_ms"] for row in data]),
        ]),
        ("처리량", "ops/sec", [
            Series("RPS", "#4c72b0", [row["rps"] for row in data]),
            Series("TPS", "#dd8452", [row["tps"] for row in data]),
        ]),
        ("오류율", "%", [
            Series("HTTP 4xx", "#8172b2", [row["http4xx_pct"] for row in data]),
            Series("HTTP 5xx", "#c44e52", [row["http5xx_pct"] for row in data]),
            Series("Timeout", "#55a868", [row["timeout_pct"] for row in data]),
        ]),
        ("대기/네트워크 지연", "ms", [
            Series("TTFB", "#4c72b0", [row["ttfb_ms"] for row in data]),
            Series("Connect", "#dd8452", [row["connect_ms"] for row in data]),
            Series("DNS", "#55a868", [row["dns_ms"] for row in data]),
            Series("SSL", "#8172b2", [row["ssl_ms"] for row in data]),
        ]),
        ("리소스 사용률", "% / MB", [
            Series("App CPU%", "#4c72b0", [row["app_cpu_pct"] for row in data]),
            Series("DB CPU%", "#dd8452", [row["db_cpu_pct"] for row in data]),
            Series("App Mem(MB)", "#55a868", [row["app_mem_mb"] for row in data]),
            Series("DB Mem(MB)", "#8172b2", [row["db_mem_mb"] for row in data]),
        ]),
        ("GC/DB 대기", "count/ms", [
            Series("GC Count", "#4c72b0", [row["gc_count"] for row in data]),
            Series("GC Time(ms)", "#dd8452", [row["gc_time_ms"] for row in data]),
            Series("Lock Wait(ms)", "#55a868", [row["lock_wait_ms"] for row in data]),
        ]),
        ("DB 성능", "ms / qps", [
            Series("DB q avg", "#4c72b0", [row["db_q_avg_ms"] for row in data]),
            Series("DB q p95", "#dd8452", [row["db_q_p95_ms"] for row in data]),
            Series("DB QPS", "#55a868", [row["db_qps"] for row in data]),
            Series("Slow queries", "#c44e52", [row["slow_queries"] for row in data]),
        ]),
        ("캐시/외부 API", "% / ms", [
            Series("Cache hit%", "#4c72b0", [row["cache_hit_pct"] for row in data]),
            Series("Ext API ms", "#dd8452", [row["ext_api_ms"] for row in data]),
            Series("Ext API err%", "#c44e52", [row["ext_api_err_pct"] for row in data]),
        ]),
        ("큐/비동기", "count/ms", [
            Series("Queue depth", "#4c72b0", [row["queue_depth"] for row in data]),
            Series("Queue delay(ms)", "#dd8452", [row["queue_delay_ms"] for row in data]),
            Series("Retry count", "#55a868", [row["retry_count"] for row in data]),
        ]),
        ("연결/소켓", "count/%", [
            Series("Open conns", "#4c72b0", [row["open_conns"] for row in data]),
            Series("Conn drops", "#c44e52", [row["conn_drops"] for row in data]),
            Series("Keep-alive%", "#55a868", [row["keep_alive_pct"] for row in data]),
        ]),
        ("UX 지표", "score/%", [
            Series("Apdex", "#4c72b0", [row["apdex"] for row in data]),
            Series("Failed scenario%", "#c44e52", [row["failed_scenario_pct"] for row in data]),
        ]),
    ]

    total_height = padding * 2 + len(charts_def) * chart_height + (len(charts_def) - 1) * charts_gap
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{total_height}" viewBox="0 0 {width} {total_height}">',
        '<style>text { font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif; }</style>',
    ]

    x_labels = [int(row["users"]) for row in data]

    for idx, (title, y_label, series_list) in enumerate(charts_def):
        origin_y = padding + idx * (chart_height + charts_gap)
        parts.append(
            render_chart(
                x_labels=x_labels,
                series_list=series_list,
                title=title,
                y_label=y_label,
                origin_x=70,
                origin_y=origin_y,
                plot_w=940,
                plot_h=chart_height - 30,
            )
        )

    parts.append("</svg>")
    return "\n".join(parts)


def main() -> None:
    data = read_data(DATA_FILE)
    svg = build_svg(data)
    SVG_FILE.write_text(svg, encoding="utf-8")
    print(f"Wrote {SVG_FILE.relative_to(Path.cwd())}")


if __name__ == "__main__":
    main()
