# Phase 11.1 — Selection Policy & Interaction Repair: Problem & Contract Freeze

**Status: design only. Zero production behavior change.** This document
specifies, against actual current code (not hypothetical pipeline
shapes), exactly where the two known failures happen, then freezes two
new semantic contracts as pure additive enums. Nothing in this phase is
wired into `CounselorDecision`, `CounselingTurnPlan`, or any selector.
Production output for every existing scenario is unaffected — the same
guarantee Phase 10.2 made for `CounselingRealizationSpec`.

## Scope freeze

```text
FROZEN (do not touch this phase):
  SafetyGate
  CBT knowledge/intervention registry
  RemoteLlmRealizer / realize_v2 prompt
  CounselingRealizationSpec (Phase 10.2-10.6's semantic contract)
  Canary rollout infrastructure (RolloutConfig, telemetry, allowlist)
  HybridTurnRouter

IN SCOPE:
  Selection layer (PolicyPipelineTurnPlanner, DeterministicCounselorAgent,
    the selectors/ directory)
  Hard Guard / process-signal layer (DeterministicProcessSignalTurnPlanner)
  A new interaction-repair concept, additive to the above
```

Phase 11 is exactly the mirror of Phase 10: Phase 10 froze selection and
improved realization; Phase 11 freezes realization (and safety/CBT) and
improves selection. `counseling-v1-clean-baseline` (2026-09-28) is the
fixed starting point — this phase builds on top of it, not instead of it.

## P1 — Goal exhaustion has no recovery path

**Exact location**: `lib/features/counseling/policy/selectors/reflect_decision_selector.dart`,
`ReflectDecisionSelector._selectGoal()` (lines ~139-149):

```dart
ReflectQuestionGoal _selectGoal(List<CounselingMessage> messages) {
  final askedIds = messages
      .where((message) => !message.isUser)
      .map((message) => message.dialogueGoalId)
      .whereType<String>()
      .toSet();

  for (final goal in goalOrder) {
    if (!askedIds.contains(goal.name)) return goal;
  }
  return goalOrder.last;   // <- "GoalExhaustionPolicy.repeatLast"
}
```

`GoalExhaustionPolicy.repeatLast` is not a class — it's a *name for this
one line's behavior*, referenced only in comments
(`policy_boundary.dart`, `policy_boundary_request.dart`,
`evaluation/aggregate_report.dart`, `evaluation/holdout_v2_realization_scenarios.dart`).
There is no `GoalExhaustionPolicy` type in the codebase today. When
`askedIds` already contains all three `ReflectQuestionGoal` values
(`evidence`, `alternative`, `probability` — tracked via
`CounselingMessage.dialogueGoalId`, set from `TurnPlan.progressGoalId`),
the only possible outcome is: **re-select the last goal in the fixed
order (`probability`), forever.** There is no branch that considers
summarizing, transitioning to intervention, revisiting a different
topic, or just acknowledging without a new question.

**Reproduced live**: `phase10_6c_dogfood_log.md` (Build A, session 2) —
identical question repeated verbatim across two consecutive turns after
all three goals were exhausted.

**Real recovery options are structurally different from each other** —
this is why a single enum value replacing `repeatLast` isn't enough; the
contract needs to name the actual distinct actions available:

- `summarize` — hand off to `closing`-style summary of what's been
  covered, without asking anything new.
- `listenWithoutQuestion` — the process-signal-style "no question this
  turn" pattern (already exists as a *response shape* in
  `DeterministicProcessSignalTurnPlanner`, just never chosen by goal
  exhaustion itself).
- `revisitPreviousIssue` — pull a different topic into `reflectionTarget`
  instead of the exhausted one. **Design note**: the infrastructure this
  would need only half-exists — `CounselingProvider._carriedUnfinishedIssue`
  (`counseling_provider.dart:109`, sourced from
  `PreviousSessionSelector.selectUnfinishedIssue`) carries an unresolved
  topic *across sessions*, but there is no equivalent "other topics raised
  earlier in *this* session" tracker exposed to the reflect selector today.
  Implementing this recovery option for real (Phase 11.3) needs that
  same-session tracker built first — noted here so 11.3 doesn't discover
  it mid-implementation.
- `transition` — end reflect early and move to intervention/closing, via
  the existing `CounselingStatePolicy` acceleration mechanism (an
  existing `DialogueAct` already does this for other cases —
  `_acceleratesFrom`, referenced in `DeterministicProcessSignalTurnPlanner`'s
  own comment at line ~428).

## P2 — Meta-conversation recognition is partial, not absent

**Correction to the Phase 10.6C-DOGFOOD framing**: that finding said the
selection/router layer has "no way" to recognize meta-conversation. Code
inspection for this phase found that's only partially true.

**Exact location**: `lib/features/counseling/turn_plan.dart`,
`DeterministicProcessSignalTurnPlanner` (lines 370-441, reused unchanged
inside `PolicyPipelineTurnPlanner` as a Hard Guard — see that file's own
doc comment: "identical order, identical logic"). It already matches:

```dart
_requestsEmpathy:  그냥 얘기 좀 들어주세요 | 들어만 주세요 | 왜 자꾸 물어 |
                   질문 그만/말고 | 그만 물어/질문 | 공감 좀 해줘 | 위로 좀 해줘
_showsProcessResistance: 뭐가 달라질까 | 소용 없 | 의미 없 | 그냥 하라고 해서 | ...
```

