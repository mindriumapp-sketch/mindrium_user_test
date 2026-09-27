# Phase 10.6B — Canary Rollout Infrastructure

**Status: infrastructure built, wired, and tested. Production behavior
unchanged.** `COUNSELING_REMOTE_REALIZER` is still `false` by default;
`lib/chatbot/chatbot_main.dart` — the only real call site — was not
touched and does not construct a `RolloutConfig`. Every existing test
(853/853 before this phase) still passes unmodified. Activating anything
for real users is Phase 10.6C, not this phase.

## What was built

```
lib/features/counseling/policy/rollout/
  rollout_config.dart          RolloutStage, RolloutConfig, RolloutDecision,
                                stableBucket(), evaluateRollout()
  realization_telemetry.dart   RealizationTelemetryEvent, RealizationTelemetrySink
```

Wired into `CounselingHarness` (additively — three new fields, all
optional, all defaulting to "no-op"):

```dart
final RolloutConfig? rolloutConfig;       // null = legacy behavior (routing.allowLlm alone)
final bool isInternalAccount;             // false by default
final RealizationTelemetrySink? telemetrySink;  // null = no telemetry emitted
```

`CounselingHarness.remoteGpt(...)` now also accepts and forwards these
three, so Phase 10.6C's job is passing a real `RolloutConfig` at the
existing call site — not writing a new factory or new gating logic.

`handleTurn()`'s gate changed from:

```dart
final realization = routing.allowLlm ? await responseRealizer.realize(...) : ...;
```

to:

```dart
final rolloutDecision = rolloutConfig == null ? null : evaluateRollout(
  config: rolloutConfig!,
  routerAllowsLlm: routing.allowLlm,
  cohortKey: cohortKey ?? session.sessionId,
  isInternalAccount: isInternalAccount,
);
final effectiveAllowLlm = routing.allowLlm && (rolloutDecision?.attemptRemote ?? true);
final realization = effectiveAllowLlm ? await responseRealizer.realize(...) : ...;
```

`rolloutConfig == null` makes `effectiveAllowLlm == routing.allowLlm`
exactly — provably unchanged behavior, verified by the full existing suite
passing without modification.

### `RealizationResult` gained two additive fields

`modelIdentifier`/`promptVersion` (both nullable, both new), populated by
`RemoteLlmRealizer` from the backend's own `model`/`prompt_version`
response fields — needed so telemetry can report which model/prompt
version actually produced an accepted reply, per the frozen spec.
`DeterministicResponseRealizer`/`SemanticDeterministicResponseRealizer`
leave both `null` (unchanged, no source of this data for them).

## Authority boundary — unchanged, re-verified

The rollout gate is a pure AND with `HybridTurnRouter`'s existing decision
— it can only narrow when Remote is attempted, never widen it.
`checkIn`/`intervention`/`closing` stay at 0 Remote calls regardless of
`RolloutConfig` (verified: a `RolloutConfig(enabled: true, stage: pilot,
rolloutPercentage: 100)` — the widest possible config — still produces 0
calls for all three states in `canary_rollout_integration_test.dart`).

## Tests (28 new, all green)

`test/counseling/rollout_config_test.dart` (13) — pure `evaluateRollout`/
`stableBucket` unit tests: precedence order (router > kill switch >
enabled > stage), `internalOnly` both branches, `pilot` at 0%/100%/a real
boundary key, bucket determinism, and the **5%⊆10%⊆25% monotonicity**
property across 500 synthetic keys.

`test/counseling/canary_rollout_integration_test.dart` (15) — harness-level
orchestration with a fake in-memory realizer (no network):
- `rolloutConfig: null` → legacy behavior unchanged
- default `RolloutConfig()`, kill switch, `internalOnly` (both branches),
  pilot cohort (both branches) → correct call-count (0 or 1)
- `checkIn`/`intervention`/`closing` → 0 calls even at the widest-open
  config
- Remote validation failure → deterministic fallback, rejected reply never
  reaches the user
- telemetry: exactly one event per gated turn, `question_count_mismatch`
  correctly flagged, **no raw user text/reply text anywhere in
  `toLogEntry()`'s output** (asserted by string-searching the serialized
  log entry for the actual Korean test message and reply text), no event
  when `telemetrySink` is `null`
- same `sessionId` at a fixed percentage always yields the same in/out
  decision across two independent harness instances

Full suite: **881/881 pass** (853 pre-existing + 28 new).

## Explicit non-goals (per the frozen spec, honored)

- No prompt/`RemoteLlmRealizer`/validator/`CounselorAgent`/CBT policy
  changes — this phase touched orchestration only.
- No automatic stage promotion — `RolloutConfig` is a value a caller must
  construct and change; nothing in this code advances a stage on its own.
- No telemetry pipeline/destination wired — `RealizationTelemetrySink` is
  a call shape only; Phase 10.6C (or later) connects it to this project's
  actual logging/analytics infrastructure, which this phase has no
  visibility into.
- No account/auth lookup — `isInternalAccount` is supplied by the caller;
  this layer has and needs no concept of accounts.
- `exhausted_repeat`/`GoalExhaustionPolicy.repeatLast` — untouched, as
  every prior Phase 10.5 document already fixed.

## What Phase 10.6C still needs to decide/do

1. Construct a real, non-default `RolloutConfig` (starting at
   `RolloutStage.internalOnly` per the frozen spec's Stage 1) and pass it
   at the `lib/chatbot/chatbot_main.dart` call site.
2. Supply a real `isInternalAccount` value at that call site (this project
   has no existing internal-account concept to reuse — needs its own small
   decision, e.g. an allowlist or a build flavor check).
3. Connect `telemetrySink` to a real destination.
4. Only then does `COUNSELING_REMOTE_REALIZER`-equivalent real-user
   activation begin — and only for Stage 1 (internal accounts), per the
   frozen spec's staged plan, not full rollout.
