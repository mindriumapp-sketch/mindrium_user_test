"""Phase 14.2A-5: summarize shadow-perception log lines from an internal device.

  adb logcat -d | grep SHADOW_PERCEPTION > build/classifier_eval/shadow.log
  python3 tools/classifier_eval/analyze_shadow.py build/classifier_eval/shadow.log

Lines carry labels, agreement, latency and fallback reasons only (no text).
"""
import json
import statistics
import sys
from collections import Counter

rows = []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    i = line.find("SHADOW_PERCEPTION ")
    if i < 0:
        continue
    try:
        rows.append(json.loads(line[i + len("SHADOW_PERCEPTION "):].strip()))
    except json.JSONDecodeError:
        pass

ok = [r for r in rows if r.get("fallback_reason") is None]
print(f"turns {len(rows)}  sessions {len({r['session'] for r in rows})}  "
      f"fallback {Counter(r['fallback_reason'] for r in rows if r.get('fallback_reason'))}")
lat = [r["latency_ms"] for r in ok if r.get("latency_ms") is not None]
if len(lat) >= 2:
    q = statistics.quantiles(lat, n=20)
    print(f"latency p50 {statistics.median(lat):.0f}ms  p95 {q[18]:.0f}ms")

print("\nrule signal x model raw signal")
for (rule, raw), n in Counter((r["rule_signal"], r["model_raw_signal"]) for r in ok).most_common():
    print(f"  rule={rule:26s} model={raw:26s} {n}")

nu = Counter()
for r in ok:
    rule = r["rule_signal"] == "assistant_not_understood"
    g = bool(r.get("model_guarded_not_understood"))
    nu[("both" if rule and g else "rule_only" if rule else "model_only" if g else "neither")] += 1
print(f"\nassistant_not_understood (guarded): {dict(nu)}")
print(f"open content (guarded): {Counter(r.get('model_guarded_open') for r in ok)}")
print(f"guard rejections: {Counter(x for r in ok for x in (r.get('guard_reasons') or []))}")

# Phase 14.2B causal-mode fields
causal = [r for r in rows if r.get("causal")]
if causal:
    print(f"\ncausal turns {len(causal)}")
    print(f"classifier status: {Counter(r.get('classifier_status') for r in causal)}")
    print(f"skip reasons: {Counter(r.get('fallback_reason') for r in causal if r.get('classifier_status') == 'skipped')}")
    print(f"effective signal: {Counter(r.get('effective_signal') for r in causal)}")
    print(f"used causally (model added a signal the rules missed): {sum(1 for r in causal if r.get('used_causally'))}")
    print(f"speculative remote discarded: {sum(1 for r in causal if r.get('discard_reason'))}"
          f"  remote used: {sum(1 for r in causal if r.get('remote_used'))}")
    lat = [r['latency_ms'] for r in causal if r.get('classifier_status') == 'success']
    if len(lat) >= 2:
        print(f"classifier latency (success) p50 {statistics.median(lat):.0f}ms max {max(lat)}ms")
