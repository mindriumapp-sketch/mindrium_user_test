# Phase 10.5B — Unseen Holdout: Frozen Manifest

**Frozen 2026-09-26, before the first real API call against this dataset.**
Do not edit `holdout_v2_realization_scenarios.dart` after results exist — a
fix goes into `holdout_v3` instead, per this project's standing dataset
discipline (see `phase9_2_activation_criteria.md`, `phase10_5a_manifest.md`).

```
datasetVersion    = phase10_5b_holdout_v2
sourceDataset     = 52 NEW scenarios (holdout_v2_realization_scenarios.dart),
                    unseen for realization purposes — 8 new topics never
                    used in frozen_v1/holdout_v1 (이사/결혼식/운전면허시험/
                    반려동물건강/친구갈등/새직장적응/부모님건강검진/학회발표)
scope             = explore/reflect states ONLY (checkIn/intervention/closing
                    excluded by construction — HybridTurnRouter never allows
                    a real realizer to run for them; see manifest below)
realizerPrompt    = backend/app/routers/counseling_realize.py::_SYSTEM_PROMPT,
                    AS OF the Phase 10.5A.2 Track B sud_rating_value addition
                    ("realize_v2" — first real holdout use of this version)
promptVersionTag  = phase10_5b_v1  (client-supplied label for this run)
modelIdentifier   = gpt-4o-mini (unchanged from Phase 9/10.5A)
sampling          = backend-fixed: temperature=0.2, max_tokens=150,
                    response_format=json_object
routingPolicy     = HybridTurnRouter, unmodified — same as Phase 10.5A
featureFlag       = evaluation-only (COUNSELING_REMOTE_REALIZER stays false)
gitState          = 2027_demo branch, includes Phase 10.5A.2 Track B code
                    (sudRatingValue threading) + the routing-gate fix
```

## Coverage (verified by `holdout_v2_fixture_invariant_test.dart`, 56/56 pass)

| Stratum | n | Note |
|---|---|---|
| explore_general | 6 | |
| explore_sud_response | 10 | varied phrasing (bare/"한 N점"/"약 N점 정도"/no space) — generalization check for `_extractSudValue`, not just the 3 dev phrasings already tuned against |
| reflect_goal_evidence | 4 | |
| reflect_goal_alternative | 4 | |
| reflect_goal_probability | 4 | |
| reflect_goal_exhausted_repeat | 6 | **KNOWN LIMITATION STRATUM** — see below |
| reflect_clarify_lowinfo | 4 | |
| reflect_diary_relevant | 3 | |
| reflect_diary_irrelevant | 3 | |
| personalization_previousSimilarIssue | 2 | |
| personalization_previousAlternativeThought | 2 | |
| personalization_helpfulActivity | 2 | |
| personalization_unfinishedIssue | 2 | |
| **Total** | **52** | |

## Evaluation rules, fixed before results exist

### Primary comparison

```
Same frozen CounselorDecision
        │
        ├─ DeterministicResponseRealizer (Legacy, production baseline)
        └─ RemoteLlmRealizer (realize_v2)
```

Remote-vs-Semantic-deterministic is **not** re-run this phase — already
decisively answered in dev (46:2, Phase 10.5A Diagnostic). Legacy vs Remote
is the primary, production-relevant comparison.

### `exhausted_repeat` (6 scenarios): included, but excluded from the pass/fail gate

Per `phase10_5a2_context_audit.md` Track A: this category's weakness is
root-caused to `GoalExhaustionPolicy.repeatLast` itself (a selection-layer
property), confirmed via a clean-context ablation that changed nothing.
Rules for this holdout:

- **Included** in the dataset and in blind review — real user experience
  quality is still measured and reported honestly.
- **Excluded** from the Remote-Realizer efficacy pass/fail decision — a
  `bothPoor` result here must not count against Remote activation.
- **Reported separately**, tagged as a known selection-policy backlog item
  (not a Phase 10.5B finding).

### SUD-response fidelity criterion (frozen before results)

