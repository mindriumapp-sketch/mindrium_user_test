# Phase 10.6A — Canary Activation Specification

**Status: SPEC ONLY. No feature flag has been flipped. No rollout code has
been written in this phase.** This document freezes activation scope,
monitoring, and kill-switch criteria *before* any real-user traffic sees
`RemoteLlmRealizer` — the same discipline this project has used for every
evaluation gate since Phase 9. Building the staged-percentage mechanism and
telemetry pipeline this spec calls for is **Phase 10.6B**; turning the flag
on for the first real cohort is **Phase 10.6C**, and only after this spec's
criteria are met, not as a side effect of writing this document.

## Why a canary, not a single flag flip

`COUNSELING_REMOTE_REALIZER` today is a single boolean — off, or on for
100% of eligible (`explore`/`reflect`) turns for every user
(`lib/chatbot/chatbot_main.dart`). Phase 10.5's evidence (dev 35:0, unseen
holdout 38:0) is strong, but it is sequential, single-account, dev/holdout-
scale evidence — it says nothing about concurrent real traffic, real cost
at scale, or rare failure modes a synthetic dataset (48-52 scenarios) can't
surface. A counseling product is exactly the case where "the average
response is more natural" is not sufficient justification for instant
100% rollout. Hence: staged.

## Authority boundary (unchanged from Phase 10.5, restated as the rollout's hard constraint)

```
Remote MAY change              Remote MUST NOT change
──────────────────             ───────────────────────
wording                        CounselorDecision (selectedAction/Goal/Intervention)
sentence connection            questionGoal
acknowledgment phrasing        selectedIntervention / CBT technique
reflection phrasing            state transition
                               question count
                               Safety response
                               CheckIn / Intervention / Closing turns (router keeps these
                                 deterministic regardless of the flag — unchanged)
```

This is not a new constraint to build — it is what `HybridTurnRouter` +
`RemoteLlmRealizer`'s validator already enforce today (verified across 100
real dev/holdout API calls with 0 boundary violations). The rollout's job
is to keep it true under real traffic, not to invent it.

## Stages

```
Stage 0 — current state
  flag OFF, 0% of traffic, unchanged today.

Stage 1 — internal/dev accounts only
  flag ON for a hardcoded internal-account allowlist (or a debug build
  flag), explore/reflect only. Goal: confirm the pipeline behaves under
  real app usage (not just scripted API calls) — real session state,
  real retry/navigation patterns, real network conditions on a device.
  No pilot-user-facing claim yet.

Stage 2 — small pilot cohort
  5-10% of sessions that reach an eligible (explore/reflect) turn,
  assigned by a stable per-session hash (not per-request — a session
  shouldn't flip between Remote and Legacy mid-conversation).

Stage 3 — expanded pilot
  25%, only after Stage 2's metrics (below) hold for a minimum observation
  window (see Advancement rule).

Stage 4 — re-evaluate for broader rollout
  A deliberate decision point, not an automatic continuation — requires
  its own go/no-go review of accumulated Stage 2/3 data, same rigor as
  Phase 10.5's dev→holdout gate.
```

No stage duration/sample-size threshold is fixed numerically in this spec —
that depends on real traffic volume, which isn't known yet. **Rule:**
advancement requires the receiving stage's full monitoring window to show
zero occurrences of any "immediate OFF" condition (below) and all
"reliability" metrics within their frozen thresholds, reviewed explicitly
before advancing — never advanced automatically by a timer or a script.

## Monitoring metrics (frozen before Stage 1 begins)

### Reliability

| Metric | Source | Notes |
|---|---|---|
| Remote call success rate | HTTP 200 rate on `/counseling/realize` | |
| Fallback rate | `accepted == false` rate in `RealizationResult` | Mirrors Phase 10.5's own accept/reject tracking |
| Timeout rate | transport-layer timeout vs other failure | |
| Validator rejection rate (aggregate) | `RealizationValidationResult.violations` non-empty | |
| **`question_count_mismatch` rate specifically** | one `violations` category | Called out separately per Phase 10.5B's finding (3/52 holdout) — this project's own instruction to not bury it inside an aggregate |

### Operational

