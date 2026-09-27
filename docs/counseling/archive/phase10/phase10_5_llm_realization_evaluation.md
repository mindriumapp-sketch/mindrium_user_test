# Phase 10.5 — LLM Realization Evaluation (opened 2026-09-24)

## Why this phase exists

Phase 10.4A's blind dev review compared two **deterministic-template**
realizers (legacy vs. Phase 10.3B semantic). The user's own review verdict:
both still read as mechanical, still effectively re-stating user input
through a fixed frame. Root cause, confirmed by inspection: every
Phase 10.3/10.3B fix changed *which* pre-written string gets selected, never
changed the fact that composition is template-filling, not generation. A
deterministic rule-based realizer has a naturalness ceiling that no amount
of shape-classification or candidate-pool tuning can cross — genuine
paraphrase requires generative capability, not more rules.

This is a **different** question from Phase 9's:

```
Phase 9  — should an LLM choose WHAT to do (selection)?        -> NO-GO (Level 0)
Phase 10.5 — should an LLM choose HOW TO SAY what's already
             been decided (realization only)?                   -> under evaluation
```

Selection stays exactly as frozen as it has been since Phase 8.

## Major finding: the infrastructure already exists, unused

`docs/counseling/remote_gpt_realizer_integration.md` (dated 2026-09-05, predates
this session) already designed this exact fork and it was already fully
implemented, just never activated or evaluated:

- `lib/features/counseling/response_realizer.dart` — `RealizationRequest`/
  `RealizationResult`/`RealizationSource` contract (already extended
  additively in Phase 10.2/10.3 with `realizationSpec`).
- `lib/features/counseling/remote_llm_realizer.dart` — `RemoteLlmRealizer`,
  fail-closed (never throws; any error/violation returns `isValid: false`,
  triggering `CounselingHarness`'s existing fallback to `deterministicDraft`).
  Validates: empty reply, question-count mismatch, act-not-allowed,
  advice-language pattern, format-leak pattern, length cap.
- `backend/app/routers/counseling_realize.py` — `/counseling/realize`,
  already asks the model not to quote the user's words back verbatim
  (`"...인용부호로 그대로 반복하기... 핵심 내용을 상담사 자신의 표현으로 짧게
  풀어서 반영할 것"`) — stricter than anything built in Phase 10.3.
- `lib/chatbot/chatbot_main.dart` — `COUNSELING_REMOTE_REALIZER` flag
  (default `false`), wires `CounselingHarness.remoteGpt(...)` when enabled.
- `test/counseling/remote_llm_realizer_test.dart` — already covers most of
  the integration doc's §11 test checklist at the unit level (empty reply,
  question-count mismatch, advice language, format leak, exception
  swallowing, act-membership both branches, conversation-window truncation).

`docs/counseling/remote_gpt_realizer_integration.md` §10 (R5), §11, and §12
are adopted as this phase's frozen evaluation criteria — they were written
before any result existed, exactly per this project's own discipline, so
there is no need to write new criteria from scratch.

## Critical safety gap found and fixed before any further work

While reading `counseling_harness.dart` to understand the call path,
found: `HybridTurnRouter.route(...)` computes `routing.allowLlm` — and
`counseling_harness.dart` stored it on the result for diagnostics but never
checked it before calling `responseRealizer.realize(...)`. Harmless while
the only realizer ever configured was `DeterministicResponseRealizer`
(makes no model call regardless), but activating a real LLM realizer would
have sent **approved-intervention-turn wording to the model**, directly
contradicting `HybridTurnRouter`'s own stated purpose (an approved CBT
turn's wording is fixed; letting a model change it risks pushing it outside
approved scope — see its `case CounselingState.intervention` branch).

Fixed, same commit as this phase's opening:

1. `counseling_harness.dart`'s `handleTurn`: `responseRealizer.realize(...)`
   is now called only when `routing.allowLlm` is true; otherwise the turn
   uses `turnPlan.deterministicReply` directly, with zero model/network
   call, regardless of which `responseRealizer` is configured.
2. `CounselingHarness.remoteGpt(...)` now explicitly passes
   `turnRouter: const HybridTurnRouter(llmEnabled: true)` — without this,
   fix #1 alone would have made the factory's whole reason to exist
   (explore/reflect realization) unreachable, since the router's default
   `llmEnabled` is `false`.

New regression test: `test/counseling/hybrid_turn_router_gating_test.dart`
— asserts a spy realizer is called 0 times for `intervention`/`checkIn`
turns and exactly once for `explore` turns under `remoteGpt()`, and 0 times
under a harness that doesn't opt into `llmEnabled: true`. Full suite:
**790/790 pass** after both fixes (was 786/786 immediately before).

## Scope consequence of the router's existing design (not changed here)

