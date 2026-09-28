// Phase 10.4A: builds the blind pairwise dev-review export comparing
// LegacyDeterministicResponseRealizer (DeterministicResponseRealizer) vs
// SemanticDeterministicResponseRealizer (Phase 10.3 + 10.3B) over the SAME
// CounselorDecision, across the 72 holdout_v1 dev scenarios.
//
// Pure computation, no network call (ScenarioRunner.run with
// remoteAgent: null). This is a `flutter test` file for the same reason as
// phase10_3_dev_comparison_export.dart: this repo's plain `dart run` fails
// on Flutter SDK deps.
//
// Output: /tmp/phase10_4a_dev_review_export.json — {review_rows,
// mapping_rows}. review_rows carries NO realizer identity (only
// scenario_id/minimal_context/response_a/response_b); mapping_rows (the
// hidden key) must never be shown to a reviewer before review completes.
//
// This is DEV evidence only (Phase 10.3B code is frozen for the duration
// of this review, per the instructions) — not activation evidence, not a
// production-switch justification.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/holdout_v1_scenarios.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/realizer_pairwise_export.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_runner.dart';
import 'package:gad_app_team/features/counseling/policy/realization/semantic_deterministic_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';

void main() {
  test('export Phase 10.4A blind pairwise dev review (legacy vs semantic realizer)', () async {
    final fixtures = buildHoldoutV1Scenarios();
    const runner = ScenarioRunner();
    const legacyRealizer = DeterministicResponseRealizer();
    const semanticRealizer = SemanticDeterministicResponseRealizer();

    final rows =
        <({String scenarioId, String category, String legacyText, String semanticText})>[];
    var skipped = 0;

    for (final fixture in fixtures) {
      final result = await runner.run(fixture);
      final plan = result.deterministicTurnPlan;
      if (plan == null) {
        skipped++;
        continue;
      }

      final request = RealizationRequest.fromPlan(
        plan: plan,
        retrievalSummary: RetrievalSummary.empty,
      );
      final legacy = (await legacyRealizer.realize(request)).reply;
      final semantic = (await semanticRealizer.realize(request)).reply;

      rows.add((
        scenarioId: fixture.id,
        category: fixture.category,
        legacyText: legacy,
        semanticText: semantic,
      ));
    }

    final export = RealizerPairwiseExport.build(rows);

    final output = {
      'purpose':
          'Phase 10.4A dev blind pairwise review — legacy vs semantic '
          'realizer, SAME deterministic decision. DEV evidence only, not '
          'activation evidence, not a production-switch justification.',
      'dataset_version': holdoutV1Version,
      'total_scenarios': fixtures.length,
      'skipped_no_turn_plan': skipped,
      'review_row_count': export.reviewRows.length,
      'review_rows': export.reviewRows.map((r) => r.toJson()).toList(),
      'mapping_rows': export.mappingRows.map((r) => r.toJson()).toList(),
    };

    final outPath = '/tmp/phase10_4a_dev_review_export.json';
    File(outPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(output),
    );
    // ignore: avoid_print
    print(
      'Wrote $outPath — ${export.reviewRows.length} review rows, '
      '$skipped skipped (no turn plan).',
    );

    expect(export.reviewRows.length, export.mappingRows.length);
    expect(export.reviewRows.length + skipped, fixtures.length);
  });
}
