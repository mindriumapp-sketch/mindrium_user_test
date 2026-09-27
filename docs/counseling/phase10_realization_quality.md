# Phase 10 — Counseling Realization Quality (opened 2026-09-24)

## Why this phase exists

Phase 9's holdout blind review (`phase9_2_activation_criteria.md`, "Phase 9
final result & closure") found `RemoteCounselorAgent` did not clear the
quality gate, and that the dominant human-review signal — 45/72 (62.5%)
`bothPoor` verdicts, 100% in `intervention_*` — tracked with two concrete
complaints from the reviewer:

1. User input is echoed back verbatim inside quotation marks
   (`"..."라고 말씀해 주셨군요` pattern).
2. The response does not connect naturally to what the user just said
   before jumping to the next scripted question.

Because both the Remote and Deterministic arms in that evaluation were
rendered through the **same** `TurnPlanMaterializer` templates, this is a
finding about the realization layer that is **already live in production
today**, independent of whether `RemoteCounselorAgent` is ever activated.

## Scope boundary (explicit, do not cross)

```
CounselorDecision            <-- FROZEN, out of scope for Phase 10
   |
   v
TurnPlanMaterializer         <-- in scope
   |
   v
ResponseRealizer             <-- in scope
```

Phase 10 does not change what is decided (goal/reflectionTarget/action/
intervention selection, `DeterministicCounselorAgent` vs `RemoteCounselorAgent`,
`decisionRequirementsFor`, the validator). It only changes how an already-made
decision is turned into a sentence. This boundary exists so that a future
re-attempt at evaluating `RemoteCounselorAgent` (a `holdout_v2`) is not
confounded by simultaneous realization changes.

## Known concrete issues (from Phase 9.2E review)

- Verbatim quotation of user input via string interpolation into a fixed
  template sentence.
- Reflection → next-question transition reads as two unrelated sentences
  concatenated, rather than one that acknowledges the first before moving
  to the second.

## Status

**Phase 10.1 complete** (code-verified inventory + taxonomy + baseline
tests, zero production changes):
- `phase10_1_realization_inventory.md` — full call graph
  (`CounselorDecision → TurnPlanMaterializer → CounselingTurnPlan →
  ResponseRealizer`), confirming production's `DeterministicResponseRealizer`
  is a no-op passthrough — `TurnPlanMaterializer` is the sole author of
  final user-facing wording today, and it fuses "materialization" and
  "surface realization" into one class with no seam between them.
