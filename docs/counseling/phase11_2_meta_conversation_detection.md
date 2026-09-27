# Phase 11.2 — Meta-conversation Detection (repeatedQuestion)

**Status: complete.** Extended `DeterministicProcessSignalTurnPlanner`'s
existing detection coverage with the one confirmed gap from Phase 11.1
(complaints framed around *repetition*, e.g. "왜 똑같은 말을 반복하지?").
Detection only — `GoalExhaustionRecovery`/`ReflectDecisionSelector` are
untouched, per Phase 11.1's explicit scope split.

## What changed

- `lib/data/counseling/counseling_models.dart`: `InteractionRepairReason`
  and `GoalExhaustionRecovery` enums **relocated here** from
  `lib/features/counseling/policy/interaction_repair.dart` (deleted).
  Correction to Phase 11.1's initial placement: `CounselingMessage` (data
  layer) needs to carry `interactionRepairReason` forward the same way it
  already carries `dialogueGoalId`, and `DialogueAct` itself lives in this
  same file for exactly that reason — a data-layer file can't import
  from `features/`. Also added `CounselingMessage.interactionRepairReason`
  (nullable, mirrors `dialogueGoalId`'s doc pattern).
- `lib/features/counseling/turn_plan.dart`:
  - `CounselingTurnPlan` gained `interactionRepairReason` (nullable).
  - `DeterministicProcessSignalTurnPlanner` gained a third regex,
    `_repeatsInteraction`, and now assigns
    `InteractionRepairReason.{stopQuestioning,processFrustration,repeatedQuestion}`
    on every turn it handles (previously it produced a plan but never
    labeled *why*).
- `lib/features/counseling/counseling_harness.dart`: threads
  `turnPlan.interactionRepairReason` into the assistant
  `CounselingMessage`, alongside the existing `dialogueGoalId` line.
- `test/counseling/process_signal_repeated_question_test.dart` (new,
  20 tests, groups A-D per the frozen test plan).

## The detection pattern, and why it's not `contains('반복')`

```dart
static final RegExp _repeatsInteraction = RegExp(
  r'(왜\s*(똑같은|같은)\s*말(을|은)?\s*(계속\s*)?반복|'
  r'왜\s*(똑같은|같은)\s*질문(을|은)?\s*계속|'
  r'아까도\s*(물어|여쭤)|'
  r'방금도\s*(그\s*)?(질문|얘기)\s*(했|말했)|'
  r'그\s*얘기\s*방금도\s*(했|말했)|'
  r'또\s*같은\s*(거|것|걸)\s*물어|'
  r'아까\s*(말한|물어본)\s*거(랑|와)\s*똑같|'
  r'계속\s*비슷한\s*질문)',
);
```

Every alternative pairs a **repetition cue** (똑같은/같은/또/계속/아까도/
방금도) with an **interaction cue that names the counselor's own
question/statement** (질문/물어/여쭤/얘기+했) — never a bare 말/생각/걱정.
Worry content routinely uses repetition language about the user's own
life ("같은 생각이 계속 반복돼요", "매일 똑같은 걱정을 해요") without ever
naming the interaction itself, so it never matches. Verified directly,
not assumed — see the test file's groups B (8 positives, all frozen in
Phase 11.1's design doc) and C (7 negatives, same source), all passing.

## Guarantees this phase makes — and does not make

```text
Phase 11.2 guarantees:
  - meta-feedback about repetition is not ignored (detected, acknowledged)
  - the acknowledgment carries no new question
    (TurnConstraint.requireNoQuestion, questionSentence: '')
  - existing stopQuestioning/processFrustration detection unchanged
    (group A, byte-identical reflectionSentence text)
  - no CBT intervention introduced by a repair turn
  - routing is unaffected: HybridTurnRouter.route() only inspects
    session.state, never which planner produced the plan (verified in
    the D group directly against the real .remoteGpt() harness) — so a
    repeatedQuestion repair turn in checkIn/intervention/closing gets
    exactly 0 Remote calls, same as any other turn there, and in
    explore/reflect it's gated exactly like ordinary content

Phase 11.2 does NOT guarantee:
  - that the next reflect-goal selection changes (ReflectDecisionSelector
    ._selectGoal is untouched — repeatLast still fires exactly as before)
  - that state stops advancing on a repair turn — CounselingStatePolicy's
    ordinary turn-budget exhaustion rule still fires regardless of which
    planner produced the turn (confirmed directly: a repair turn landing
    on reflect's 2nd budgeted turn advances to intervention, identically
    to an ordinary content turn at the same budget position — this is
    normal progression, not a bug this phase introduces or needs to fix)
```

The second non-guarantee is deliberate, not a gap discovered late: Phase
11.1 already scoped goal-exhaustion recovery to Phase 11.3.

## Regression evidence

- `flutter analyze`: clean (same 5 pre-existing, unrelated info-lints as
  every prior phase this session).
- `flutter test` (whole project): **889/889** (869 baseline + 20 new).
- Nothing in `ReflectDecisionSelector`, `CounselingRealizationSpec`,
  `RemoteLlmRealizer`, `realize_v2`, `RolloutConfig`, or `SafetyGate` was
  touched — grep-confirmed before committing.

## Next

Phase 11.3 — Goal exhaustion recovery. `GoalExhaustionRecovery` is
already frozen (Phase 11.1, relocated alongside `InteractionRepairReason`
in this phase); nothing constructs it yet. Per Phase 11.1's design note,
`revisitPreviousIssue` specifically needs a same-session "other topics
raised earlier this session" tracker that doesn't fully exist yet
(`CounselingProvider._carriedUnfinishedIssue` only carries a topic
*across* sessions) — that's 11.3's first real sub-problem to solve, not
an integration afterthought.
