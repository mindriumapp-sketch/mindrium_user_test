// Phase 10.3, item 12: dev comparison artifact — Legacy
// (DeterministicResponseRealizer) vs Semantic
// (SemanticDeterministicResponseRealizer) response text for the SAME
// CounselorDecision/CounselingTurnPlan, across the 72 holdout_v1 scenarios
// already used as Phase 9.2E's activation-evidence dataset.
//
// Written as a `flutter test` (this project's only working Dart run
// harness — plain `dart run` fails on this repo's Flutter SDK deps) rather
// than a real assertion-bearing test: its "test" body writes a JSON file
// as a side effect and asserts nothing beyond "it ran". It performs pure
// computation only: no network call, no OpenAI/remote agent involved
// (ScenarioRunner.run with remoteAgent: null), so it never touches
// `holdout_v1`'s "unseen" status for RemoteCounselorAgent evaluation — it
// only compares two ResponseRealizer implementations against the
// DETERMINISTIC decision, which was never the subject of Phase 9's
// held-out evaluation in the first place.
//
// Per Phase 10.3's explicit scope: this produces a DEV comparison export
// only. It is not a blind pairwise review and must not be used to justify
// a production Realizer switch — see phase10_3_semantic_realizer.md's
// "Phase 10.4" section for what a real evaluation requires.
//
// Run with:
//   flutter test test/counseling/evaluation/phase10_3_dev_comparison_export.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/holdout_v1_scenarios.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_runner.dart';
import 'package:gad_app_team/features/counseling/policy/realization/semantic_deterministic_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';

void main() {
  test('export legacy vs semantic realizer comparison for holdout_v1 (dev artifact only)', () async {
    final fixtures = buildHoldoutV1Scenarios();
    const runner = ScenarioRunner();
    const legacyRealizer = DeterministicResponseRealizer();
    const semanticRealizer = SemanticDeterministicResponseRealizer();

    final rows = <Map<String, Object?>>[];
    for (final fixture in fixtures) {
      final result = await runner.run(fixture); // remoteAgent: null — deterministic only, no network.
      final plan = result.deterministicTurnPlan;
      if (plan == null) {
        rows.add({
          'scenario_id': fixture.id,
          'category': fixture.category,
          'legacy': null,
          'semantic': null,
          'note': 'no turn plan (unavailable turn)',
        });
        continue;
      }

      final request = RealizationRequest.fromPlan(
        plan: plan,
        retrievalSummary: RetrievalSummary.empty,
      );
      final legacy = (await legacyRealizer.realize(request)).reply;
      final semantic = (await semanticRealizer.realize(request)).reply;

      rows.add({
        'scenario_id': fixture.id,
        'category': fixture.category,
        'multi_option_actual': fixture.multiOption,
        'legacy': legacy,
        'semantic': semantic,
        'changed': legacy != semantic,
      });
    }

    final changedCount = rows.where((r) => r['changed'] == true).length;
    final output = {
      'purpose':
          'Phase 10.3 dev comparison ONLY — not a blind pairwise review, '
          'not activation evidence for any agent, not a production switch '
          'justification.',
      'dataset_version': holdoutV1Version,
      'total_scenarios': fixtures.length,
      'changed_count': changedCount,
      'rows': rows,
    };

    final outPath = '/tmp/phase10_3_dev_comparison.json';
    File(outPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(output),
    );
    // ignore: avoid_print
    print(
      'Wrote $outPath — ${rows.length} scenarios, $changedCount changed '
      'between legacy and semantic realizer output.',
    );

    expect(rows.length, fixtures.length);
  });
}
