# Phase 10.6C-OBS — Internal Dogfooding Verification

**Status: complete.** Real backend, real internet-facing OpenAI-backed
`/counseling/realize` calls, and realistic failure injection — all run
against the exact production `CounselingHarness`/`RemoteLlmRealizer`
classes `chatbot_main.dart` actually wires. No code changed this pass;
this is verification only.

## What could and couldn't be run as literal on-device dogfooding

Before running anything, tried to execute the real `ApiClient` +
`RemoteLlmRealizer` end-to-end inside `flutter test` (no workaround). Two
attempts, both conclusively ruled out:

- Plain `dart run` on any file importing even `package:flutter/foundation.dart`
  fails at the SDK level (`Offset`/`dart:ui` symbols unavailable outside
  Flutter's patched frontend) — confirmed with a minimal probe file, not
  assumed.
- A live `ApiClient(...).dio.get(...)` call inside `flutter test` hangs
  indefinitely (30s timeout) — `ApiClient`'s auth interceptor reads
  `TokenStorage`, which uses `FlutterSecureStorage`'s platform channel,
  unavailable in the test VM. Confirmed by a direct probe, not inferred
  from the Phase 9 finding alone.

So, as in Phase 9/10.5, real network calls went through the established
3-pass pattern (Dart pure-compute → Python real HTTP → Dart pure-compute),
reusing the exact same `RemoteLlmRealizer`/telemetry-construction code
`counseling_harness.dart` runs — the only thing NOT exercised with a live
call is `DioCounselingRealizeApi`'s own Dio transport (a thin, ~10-line
wrapper) and `ApiClient`'s auth-token interceptor, both structurally
untestable in this environment. Everything downstream of the HTTP
boundary — parsing, validation, fallback decision, telemetry — used the
real, unmodified classes against a real running local backend.

## Step A — routing/boundary proof (0 real backend calls)

Ran the real `CounselingHarness.remoteGpt(...)` (same factory, same
`RemoteLlmRealizer`/`DioCounselingRealizeApi` pointed at a real local
backend on port 8074) through `handleTurn()` for:

- `checkIn`/`intervention`/`closing`, rollout config wide open
  (`internalOnly`, `isInternalAccount: true`)
- `explore` with `isInternalAccount: false`
- `explore` with `killSwitch: true`
- `explore` with the fully-off default `RolloutConfig()` (today's real
  production config)

**Independently verified via the backend's own access log** (not just an
in-process assertion): grepped `/tmp/phase10_6c_backend.log` for
`POST /counseling/realize` before and after — **0 occurrences**, across
all 6 cases. The only request line present the whole time was the one
`/auth/login` call made once to obtain a token.

## Step B — real call + failure injection

**B1 — normal real API call.** Built the real request for an
`explore`-state turn via the actual production pipeline
(`DeterministicPolicyBoundaryBuilder` → `DeterministicCounselorAgent` →
`TurnPlanAdapter` → `RealizationRequest.fromPlan`), confirmed
`HybridTurnRouter.allowLlm` and `evaluateRollout(...)` both approve it
(`reason: internal_account`), then made a real HTTP call:

```
사용자: "내일 팀 회의에서 발표할 생각을 하니 계속 초조해요."
Remote reply: "내일 팀 회의에서 발표를 생각하니 초조함을 느끼고 계시군요.
              발표 중에 특히 어떤 순간이 가장 걱정되나요?"
```

Fed the real response through the real `RemoteLlmRealizer.realize()`:
accepted, no violations, telemetry event correctly shows
`remote_accepted: true`, `model_identifier: gpt-4o-mini`,
`fallback_reason: null`. Verified the serialized telemetry log entry
contains neither "발표" nor "초조" (the actual Korean content words from
this turn) — the no-raw-content rule holds on a real payload, not just a
synthetic test string.

**B2 — backend unreachable.** Pointed a real request at a closed port
(connection refused). Fed the resulting exception through the real
`RemoteLlmRealizer.realize()`: `accepted: false`,
`fallback_reason: request_failed`, and critically — **the reply actually
shown to the user was verified to equal the deterministic draft exactly**,
never empty, never broken. `model_identifier`/`prompt_version` correctly
`null` (no response was ever obtained to read them from).

**B3 — malformed/2-question reply.** Reused the real 2-question failure
pattern already observed for real in Phase 10.5B
(`question_count_mismatch`, 3/52 occurrences there) as a synthetic backend
response, fed through the real validator: correctly rejected,
`question_count_mismatch: true`, `fallback_reason: question_count_mismatch`,
user again gets the deterministic draft.

**B4 — feature-flag/allowlist off → 0 calls.** Already proven structurally
in Step A (no live call needed to demonstrate an absence) and independently
by the 886-test regression suite (`rollout_config_test.dart`,
`canary_rollout_integration_test.dart`).

## Exit-criteria checklist (against the frozen Phase 10.6A spec)

| Item | Result |
|---|---|
| Routing: Remote called only for explore/reflect | ✅ verified (Step A + B1) |
| Boundary: checkIn/intervention/closing = 0 calls | ✅ verified via real backend access log |
| Reliability: success/fallback distinguishable | ✅ (B1 vs B2/B3) |
| Validation: question_count_mismatch correctly caught | ✅ (B3) |
| Latency: p50/p95 | Single real call only — 1 data point, not a distribution. Not a meaningful p50/p95 yet; needs actual multi-session dogfooding by a human, which this pass (an automated script) cannot substitute for. |
| Quality: natural wording, no meaning drift | ✅ for this one real reply (matches Phase 10.5's already-established pattern — no new quality claim made here) |
| Safety: no new user fact/CBT content | ✅ (single real reply audited; full-scale evidence already in Phase 10.5B, not re-litigated here) |
| Fallback: real deterministic response on failure | ✅ verified the exact final string shown to the user, not just an internal flag |
| Telemetry: no raw content leak | ✅ verified against real Korean content strings from this actual run |
| routing/safety/hallucination violations | 0 (across this run) |

## What this phase does NOT establish

- **No real multi-session human dogfooding happened.** This was an
  automated verification of the mechanism (routing, fallback, telemetry
  correctness) using one real API call plus two realistic failure
  injections — not a person using the app conversationally across several
  real sessions. The frozen spec's "실제 체감" (subjective felt latency/
  quality across real use) and any multi-turn conversational quality
  observation still require a human to actually use the app.
- **No real p50/p95 latency distribution** — one real data point
  (~1-2s, consistent with Phase 10.5's measured range) is not a
  distribution.
- Does not change any of Phase 10.6C's known, deliberate limitations
  (local-only telemetry, compile-time-only kill switch, empty allowlist) —
  those still stand exactly as documented in
  `phase10_6c_stage1_internal_activation.md`.

## Recommendation

The mechanism itself — routing, rollout gating, fallback, telemetry
shape — is verified correct against a real backend and real failure
modes. What remains before calling Stage 1 "exited" is genuinely-human
dogfooding (a real person, a real allowlisted email, several real
conversational sessions, watching `flutter logs` live) — which only the
user can actually perform, not something scriptable from here.
