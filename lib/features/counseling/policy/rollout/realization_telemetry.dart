/// Phase 10.6B: structural-only telemetry for a real turn's realization
/// outcome, per `docs/counseling/chatbot_system.md` (tag counseling-handover-v1),
/// telemetry section. Logs structure only, never content.
///
/// **Never put raw content on this class.** No user message, no assistant
/// reply text, no diary/personalization text, no direct user identifier —
/// only ids, enums, booleans, and numbers. If a field would require adding
/// a `String` that could contain real conversation content, it does not
/// belong here.
library;

import '../../counseling_state.dart';
import 'rollout_config.dart';

class RealizationTelemetryEvent {
  /// The rollout config's stage at the time of this turn — NOT which
  /// realizer ultimately produced the reply (see [remoteAccepted] for
  /// that); this is "what the rollout was configured to attempt".
  final RolloutStage rolloutStage;

  /// This session's stable 0-99 bucket (see [stableBucket]) — never the
  /// raw cohort key (session id) itself, so this event carries no
  /// resolvable session identity on its own.
  final int cohortBucket;

  final CounselingState state;
  final String rolloutReason;

  /// Whether `RemoteLlmRealizer.realize()` was actually invoked this turn
  /// (i.e. `evaluateRollout(...).attemptRemote && routing.allowLlm`).
  final bool remoteAttempted;

  /// Whether the Remote reply passed validation and was actually shown to
  /// the user (`false` whenever [remoteAttempted] is `false` too, or when
  /// Remote was attempted but rejected/failed and the turn fell back).
  final bool remoteAccepted;

  /// Null when [remoteAccepted] is true or [remoteAttempted] is false.
  /// One of `RealizationValidationResult.violations`' categories, or a
  /// transport-failure kind (`request_failed`) — never free text.
  final String? fallbackReason;

  /// `true` iff `fallbackReason` names the `question_count_mismatch`
  /// category specifically — called out as its own field per the frozen
  /// spec's instruction not to bury this rate inside an aggregate.
  final bool questionCountMismatch;

  final int? latencyMs;
  final String? modelIdentifier;
  final String? promptVersion;

  const RealizationTelemetryEvent({
    required this.rolloutStage,
    required this.cohortBucket,
    required this.state,
    required this.rolloutReason,
    required this.remoteAttempted,
    required this.remoteAccepted,
    this.fallbackReason,
    this.questionCountMismatch = false,
    this.latencyMs,
    this.modelIdentifier,
    this.promptVersion,
  });

  Map<String, Object?> toLogEntry() => {
    'rollout_stage': rolloutStage.name,
    'cohort_bucket': cohortBucket,
    'state': state.name,
    'rollout_reason': rolloutReason,
    'remote_attempted': remoteAttempted,
    'remote_accepted': remoteAccepted,
    'fallback_reason': fallbackReason,
    'question_count_mismatch': questionCountMismatch,
    'latency_ms': latencyMs,
    'model_identifier': modelIdentifier,
    'prompt_version': promptVersion,
  };
}

/// Injected by whatever this project's real logging/analytics destination
/// turns out to be — this file has no visibility into that infrastructure
/// (per the frozen spec's explicit non-goals), so it only defines the
/// call shape. A `null` sink (the default everywhere in this phase) means
/// no telemetry is emitted at all — behavior-neutral, matching "no rollout
/// mechanism activated yet".
typedef RealizationTelemetrySink = void Function(RealizationTelemetryEvent event);
