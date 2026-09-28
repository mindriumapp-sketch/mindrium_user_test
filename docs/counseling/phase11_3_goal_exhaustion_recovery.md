# Phase 11.3 — Goal Exhaustion Recovery

**Status: complete.** Replaces the `repeatLast` magic fallback
(`ReflectDecisionSelector._selectGoal` silently returning `goalOrder.last`
forever once all three `ReflectQuestionGoal`s were asked) with an
explicit, typed recovery selection that goes through the same
decision/validator/materializer contract as every other reflect
decision — closing the exact class of gap Phase 9.2D's real evaluation
run found (a decision shape the validator and materializer disagreed
about). Detection (Phase 11.2) is untouched; this phase is recovery
only, per Phase 11.1's explicit scope split.

## What changed

- `lib/features/counseling/policy/counselor_decision.dart`: `CounselorDecision`
  gained `final GoalExhaustionRecovery? goalExhaustionRecovery;` — mutually
  exclusive with `selectedGoalId` for reflect decisions (never both, never
  neither), enforced below, not just documented.
- `lib/features/counseling/policy/decision_contract.dart`: new
  `RecoveryRequirement` enum (`required`/`forbidden`), a `recoveryRequirement`
  field on `DecisionRequirements` (default `forbidden`, so every existing
  non-reflect branch is unaffected), and a third reflect branch in
  `decisionRequirementsFor` for `selectedAction == DialogueAct.reflect`
  (goal forbidden, recovery required) alongside the existing `explore`
  (clarify) and default (normal `socraticQuestion`) branches.
- `lib/features/counseling/policy/counselor_decision_validator.dart`:
  `CounselorDecisionValidator` now checks `recoveryRequirement` the same
  way it already checked `goalRequirement` — this is what actually
  enforces the XOR contract release-safely, not just via selector
  discipline.
- `lib/features/counseling/policy/selectors/reflect_decision_selector.dart`:
  - New sealed `ReflectGoalSelection` (`SelectedReflectGoal` /
    `ExhaustedReflectGoals`), mirroring `ReflectionTarget`'s existing
    pattern — replaces the old `_selectGoal() -> ReflectQuestionGoal`
    (which had no way to express "exhausted" except lying about which
    goal was chosen).
  - `_selectGoalOrRecover` replaces `_selectGoal`; the exhausted branch no
    longer sets `selectedGoalId` at all — no `selectedGoalId = 'summarize'`
    or similar placeholder.
  - New `_selectRecovery(recentMessages)`: looks **only** at
    `recentMessages.last` (the immediately preceding turn, never any
    earlier occurrence) — if it was an `InteractionRepairReason.repeatedQuestion`
    or `.stopQuestioning` acknowledgment, picks
    `GoalExhaustionRecovery.listenWithoutQuestion`; otherwise (including
    `.processFrustration` or no repair signal at all) picks
    `GoalExhaustionRecovery.summarize`.
  - `select()`'s exhausted branch returns
    `selectedAction: DialogueAct.reflect` — deliberately not `.summarize`
    (would trigger `CounselingState._acceleratesFrom`'s reflect→intervention
    acceleration) and not `.socraticQuestion` (would imply a goal was
    pursued).
- `lib/features/counseling/policy/materializers/turn_plan_materializer.dart`:
  `reflect()` gained a third branch (`decision.goalExhaustionRecovery != null`)
  dispatching to new `_reflectRecovery()`, which materializes `summarize`
  and `listenWithoutQuestion` explicitly (no new question, generic/safe
  recap-or-acknowledge content, `TurnConstraint.requireNoQuestion` +
  `forbidNewUserFacts` + `forbidNewIntervention`, `requiredAct:
  DialogueAct.reflect`); `revisitPreviousIssue`, `transition`, and
  `repeatLast` throw a descriptive `StateError` — an explicit "not
  implemented yet" failure, not a silent generic-response fallback (the
  exact anti-pattern this phase replaces). No `realizationSpec` is built
  for recovery turns: Remote Realizer is deliberately not invoked for
  recovery surfaces yet (deterministic only), matching
  `DeterministicProcessSignalTurnPlanner`'s existing precedent for its own
  "no new question" turns.
- `lib/data/counseling/counseling_models.dart`: `CounselingMessage` gained
  `final GoalExhaustionRecovery? goalExhaustionRecovery;`, mirroring
  Phase 11.2's `interactionRepairReason` precedent; `GoalExhaustionRecovery`'s
  doc comments updated to reflect which members are implemented
  (`summarize`/`listenWithoutQuestion`) vs. frozen-but-not-selectable
  (`revisitPreviousIssue`/`transition`) vs. legacy history (`repeatLast`).
- `lib/features/counseling/turn_plan.dart`: `CounselingTurnPlan` gained the
  matching `goalExhaustionRecovery` field.
- `lib/features/counseling/counseling_harness.dart`: threads
  `turnPlan.goalExhaustionRecovery` into the assistant `CounselingMessage`,
  alongside the existing `interactionRepairReason` line.
- Tests: `test/counseling/goal_exhaustion_recovery_test.dart` (new, 12
  tests, groups A/B/C per the frozen plan), 7 new decision-contract-matrix
  cases in `test/counseling/decision_contract_matrix_test.dart` (the XOR
  invariant, both directions, plus the recovery branch's own text/goal
  requirements), and three pre-existing tests updated because they
  asserted the exact `repeatLast` behavior this phase removes:
  `test/counseling/reflect_planner_test.dart`,
  `test/counseling/counselor_decision_materializer_invariant_test.dart`,
  and two archived Phase 8 equivalence tests in `test/research_regression/`
  (`phase8_3b_selector_equivalence_test.dart`,
  `phase8_counselor_agent_equivalence_test.dart` — updated rather than
  left broken, since both exercise the *same shared* `ReflectDecisionSelector`
  production code, not a frozen copy of it).

