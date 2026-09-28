import 'pairwise_export.dart';

/// Phase 9.2C: a blind reviewer's verdict on one [PairwiseReviewRow] — filled
/// in by a human after seeing only `responseA`/`responseB`, never agent
/// identity. `preference` is the only required judgment; `diagnosticFlags`
/// are optional free-text tags a reviewer can attach (e.g.
/// `'repeats_question'`, `'uses_unrelated_context'`, `'intervention_timing_off'`)
/// — this schema does not predefine an exhaustive flag vocabulary, since
/// that would bias what reviewers look for before any real review has
/// happened.
enum PairwisePreference { aBetter, bBetter, tie, bothPoor }

class PairwiseReview {
  final String scenarioId;
  final PairwisePreference preference;
  final List<String> diagnosticFlags;

  const PairwiseReview({
    required this.scenarioId,
    required this.preference,
    this.diagnosticFlags = const [],
  });

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'preference': preference.name,
    'diagnostic_flags': diagnosticFlags,
  };

  factory PairwiseReview.fromJson(Map<String, Object?> json) {
    return PairwiseReview(
      scenarioId: json['scenario_id'] as String,
      preference: PairwisePreference.values.byName(json['preference'] as String),
      diagnosticFlags:
          (json['diagnostic_flags'] as List? ?? const []).cast<String>(),
    );
  }
}

/// One [PairwiseReview] resolved back onto which side (remote/deterministic)
/// it actually favored, using [PairwiseMappingRow] — this resolution must
/// only ever happen AFTER review collection is complete, never before (that
/// would defeat the blinding).
class ResolvedPreference {
  final String scenarioId;
  final PairwisePreference preference;
  final bool remoteBetter;
  final bool remoteWorse;
  final bool tie;
  final bool bothPoor;

  const ResolvedPreference({
    required this.scenarioId,
    required this.preference,
    required this.remoteBetter,
    required this.remoteWorse,
    required this.tie,
    required this.bothPoor,
  });
}

/// Phase 9.2C: merges blind [PairwiseReview]s with the hidden
/// [PairwiseMappingRow]s to determine actual remote-vs-deterministic
/// preference — the only place in this evaluation pipeline where agent
/// identity and human judgment are combined.
class HumanReviewSummary {
  final List<ResolvedPreference> resolved;

  const HumanReviewSummary({required this.resolved});

  factory HumanReviewSummary.merge({
    required List<PairwiseReview> reviews,
    required List<PairwiseMappingRow> mapping,
  }) {
    final aIsRemoteByScenario = {
      for (final row in mapping) row.scenarioId: row.aIsRemote,
    };

    final resolved = <ResolvedPreference>[];
    for (final review in reviews) {
      final aIsRemote = aIsRemoteByScenario[review.scenarioId];
      if (aIsRemote == null) {
        // No mapping for this scenario id — can't resolve identity, so this
        // review is dropped rather than guessed at.
        continue;
      }

      bool remoteBetter = false;
      bool remoteWorse = false;
      bool tie = false;
      bool bothPoor = false;
      switch (review.preference) {
        case PairwisePreference.aBetter:
          if (aIsRemote) {
            remoteBetter = true;
          } else {
            remoteWorse = true;
          }
        case PairwisePreference.bBetter:
          if (aIsRemote) {
            remoteWorse = true;
          } else {
            remoteBetter = true;
          }
        case PairwisePreference.tie:
          tie = true;
        case PairwisePreference.bothPoor:
          bothPoor = true;
      }

      resolved.add(
        ResolvedPreference(
          scenarioId: review.scenarioId,
          preference: review.preference,
          remoteBetter: remoteBetter,
          remoteWorse: remoteWorse,
          tie: tie,
          bothPoor: bothPoor,
        ),
      );
    }

    return HumanReviewSummary(resolved: resolved);
  }

  int get remoteBetterCount => resolved.where((r) => r.remoteBetter).length;
  int get remoteWorseCount => resolved.where((r) => r.remoteWorse).length;
  int get tieCount => resolved.where((r) => r.tie).length;
  int get bothPoorCount => resolved.where((r) => r.bothPoor).length;

  /// The Phase 9.2 spec's primary quality signal: `better > worse`. This is
  /// NOT an activation criterion by itself (see
  /// `docs/counseling/phase9_2_activation_criteria.md`'s "quality gates" —
  /// it must be combined with the absence of critical failures), but it's
  /// the single number the spec calls out explicitly.
  bool get remoteBetterThanWorse => remoteBetterCount > remoteWorseCount;
}
