# Phase 10.3 — Semantic Deterministic Response Realizer

**Status: complete. Production default NOT switched.** Verified:
`flutter analyze` clean on all new/changed files; `flutter test
test/counseling/` 774/774 pass (766 pre-existing + 8 new Phase 10.3 tests),
including Phase 10.1's golden baseline tests unmodified.

## What was built

```
ResponseRealizer (interface, unchanged)
  ├─ DeterministicResponseRealizer        <-- PRODUCTION DEFAULT, unchanged
  │     realize(request) => request.deterministicDraft  (identity)
  │
  └─ SemanticDeterministicResponseRealizer   <-- NEW, Phase 10.3, PARALLEL
        realize(request):
          if request.realizationSpec == null:
            => request.deterministicDraft  (same identity fallback)
          else:
            reflection := render(spec.reflectionTarget)   [R1]
            bridge     := spec.intervention == null ? null
                           : render(spec.intervention.rationale)  [R7]
            question   := request.questionSentenceRaw  (byte-identical, unchanged)
            => [reflection, bridge, question].where(nonEmpty).join(' ')
```

Not wired into `counseling_harness.dart`'s default — the harness constructor
still defaults to `const DeterministicResponseRealizer()`
(`lib/features/counseling/counseling_harness.dart:176`, unchanged this
phase).

New files:
- `lib/features/counseling/policy/realization/semantic_deterministic_realizer.dart`
- `test/counseling/evaluation/phase10_3_semantic_realizer_test.dart` (8 tests, A/B-C/D/F/G/H/I/J)
- `test/counseling/evaluation/phase10_3_dev_comparison_export.dart` (dev artifact generator, item 12)

Changed files (additive only):
- `lib/features/counseling/response_realizer.dart` — `RealizationRequest`
  gained 3 new fields (`reflectionSentenceRaw`, `questionSentenceRaw`,
  `realizationSpec`), all populated by `fromPlan`. Nothing removed.

## What this realizer targets, and by how much

- **R1 (verbatim quoting)** — resolved structurally for the common case:
  reflection wording is rebuilt from `reflectionTarget`'s raw text through a
  3-candidate, non-quoting template pool (rotated via the existing
  `DeterministicSurfaceVariation`), instead of reusing any
  `"$target"라고...` legacy sentence. Verified across all 72
  `holdout_v1` scenarios via the dev comparison export (see below):
  0 of the semantic-path outputs contain `"`/`"` quote marks; the legacy
  path's do, in every non-empty-target case.
- **R7 (no intervention rationale/bridge)** — resolved: all 5
  `InterventionRationale` values now render a distinct, grounded bridging
  clause between the reflection and the (unchanged) question. Verified by
  test D and by the dev export's `holdout_intervention_*` rows.
- **R3 (abrupt concat)** partially addressed for intervention specifically
  (reflection → bridge → question is no longer a bare 2-part join), but
  **not** addressed for the other four states — `checkIn`/`explore`/
  `reflect`/`closing` still compose as `[reflection, question].join(' ')`,
  now with a de-quoted reflection but still no transition clause. This was
  a deliberate scope-narrowing: the instructions singled out intervention's
  bridge as the priority target for this phase, and Phase 10.3 does not
  claim to have solved R3 generally.
- **R2/R5/R8/R11/R12** — **not addressed.** R8 (zero rotation) is
  structurally improved only insofar as intervention's reflection now
  rotates (3 candidates) where before it didn't — but the bridge itself,
  while grounded per-rationale, is still only 2 fixed candidates per
  rationale. R2/R5/R11/R12 are unchanged.

## Known limitation found during dev comparison

**Fixed in Phase 10.3B** (`docs/counseling/phase10_3b_reflection_robustness.md`)
— left as a known, documented gap at the end of 10.3A, then addressed
immediately as its own narrow follow-up rather than folded into this
phase's scope.

The reflection template (`"$clean 부분이 마음에 걸리시는 것 같아요."` and
siblings) assumes `clean` reads as a noun-phrase-ending fragment. Two
`holdout_v1` scenarios expose where this breaks:

