# Phase 10.1 — Realization Call Graph & Template Inventory

**Status: complete, code-verified.** No production behavior changed. This
document records what the code actually does today, not a target design.

## 1. Call graph (verified against source)

```
CounselorDecision                                  [FROZEN — selection]
  (selectedAction, selectedGoalId, selectedInterventionId,
   reflectionTarget, usedFactIds, isUnavailable)
        │
        ▼
TurnPlanMaterializer.{checkIn,explore,reflect,intervention,closing}
  lib/features/counseling/policy/materializers/turn_plan_materializer.dart
        │  produces per state:
        │    reflectionSentence  (string, already fully worded)
        │    questionSentence    (string, already fully worded)
        │    questionGoal        (string, semantic — not shown to user)
        │    forbidden / constraints / requiredAct / interventionPlan
        ▼
CounselingTurnPlan
  lib/features/counseling/turn_plan.dart
        │  .deterministicReply =>
        │    [reflectionSentence.trim(), questionSentence.trim()]
        │      .where(isNotEmpty).join(' ')
        │  — PURE STRING CONCATENATION. No bridging/transition text,
        │  no rewriting, no awareness of one sentence following the other.
        ▼
RealizationRequest.fromPlan(plan, ...)
  lib/features/counseling/response_realizer.dart
        │  deterministicDraft := plan.deterministicReply   (copied verbatim)
        ▼
ResponseRealizer.realize(request)
        │
        ├─ DeterministicResponseRealizer   <-- PRODUCTION DEFAULT
        │    (counseling_harness.dart:176)
        │    return request.deterministicDraft UNCHANGED.
        │    i.e. in production today, TurnPlanMaterializer's output
        │    IS the final user-facing sentence, verbatim.
        │
        └─ RemoteLlmRealizer  (lib/features/counseling/remote_llm_realizer.dart)
             NOT wired as the default; calls /counseling/realize
             (backend/app/routers/counseling_realize.py) to rewrite
             deterministicDraft into freer prose. Not evaluated in Phase 9/10
             so far and not in scope for this inventory.
```

**Conclusion:** the production realization pipeline currently has **one real
author of surface wording**: `TurnPlanMaterializer`. `ResponseRealizer`
(deterministic) is a no-op passthrough. Any fix to the Phase 9.2E complaints
(verbatim quoting, abrupt transitions) must happen in `TurnPlanMaterializer`
and/or in how `CounselingTurnPlan.deterministicReply` composes its two
sentences — not in `ResponseRealizer`, which currently does nothing.

## 2. Per-state template inventory

All sentence fragments below are produced entirely inside
`turn_plan_materializer.dart`. "Rotation" = `DeterministicSurfaceVariation.select`
(`lib/features/counseling/surface_variation.dart`): picks the first candidate
whose `repetitionMarkers` substring hasn't appeared in recent assistant
messages, else a stable hash of `seed` — deterministic, not random, but still
just picking between fixed strings.

