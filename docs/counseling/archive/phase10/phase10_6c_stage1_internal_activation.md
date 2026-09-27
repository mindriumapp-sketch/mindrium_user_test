# Phase 10.6C — Stage 1 Internal-Only Activation

**Status: wired into the real production call site
(`lib/chatbot/chatbot_main.dart`). Production behavior for real users is
still unchanged today** — see "Why nothing changes yet" below. This is the
first phase where Remote realization code runs in the actual app, not just
in tests/eval scripts, but it only activates for a currently-empty email
allowlist.

## What changed at the real call site

`lib/chatbot/chatbot_main.dart`'s `_createProvider()`:

```dart
final rolloutConfig = useRemoteRealizer
    ? RolloutConfig(enabled: true, stage: RolloutStage.internalOnly, killSwitch: _rolloutKillSwitch)
    : null;
final userEmail = useRemoteRealizer ? context.read<UserProvider>().userEmail : null;
final isInternalAccount = isInternalAccountEmail(userEmail);

final harness = useRemoteRealizer
    ? CounselingHarness.remoteGpt(
        ...,
        rolloutConfig: rolloutConfig,
        isInternalAccount: isInternalAccount,
        telemetrySink: logRealizationTelemetryLocally,
      )
    : CounselingHarness.deterministic(...);
```

New files:
- `lib/features/counseling/policy/rollout/internal_account_allowlist.dart` —
  `internalAccountEmailAllowlist` (a `const Set<String>`, **empty by
  default**) and `isInternalAccountEmail()`.
- `lib/features/counseling/policy/rollout/local_realization_telemetry_sink.dart` —
  `logRealizationTelemetryLocally()`, using `dart:developer.log()` (visible
  in `flutter logs`/IDE consoles/DevTools — not `print`, which truncates
  long lines).

New flag alongside the existing one:

```dart
static const bool _rolloutKillSwitch = bool.fromEnvironment(
  'COUNSELING_REMOTE_REALIZER_KILL_SWITCH',
  defaultValue: false,
);
```

## Why nothing changes yet for real users

Three independent reasons, any one of which alone would already prevent
activation:

1. `COUNSELING_REMOTE_REALIZER` (the pre-existing flag) is still `false` by
   default in every build — confirmed no `.gradle`/`.xcconfig`/CI config
   anywhere in this repo sets it. Without it, `useRemoteRealizer` is
   `false` and the harness takes the `.deterministic()` branch exactly as
   before this phase — `rolloutConfig` is never even constructed.
2. Even in a build that deliberately sets `COUNSELING_REMOTE_REALIZER=true`
   (e.g. for a developer's own dogfood build), `internalAccountEmailAllowlist`
   is **empty** — `isInternalAccountEmail()` returns `false` for every real
   address, so `RolloutStage.internalOnly` routes everyone to
   `not_internal_account` and the turn stays deterministic.
3. This dogfood build should also set `COUNSELING_REMOTE_REALIZER_KILL_SWITCH=false`
   (the default) — setting it `true` forces every session off regardless
   of the allowlist, as an extra independent stop.

**A genuine safety improvement over Phase 10.6B's baseline, not just
neutral**: before this phase, a build with `COUNSELING_REMOTE_REALIZER=true`
gave Remote realization to *100% of that build's explore/reflect users*.
Now the same flag only enables the *possibility*, gated a second time by
`internalOnly` — closing a real gap (a flag flip that was previously
all-or-nothing is now properly staged).

## To actually begin Stage 1 dogfooding (manual steps, not done by this phase)

1. Add real internal/dev email addresses to `internalAccountEmailAllowlist`
   in `internal_account_allowlist.dart`.
2. Build/run with `--dart-define=COUNSELING_REMOTE_REALIZER=true` (and
   leave the kill switch at its default `false`).
3. Watch `flutter logs` (or the IDE console / DevTools Logging view,
   filtered to `counseling.realization`) for `RealizationTelemetryEvent`
   entries while using the app as one of the allowlisted accounts.
4. To stop immediately without editing the allowlist: rebuild with
   `--dart-define=COUNSELING_REMOTE_REALIZER_KILL_SWITCH=true`, or simply
   drop `COUNSELING_REMOTE_REALIZER` back to its default. Both require a
   rebuild — there is still no remote/live kill switch (see below).

## Known limitations, chosen deliberately for this stage (not oversights)

Per explicit choice when scoping this phase — each was a real option with
a bigger alternative, and the smaller one was chosen on purpose for Stage 1:

- **Telemetry is local-only** (`dart:developer.log`, read via `flutter logs`/
  DevTools on the dogfooder's own device). No backend endpoint or DB table
  was built. Sufficient for a handful of internal dogfooders reading their
  own device logs; revisit before Stage 2 (a real pilot cohort can't be
  asked to read their own device logs).
- **Kill switch is compile-time only** (`bool.fromEnvironment`, same
  mechanism as `COUNSELING_REMOTE_REALIZER` itself) — turning it on/off
  requires a rebuild, same speed as flipping the flag it protects. Not a
  live remote-config endpoint. Sufficient for Stage 1 given internal
  dogfooders can rebuild quickly; **not sufficient for Stage 2+**, where a
  real incident would need to be stoppable without waiting on a release —
  a real remote-config/kill-switch endpoint is a prerequisite for Stage 2,
  not built here.
- **Internal-account identification is a hardcoded, empty-by-default email
  allowlist** — the only account attribute this codebase has (no role/
  admin/staff field exists anywhere, verified before choosing this).

## Verification

886/886 tests pass (881 Phase 10.6B baseline + 5 new
`internal_account_allowlist_test.dart`). `test/counseling/chat_page_test.dart`
re-verified directly (13/13), including its existing "기본 제품 경로는
deterministic planner로 LLM을 호출하지 않는다" test — the real `ChatPage`
widget's default path is unaffected. No `.gradle`/`.xcconfig`/CI file
anywhere sets either flag to `true`.

## Next: observe, then decide on Stage 2

Per `phase10_6a_canary_rollout_spec.md`: advancing to Stage 2 (5-10% pilot)
requires a deliberate review of Stage 1's observed metrics (fallback rate,
`question_count_mismatch` rate, latency, and zero safety-boundary
violations) — never an automatic promotion, and not something this
document decides in advance of actually watching Stage 1 run.
