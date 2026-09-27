# Phase 10.5A — Frozen Manifest

**Frozen 2026-09-24, before the first real eligible-set API call.** Do not
edit after results exist — a fix goes into a new manifest/prompt version.

```
datasetVersion    = phase10_5a_dev_v1 (= existing phase9_2e_holdout_v1, reused as dev-only)
sourceDataset     = 72 holdout_v1 scenarios (buildHoldoutV1Scenarios())
realizerPrompt    = backend/app/routers/counseling_realize.py::_SYSTEM_PROMPT (unmodified since 2026-09-05 design)
promptVersionTag  = phase10_5a_full_v1  (client-supplied label; server prompt text itself is not versioned server-side)
modelIdentifier   = gpt-4o-mini (backend default, same model used for Phase 9's decide_v2 — no model-choice confound)
sampling          = backend-fixed: temperature=0.2, max_tokens=150, response_format=json_object (not client-adjustable)
routingPolicy     = HybridTurnRouter, unmodified: explore/reflect eligible (llmEnabled:true only via
                    CounselingHarness.remoteGpt()); checkIn/intervention/closing always allowLlm:false
eligibleCount     = 48 (explore=8, reflect=40)
ineligibleCount   = 24 (checkIn=3, intervention=16, closing=5) — NOT sent to the model, deterministic unchanged
featureFlag       = evaluation-only (COUNSELING_REMOTE_REALIZER production flag remains false)
gitState          = 2027_demo branch, includes the routing-gate fix (counseling_harness.dart,
                    HybridTurnRouter.route()'s allowLlm now enforced) + Phase 10.2/10.3/10.3B additions
smokeRun          = 10/10 scenarios, 10/10 HTTP 200, 10/10 passed RemoteLlmRealizer validation,
                    0 violations, grounding spot-checked (holdout_explore_sud_2 confirmed to use only
                    recent_conversation content, no fabrication) — see /tmp/phase10_5a_smoke_validated.json
```

## Evaluation question this phase can answer

> Does `RemoteLlmRealizer` produce better surface wording than the current
> deterministic paths for **explore/reflect** turns specifically, given the
> exact same frozen `CounselorDecision`?

## Evaluation question this phase CANNOT answer (explicitly out of scope)

- Whether realization quality improved "for counseling overall" —
  `checkIn`/`intervention`/`closing` (24/72, 33%) are untouched by this
  phase regardless of outcome, by `HybridTurnRouter`'s existing design.
- Whether `intervention`'s 16/16 `bothPoor` finding (Phase 9.2E) is
  resolved — it is explicitly NOT in scope here and must not be reported as
  addressed by any result from this phase.

## Results (recorded 2026-09-24, run complete)

**Smoke run (10 scenarios)**: 10/10 HTTP 200, 10/10 passed
`RemoteLlmRealizer` validation, 0 violations, latencies 1.0-2.7s. Grounding
spot-checked (`holdout_explore_sud_2`): the reply's mention of "검진 결과"
traced directly to `recent_conversation`, not fabricated. Prompt/transport
confirmed clean — proceeded to full run without any wording changes.

**Full eligible run (48 scenarios, exactly once)**: 48/48 HTTP 200.
Client-latency: min 1002ms, median 1245ms, p95 1631ms, max 5058ms (one
outlier, `holdout_reflect_probability_2`), mean 1357ms — well inside the
5-8s total-deadline policy.

**Validation (via the real, unmodified `RemoteLlmRealizer`)**: 47/48
accepted (97.9%). 1 rejected: `holdout_reflect_alternative_3`, flagged
`advice_language` — the reply asked "...그 경험이 다음 면접에 어떻게 도움이
될 수 있을까요?" (a genuine Socratic question about future benefit), which
tripped the `_advicePattern` regex's `도움이 될` term. This is a validator
false positive, not a real forbidden-content violation — but the fail-closed
design worked exactly as intended: this one scenario fell back to the
deterministic draft, with zero user-facing risk.

**Hard-gate manual audit (all 48 replies)**: 0 new CBT techniques, 0
question-goal deviations beyond the accepted act, 0 fabricated user facts —
every reference to prior context (e.g. `holdout_mixed_portion_2`'s "이완
활동") traced to `reflection_target`/`recent_conversation`, never invented.
Act-selection: 48/48 `chosen_act == required_act` (no act-switching
occurred in this run). **Zero critical failures.**

**R1 (verbatim quoting) recurrence**: 1/48 (2.1%) — `holdout_reflect_clarify_1`
wrapped the user's own short reply in single quotes (`'모르겠어요'`),
violating the backend prompt's own explicit no-quoting instruction. Down
from ~100% in both deterministic paths, but not fully eliminated — the
model doesn't perfectly follow this instruction 100% of the time.

**Soft observation (not a hard-gate failure)**: `holdout_mixed_portion_2`'s
reply contains two distinct asks in one sentence-count-compliant reply
("...느껴지나요? 그 걱정이 이완 활동에 어떤 영향을 미치고 있는지
궁금합니다.") — passes the literal `?`-count check but reads as asking two
things. Flagged for the human reviewer (R4-adjacent), not auto-rejected.

**Human blind review**: published, not yet completed —
https://claude.ai/artifact/VJLDSijsNcoSv888qCxZXk (Primary: Remote vs
Legacy, 48 pairs; Diagnostic: Remote vs Semantic-deterministic, 48 pairs).
The 1 fallback scenario is included in the pairwise set per the
never-silently-exclude rule (marked `remote_fell_back` in the mapping and
visibly badged in the review UI), not hidden.

## Reporting discipline

Every quality metric in this phase's results must state its denominator as
one of:
- `remoteEligible (n=48)` — the only valid denominator for any
  Remote-vs-Legacy or Remote-vs-Semantic comparison.
- `remoteIneligible (n=24)` — reported separately, never merged into a
  "some passed some failed" pooled statistic, since these were never sent
  to the model at all (0 API calls, deterministic output unchanged).

## Hard gates (semantic fidelity — checked before any quality/preference judgment)

Zero occurrences allowed, across all 48 eligible scenarios:
- New CBT technique introduced
- Selected intervention meaning changed (N/A for explore/reflect, listed
  for completeness/consistency with Phase 9's taxonomy)
- `question_goal` changed/ignored
- Question count increased beyond what `CounselingTurnPlan` specified
- Fabricated user fact (content not present in `reflection_target` or
  `recent_conversation`)
- Fabricated/invented past record
- Safety or clinical claim added
- A new counseling behavior not called for by the realization plan

Any single occurrence blocks activation consideration regardless of
aggregate quality scores — same discipline as Phase 9's critical failure
taxonomy.
