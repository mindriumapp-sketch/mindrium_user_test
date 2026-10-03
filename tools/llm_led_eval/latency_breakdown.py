"""Phase 14.X 2단계: 지연시간·실패 분해.

입력: 기기 logcat 파일(`LLM_LED {...}` 줄) 또는 E2 결과 JSON(B 경로 행).
그룹: direct(B 표시) | content_fallback(B 응답이 검증에서 거절 → A) |
transport_fallback(응답 없음 → A) | safety.

    adb logcat -d | grep LLM_LED > build/llm_led/device_log.txt
    python3 tools/llm_led_eval/latency_breakdown.py build/llm_led/device_log.txt
"""

import json
import sys
from collections import Counter, defaultdict

FIELDS = ("request_ms", "model_ms", "validate_ms", "fallback_ms", "end_to_end_ms")
GROUPS = ("direct", "content_fallback", "transport_fallback", "safety")


def group_of(row):
    if row.get("group"):
        return row["group"]
    s = row.get("status")
    return {"success": "direct", "safety": "safety", "rejected": "content_fallback",
            "schema_reject": "content_fallback"}.get(s, "transport_fallback")


def rows_from(path):
    text = open(path, encoding="utf-8").read()
    if text.lstrip().startswith("{"):
        data = json.loads(text)
        for s in data["scripts"]:
            for r in s["B"]:
                yield {**r, **(r.get("timing") or {})}
        return
    for line in text.splitlines():
        i = line.find("LLM_LED {")
        if i >= 0:
            yield json.loads(line[i + len("LLM_LED "):])


def pct(xs, p):
    xs = sorted(xs)
    return xs[max(0, round(len(xs) * p) - 1)] if xs else None


def main():
    rows = list(rows_from(sys.argv[1]))
    by = defaultdict(list)
    for r in rows:
        by[group_of(r)].append(r)
    n = len(rows)
    print(f"turns {n}")
    for g in GROUPS:
        rs = by.get(g, [])
        if not rs:
            continue
        print(f"\n[{g}] {len(rs)} ({100 * len(rs) / n:.1f}%)")
        for f in FIELDS:
            xs = [r[f] for r in rs if isinstance(r.get(f), (int, float))]
            if xs:
                print(f"  {f:<14} p50 {pct(xs, .5):>6}  p95 {pct(xs, .95):>6}  max {max(xs):>6}  (n={len(xs)})")
    status = Counter(r.get("request_status") or "unrecorded" for r in by.get("transport_fallback", []))
    if status:
        print("\ntransport failures by request_status:", dict(status))
        codes = Counter(r.get("http_status") for r in by["transport_fallback"])
        print("http_status:", dict(codes))
    e2e = [r["end_to_end_ms"] for r in rows if isinstance(r.get("end_to_end_ms"), (int, float))]
    if e2e:
        print(f"\nall turns end_to_end_ms p50 {pct(e2e, .5)}  p95 {pct(e2e, .95)}  max {max(e2e)}")
    fb = len(by.get("content_fallback", [])) + len(by.get("transport_fallback", []))
    print(f"total fallback {fb}/{n} ({100 * fb / n:.1f}%)")


if __name__ == "__main__":
    main()
