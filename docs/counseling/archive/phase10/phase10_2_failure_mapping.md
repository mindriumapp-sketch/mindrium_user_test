# Phase 10.2 — Semantic Realization Contract & Failure Mapping

**Status: contract implemented, zero production behavior change** (verified:
`flutter test test/counseling/` — 766/766 pass, including Phase 10.1's
golden baseline tests unmodified).

## What was built

```
CounselorDecision                                          [FROZEN]
        │
        ▼
TurnPlanMaterializer.{checkIn,explore,reflect,intervention,closing}
        │
        ├──▶ reflectionSentence / questionSentence   [unchanged, legacy]
        │        │
        │        ▼
        │    CounselingTurnPlan.deterministicReply    [unchanged, legacy]
        │        │
        │        ▼
        │    ResponseRealizer (DeterministicResponseRealizer = no-op)
        │        │
        │        ▼
        │    what the user sees today — BYTE-IDENTICAL to before Phase 10.2
        │
        └──▶ CounselingRealizationSpec                [NEW, additive]
                 (TransitionIntent, InterventionRationale,
                  InterventionRealizationSpec, ClosingIntent)
             — built by RealizationSpecBuilder, attached to
               CounselingTurnPlan.realizationSpec (nullable).
               Nothing reads it yet. It exists for a future
               ResponseRealizer to consume.
```

New files:
- `lib/features/counseling/policy/realization/realization_spec.dart` —
  the contract types (`CounselingRealizationSpec`, `TransitionIntent`,
  `InterventionRationale`, `InterventionRealizationSpec`, `ClosingIntent`).
- `lib/features/counseling/policy/materializers/realization_spec_builder.dart` —
  pure functions building the spec per state, kept separate from
  `TurnPlanMaterializer`'s sentence-building methods so the two concerns
  (legacy strings vs. semantic contract) stay visibly distinct in source.

Changed files (additive only — no existing field, string, or branch
removed or altered):
- `lib/features/counseling/turn_plan.dart` — `CounselingTurnPlan` gained one
  new optional field, `realizationSpec` (default `null`).
- `lib/features/counseling/policy/materializers/turn_plan_materializer.dart` —
  each of the 7 `CounselingTurnPlan(...)` construction sites (checkIn,
  explore, reflect×2, intervention, interventionUnavailable, closing) now
  also passes `realizationSpec: RealizationSpecBuilder.____(...)`.

Legacy `Deterministic*TurnPlanner` classes in `turn_plan.dart` (the two
non-materializer `CounselingTurnPlan(...)` sites, predating `CounselorDecision`)
were left untouched — `realizationSpec` stays `null` there, as documented
on the field. Out of scope for this phase.

## Failure taxonomy (R1-R12) → contract mapping

