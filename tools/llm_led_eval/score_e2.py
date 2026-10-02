"""Phase 14.X E2: score A and B replies on the frozen cross-domain scripts.

  python3 tools/llm_led_eval/score_e2.py build/llm_led/e2.json

Checks are judged by simple rules on the reply text and closing metadata,
the same function for both paths. Rules are coarse on purpose; the report
lists every failure so the transcripts can be read.
"""
import json
import re
import sys
from collections import Counter, defaultdict

APP = re.compile(r"(오늘의\s*할\s*일|홈|교육|이완|보관함|리포트|마이\s*페이지|알림|설정|위젯|걱정\s*기록|탭|메뉴|화면|버튼)")
ACK_META = re.compile(r"(답답|불편|미안|죄송|헷갈|느끼셨|느끼실|그렇게\s*느|전달이|안\s*맞|이해하지\s*못|제가\s.{0,10}못|서운|짜증)")
PLAIN = re.compile(r"(헷갈|쉽게|다시\s*말|다른\s*말로|풀어서|쉬운\s*말|간단히|다시\s*여쭤)")
BOT_REPAIR = re.compile(r"(제\s*말이|더\s*묻지\s*않|질문을\s*그만|질문보다|헷갈리게\s*들렸|더\s*여쭙지)")
FABRICATED = re.compile(r"(지난번|예전에|전에|이전에).{0,30}(적으|쓰셨|말씀하셨|정리하셨|기록하신|작성하신|적어\s*두신)")
STOP = {"그냥", "너무", "진짜", "정말", "요즘", "오늘", "내일", "어제", "이번", "다음", "내가", "제가", "나는", "저는",
        "걱정", "불안", "생각", "같아", "그거", "이거", "저거", "뭐야", "어떻", "있어", "없어", "하는", "해서", "그런", "이런"}


def keys(t):
    return {w[:2] for w in re.split(r"[\s.,!?~…]+", t) if len(w) >= 2 and re.match(r"^[가-힣]", w)} - STOP


def check(row):
    """True = pass, False = fail, None = not applicable."""
    c, r = row["check"], row["reply"]
    if c is None:
        return None
    if c in ("finalize_on_refusal", "continue_on_wish") and row.get("only_if_proposed") and not row["prev_proposed"]:
        return None
    return {
        "app_answer": lambda: bool(APP.search(r)),
        "mixed_both": lambda: bool(APP.search(r)) and (bool(keys(row["user"]) & keys(r)) or "걱정" in r or "불안" in r),
        "no_question": lambda: "?" not in r and "？" not in r,
        "acknowledge_meta": lambda: bool(ACK_META.search(r)),
        "clarify_plainly": lambda: bool(PLAIN.search(r)),
        "take_new_content": lambda: bool(keys(row["user"]) & keys(r)),
        "not_meta": lambda: not BOT_REPAIR.search(r),
        "finalize_on_refusal": lambda: row["closing"] == "finalized",
        "continue_on_wish": lambda: row["closing"] != "finalized",
        "no_fabricated_record": lambda: not FABRICATED.search(r),
        # moved forward: a technique step, a summary, or a wrap-up proposal,
        # not yet another exploratory question about the same thing
        "progress": lambda: row.get("step") is not None
        or row["closing"] in ("proposed", "finalized")
        or row.get("act") == "summarize",
    }[c]()


CONTEXT_IGNORE = {"app_answer", "mixed_both", "no_question", "acknowledge_meta", "finalize_on_refusal", "not_meta"}


def main():
    data = json.load(open(sys.argv[1]))
    per = {p: defaultdict(lambda: [0, 0]) for p in ("A", "B")}
    fails = {p: [] for p in ("A", "B")}
    status = Counter()
    turns = Counter()
    for s in data["scripts"]:
        for p in ("A", "B"):
            for i, row in enumerate(s[p]):
                turns[p] += 1
                if p == "B":
                    status[row["status"]] += 1
                ok = check(row)
                if ok is None:
                    continue
                per[p][row["check"]][1] += 1
                per[p][row["check"]][0] += int(ok)
                if not ok:
                    fails[p].append(f'{s["id"]}#{i} {row["check"]}: "{row["user"]}" -> {row["reply"][:120]}')
    print(f"turns A {turns['A']}  B {turns['B']}   B status {dict(status)}")
    calls = sum(v for k, v in status.items() if k != "safety")
    print(f"B fallback rate {100 * (calls - status['success']) / max(calls, 1):.1f}%")
    print(f"{'check':22s} {'A':>10s} {'B':>10s}")
    for c in sorted(set(per["A"]) | set(per["B"])):
        a, b = per["A"][c], per["B"][c]
        print(f"{c:22s} {a[0]:>4d}/{a[1]:<4d} {b[0]:>5d}/{b[1]:<4d}")
    ci = {p: sum(n - k for c, (k, n) in per[p].items() if c in CONTEXT_IGNORE) for p in per}
    print(f"context-ignore failures  A {ci['A']}  B {ci['B']}")
    report = {"per_check": {p: {c: v for c, v in per[p].items()} for p in per},
              "context_ignore_failures": ci, "b_status": status, "failures": fails}
    out = sys.argv[1].replace(".json", "_score.json")
    json.dump(report, open(out, "w"), ensure_ascii=False, indent=1)
    print(f"-> {out}")


if __name__ == "__main__":
    main()