## Why `DialogueAct.reflect`, not `.summarize`

`CounselingState._acceleratesFrom(reflect, act)` returns `true` only for
`act == DialogueAct.summarize` — this is reflect's *only* early-exit
trigger (see `counseling_state.dart`). A recovery turn's whole point is to
stay on the ordinary turn-budget schedule, not to introduce a second,
selection-driven way to leave reflect early. `DialogueAct.reflect` is
already a member of `CounselingState.reflect.allowedActs`
(`[reflect, summarize, socraticQuestion]`), so no boundary-widening change
was needed — the same reasoning `DeterministicProcessSignalTurnPlanner`
already uses for its own repair turns in reflect/intervention state.

## The XOR contract, and where Phase 9.2D's lesson applies

Phase 9.2D found that `CounselorDecisionValidator` and
`TurnPlanMaterializer` had silently diverged: a decision shape the
validator accepted crashed materialization, because "what shape is valid"
existed only informally, split across two files. This phase's XOR
(`(selectedGoalId != null) XOR (goalExhaustionRecovery != null)` for every
reflect decision) is enforced the same centralized way Phase 9.2D fixed
that gap — as a `RecoveryRequirement` value inside `decisionRequirementsFor`,
read by both the validator (`CounselorDecisionValidator`) and indirectly
guaranteed for the materializer (which only reads `goalExhaustionRecovery`
after the validator has already rejected any decision where it's
inconsistent). The decision-contract-matrix tests exercise all four
corners directly: recovery alone (valid), goal alone (valid, existing),
both set (invalid), neither set for `action=reflect` (invalid).

## Guarantees this phase makes — and does not make

```text
Phase 11.3 guarantees:
  - no goal is ever re-asked once all three are exhausted (no more
    `selectedGoalId = goalOrder.last` repeated forever)
  - no fake goal id is invented for a recovery turn (selectedGoalId is
    null, not a placeholder string)
  - a recovery turn asks zero new questions
    (TurnConstraint.requireNoQuestion, questionSentence: '')
  - a recovery turn introduces no new CBT intervention or user fact
    (forbidNewIntervention, forbidNewUserFacts)
  - a recovery turn does not bypass CounselingStatePolicy — it stays on
    the ordinary turn-budget schedule exactly like any other reflect
    turn (verified against a control scenario at the same budget
    position, not by asserting "state never changes" — see below)
  - the recovery choice reacts to the immediately preceding turn's
    InteractionRepairReason only (repeatedQuestion/stopQuestioning ->
    listenWithoutQuestion instead of summarize) — never any earlier
    occurrence in the session
  - an unimplemented recovery type (revisitPreviousIssue/transition/
    repeatLast) fails loudly (StateError) if ever constructed, rather
    than silently falling back to a generic response

Phase 11.3 does NOT guarantee:
  - revisitPreviousIssue is selectable (the same-session "other topics
    raised earlier" tracker it needs still doesn't exist — Phase 11.1's
    finding, unchanged)
  - transition is selectable (ending reflect early is not this
    recovery's job; CounselingStatePolicy's turn budget remains the only
    authority over state advancement, confirmed unchanged in Phase 11.2)
  - Remote Realizer produces recovery wording (no realizationSpec is
    built for a recovery turn; only the deterministic path materializes
    it, matching DeterministicProcessSignalTurnPlanner's own precedent)
```

### The corrected "state progression" assertion

Phase 11.2 already established the right invariant the hard way (a wrong
first assertion, fixed after tracing the actual budget rule): **"the state
did not change" is not the guarantee.** Reflect's turn budget is 2; a
recovery turn landing on the reflect-state's budget-exhausting position
advances to intervention exactly like an ordinary content turn would, and
that is expected, not a bug. What must not happen is an *extra*
acceleration specific to the recovery mechanism itself — which would only
be possible via `_acceleratesFrom`, which recovery turns never trigger
(see above). The B-group harness test in
`goal_exhaustion_recovery_test.dart` verifies this directly: a recovery
turn and a plain control turn at the same `turnsInCurrentState` position
end up in the same state.

## Regression evidence

- `flutter analyze`: clean (same 5 pre-existing, unrelated info-lints as
  every prior phase this session — all `unnecessary_import`, none in
  files this phase touched).
- `flutter test` (whole project): **907/907** passing (869 baseline +
  20 Phase 11.2 + 12 new Phase 11.3 tests + 6 net new decision-contract-matrix
  cases; 5 pre-existing tests updated in place because they asserted the
  exact `repeatLast` behavior this phase intentionally replaces, not
  because anything broke unexpectedly).
- Nothing in `SafetyGate`, CBT knowledge/intervention registry,
  `RemoteLlmRealizer`/`realize_v2`, `CounselingRealizationSpec`,
  `RolloutConfig`, or `HybridTurnRouter` was touched — grep-confirmed
  before committing, matching Phase 11.1's frozen scope list.

## Next

Phase 11.4 — frozen scenario evaluation (selection regression, not an LLM
wording evaluation): same-goal-repeated == 0, meta-feedback-ignored == 0,
unauthorized-state-jump == 0, CBT/safety regression == 0, run across the
scenario set already used for Phase 10's realization evaluation. Not
started.