`HybridTurnRouter.route()`'s state switch marks `allowLlm: false`
unconditionally for `checkIn`, `closing`, and `intervention` — only
`explore`/`reflect` ever get `allowLlm: llmEnabled`. This means:

- **Intervention wording — the worst-scoring category in every review so
  far (Phase 9.2E: 16/16 `bothPoor`; Phase 10.4A: still poor) — will NOT
  benefit from this phase's evaluation at all.** It stays
  deterministic-template forever under the current router design, by
  deliberate safety choice, independent of what Phase 10.5 finds.
- Only `explore`/`reflect` turns are in scope for this evaluation.
- Changing this is a separate, later decision (loosening intervention's
  `allowLlm`, or a different fix targeted at intervention specifically) —
  out of scope here.

## What remains before a real (paid, network) evaluation run

Not yet done, in order:

1. Wire `CounselingRealizationSpec` (`transitionIntent`, `questionGoal`)
   into `RemoteLlmRealizer`'s request / the backend prompt as additive
   grounding — the backend prompt currently only gets raw
   `reflection_target`/`question_goal`, not the Phase 10.2 semantic fields.
   Optional but likely helpful; needs its own before/after check.
2. The two `docs/counseling/remote_gpt_realizer_integration.md` §11 items
   not yet covered by any test: crisis-turn zero-remote-calls (actually
   already true structurally — `safety.isNormal` gate returns before
   `turnPlan`/realizer ever run — but not asserted as its own test) and
   "느린 응답이 이미 표시된 문장을 교체하지 않음" (UI-level, not this layer).
3. Freeze a dataset/model/prompt-version manifest exactly as
   `phase9_2_activation_criteria.md` required, before the first real API
   call — same discipline, new artifact.
4. Dev/regression run on the existing 72 `holdout_v1` scenarios (dev-only,
   not activation evidence, per the same rule as Phase 9).
5. A fresh unseen holdout (new scenarios — `holdout_v1` is now dev-seen
   for realization purposes too, after Phase 10.4A).
6. Blind pairwise review (Legacy/Semantic-deterministic vs. RemoteLlmRealizer,
   explore/reflect states only, same decision held constant) — reusing the
   `RealizerPairwiseExport` mechanism built for Phase 10.4A.
7. Evaluate against `remote_gpt_realizer_integration.md` §12's 8 completion
   conditions before any production flag flip.

Real API calls have not yet started. No cost has been incurred this phase.

## Final result — GO for limited Explore/Reflect rollout (recorded 2026-09-26)

**Verdict: Remote Realizer GO for limited Explore/Reflect rollout.** Remote
LLM realization showed consistent improvement over the legacy deterministic
realization in both development (`phase10_5a_manifest.md`) and unseen
evaluation (`phase10_5b_manifest.md`). In the unseen eligible holdout,
Remote was preferred in 38/46 cases and Legacy in 0/46 (known-limitation
`exhausted_repeat` excluded from this count, reported separately).
Selection, CBT policy, safety, and state control remain fully deterministic
throughout — nothing in this evaluation touched
`CounselorDecision`/`PolicyBoundary`/selectors. `GoalExhaustionPolicy
.repeatLast`'s poor showing was isolated to the selection layer (Phase
10.5A.2 Track A) and excluded from this realization-efficacy verdict.

```
                    Dev (10.5A)         Unseen holdout (10.5B)
Remote vs Legacy    35 : 0              38 : 0  (n=46, known-limitation excluded)
bothPoor rate       12/48 (25%)         8/46 (17.4%)
SUD acknowledgment  1/3 → fixed          9/10 = 90%, 0 hallucinated rating
Critical failures   0                    0
```

Therefore Remote realization is eligible for a controlled canary rollout
limited to `explore`/`reflect` turns, with the existing deterministic
fallback and feature-flag rollback retained unchanged. Full production
activation (100% of eligible turns) is **not** decided by this result alone —
see `phase10_6a_canary_rollout_spec.md` for the staged activation plan this
finding unlocks.

### What this evaluation does NOT establish (explicit non-claims)

- Does not claim `checkIn`/`intervention`/`closing` should ever use Remote
  realization — `HybridTurnRouter`'s existing design keeps them
  deterministic regardless, untouched by this finding.
- Does not claim `exhausted_repeat`/`GoalExhaustionPolicy.repeatLast` is
  fixed — it is a known, separate, unresolved selection-layer limitation.
- Does not claim production-scale reliability under real traffic (concurrency,
  rate limits, cost-at-scale) — only dev/holdout-scale sequential real API
  calls were exercised.
- Does not authorize flipping `COUNSELING_REMOTE_REALIZER` — that is a
  distinct, later decision gated on `phase10_6a_canary_rollout_spec.md`'s
  own criteria.
