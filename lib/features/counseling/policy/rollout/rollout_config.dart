/// Phase 10.6B: canary rollout configuration and the pure decision function
/// that gates a real turn's Remote-realization attempt, per
/// `docs/counseling/chatbot_system.md` (tag counseling-handover-v1).
///
/// This file is infrastructure only — constructing a [RolloutConfig] with
/// anything other than the fully-off default and wiring it into a real
/// [CounselingHarness] is Phase 10.6C's job, not this one's. The default
/// constructor is deliberately "everything off", so any code that builds a
/// `RolloutConfig()` with no arguments gets the same behavior as having no
/// rollout config at all.
library;

/// The staged rollout scope, per the frozen spec's Stage 0-3 (Stage 4 is a
/// re-evaluation decision point, not a config value — it starts a new
/// spec/decision, not a bigger number here).
enum RolloutStage {
  /// Stage 0 — nobody, regardless of [RolloutConfig.enabled]/[RolloutConfig.killSwitch].
  off,

  /// Stage 1 — internal/dev accounts only, decided by the caller-supplied
  /// `isInternalAccount` flag (this layer has no concept of an account or
  /// auth — that lives outside the counseling harness).
  internalOnly,

  /// Stage 2/3 — a percentage of eligible turns, assigned by stable
  /// per-cohort-key hashing (see [stableBucket]). The stage value itself
  /// doesn't encode 5% vs 10% vs 25% — [RolloutConfig.rolloutPercentage]
  /// does, so advancing 5% -> 25% is a config change, not a new enum value.
  pilot,
}

/// Frozen shape per `phase10_6a_canary_rollout_spec.md`: four separate
/// concepts, deliberately not collapsed into one boolean. `enabled` and
/// `killSwitch` are distinct axes on purpose — an operator can leave
/// `enabled: true` with `stage: off` (the rollout system is "live" but
/// targeting nobody) separately from an emergency `killSwitch: true` that
/// overrides every other field instantly.
///
/// The default constructor is the current production reality: nobody gets
/// Remote realization via this mechanism. Passing this default is
/// equivalent to not passing a [RolloutConfig] to [CounselingHarness] at
/// all (see that class's gating logic).
class RolloutConfig {
  final bool enabled;
  final RolloutStage stage;

  /// 0-100. Only consulted when [stage] is [RolloutStage.pilot].
  final int rolloutPercentage;

  /// Emergency override. `true` forces zero Remote attempts regardless of
  /// every other field — see [evaluateRollout]'s check order.
  final bool killSwitch;

  const RolloutConfig({
    this.enabled = false,
    this.stage = RolloutStage.off,
    this.rolloutPercentage = 0,
    this.killSwitch = false,
  }) : assert(
         rolloutPercentage >= 0 && rolloutPercentage <= 100,
         'rolloutPercentage must be 0-100',
       );
}

/// The outcome of [evaluateRollout] — never just a bool, so telemetry and
/// debugging always have a `reason` to log without re-deriving it.
class RolloutDecision {
  final bool attemptRemote;
  final String reason;

  const RolloutDecision({required this.attemptRemote, required this.reason});

  static const RolloutDecision _killSwitch = RolloutDecision(
    attemptRemote: false,
    reason: 'kill_switch',
  );
  static const RolloutDecision _disabled = RolloutDecision(
    attemptRemote: false,
    reason: 'rollout_disabled',
  );
  static const RolloutDecision _stageOff = RolloutDecision(
    attemptRemote: false,
    reason: 'stage_off',
  );
  static const RolloutDecision _routerDisallowed = RolloutDecision(
    attemptRemote: false,
    reason: 'router_disallowed',
  );
  static const RolloutDecision _internalAccount = RolloutDecision(
    attemptRemote: true,
    reason: 'internal_account',
  );
  static const RolloutDecision _notInternalAccount = RolloutDecision(
    attemptRemote: false,
    reason: 'not_internal_account',
  );
  static const RolloutDecision _pilotCohort = RolloutDecision(
    attemptRemote: true,
    reason: 'pilot_cohort',
  );
  static const RolloutDecision _outsidePilotCohort = RolloutDecision(
    attemptRemote: false,
    reason: 'outside_pilot_cohort',
  );
}

/// Stable 0-99 bucket for [cohortKey] (a session id, never a raw user
/// identifier beyond what the caller already treats as an opaque key).
/// Same key always yields the same bucket — this is what makes rollout
/// percentage increases monotonic (a session in the 5% cohort stays in at
/// 10%/25%, since its bucket never changes and the inclusion test is
/// `bucket < percentage`) without any extra bookkeeping. Deliberately the
/// same simple stable-hash shape already used elsewhere in this codebase
/// for reproducible-but-not-cryptographic bucketing (see
/// `RealizerPairwiseExport._seedBit`, `PairwiseExport._seedBit`) — not a
/// security boundary, just deterministic assignment.
int stableBucket(String cohortKey) {
  var hash = 0;
  for (final codeUnit in cohortKey.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash % 100;
}

/// The single AND-gate Phase 10.6B adds in front of Remote realization.
/// [routerAllowsLlm] is `HybridTurnRouter`'s own existing, state-based
/// decision (`explore`/`reflect` only) — this function only ever narrows
/// that further, never widens it. A `RolloutConfig()` default always
/// returns `attemptRemote: false` here regardless of [routerAllowsLlm],
/// matching "production stays OFF until Phase 10.6C decides otherwise".
RolloutDecision evaluateRollout({
  required RolloutConfig config,
  required bool routerAllowsLlm,
  required String cohortKey,
  required bool isInternalAccount,
}) {
  if (!routerAllowsLlm) return RolloutDecision._routerDisallowed;
  if (config.killSwitch) return RolloutDecision._killSwitch;
  if (!config.enabled) return RolloutDecision._disabled;

  switch (config.stage) {
    case RolloutStage.off:
      return RolloutDecision._stageOff;
    case RolloutStage.internalOnly:
      return isInternalAccount
          ? RolloutDecision._internalAccount
          : RolloutDecision._notInternalAccount;
    case RolloutStage.pilot:
      final bucket = stableBucket(cohortKey);
      return bucket < config.rolloutPercentage
          ? RolloutDecision._pilotCohort
          : RolloutDecision._outsidePilotCohort;
  }
}
