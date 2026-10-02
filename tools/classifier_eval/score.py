"""Phase 14.2A: score model and rule labels against an eval set with one function.

  python3 tools/classifier_eval/score.py <set.json> <rules.json> <model.json> [report.json]

A prediction is correct when it is in the item's allowed values for that field:
frozen set -> gold plus "acceptable"; dev set -> "expect" (unlisted fields are not scored).
Per-label recall uses the primary gold (first allowed value). Model confidence is
reported for analysis only; it is not a calibrated probability.
"""
import json
import statistics
import sys
from collections import Counter, defaultdict

FIELDS = ["content_type", "interaction_signal", "open_content"]
META = {"repeated_question", "stop_questioning", "assistant_not_understood", "process_resistance"}

# gpt-4o-mini list price per 1M tokens (USD) at the time of writing; an estimate only.
PRICE_IN, PRICE_OUT = 0.15, 0.60


def allowed(item):
    if "gold" in item:
        out = {f: [item["gold"][f]] for f in FIELDS}
        for f, alts in (item.get("acceptable") or {}).items():
            out[f] = out[f] + [a for a in alts if a not in out[f]]
        return out
    return item["expect"]


def pct(a, b):
    return None if b == 0 else round(100 * a / b, 1)


def score(items, preds):
    """preds: id -> labels dict, or None when the source produced nothing (reject)."""
    acc = {f: [0, 0] for f in FIELDS}
    per_label = {f: defaultdict(lambda: {"tp": 0, "gold": 0, "pred": 0}) for f in FIELDS}
    meta_fp, meta_fp_items = 0, []
    meta_gold_none = 0
    tags = defaultdict(lambda: [0, 0])
    for it in items:
        a = allowed(it)
        p = preds.get(it["id"])
        for f, ok_vals in a.items():
            acc[f][1] += 1
            primary = ok_vals[0]
            per_label[f][primary]["gold"] += 1
            if p is None:
                continue
            got = p[f]
            per_label[f][got]["pred"] += 1
            if got in ok_vals:
                acc[f][0] += 1
                per_label[f][primary]["tp"] += 1
        # every constrained field correct -> item correct (per tag)
        item_ok = p is not None and all(p[f] in v for f, v in a.items())
        for t in it.get("tags", []):
            tags[t][1] += 1
            tags[t][0] += int(item_ok)
        sig = a.get("interaction_signal")
        if sig and sig[0] == "none":
            meta_gold_none += 1
            if p is not None and p["interaction_signal"] in META:
                meta_fp += 1
                meta_fp_items.append(it["id"])

    # precision needs the allowed sets, recompute
    for f in FIELDS:
        for lab in list(per_label[f]):
            tp_pred = sum(1 for it in items
                          if f in allowed(it) and preds.get(it["id"]) is not None
                          and preds[it["id"]][f] == lab and lab in allowed(it)[f])
            n_pred = sum(1 for it in items
                         if f in allowed(it) and preds.get(it["id"]) is not None
                         and preds[it["id"]][f] == lab)
            per_label[f][lab]["precision"] = pct(tp_pred, n_pred)

    return {
        "accuracy": {f: {"correct": c, "of": n, "pct": pct(c, n)} for f, (c, n) in acc.items() if n},
        "per_label": {f: {lab: {"recall": pct(v["tp"], v["gold"]), "precision": v["precision"],
                                "gold": v["gold"], "pred": v["pred"]}
                          for lab, v in sorted(per_label[f].items())}
                      for f in FIELDS if acc[f][1]},
        "meta_false_positive": {"count": meta_fp, "of_gold_none": meta_gold_none, "ids": meta_fp_items},
        "by_tag": {t: {"correct": c, "of": n, "pct": pct(c, n)} for t, (c, n) in sorted(tags.items())},
    }


def ops(model_results):
    vals = list(model_results.values())
    lat = [v["latency_ms"] for v in vals if "latency_ms" in v]
    rej = Counter(v["rejected"] for v in vals if "rejected" in v)
    tin = sum(v.get("prompt_tokens", 0) for v in vals)
    tout = sum(v.get("completion_tokens", 0) for v in vals)
    n_ok = len(lat)
    per_utt = (tin * PRICE_IN + tout * PRICE_OUT) / 1e6 / max(n_ok, 1)
    q = statistics.quantiles(lat, n=20) if len(lat) >= 20 else [None] * 19
    return {
        "items": len(vals),
        "rejected": dict(rej),
        "reject_rate_pct": pct(sum(rej.values()), len(vals)),
        "latency_ms": {"p50": statistics.median(lat) if lat else None, "p95": q[18]},
        "tokens": {"prompt_avg": round(tin / max(n_ok, 1), 1), "completion_avg": round(tout / max(n_ok, 1), 1)},
        "cost_usd_estimate": {"per_utterance": round(per_utt, 6), "per_10_turn_session": round(10 * per_utt, 5)},
    }


def main():
    set_path, rules_path, model_path = sys.argv[1:4]
    items = json.load(open(set_path))["items"]
    rules = json.load(open(rules_path))
    model = json.load(open(model_path))
    mpreds = {k: (v["labels"] if "labels" in v else None) for k, v in model["results"].items()}
    # rejected model items fall back to the rule labels (what the app would do)
    with_fallback = {k: (v if v is not None else rules[k]) for k, v in mpreds.items()}
    report = {
        "set": set_path.rsplit("/", 1)[-1],
        "model": model["model"],
        "prompt_version": model["prompt_version"],
        "rules": score(items, rules),
        "model_raw": score(items, mpreds),
        "model_with_rule_fallback": score(items, with_fallback),
        "ops": ops(model["results"]),
    }
    disagree = []
    for it in items:
        p = mpreds.get(it["id"])
        a = allowed(it)
        bad = [f for f, v in a.items() if p is None or p[f] not in v]
        if bad:
            disagree.append({"id": it["id"], "user": it["user"], "fields": bad,
                             "allowed": {f: a[f] for f in bad},
                             "model": None if p is None else {f: p[f] for f in bad},
                             "rules": {f: rules[it["id"]][f] for f in bad}})
    report["model_errors"] = disagree
    out = json.dumps(report, ensure_ascii=False, indent=1)
    if len(sys.argv) > 4:
        open(sys.argv[4], "w").write(out)
    s = lambda r, f: r["accuracy"].get(f, {}).get("pct")
    print(f"{report['set']}  model={report['model']} prompt={report['prompt_version']}")
    for f in FIELDS:
        print(f"  {f:20s} rules {s(report['rules'], f)}%  model {s(report['model_raw'], f)}%  "
              f"model+fallback {s(report['model_with_rule_fallback'], f)}%")
    print(f"  meta false positives  rules {report['rules']['meta_false_positive']['count']}"
          f"  model {report['model_raw']['meta_false_positive']['count']}"
          f"  (of {report['rules']['meta_false_positive']['of_gold_none']} gold-none)")
    print(f"  ops {json.dumps(report['ops'])}")


if __name__ == "__main__":
    main()
