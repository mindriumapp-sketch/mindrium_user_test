# MindRium Counseling Baseline

**2026-09-28**

- Phase 10.7 production cleanup complete
- Remote CounselorAgent removed from production (archived, never wired to any factory; Phase 9 concluded NO-GO/Level 0)
- Remote Realizer retained (explore/reflect wording only)
- Deterministic policy/safety/selection retained, unchanged
- Canary rollout infrastructure retained (Stage 1: internalOnly)
- Research artifacts archived (`research_archive/`, `docs/counseling/archive/`, `test/research_regression/`)
- `flutter test`: 869/869
- Backend smoke: PASS (`/counseling/decide` gone, `/counseling/realize` + `/counseling-sessions` intact)
- Real-device smoke (SM A716S): PASS — see `phase10_6c_dogfood_log.md` and this session's smoke test (checkIn→explore→intervention-unavailable→session end via max-turn budget; 3/3 real Remote calls confined to explore; 0 calls in checkIn/intervention; 0 crashes; 0 duplicate bubbles; 0 legacy-quote recurrence on Remote-reject fallback; session persistence PUT confirmed)

Current product philosophy, now structurally enforced end to end:

```text
LLM decides what to do       -> no (deterministic selection/policy)
LLM realizes how to say it   -> yes (explore/reflect only, Stage 1 internal accounts only)
```

## What's next

Not cleanup — feature work, backlogged from real dogfooding evidence:

**Selection Policy / Interaction Repair** — `GoalExhaustionPolicy.repeatLast`
has no recovery path other than repeating, and there is no way for the
selection/router layer to recognize a meta-conversation turn ("왜 계속
같은 말을 물어봐?") as anything other than ordinary worry content. Both
reproduced live in real sessions (`phase10_6c_dogfood_log.md`). Needs a
dedicated design phase — selection stays frozen for the remainder of
Phase 10's original scope, so this is deliberately a new phase, not a
continuation of this cleanup.

## Known follow-ups (not urgent, not blocking)

- `CounselingHarness`'s `llm`/`outputParser`/`turnPlanValidator` constructor
  params are now unused dead weight (the code path that used them was
  removed in Phase 10.7B) but stay required/present — removing them
  touches every test's construction call site, a separate, lower-urgency
  refactor.
- Runtime (non-compile-time) remote kill switch + backend aggregate
  telemetry are still prerequisites for Stage 2 (5-10% external pilot),
  not built yet.