| ID | Category | Resolved by | How |
|---|---|---|---|
| R1 | Verbatim repetition | `CounselingRealizationSpec.reflectionTarget` (already `ReflectionTarget`, not a pre-quoted string) | A future realizer receives the raw target and an explicit `TransitionIntent`, and can choose to paraphrase — the *option* to not quote now exists structurally; today's legacy strings still quote, unchanged in this phase |
| R2 | Mechanical acknowledgment skeleton | Not resolved by the contract alone — it's a *wording* choice a realizer makes | Deferred to Phase 10.3 (an actual `ResponseRealizer` implementation) |
| R3 | Abrupt question transition | `TransitionIntent` | Names *why* a question follows a reflection (`assessSeverity`, `exploreMoment`, `askForEvidence`, `bridgeToIntervention`, etc.) instead of the plan only holding two independent finished strings joined by `' '`. A realizer can now write an actual bridging clause because it knows the semantic relationship, not just two strings to concatenate |
| R4 | Reflection-question mismatch | `questionGoal` + `TransitionIntent` together | Both are now available to a realizer at the same time it sees `reflectionTarget`, instead of the question being computed independently (as `explore`'s inline string-matching still does today) |
| R5 | Generic empathy | Not resolved — this is a template-content problem, not a missing-field problem | Deferred to Phase 10.3 |
| R6 | Redundant semantic repetition | Unconfirmed in 10.1; not applicable here | Re-check in Phase 10.3 against real transcripts |
| R7 | Intervention bridge failure | `InterventionRealizationSpec.rationale` (`InterventionRationale` enum) | This is the field that did not exist at all before — "why this intervention" is now a grounded, traceable enum value (`examineThought`, `reviewAvoidancePattern`, etc.), not absent |
| R8 | Intervention template rigidity | Not resolved by the contract alone — rotation/variation is a realizer-side wording choice | The contract makes rotation *possible* (a realizer sees rationale + target + transition, enough to vary wording); Phase 10.3 must still implement it |
| R9 | Closing discontinuity | `ClosingIntent` (`summarizeWithTopic` / `summarizeGeneric`) | Names the branch explicitly instead of only an inline `target == null` check; still doesn't feed `recentMessages` into closing — flagged as a remaining gap, not solved |
| R10 | Over-composed turn | N/A (Phase 10.1 found this isn't a real issue — `requireExactlyOneQuestion` structurally prevents it) | No action needed |
| R11 | Under-responsive turn | Partially — `questionGoal` now always travels with `reflectionTarget` in one object | Whether checkIn/intervention's *questions* themselves become responsive to `target` is a Phase 10.3 wording decision; the contract doesn't force it |
| R12 | Quote/punctuation artifact | Not resolved — these are string-manipulation bugs in the legacy sentence-building code, unrelated to the new contract | Deferred to Phase 10.3 if still present after R1/R8 fixes change how quoting happens |

## Explicit scope compliance

- Selection layer (`selectedAction`/`selectedGoalId`/`selectedInterventionId`,
  `PolicyBoundary`, all `policy/selectors/*.dart`) — **not touched.**
- `CounselorDecision` — **not touched.**
- `ResponseRealizer` / `DeterministicResponseRealizer` behavior — **not
  touched**; still reads only `deterministicDraft`, ignores `realizationSpec`
  entirely.
- `RemoteCounselorAgent`, `/counseling/realize` — **not touched.**
- No sentence template, wording, or string literal in
  `TurnPlanMaterializer` was changed.
- `reflectionSentence` / `questionSentence` / `deterministicReply` — kept
  exactly as-is, per the compatibility-path requirement.

## Verification

- `flutter analyze` on all new/changed files: no issues.
- `flutter test test/counseling/`: 766/766 pass — includes
  `phase10_1_realization_baseline_test.dart`'s 4 golden-output assertions,
  unmodified, still green; includes the full pre-existing suite
  (`decision_contract_matrix_test.dart`, `holdout_v1_fixture_invariant_test.dart`,
  `phase8_4b_causal_wiring_test.dart`, etc.) with no regressions.

## Phase 10.2 completion checklist (against the request)

- [x] Semantic realization contract exists (`CounselingRealizationSpec`)
- [x] Transition intent separated from surface string (`TransitionIntent` enum)
- [x] Intervention rationale explicit and grounded (`InterventionRationale`
      enum, mapped 1:1 from `InterventionType`)
- [x] All 5 states produce a semantic spec via `TurnPlanMaterializer`
- [x] Materializer/Realizer responsibility boundary now named in code
      (see this file's diagram) — though `ResponseRealizer` still doesn't
      *use* the boundary yet; that's Phase 10.3
- [x] Legacy `reflectionSentence`/`questionSentence`/`deterministicReply`
      path fully preserved
- [x] `ResponseRealizer` contract can be extended later to accept
      `CounselingRealizationSpec` (via `CounselingTurnPlan.realizationSpec`)
      without any interface change needed now
- [x] Production output change: 0 (test-verified)
- [x] Phase 10.1 golden tests green, unmodified
- [x] Full existing suite green (766/766)

## Next: Phase 10.3

Implement an actual `ResponseRealizer` that reads `realizationSpec` (not
just `deterministicDraft`) and produces improved wording — this is where
R1/R2/R5/R8/R11/R12 get addressed for real, evaluated first as dev/regression
against Phase 9.2E's 72 holdout scenarios (already-seen, dev-only), then a
fresh unseen holdout before any production wiring change.