- `phase10_1_failure_taxonomy.md` — 12 named failure categories (R1-R12),
  each tied to a specific code location; R1 (verbatim quoting), R3 (abrupt
  transition via `CounselingTurnPlan.deterministicReply`'s naive
  `join(' ')`), and R8 (zero rotation in `intervention`'s templates) are the
  three confirmed to explain the Phase 9.2E human-review pattern, especially
  `intervention_*`'s 16/16 `bothPoor`.
- `test/counseling/evaluation/phase10_1_realization_baseline_test.dart` — 4
  golden-output tests locking in today's exact `checkIn`/`intervention`/
  `closing`/`reflect` wording as the pre-change baseline for Phase 10.2's
  before/after comparison.

**Phase 10.2 complete** — see `phase10_2_failure_mapping.md`. Added a new,
purely additive `CounselingRealizationSpec` semantic contract
(`TransitionIntent`, `InterventionRationale`, `InterventionRealizationSpec`,
`ClosingIntent`) built by all 5 `TurnPlanMaterializer` states and attached
to `CounselingTurnPlan.realizationSpec` (nullable). Legacy
`reflectionSentence`/`questionSentence`/`deterministicReply` and
`ResponseRealizer` behavior are completely unchanged — production output
is byte-identical (766/766 tests green, including Phase 10.1's golden
baseline unmodified). Nothing consumes the new contract yet.

**Phase 10.3 complete** — see `phase10_3_semantic_realizer.md`. Added
`SemanticDeterministicResponseRealizer`, a parallel (not default)
`ResponseRealizer` that consumes `realizationSpec` for the first time:
removes verbatim quoting (R1) via a non-quoting reflection template, and
adds the missing intervention why-now bridge (R7) via `InterventionRationale`.
R3 partially addressed for intervention only; R2/R5/R8/R11/R12 unchanged.
A known limitation (multi-clause/question-shaped targets render awkwardly)
was found via the 72-scenario dev comparison export and documented, not
fixed. Production default realizer unchanged (774/774 tests green).

**Phase 10.3B complete** — see `phase10_3b_reflection_robustness.md`. Fixed
exactly the two target-shape composition defects found in 10.3 (multi-clause
targets, question-shaped targets) via a conservative surface-shape
classifier (`ReflectionTargetShape`) that routes unsafe shapes to a
generic, content-free grounded-acknowledgment fallback instead of a broken
suffix concatenation. 7/72 dev scenarios now use the fallback; the other 65
are unchanged from Phase 10.3A. 786/786 tests green. Production default
realizer still unchanged.

**Phase 10.4A executed** (blind review artifact published and used by the
user). Verdict: both legacy and semantic-deterministic responses still read
as mechanical — confirms the deterministic-template ceiling described
below, not a fixable wording bug.

**Direction change, confirmed with the user**: deterministic template
refinement is at its ceiling. Moved to **Phase 10.5 — LLM Realization
Evaluation** (`phase10_5_llm_realization_evaluation.md`): evaluate the
already-built-but-never-activated `RemoteLlmRealizer`/`/counseling/realize`
path (selection stays frozen; only wording generation becomes an LLM call,
fail-closed to the deterministic draft on any failure/violation). Found and
fixed a real safety gap first: `HybridTurnRouter.route()`'s `allowLlm`
decision was computed but never enforced, which would have let approved
intervention-turn wording reach the model once activated — fixed, 790/790
tests green. Scope note: intervention/checkIn/closing stay
deterministic-only by the router's existing design regardless of this
phase's outcome; only explore/reflect are in scope.

**Phase 10.5 complete — GO for limited Explore/Reflect rollout.** See
`phase10_5_llm_realization_evaluation.md`'s Final Result section: dev
(Remote vs Legacy 35:0) and unseen holdout (`phase10_5b_manifest.md`,
38:0, known-limitation excluded) both show Remote LLM realization
decisively preferred over Legacy, 0 critical failures across 100 real API
calls. Along the way: root-caused `exhausted_repeat`'s poor quality to
`GoalExhaustionPolicy.repeatLast` itself (a selection-layer property, not
a realization defect) via a clean-context ablation
(`phase10_5a2_context_audit.md` Track A) — excluded from the rollout gate,
logged as a separate backlog item. Added an explicit `sudRatingValue`
semantic signal so the realizer acknowledges numeric check-in replies
(Track B) — 90% acknowledgment compliance, 0 hallucinated values, verified
on 10 unseen phrasings.

**Phase 10.6A (canary rollout specification) complete** — see
`phase10_6a_canary_rollout_spec.md`. Staged activation plan (Stage 0-4),
authority boundary, monitoring metrics, kill-switch criteria, and a
privacy-preserving telemetry schema (structural metadata only, modeled on
`RemoteCounselorShadowRunner.toLogEntry()`) are frozen.

**Phase 10.6B (canary rollout infrastructure) complete** — see
`phase10_6b_rollout_infrastructure.md`. Built `RolloutConfig`/
`evaluateRollout()`/`stableBucket()` and a structural-only
`RealizationTelemetryEvent`, wired additively into `CounselingHarness`
(`rolloutConfig`/`isInternalAccount`/`telemetrySink`, all optional,
defaulting to today's exact behavior). 28 new tests (881/881 total green)
prove: legacy behavior is unchanged when no config is passed; kill switch/
disabled/wrong-stage/wrong-cohort all correctly produce 0 Remote calls;
`checkIn`/`intervention`/`closing` stay at 0 calls even at the widest-open
config; Remote failures still fall back to deterministic; telemetry never
carries raw user/reply text; cohort assignment is stable and
5%⊆10%⊆25% monotonic. **`COUNSELING_REMOTE_REALIZER` is still `false`,
`chatbot_main.dart` was not touched, no real user has been exposed to
Remote realization.**

**Phase 10.6C (Stage 1 internal-only activation) complete** — see
`phase10_6c_stage1_internal_activation.md`. Wired `RolloutConfig`/
`isInternalAccount`/`telemetrySink` into the real
`lib/chatbot/chatbot_main.dart` call site (not just tests). Real users are
still unaffected today, for three independent reasons:
`COUNSELING_REMOTE_REALIZER` stays `false` in every build config;
`internalAccountEmailAllowlist` is empty by default; and this flip
actually *closed* a pre-existing gap (previously, flipping that one flag
gave 100% of a build's explore/reflect users Remote — now it's properly
gated to `internalOnly`). Telemetry is local-only (`dart:developer.log`,
read via `flutter logs`) and the kill switch is compile-time-only — both
explicit, scoped-for-Stage-1 choices, not sufficient for Stage 2. 886/886
tests pass. Starting real dogfooding requires a manual step (adding real
emails to the allowlist) that this phase deliberately left undone.

**Phase 10.6C-OBS (dogfood mechanism verification) complete** — see
`phase10_6c_obs_dogfood_verification.md`. Verified, against a real running
backend (not mocks) using the exact production `CounselingHarness`/
`RemoteLlmRealizer` classes: (Step A) checkIn/intervention/closing and
every rollout-off variant produce 0 real backend calls, confirmed via the
backend's own access log; (Step B) one real successful API call (natural
reply, correct telemetry, no raw-content leak) plus two real failure
injections (backend-down → `request_failed` fallback;
malformed 2-question reply → `question_count_mismatch` fallback), both
correctly falling back to the exact deterministic draft shown to the
user, never an empty/broken reply. All of the frozen Stage-1 exit
criteria that an automated pass can verify are met (0 routing/safety/
fallback-failure/raw-content-leak violations). Explicitly does not
establish real multi-session human dogfooding or a real latency
distribution — those still require a person to actually use the app.

**Phase 10.6C-DOGFOOD (real internal operational observation) — protocol
frozen, dogfooding open.** See `phase10_6c_dogfood_protocol.md`: scope
(1-3 internal accounts, ~10-20 sessions, ~30-50 Remote-eligible turns,
no prompt/spec/selection/router changes permitted mid-protocol), the
aggregate observation table, per-turn issue checklist, and Stage 1 hard
exit criteria — all frozen before any real session runs.
`sehyun712@skku.edu` is now registered in
`internalAccountEmailAllowlist` (887/887 tests green) — the only account
currently eligible for Remote realization, and only in a build that also
sets `COUNSELING_REMOTE_REALIZER=true`. No other production behavior
changed. Actual dogfood sessions (a person using the app) are the
remaining step; results will be logged against this frozen protocol, not
a standard set after the fact. Phase 10.6D-PREP (runtime remote kill
switch, backend aggregate telemetry) stays explicitly deferred until
after this phase's hard exit criteria are confirmed.

**Dogfooding underway — two real-device bugs found and fixed; two
selection-layer limitations reproduced live and logged, not fixed.** See
`phase10_6c_dogfood_log.md` for the full findings taxonomy, the Build
A/B boundary (UI-level fixes mean Build A and Build B sessions are not
pooled — the 30-50 eligible-turn sample is collected from Build B only),
and the local-dogfood-backend-vs-shared-server deployment boundary
(Phase 10's `/counseling/*` endpoints exist only on the local dogfood
backend; the shared `115.145.134.180:8070` server predates the
counseling chatbot entirely and is a separate, out-of-scope deployment
blocker). Found live: duplicate chat bubbles
(`instantEmpathy` placeholder never replaced, just shown alongside the
real reply) and verbatim-quoted legacy text reaching the user whenever
Remote realization was rejected — both are App/UI-integration defects
the Phase 10.5 review artifacts structurally could not have surfaced
(they only ever showed one realized string per scenario, never the
actual chat screen). Fixed: `instantEmpathy` no longer wired to `true` at
the real call site; the rejected-Remote fallback now routes through the
already-built, already-evaluated `SemanticDeterministicResponseRealizer`
(Phase 10.3/10.3B) instead of the raw verbatim-quoting legacy draft —
scoped to only the reject-path for turns Remote was actually attempted
on, leaving every other state/user untouched. 888/888 tests green
(one new regression test added). Also reproduced live, and confirmed as
pre-existing, already-scoped-out selection-layer limitations, not
Realizer defects: `GoalExhaustionPolicy.repeatLast` (Track A,
`phase10_5a2_context_audit.md`), and a newly-named, distinct
meta-conversation/interaction-repair gap (the selection/router layer has
no way to recognize a comment about the system's own behavior, e.g. "왜
똑같은 말을 반복하지?", as anything other than ordinary worry content) —
both logged as backlog items for a future selection-policy phase, not
addressed here.