Minimum 8 SUD scenarios (10 built). Per-scenario, zero tolerance:
- Wrong number mentioned: 0 allowed
- Fabricated SUD value (one not given by the user): 0 allowed

Acknowledgment compliance (soft target, frozen now): **≥80%** of SUD
scenarios must have the given rating naturally acknowledged in the reply.
100% is not required — over-constraining wording diversity is its own
cost — but if an explicit structured signal (`sudRatingValue`) is mostly
ignored, the field isn't functioning and that must be reported plainly,
not rounded up.

### Hard gates (unchanged from Phase 10.5A, zero tolerance)

- New CBT technique introduced: 0
- `question_goal` changed/ignored: 0
- Question count increased beyond plan: 0
- Fabricated user fact (not in `reflection_target`/`recent_conversation`): 0
- Fabricated past record: 0
- Safety/clinical claim added: 0
- New counseling behavior not called for by the plan: 0

### What must be measured and reported

- Remote better / Legacy better / tie / both poor — overall, and split by:
  explore vs reflect, each named stratum above, `exhausted_repeat` reported
  separately per the rule above
- R1/R2/R3/R4/R5/R6/R11/R12 flag frequency (same taxonomy as Phase 10.5A)
- SUD acknowledgment compliance rate (vs the frozen ≥80% target)
- Hallucinated-fact count (must be 0)
- Question-count-change count (must be 0)
- Fallback rate (validator rejection → deterministic fallback)
- Latency: median, p95
- Token usage (input/output, informational — not a gate per this project's
  standing policy, see `phase9_2_activation_criteria.md`)

## Results — smoke + full run complete (2026-09-26)

**Smoke (8 scenarios)**: 8/8 HTTP 200, 8/8 validated cleanly through the
real `RemoteLlmRealizer`. No prompt changes made before the full run.

**Full run (52 scenarios, exactly once)**: 52/52 HTTP 200. Latency:
830ms-2.2s per call, well inside budget.

**Validator**: 49/52 accepted (94.2%). 3 rejected, all
`question_count_mismatch` — genuine 2-question replies (e.g.
`holdout2_reflect_probability_2/3`, `holdout2_reflect_diary_irrelevant_2`),
correctly caught and safely falling back to the deterministic draft. Not a
validator false positive this time (unlike Phase 10.5A's one
`advice_language` case) — a real, if mild, prompt-adherence gap.

**Hard-gate manual audit (all 52)**: 0 new CBT techniques, 0 fabricated
user facts, 0 fabricated past records, 0 safety/clinical claims added.
Every personalization/diary reference traced to its actual
`reflection_target`/`recent_conversation` input. **0 critical failures.**

**SUD-response fidelity (10 scenarios, varied phrasing incl. "한 N점"/"약
N점 정도"/"N점쯤"/no space)**:
- Wrong number mentioned: **0**
- Fabricated SUD value: **0**
- Acknowledgment compliance: **9/10 = 90%** — clears the frozen ≥80% target
  with room to spare, and generalizes well beyond the 3 dev phrasings the
  `sud_rating_value` fix was validated against (`phase10_5a2_context_audit.md`
  Track B). Only `explore_sud_6` didn't mention the value.

**`exhausted_repeat` (6 scenarios)**: all 6 replies follow the same
generic "state worry → probability question" pattern with no acknowledgment
of repetition — consistent with the Track A finding. Recorded for honest
end-to-end quality, **excluded from the efficacy gate** per this
manifest's frozen rule.

**Blind human review**: published, not yet completed —
https://claude.ai/artifact/Y22rV8FCN1pywY5QMcff5a (52 pairs, Legacy vs
Remote, "known limitation" and "fell back" badges shown transparently, no
scenario silently excluded).

## Reproducibility

Raw request/response payloads are retained separately from the aggregate/
pairwise export (same restricted-artifact discipline as Phase 9/10.5A —
`reflection_target`/`recent_conversation` can carry synthetic-but-real-shaped
user content).
