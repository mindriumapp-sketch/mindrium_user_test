# Phase 10.3B — Reflection Surface Robustness

**Status: complete.** Narrow follow-up to Phase 10.3, fixing exactly the
two target-shape composition defects found via the 72-scenario dev
comparison export — nothing else. Verified: `flutter analyze` clean;
`flutter test test/counseling/` 786/786 pass (774 pre-existing + 12 new
Phase 10.3B tests).

## The two defects (recap)

```
holdout_checkIn_3
  target: "가족들이랑 또 다퉜어요. 마음이 복잡해요." (multi-sentence)
  before: "가족들이랑 또 다퉜어요. 마음이 복잡해요 부분이 마음에 걸리시는 것 같아요."
  after:  "지금 이 부분이 계속 마음에 걸리시는 것 같아요."

holdout_intervention_already_used_1
  target: "생각을 또 바꿔볼까요." (question-shaped, no literal "?")
  before: "생각을 또 바꿔볼까요 부분이 마음에 걸리시는 것 같아요."
  after:  "지금 이 부분이 계속 마음에 걸리시는 것 같아요."
```

## What was built

`lib/features/counseling/policy/realization/semantic_deterministic_realizer.dart`
gained:

- `ReflectionTargetShape` (4 values: `phrase`, `declarativeSentence`,
  `questionSentence`, `multiSentence`) — a pure surface-syntax
  classification, never used for selection or meaning.
- `classifyReflectionTargetShape(String raw)` — a top-level function using
  two regex checks, both deliberately conservative:
  - **Multi-sentence detection**: any terminal punctuation
    (`.`/`!`/`?`) followed by more non-space content before the string
    ends.
  - **Question-form detection**: Korean question-predicate endings
    (`-까요`, `-나요`, `-는가요`, `-인가요`, `-일까요`) checked against the text
    *with trailing punctuation stripped* — this app's actual data uses
    `-까요.` (period), never a literal `?`, so a punctuation-only check
    would have missed every real case. Bare `-가요` is deliberately
    excluded from this list (see code comment) because it collides with
    the ordinary declarative conjugation of 가다 ("가요" = "[I] go") —
    tagging it as always-question would misclassify plain statements.
- `_renderTargetText` now branches: `multiSentence`/`questionSentence`
  (and the pre-existing empty-target case) route to a new
  `_groundedAcknowledgmentFallback` — a 3-candidate, fully generic,
  content-free acknowledgment pool (rotated via the same
  `DeterministicSurfaceVariation` mechanism already used elsewhere) —
  instead of the specific suffix-concatenation template. `phrase`/
  `declarativeSentence` are unaffected: same 3 candidates as Phase 10.3A.

No Korean sentence-final ending is truncated or reconstructed anywhere in
this change — per the explicit instruction to avoid aggressive
morphological surgery, the fallback simply doesn't use the target's raw
text at all when the shape is unsafe, rather than trying to repair it.

## Priority order followed

```
specific, safe semantic reflection      (phrase / declarativeSentence — unchanged)
        >
short grounded acknowledgment            (multiSentence / questionSentence — NEW fallback)
        >
grammatically broken specific reflection (Phase 10.3A's defect — eliminated)
```

## Verification

- New tests: `test/counseling/evaluation/phase10_3b_reflection_robustness_test.dart`
  (12 tests) — shape classifier unit tests (6, including the `-가요`
  false-positive guard) plus integration tests through
  `TurnPlanMaterializer` + `SemanticDeterministicResponseRealizer`
  confirming: the two original defects no longer occur; ordinary
  phrase/declarative targets are unaffected; the fallback introduces no
  target-specific content (`가족`/`다퉜` do not appear in the fallback
  output); `questionSentence`/`selectedAction`/`selectedGoalId`/
  `selectedInterventionId` all unchanged.
- Dev comparison export (`phase10_3_dev_comparison_export.dart`)
  regenerated: **7/72** scenarios now route through the new fallback (all
  multi-sentence or question-shaped targets); the other 65 are unaffected
  by this phase, still rendered exactly as Phase 10.3A produced them.
- `flutter test test/counseling/`: **786/786** pass, including Phase
  10.1's golden baseline (legacy realizer) and Phase 10.3's 8 tests,
  unmodified.

## Explicit scope compliance

Not touched in this phase: non-intervention transitions (R3 elsewhere),
acknowledgment variety (R2), generic empathy (R5), intervention bridge
variation (R8), under-responsiveness (R11), broader punctuation polish
(R12), the intervention bridge itself (unchanged from Phase 10.3A),
`ResponseRealizer` production default (still `DeterministicResponseRealizer`),
selection layer, `CounselorDecision`, `TransitionIntent`/`InterventionRationale`
semantics.

## Next: Phase 10.4A

Blind dev review (legacy vs. semantic, on the 72 `holdout_v1` dev
scenarios) can now proceed without reviewers re-discovering the two known
surface-composition bugs this phase removed. Expected review focus should
now land on real semantic-realization questions: does the intervention
bridge actually read as connected reasoning, does removing quotes read as
warmer or just blander, and how much of the original 45/72 `bothPoor` rate
this changes at all — not on grammatically broken sentences.