```
holdout_checkIn_3:
  target: "가족들이랑 또 다퉜어요. 마음이 복잡해요"
  semantic: "가족들이랑 또 다퉜어요. 마음이 복잡해요 부분이 마음에 걸리시는 것 같아요."
  (multi-clause target — "부분이" tacked onto a full sentence reads oddly)

holdout_intervention_already_used_1:
  target: "생각을 또 바꿔볼까요"
  semantic: "생각을 또 바꿔볼까요 부분이 마음에 걸리시는 것 같아요."
  (target is itself a question — the template doesn't detect this)
```

This is flagged, not silently hidden: the reflection template needs a guard
for multi-clause/question-shaped targets before any production
consideration. Left as a Phase 10.3 follow-up item, not fixed here, per the
instruction to report and stop rather than iterate indefinitely on wording.

## Invariants verified

| Invariant | How verified |
|---|---|
| `CounselorDecision` unchanged | No file under `policy/selectors/`, `counselor_decision.dart`, `policy_boundary*.dart` touched |
| `questionGoal` unchanged | Never read by the new realizer; only `questionSentenceRaw` (already-selected wording) is reused |
| No new intervention/CBT info | `InterventionRationale` is read, never invented; `intervention.relevantTarget`/`interventionId` pass through unchanged (test G) |
| No new user facts | Only `reflectionTarget`'s existing text and `recentConversation` (already available) are read |
| Question count unchanged | `questionSentenceRaw` reused byte-for-byte (test B/C, F); question-mark count never exceeds the legacy path (test F) |
| `realizationSpec` gaps handled | `null` spec, or a `null`/`ReflectionTargetNone` target, fall back to the legacy per-sentence string rather than inventing wording (test H) |
| Production behavior = 0 change | `flutter test test/counseling/` 774/774 green; Phase 10.1 golden baseline (legacy realizer) unmodified and still passing |

## Dev comparison artifact (item 12)

`test/counseling/evaluation/phase10_3_dev_comparison_export.dart`, run via
`flutter test`, regenerates `/tmp/phase10_3_dev_comparison.json`: legacy vs.
semantic output for all 72 `holdout_v1` scenarios, computed purely
(`ScenarioRunner.run(fixture)` with `remoteAgent: null` — no network call,
deterministic decision only). Latest run: **70/72 changed** between legacy
and semantic output (the 2 unchanged are scenarios whose
`reflectionTarget` is `ReflectionTargetNone`/absent, where the semantic
realizer's documented fallback reuses the legacy sentence verbatim by
design).

This export is explicitly a **dev artifact only** — no blind review was
run against it, and it must not be cited as evidence for or against a
production switch (per the instructions: "이번 phase에서 최종 unseen evaluation은
하지 않는다"). It also only compares realizers against the
**deterministic** decision — `RemoteCounselorAgent` is untouched and
irrelevant here.

## Explicit scope compliance

- Production default `ResponseRealizer` — **not switched.**
- `RemoteCounselorAgent` / `/counseling/realize` — **not touched.**
- `CounselorDecision`, all selectors, `PolicyBoundary` — **not touched.**
- `TurnPlanMaterializer` selection semantics — **not touched** (only
  `RealizationRequest.fromPlan` was extended, additively, in Phase 10.2/10.3).

## Next: Phase 10.4

Per the frozen sequencing:
1. **10.4A** — blind dev review of legacy vs. semantic on the (already-seen)
   72 `holdout_v1` scenarios, using the same `PairwiseExport`/blind-review
   Artifact mechanism built in Phase 9.2E. This is dev-only, not activation
   evidence.
2. Fix whatever 10.4A surfaces (the multi-clause/question-target limitation
   above is a known starting candidate).
3. **10.4B** — a fresh, unseen realization holdout (new scenarios, not
   `holdout_v1` again — it is now dev-seen for this purpose).
4. Only after 10.4B produces a passing quality signal does a production
   `ResponseRealizer` switch become a decision to make — and even then, as
   its own explicit go/no-go step, not a side effect of finishing 10.3.
