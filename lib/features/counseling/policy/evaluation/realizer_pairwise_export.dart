/// Phase 10.4A: blind pairwise export for comparing two `ResponseRealizer`
/// outputs over the SAME `CounselorDecision`/`CounselingTurnPlan` — unlike
/// `pairwise_export.dart` (Phase 9.2B), which compares Remote vs
/// Deterministic *decisions*. Here the decision is held constant
/// (deterministic selection, frozen since Phase 8) and only the realizer
/// (legacy string-concat vs Phase 10.3/10.3B semantic) varies, so any
/// reviewer preference is attributable to realization quality alone, not
/// decision-selection differences.
///
/// Reuses the same reproducible-seed-bit blinding technique as
/// `PairwiseExport._seedBit` (kept separate, not imported, so this file has
/// no dependency on Phase 9.2B's Remote/Deterministic-specific shape).
class RealizerPairwiseReviewRow {
  final String scenarioId;
  final String minimalContext;
  final String responseA;
  final String responseB;

  const RealizerPairwiseReviewRow({
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

class RealizerPairwiseMappingRow {
  final String scenarioId;
  final bool aIsSemantic;

  const RealizerPairwiseMappingRow({
    required this.scenarioId,
    required this.aIsSemantic,
  });

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'a_is_semantic': aIsSemantic,
  };
}

class RealizerPairwiseExport {
  final List<RealizerPairwiseReviewRow> reviewRows;
  final List<RealizerPairwiseMappingRow> mappingRows;

  const RealizerPairwiseExport({
    required this.reviewRows,
    required this.mappingRows,
  });

  /// [rows] must all share the same decision; only `legacyText`/
  /// `semanticText` differ per scenario. A/B order is a deterministic seed
  /// hashed from the scenario id, so re-running this against the same
  /// (frozen) Phase 10.3B code always reproduces the same A/B assignment.
  factory RealizerPairwiseExport.build(
    List<({String scenarioId, String category, String legacyText, String semanticText})>
    rows,
  ) {
    final reviewRows = <RealizerPairwiseReviewRow>[];
    final mappingRows = <RealizerPairwiseMappingRow>[];

    for (final row in rows) {
      final aIsSemantic = _seedBit(row.scenarioId);
      final responseA = aIsSemantic ? row.semanticText : row.legacyText;
      final responseB = aIsSemantic ? row.legacyText : row.semanticText;

      reviewRows.add(
        RealizerPairwiseReviewRow(
          scenarioId: row.scenarioId,
          minimalContext: row.category,
          responseA: responseA,
          responseB: responseB,
        ),
      );
      mappingRows.add(
        RealizerPairwiseMappingRow(
          scenarioId: row.scenarioId,
          aIsSemantic: aIsSemantic,
        ),
      );
    }

    return RealizerPairwiseExport(
      reviewRows: reviewRows,
      mappingRows: mappingRows,
    );
  }

  static bool _seedBit(String scenarioId) {
    var hash = 0;
    for (final codeUnit in scenarioId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.isEven;
  }
}
