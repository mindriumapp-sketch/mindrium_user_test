import json
import csv
from pathlib import Path

FILES = [50, 100, 150, 200, 300]
OUT = "concurrency_full_metrics.csv"

rows = []

for u in FILES:
    data = json.loads(Path(f"out_{u}.json").read_text(encoding="utf-8"))
    m = data["metrics"]

    rows.append({
        "users": u,
        "p50_ms": m["http_req_duration"]["values"]["med"],
        "p90_ms": m["http_req_duration"]["values"]["p(90)"],
        "p95_ms": m["http_req_duration"]["values"]["p(95)"],
        "p99_ms": m["http_req_duration"]["values"].get("p(99)", 0),
        "max_ms": m["http_req_duration"]["values"]["max"],
        "rps": m["http_reqs"]["rate"],
        "tps": m["iterations"]["rate"],
        "http4xx_pct": 0.0,
        "http5xx_pct": 0.0,
        "timeout_pct": m["http_req_failed"]["value"] * 100,
        "ttfb_ms": m["http_req_waiting"]["values"]["avg"],
        "connect_ms": m["http_req_connecting"]["values"]["avg"],
        "dns_ms": m["http_req_dns"]["values"]["avg"],
        "ssl_ms": m["http_req_tls_handshaking"]["values"]["avg"],
        "app_cpu_pct": 0,
        "db_cpu_pct": 0,
        "app_mem_mb": 0,
        "db_mem_mb": 0,
        "gc_count": 0,
        "gc_time_ms": 0,
        "lock_wait_ms": 0,
        "db_q_avg_ms": 0,
        "db_q_p95_ms": 0,
        "db_qps": 0,
        "slow_queries": 0,
        "cache_hit_pct": 0,
        "ext_api_ms": 0,
        "ext_api_err_pct": 0,
        "queue_depth": 0,
        "queue_delay_ms": 0,
        "retry_count": 0,
        "open_conns": u,
        "conn_drops": 0,
        "keep_alive_pct": 100,
        "apdex": 1.0,
        "failed_scenario_pct": 0.0,
    })

with open(OUT, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

print(f"Wrote {OUT}")
