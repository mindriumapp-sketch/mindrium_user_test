"""Phase 14.2A: build the classifier DEVELOPMENT set from the seen holdouts v1-v5.

These utterances were already seen while writing the rules, so they may be used
to debug the classifier prompt. They never decide 14.2B; the frozen unseen set does.
Each item lists the allowed values per field it constrains ("expect").

  python3 tools/classifier_eval/build_dev_set.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / "test/counseling/evaluation/fixtures"
OUT = FIX / "phase14_2_classifier_dev.json"

GREETING = "안녕하세요. 오늘 어떤 이야기를 나누고 싶으신가요?"
EVIDENCE_Q = "그 생각을 사실이라고 느끼게 하는 근거나 경험이 무엇인지 하나 떠올려볼까요?"
ALT_Q = "그 상황을 다른 관점에서 본다면 어떻게 볼 수 있을까요?"
BALANCED_Q = "이 생각을 조금 더 균형 있게 바꾼다면 어떤 문장이 될 수 있을까요?"
CLOSING_Q = "오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?"

META = ["repeated_question", "stop_questioning", "assistant_not_understood", "process_resistance"]

# category -> (assistant_prev, rule state, expect)
CATEGORIES = {
    "not_understood": (EVIDENCE_Q, "reflect", {"interaction_signal": ["assistant_not_understood"]}),
    "repetition_complaint": (EVIDENCE_Q, "reflect", {"interaction_signal": ["repeated_question"]}),
    "stop_or_frustration": (EVIDENCE_Q, "reflect", {"interaction_signal": ["stop_questioning", "process_resistance"]}),
    "mixed_meta_and_worry": (EVIDENCE_Q, "reflect", {"interaction_signal": META, "content_type": ["mixed", "worry_thought"]}),
    "non_answer": (EVIDENCE_Q, "reflect", {"content_type": ["low_information"], "interaction_signal": ["none"]}),
    "worry_that_looks_meta": (EVIDENCE_Q, "reflect", {"interaction_signal": ["none"], "content_type": ["worry_thought"]}),
    "worry_opening": (GREETING, "checkIn", {"interaction_signal": ["none"], "content_type": ["worry_thought", "situation"]}),
    "evidence_answers": (EVIDENCE_Q, "reflect", {"interaction_signal": ["none"], "content_type": ["meaningful_answer"]}),
    "alternative_answers": (ALT_Q, "reflect", {"interaction_signal": ["none"], "content_type": ["meaningful_answer"]}),
    "technique_answers": (BALANCED_Q, "intervention", {"interaction_signal": ["none"], "content_type": ["meaningful_answer"]}),
    "agree_to_wrap_up": (CLOSING_Q, "closing", {"interaction_signal": ["closing_accept"]}),
    "want_to_continue": (CLOSING_Q, "closing", {"interaction_signal": ["closing_continue"]}),
}

SETS = ["phase13_9b_holdout", "phase13_9_holdout_v2", "phase13_9_holdout_v3",
        "phase13_9_holdout_v4", "phase13_9_holdout_v5"]


def main():
    items, seen = [], set()
    for s in SETS:
        data = json.loads((FIX / f"{s}.json").read_text())
        for cat, (prev, state, expect) in CATEGORIES.items():
            for u in data.get(cat, []):
                if u in seen:
                    continue
                seen.add(u)
                items.append({
                    "id": f"d{len(items) + 1:03d}",
                    "source": s,
                    "tags": [cat],
                    "assistant_prev": prev,
                    "rule_state": state,
                    "user": u,
                    "expect": expect,
                })
    OUT.write_text(json.dumps({"version": "phase14_2_classifier_dev",
                               "note": "seen holdout utterances; for prompt debugging only",
                               "items": items}, ensure_ascii=False, indent=1))
    print(f"wrote {len(items)} items -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
