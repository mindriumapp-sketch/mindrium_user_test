import 'scenario_runner.dart';

/// Phase 9.2B: one reviewer-facing row — no agent identity anywhere in this
/// shape's field names or values. [minimalContext] is a short, non-
/// sensitive description built only from ids/enums already present on
/// [ScenarioResult] (category/state-shaped info), never the raw user
/// message or personalization text.
class PairwiseReviewRow {
  final String scenarioId;
  final String minimalContext;
  final String responseA;
  final String responseB;

  const PairwiseReviewRow({
    required this.scenarioId,
    required this.minimalContext,
    required this.responseA,
    required this.responseB,
  });

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'minimal_context': minimalContext,
    'response_a': responseA,
    'response_b': responseB,
  };
}

/// Phase 9.2B: the separate mapping row that records which side was which —
/// kept in a different list/file from [PairwiseReviewRow] so the reviewer-
/// facing export never needs to be touched to look up ground truth.
class PairwiseMappingRow {
  final String scenarioId;
  final bool aIsRemote;

  const PairwiseMappingRow({required this.scenarioId, required this.aIsRemote});

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'a_is_remote': aIsRemote,
  };
}

class PairwiseExport {
  final List<PairwiseReviewRow> reviewRows;
  final List<PairwiseMappingRow> mappingRows;

  const PairwiseExport({required this.reviewRows, required this.mappingRows});

  /// Builds a reproducible pairwise A/B export from [results].
  ///
  /// Only scenarios where BOTH `deterministicResponseText` and
  /// `remoteResponseText` are non-null are included (a failed/absent remote
  /// call has nothing to compare).
  ///
  /// The A/B order is derived from a deterministic seed hashed from the
  /// scenario id — NOT `Random()` without a seed — so calling this twice
  /// with the same input list always produces the same order, letting a
  /// human reviewer's answers be scored consistently across repeated runs/
  /// regenerated exports.
  factory PairwiseExport.build(List<ScenarioResult> results) {
    final reviewRows = <PairwiseReviewRow>[];
    final mappingRows = <PairwiseMappingRow>[];

    for (final r in results) {
      final det = r.deterministicResponseText;
      final rem = r.remoteResponseText;
      if (det == null || rem == null) continue;

      final aIsRemote = _seedBit(r.scenarioId);
      final responseA = aIsRemote ? rem : det;
      final responseB = aIsRemote ? det : rem;

      reviewRows.add(
        PairwiseReviewRow(
          scenarioId: r.scenarioId,
          minimalContext: '${r.category} (${r.scenarioLabel})',
          responseA: responseA,
          responseB: responseB,
        ),
      );
      mappingRows.add(
        PairwiseMappingRow(scenarioId: r.scenarioId, aIsRemote: aIsRemote),
      );
    }

    return PairwiseExport(reviewRows: reviewRows, mappingRows: mappingRows);
  }

  /// Deterministic, seeded pseudo-bit derived from [scenarioId]'s hash —
  /// stable across process runs (unlike `Object.hashCode`, `String.hashCode`
  /// in Dart is well-defined and stable within a given SDK for equal
  /// strings within the same run, but to be robust across SDK versions we
  /// compute our own simple stable hash here rather than relying on it).
  static bool _seedBit(String scenarioId) {
    var hash = 0;
    for (final codeUnit in scenarioId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.isEven;
  }
}
