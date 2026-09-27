# Phase 10.5A.2 — Context Propagation Audit & Targeted Fixes

## Track A — exhausted_repeat: confirmed selection-policy issue, not realization

### What was found

Auditing raw `/counseling/realize` request payloads (`/tmp/phase10_5a_full_requests.json`)
revealed a real dev-fixture defect: 13/48 eligible requests carried literal
placeholder strings (`"goal:alternative"`, `"goal:probability"`) in
`recent_conversation` instead of realistic prior assistant utterances.
Root cause: `assistantGoalMessage()` (`frozen_scenarios_common.dart`) sets
`text: 'goal:$goalName'` as a throwaway value — only `dialogueGoalId` (a
structural ID) was ever meant to be read, by `GoalExhaustionPolicy` for the
Phase 9 decision-agent evaluation this fixture was built for. Reusing it
for a realization (wording) evaluation leaked that placeholder text into
what the model actually sees.

### The ablation test

Rebuilt clean `recent_conversation` for exactly the 6 `exhausted_repeat`
scenarios (replacing the placeholders with the real production question
text for the alternative/probability goals) and re-ran them against the
identical prompt/model/sampling, nothing else changed.

**Result: replies were essentially unchanged in character.** 5/6 kept the
same generic "worry is still there → probability question" structure with
no acknowledgment of repetition; only cosmetic paraphrase differences (one
pair was byte-identical). See `/tmp/phase10_5a2_trackA_responses.json`.

### Why this rules out context corruption as the cause

The same placeholder corruption was present in `reflect_alternative` (4/48)
and `reflect_probability` (3/48) requests too — and those categories scored
well in the Primary human review (3/4 and 3/3 clear Remote preference,
respectively). Since identical corruption produced good results elsewhere
but poor results only in `exhausted_repeat`, the corruption cannot be the
differentiator.

### Conclusion

`exhausted_repeat`'s poor absolute quality is very likely a **selection-policy
UX property**, not a realization defect: `GoalExhaustionPolicy.repeatLast`
re-asks a same-style (probability-goal) question, and no wording change can
fully avoid that reading as repetitive when the underlying policy decision
genuinely is a repeat. This matches the Diagnostic review result too —
Remote still won 6/6 there (better *relative* wording than Semantic), which
is consistent with "the selected behavior sets a low ceiling on how good
*any* wording can feel," not "Remote's wording is uniquely bad here."

**Per the explicit Phase 10 boundary (selection frozen, realization only),
`GoalExhaustionPolicy.repeatLast` is NOT changed in this phase.** Logged as
a backlog item for a future policy/agent phase:

> `Reflect` goal exhaustion re-asking a probability-style question reads as
> mechanical to users regardless of wording. Candidates worth evaluating
> later (a different phase, decision-layer scope): `listenWithoutQuestion`,
> `summarize`, `revisitPreviousIssue`, `transitionToIntervention`, or
> treating repeated exhaustion as a `closing` consideration signal.

The `assistantGoalMessage` placeholder-text issue is still a real dev-fixture
bug and should be fixed before any future realization evaluation reuses
`holdout_v1_scenarios.dart` — logged, not fixed in this pass (fixing the
shared fixture file touches Phase 9's frozen dataset; a fresh
`phase10_x_dev_v2`-labeled realization-specific fixture set is the correct
place for it, per Phase 10's own dataset-versioning discipline. Not built
in this pass since it wasn't necessary to reach the conclusion above).

## Track B — SUD-response: confirmed realization issue, partial fix shipped

### What was found

Unlike `exhausted_repeat`, the `explore_sud_response` requests already
carried correct, real `recent_conversation` (the actual "0-10" question and
the user's numeric reply). The model had everything needed to acknowledge
the rating — it simply chose not to, in 2/3 cases (confirmed: old replies
never mention the number at all).

### Fix shipped (additive, versioned)

New optional semantic signal, threaded end-to-end:

```
TurnPlanMaterializer.explore()
  _extractSudValue(current) -> int? (0-10, regex "(\d{1,2})\s*점")
        │  deliberately separate from _isSudResponse (which gates an
        │  existing wording BRANCH — left untouched, out of Track B scope)
        ▼
CounselingRealizationSpec.sudRatingValue          (realization_spec.dart)
        ▼
RealizationRequest.realizationSpec.sudRatingValue  (already threaded, Phase 10.2)
        ▼
RemoteLlmRealizer.realize()  ->  CounselingRealizeApi.realize(sudRatingValue: ...)
        ▼
POST /counseling/realize  { ..., "sud_rating_value": 7 }
        ▼
backend: CounselingRealizeRequest.sud_rating_value (Optional[int], default None)
        + one new _SYSTEM_PROMPT rule: acknowledge it naturally, don't
          judge/reinterpret it
        + _build_user_prompt includes "sud_rating_value: N" when present
```

Fully additive: every new field/param defaults to `null`/`None`; a caller
that never sets it sees identical behavior to before. Backend
`_SYSTEM_PROMPT` text itself did change for all callers (one new rule line,
a no-op without a value to act on) — tracked as **`realize_v2`** in any
future evaluation manifest; prior dev results (Phase 10.5A's 48-scenario
run) remain valid `realize_v1` evidence, not overwritten.

New tests: `test/counseling/evaluation/phase10_5a2_sud_signal_test.dart` (5,
extraction correctness incl. "한 8점 정도요" which `_isSudResponse` itself
doesn't match), `test/counseling/remote_llm_realizer_test.dart` (+2, signal
reaches the API call, and stays `null` when absent). Full suite: **797/797
pass**.

### Real-API re-test result — partial, not full, fix

| Scenario | Before | After | Changed? |
|---|---|---|---|
| `explore_sud_1` (target=raw "7점이요") | No acknowledgment | Reworded, still no acknowledgment | No real improvement |
| `explore_sud_2` (target=raw "한 8점 정도요") | No acknowledgment | **Byte-identical to before** | No improvement |
| `explore_sud_3` (target=original concern text, not the number) | No acknowledgment | **"...불안이 6점이라고 하셨군요." — explicit, natural acknowledgment** | Clear improvement |

**1/3 clearly fixed, 2/3 unchanged despite the signal being present and
correctly sent in all three requests** (verified in the raw payloads). The
one success case is genuine, real evidence the mechanism works end-to-end
when followed — but `gpt-4o-mini` at `temperature=0.2` did not reliably
follow the new one-line system-prompt rule across all three calls. This
reads as an instruction-prominence/compliance issue (the rule may need to
be stated more forcefully, e.g. restated in the user prompt as a direct
imperative tied to the specific number, rather than as one bullet among
several in a shared system prompt) rather than evidence the underlying
signal is useless.

### Disposition

Shipped as-is (real, additive, tested improvement for at least this
sub-case); not iterated further this pass. Whether to strengthen prompt
compliance further, or accept the partial improvement and move on, is a
call for the next step rather than something to keep tuning against 3 dev
examples with no held-out check.

## Summary for Phase 10.5B readiness

- `exhausted_repeat`: root-caused to selection policy, out of Phase 10
  scope — no further realization-layer work planned; excluded from being
  treated as a Phase 10.5B pass/fail criterion (it cannot pass regardless
  of wording).
- `explore_sud_response`: partially improved (1/3); real fix shipped,
  versioned `realize_v2`. Any Phase 10.5B holdout should use `realize_v2`
  and report this stratum's absolute quality honestly (not just pairwise
  win rate), per the original request's own instruction.
- All other categories: already strong (Primary 35:0, Diagnostic 46:2) and
  untouched by this audit.