- p50 / p95 latency (`/counseling/realize` only, and paired end-to-end
  per the same distinction `phase9_2_activation_criteria.md` §"Operational
  gates" already established for the decision-agent evaluation — reuse,
  don't reinvent)
- Token usage (input/output) — informational, not a gate, per this
  project's standing policy (`phase9_2_activation_criteria.md`)
- Backend error rate (5xx, distinct from validator rejections)

### Safety / contract (zero-tolerance, same taxonomy as every prior phase)

- Hallucinated user fact: 0
- New CBT content introduced: 0
- `question_goal` drift: 0
- Extra question beyond plan: 0
- Forbidden advice-language pattern in an *accepted* reply: 0
- Routing boundary violation (Remote invoked for a `checkIn`/`intervention`/
  `closing` turn): 0 — should be structurally impossible per
  `HybridTurnRouter`, but rollout telemetry should still assert it, not
  assume it

### UX proxy (best-effort — build only what the app already has hooks for)

- Regenerate/retry rate, if the UI has such a control
- Session continuation rate (does the user keep chatting after a Remote-
  realized turn, vs. after a Legacy turn)
- Any existing lightweight helpfulness feedback signal, if one exists

### Explicitly excluded from pass/fail

`exhausted_repeat`/`GoalExhaustionPolicy.repeatLast` turns are **not** a
rollout failure signal — confirmed selection-layer limitation
(`phase10_5a2_context_audit.md` Track A), present identically whether
Remote is on or off. Track it as its own backlog metric (below), never
folded into "Remote realization quality" pass/fail.

## Kill-switch criteria

### Immediate OFF (manual, as soon as observed — do not wait for a review window)

- A single confirmed safety-boundary violation
- A single confirmed hallucination (new CBT content or new user fact)
  reaching a real user
- A single confirmed routing-boundary violation (Remote reached a
  non-eligible state)
- Fallback-to-deterministic itself failing (i.e., a turn reaching neither a
  valid Remote reply nor the deterministic draft) — this must never happen
  given the current fail-closed design, so any occurrence is a stop-ship
  bug in its own right, not just a rollout metric

### Operational review trigger (pause advancement, investigate — not
necessarily an immediate full OFF, but do not proceed to the next stage)

- Fallback rate exceeds a pre-agreed threshold (to be set from Stage 1's
  own observed baseline — Phase 10.5B's 3/52 ≈ 5.8% question-count-mismatch
  rate is the only real-traffic-shaped data point available before Stage 1
  runs; do not import Phase 9's decide-agent operational thresholds
  unmodified, since realize and decide are different calls with different
  budgets)
- p95 latency exceeds the frozen budget (reuse `phase9_2_activation_criteria.md`'s
  `end_to_end_p95_latency_operational` ≤ 8000ms decide+realize framing,
  computed the *paired* way per that document's own preference — not two
  independent percentiles summed)
- `question_count_mismatch` rate rises materially above Phase 10.5B's
  holdout baseline (5.8%)
- Backend 5xx/timeout rate rises materially above baseline

**Fallback path stays exactly as built and already tested**: any Remote
failure/rejection returns `turnPlan.deterministicReply` — this spec does
not change that mechanism, only decides who gets routed to attempt Remote
at all.

## Telemetry — structural metadata only, same discipline as every prior phase

Modeled directly on the already-existing, already-tested
`RemoteCounselorShadowRunner.toLogEntry()` pattern
(`lib/features/counseling/policy/remote/remote_counselor_shadow_runner.dart`) —
reuse the discipline, not the exact fields (that class logs *decisions*,
this logs *realizations*):

```
session_local_anonymous_id     (no raw user id in this telemetry stream)
state                          (explore | reflect)
remote_attempted                bool
remote_accepted                 bool
fallback_reason                 (null | validator violation category | transport failure kind)
latency_ms
model_identifier
prompt_version                  ("realize_v2" going forward)
question_count                  (post-hoc, for the mismatch-rate metric)
validation_result                (violations list, if any)
```

**Never in general telemetry**: raw user utterance, full reply text, full
conversation transcript, diary/personalization content. This mirrors the
"raw model output retention" restriction `phase9_2_activation_criteria.md`
already established for evaluation runs — a rollout's *ongoing* logs need
this discipline even more than a one-off evaluation did, since it runs
continuously against real users, not synthetic fixtures.

## What must exist before Stage 1 can start (Phase 10.6B's job, not this spec's)

1. A per-session stable assignment mechanism (hash-based, not per-request)
   for Stage 2/3 percentage rollout — does not need to exist for Stage 1
   (internal allowlist is simpler and doesn't need it).
2. The telemetry pipeline above, wired to whatever this project's existing
   logging/analytics destination is (not designed in this spec — depends on
   infrastructure this document doesn't have visibility into).
3. A dashboard or at minimum a query surfacing the Reliability/Operational/
   Safety metrics above per stage.
4. Backend-side kill switch confirmed independent of the client flag (per
   `remote_gpt_realizer_integration.md` §4's original R4 requirement:
   "backend/user cohort 기준 remote kill switch도 둔다" — the client
   `COUNSELING_REMOTE_REALIZER` define alone is not sufficient if the
   backend has no independent way to refuse `/counseling/realize` traffic).

## Explicit non-goals of this spec

- Does not implement the percentage-rollout mechanism.
- Does not implement the telemetry pipeline.
- Does not flip `COUNSELING_REMOTE_REALIZER` for anyone.
- Does not set numeric fallback-rate/latency thresholds beyond what prior
  frozen documents already set — Stage 1's own baseline sets the first
  real-traffic thresholds, to be recorded as an explicit addendum to this
  document once observed, not guessed now.