### CheckIn (`.checkIn`, line 83)
- `reflectionSentence`: **fixed template, no rotation** — `“$clean”라고 말씀해 주셨군요.`
  (`clean` = raw `reflectionTarget` with trailing punctuation stripped —
  i.e. user's own words, quoted verbatim, always).
- `questionSentence`: fixed literal, same every time — `지금 느끼는 불안을 0에서 10 사이로...`

### Explore (`.explore`, line 164)
- `reflectionSentence`: rotates among 4 candidates (`surfaceVariation.select`),
  3 of which quote `target` verbatim in `""`, 1 generic non-quoting fallback.
- `questionSentence`: **no rotation** — one of 3 hardcoded literals chosen by
  simple string-matching (`askedMoment`, `target.contains('발표')`).
- `questionGoal`: semantic only, never shown to user.

### Reflect (`.reflect`, line 248) — four sub-branches
- Clarify branch (`_clarifyingReflectionSentence`/`_clarifyingQuestionSentence`):
  rotates among 2-3 candidates; quotes `target` verbatim in 2 of 3 reflection
  candidates.
- Non-clarify, `evidence` goal (`_reflectionSentence`, line 343): rewrites
  `target` via a few `.replaceAll`/regex passes into a noun-phrase, then
  rotates among 3 candidates — the **only** state/branch that paraphrases
  rather than quoting.
- Non-clarify, follow-up goals (`_followUpReflectionSentence`, line 366):
  rotates among 4 candidates, 2 of which quote `target` verbatim in `""`.
- `questionSentence`: comes from `ReflectQuestionGoal.question` (not in this
  file — a fixed string per goal enum value, no rotation, no connection to
  `target`'s actual content).

### Intervention (`.intervention`, line 404 / `.interventionUnavailable`, line 452)
- `reflectionSentence` (`_reflectionFor`, line 524): **fixed template per
  `InterventionType`, zero rotation, always quotes `target` verbatim** —
  e.g. `“$target”라는 생각을 함께 살펴보겠습니다.` This is the most rigid template
  of any state: one literal string per intervention type, no variation ever.
- `questionSentence` (`_questionFor`, line 490): fixed literal per type, zero
  rotation, no connection to `target`'s content.
- `interventionUnavailable`'s reflection does rotate (2 candidates) when
  `clean` is non-empty.

### Closing (`.closing`, line 118)
- `reflectionSentence`: **no rotation** — one of 2 fixed templates chosen by
  a single null-check on `target`; quotes verbatim when non-null:
  `오늘은 "${target}"라는 이야기를 나눴습니다.`
- `questionSentence`: always empty string (closing asks no question, by
  design — `TurnConstraint.requireNoQuestion`).

## 3. Selection vs. Materialization vs. Surface realization

| Layer | Owns | Code | Phase 10 status |
|---|---|---|---|
| **A. Selection** | which action/goal/intervention/reflectionTarget id | `policy/selectors/*.dart`, `CounselorDecision` | **FROZEN** — out of scope |
| **B. Materialization** | turning a decision into semantic plan fields (`questionGoal`, `interventionPlan`, `constraints`) | `TurnPlanMaterializer` (semantic parts) | in scope, likely untouched |
| **B/C boundary — blurred today** | turning a decision into the *actual final sentence* (`reflectionSentence`, `questionSentence`) | `TurnPlanMaterializer` (wording parts) | **in scope — this is where the Phase 9.2E complaints live** |
| **C. Surface realization** | rewriting/smoothing a drafted sentence, tone, transition | `ResponseRealizer` — currently a **no-op** in production | in scope, currently does nothing to fix |

`TurnPlanMaterializer` does not cleanly stop at "materialization" — it
directly authors final user-facing prose (layer B and C are fused in one
class today). This fusion is itself a finding, not just the individual
templates: there is no field carrying "reflection intent" separately from
"reflection final wording," so nothing downstream (including a future
`ResponseRealizer`) has anything to work with except an already-finished,
already-quoting sentence.

## 4. Answers to the Phase 10.1 boundary questions

- **Does `TurnPlanMaterializer` over-own surface wording?** Yes — it emits
  finished sentences, not a semantic plan a realizer could still shape.
- **Does `ResponseRealizer` have real rewrite authority in production?**
  No — `DeterministicResponseRealizer` is an identity function over
  `deterministicDraft`. All authority is upstream, in the Materializer.
- **Is `deterministicReply` too tightly coupled to the final sentence?**
  Yes — it *is* the final sentence via simple concatenation; there's no
  seam for a bridging/transition step to insert itself.
- **Is `reflectionTarget` semantic content or raw surface string?** Both,
  ambiguously — it's typed as raw user-derived text (`ReflectionTargetText.value`),
  and every template except `reflect`'s `evidence` branch treats it as
  ready-to-quote surface text rather than something to paraphrase first.
- **Does a transition-intent field exist?** No. `deterministicReply`'s
  `join(' ')` is the entire "transition."
- **Does an intervention rationale/bridge field exist?** No —
  `InterventionPlan` carries `type`/`target`/`promptSentence`/`recommendation`,
  no field for "why this, now, given what was just reflected."

## 5. Phase 9.2E evidence mapped to this inventory

- **`intervention_*` 16/16 bothPoor**: matches finding above exactly —
  intervention's `reflectionSentence` is the single most rigid template in
  the codebase (zero rotation, always-verbatim quote, one fixed string per
  type). No other state is this inflexible.
- **Pervasive `bothPoor` across states, not concentrated**: matches finding
  that `deterministicReply`'s naive `join(' ')` (the R3/abrupt-transition
  root cause) applies identically to *every* state, not just one.
- **User's own two complaints map 1:1** to concrete, named code:
  - "따옴표로 원문 그대로 인용" → the `"$target"라고...` / `"$clean"라고...`
    pattern present in `checkIn`, `explore`, most of `reflect`'s branches,
    `intervention`, and `closing`.
  - "자연스럽게 안 이어지고 형식적으로 다음 질문" → `deterministicReply`'s
    `[reflectionSentence, questionSentence].join(' ')`.

This does **not** mean Remote-vs-Deterministic decision quality was
unmeasurable in Phase 9.2E — see the 13 clear-preference-pair analysis in
`phase9_2_activation_criteria.md`'s closure section — but it does mean the
`bothPoor` rate specifically is dominated by this shared, pre-existing
realization layer, not by which agent chose the decision.

## 6. Baseline examples (verbatim from Phase 9.2E holdout run, unmodified)

```
[intervention_balancedThought]
  reflection: "시험에서 떨어지면 인생이 끝날 것 같다"라는 생각을 함께 살펴보겠습니다.
  question:   이 생각을 조금 더 균형 있게 바꾼다면 어떤 문장이 될 수 있을까요?
  combined:   "시험에서 떨어지면 인생이 끝날 것 같다"라는 생각을 함께 살펴보겠습니다.
              이 생각을 조금 더 균형 있게 바꾼다면 어떤 문장이 될 수 있을까요?

[checkIn]
  reflection: "면접 전날부터 계속 긴장돼서 잠을 못 잤다"라고 말씀해 주셨군요.
  question:   지금 느끼는 불안을 0에서 10 사이로 표현하면 어느 정도인가요?

[closing]
  reflection: 오늘은 "가족 모임에서 오빠와 다시 부딪힐까 봐 걱정된다"라는 이야기를 나눴습니다.
              여기까지 이야기해 주셔서 감사합니다.
  question:   (empty)
```

These are recorded here as the fixed reference point for Phase 10.2's
before/after comparison — not rewritten in this document.

## 7. Explicit non-actions this phase

No file under `lib/features/counseling/policy/materializers/`,
`lib/features/counseling/turn_plan.dart`, `lib/features/counseling/response_realizer.dart`,
any selector, `CounselorDecision`, or `PolicyBoundary` was modified. `flutter
test` was not re-run since nothing changed; the existing suite (including
`decision_contract_matrix_test.dart`, `holdout_v1_fixture_invariant_test.dart`)
remains the last-known-green baseline for this inventory.
