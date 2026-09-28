# Phase 11.4 — Frozen Scenario Evaluation (Selection Regression)

**Status: complete. Result: all four zero-tolerance metrics at 0.**
This is a selection regression check, not an LLM wording evaluation — no
network calls, no realizer, fully deterministic and re-runnable as part
of `flutter test`.

## Manifest

```text
datasetVersion : phase9_2b_frozen_v1 (frozenScenarios)
scenarioCount  : 89  (checkIn/explore 14, reflect 31, intervention 21,
                      personalization/closing/mixed 23 — all 5 states)
entry point    : PolicyPipelineTurnPlanner.plan()  (Hard Guard +
                 boundary -> DeterministicCounselorAgent -> validator ->
                 TurnPlanAdapter; the same planner CounselingHarness uses)
extra fixtures : 10 interaction-repair phrasings x 4 states = 40
                 (Phase 11.2's 8 repeatedQuestion positives + 1
                 stopQuestioning + 1 processFrustration)
runner         : test/counseling/evaluation/phase11_4_selection_regression_test.dart
baseline       : counseling-v1-clean-baseline + Phase 11.2 + 11.3 (155df0d)
```

### Why `frozen_v1`, not the Phase 10.5 holdout sets

Phase 11.3's "Next" note said to reuse the scenario set from Phase 10's
realization evaluation. That set is `holdout_v2` (52, the GO verdict) and
`holdout_v1` (72, dev) — both **explore/reflect only by construction**,
because realization only runs there. Two of this phase's four metrics
(unauthorized state jumps, CBT regression) are mostly exposed in
checkIn/intervention/closing, which those sets never contain. `frozen_v1`
is the only frozen corpus covering all five states, so it's the primary
set here. The holdout sets can be added as a second pass if wanted; they
would only add explore/reflect coverage.

## Metric definitions (fixed before running)

| Metric | Definition | Scope |
|---|---|---|
| same-goal-repeated | reflect plan's `progressGoalId` is already in the fixture's asked-goal set; or, when all 3 goals are asked, any goal id selected at all (instead of `goalExhaustionRecovery` + no question) | 31 reflect scenarios |
| unauthorized-state-jump | a repair or recovery turn whose `requiredAct` is the state's early-acceleration act (`explore`→`reflect`, `reflect`→`summarize`, per `CounselingStatePolicy._acceleratesFrom`) | all 89 + 40 |
| meta-feedback-ignored | an interaction-repair phrasing that does not produce `interactionRepairReason` of the right type, or that still asks a question / cites CBT | 40 (4 states x 10) |
| CBT/safety regression | deterministic decision rejected by `CounselorDecisionValidator`, or `TurnPlanAdapter.build` throws, or the plan cites CBT outside `eligibleInterventionIds`, or an intervention plan outside intervention state | all 89 |

"CBT/safety regression" uses Phase 9.2D's definition of regression for
this pipeline (validator/materializer disagreement). `SafetyGate` itself
is frozen for Phase 11 and runs before planning, so it isn't in scope.

"Unauthorized state jump" follows the definition settled in 11.2/11.3:
ordinary turn-budget advancement is allowed. Only an extra,
selection-driven acceleration counts.

## Results

| Metric | Count | Checked |
|---|---|---|
| same-goal-repeated | **0** | 31 reflect scenarios (incl. 4 `reflect_goal_exhausted_repeat`, which now all select `goalExhaustionRecovery`) |
| unauthorized-state-jump | **0** | 129 turns |
| meta-feedback-ignored | **0** | 40 phrasing x state cases |
| CBT/safety regression | **0** | 89 scenarios |

219 tests in the runner, all passing. Whole project: **1126/1126**,
`flutter analyze` unchanged (5 pre-existing `unnecessary_import` infos).

## Limits of this evaluation

- **Single-turn only.** Every fixture is one planning call on a fixed
  history. It does not simulate multi-turn sessions, so it can't catch
  cases like "recovery fires and the next turn loops back into the same
  summary". Phase 11.3's harness-level tests cover a few of these by hand.
- **No state machine.** `PolicyPipelineTurnPlanner` returns a plan, not a
  next state. The state-jump metric checks the act that would drive
  `CounselingStatePolicy`, not an actual transition.
- **The meta-feedback phrasings are the same ones used to build the
  detector** (Phase 11.2). This is a regression guard, not a
  generalization test. Real paraphrase coverage still needs dogfood data
  or a fresh holdout.
- Fixture labels in `frozen_scenarios_reflect.dart` still say
  "exhausted repeat-last". The frozen corpus wasn't edited, so the label
  is historical.

## Phase 11 status

11.1 (problem freeze) → 11.2 (repeated-question detection) → 11.3 (goal
exhaustion recovery) → 11.4 (this evaluation) are all done. Natural next
steps, none started:

1. Device dogfooding of the 11.2/11.3 behavior (Korean input has to be
   typed by hand, since `adb input text` can't send Hangul).
2. A multi-turn scripted evaluation, to cover the single-turn limit above.
3. `revisitPreviousIssue`, which needs a same-session topic tracker first.