So **"그 질문 그만해"** and **"왜 자꾸 물어봐"** are already caught today
— confirmed by matching the live regex, not assumed. What is **not**
caught (confirmed by the same method — these do not match either
regex):

- "왜 똑같은 말을 반복하지?" (the exact phrase from the real dogfood
  session, `phase10_6c_dogfood_log.md`) — "반복" is not in either
  pattern; `_requestsEmpathy`'s "왜...자꾸...물어" requires literally
  "자꾸"+"물어", not "반복".
- "아까도 물어봤잖아" — no pattern references referring back to a prior
  turn at all.
- Any phrasing built around *repetition* as the complaint, as opposed to
  *frequency of questioning* or *general futility*.

**Refined problem statement**: this is not "add meta-conversation
detection from scratch" — it's "the existing Hard Guard already has the
right architectural slot (it runs before selection, can produce a
no-new-content turn, and is state-position-preserving); its pattern
coverage has a specific, named gap: complaints about *repetition*
specifically." That's a much smaller, more precise fix surface than the
original framing suggested.

**Also worth noting for 11.2** (not a change here): when this planner's
plan fires during `explore`/`reflect` state, it currently builds no
`realizationSpec` at all (its `CounselingTurnPlan` literal omits the
field — defaults to `null`). Per §9.2/9.3 of `chatbot_architecture.md`,
a null spec makes `SemanticDeterministicResponseRealizer` fall back to
`reflectionSentenceRaw` — harmless today because this planner's raw
sentences don't quote anything, but worth deciding deliberately in 11.2
whether process-signal turns should get a real
`InteractionRepairReason`-carrying spec instead of relying on that
fallback being accidentally safe.

## New contracts (additive only — not referenced by any selector yet)

Proposed location: `lib/features/counseling/policy/interaction_repair.dart`
(new file, no imports from anywhere production-reachable yet — mirrors
how `CounselingRealizationSpec` started in Phase 10.2, a freestanding
file nothing consumes until the next sub-phase wires it in).

```dart
/// Phase 11.1: names *why* a turn is being redirected into repair mode,
/// instead of continuing ordinary worry-content selection. Grounded in
/// the concrete phrasings found missing from
/// `DeterministicProcessSignalTurnPlanner`'s existing coverage (P2 above)
/// — not a speculative taxonomy.
enum InteractionRepairReason {
  /// "왜 똑같은 말을 반복하지?" / "아까도 물어봤잖아" — the complaint is
  /// specifically that the same thing keeps being asked. Distinct from
  /// [stopQuestioning]: the user isn't asking to stop, they're pointing
  /// out non-progress.
  repeatedQuestion,

  /// "질문 그만해" / "그만 물어" — already detected today via
  /// `_requestsEmpathy`; named here so the *contract* has one place that
  /// describes both the already-handled and not-yet-handled cases
  /// uniformly, ahead of 11.2 actually restructuring the detection code.
  stopQuestioning,

  /// "뭐가 달라질까" / "소용 없어" — already detected today via
  /// `_showsProcessResistance`. Same rationale as above.
  processFrustration,
}

/// Phase 11.1: names the recovery actions available to the reflect
/// selector once every `ReflectQuestionGoal` has been asked (P1 above).
/// `repeatLast` stays the last-resort member, not deleted — see
/// Phase 11.3's intended precedence order.
enum GoalExhaustionRecovery {
  summarize,
  listenWithoutQuestion,
  revisitPreviousIssue,
  transition,

  /// Today's only behavior (`ReflectDecisionSelector._selectGoal`'s
  /// `return goalOrder.last`), kept as the explicit final fallback so a
  /// recovery selector that can't confidently choose one of the above
  /// still has a defined, tested exit rather than an unhandled case.
  repeatLast,
}
```

Both enums are pure data. Nothing constructs them yet — that's Phase
11.2 (interaction repair detection → `InteractionRepairReason`) and
Phase 11.3 (goal exhaustion recovery → `GoalExhaustionRecovery`).

## Explicit non-goals for 11.1

- No change to `ReflectDecisionSelector`, `DeterministicProcessSignalTurnPlanner`,
  `CounselorDecision`, or `CounselingTurnPlan`'s fields.
- No new regex patterns added to production matching.
- No same-session topic tracker built (noted as a real dependency for
  `revisitPreviousIssue`, not built here).
- No test changes — nothing production-reachable changed, so nothing to
  regress. (This differs from Phase 10.1-10.2's baseline-lock tests
  because those phases were building *toward* a realization contract
  that would later be consumed unconditionally; this phase's contract
  isn't consumed until 11.2/11.3, so there's no behavior to lock yet.)

## Planned sequence (unchanged from the brief, recorded here for continuity)

```text
11.1  Problem & contract freeze              <- this document
11.2  Meta-conversation detection            extend the Hard Guard's
                                              existing regex coverage
                                              (repeatedQuestion), attach
                                              InteractionRepairReason
11.3  Goal exhaustion recovery               GoalExhaustionRecovery
                                              selector, repeatLast as
                                              final fallback only
11.4  Frozen scenario evaluation             selection regression, not
                                              an LLM wording evaluation:
                                              same-goal-repeated == 0,
                                              meta-feedback-ignored == 0,
                                              unauthorized-state-jump == 0,
                                              CBT/safety regression == 0
```
