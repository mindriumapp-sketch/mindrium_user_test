// Phase 9.2B: PairwiseExport — same seed => same A/B order across two
// calls, and the reviewer-facing output never leaks agent identity.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/pairwise_export.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_runner.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';

List<ScenarioResult> _results() => [
  ScenarioResult(
    scenarioId: 'scn_a',
    scenarioLabel: 'Label A',
    category: 'explore_general',
    multiOptionActual: true,
    deterministicDecision: const CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text('t'),
    ),
    deterministicResponseText: 'sentence one for A',
    remoteResponseText: 'sentence two for A',
  ),
  ScenarioResult(
    scenarioId: 'scn_b',
    scenarioLabel: 'Label B',
    category: 'reflect_goal_evidence',
    multiOptionActual: true,
    deterministicDecision: const CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      reflectionTarget: ReflectionTarget.text('t'),
    ),
    deterministicResponseText: 'sentence one for B',
    remoteResponseText: 'sentence two for B',
  ),
  // No remote response — must be excluded from the export.
  ScenarioResult(
    scenarioId: 'scn_c',
    scenarioLabel: 'Label C',
    category: 'checkIn',
    multiOptionActual: false,
    deterministicDecision: const CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text('t'),
    ),
    deterministicResponseText: 'sentence one for C',
  ),
];

void main() {
  test('same seed produces the same A/B order across two calls', () {
    final export1 = PairwiseExport.build(_results());
    final export2 = PairwiseExport.build(_results());

    expect(export1.mappingRows.length, export2.mappingRows.length);
    for (var i = 0; i < export1.mappingRows.length; i++) {
      expect(
        export1.mappingRows[i].aIsRemote,
        export2.mappingRows[i].aIsRemote,
      );
      expect(
        export1.reviewRows[i].responseA,
        export2.reviewRows[i].responseA,
      );
      expect(
        export1.reviewRows[i].responseB,
        export2.reviewRows[i].responseB,
      );
    }
  });

  test('scenarios missing a remote response are excluded', () {
    final export = PairwiseExport.build(_results());
    expect(export.reviewRows.length, 2);
    expect(export.mappingRows.length, 2);
    expect(export.reviewRows.any((r) => r.scenarioId == 'scn_c'), isFalse);
  });

  test('mapping correctly identifies which side is remote', () {
    final export = PairwiseExport.build(_results());
    for (var i = 0; i < export.reviewRows.length; i++) {
      final row = export.reviewRows[i];
      final mapping = export.mappingRows[i];
      expect(mapping.scenarioId, row.scenarioId);
      final expectedRemoteText =
          row.scenarioId == 'scn_a' ? 'sentence two for A' : 'sentence two for B';
      final expectedDetText =
          row.scenarioId == 'scn_a'
              ? 'sentence one for A'
              : 'sentence one for B';
      if (mapping.aIsRemote) {
        expect(row.responseA, expectedRemoteText);
        expect(row.responseB, expectedDetText);
      } else {
        expect(row.responseA, expectedDetText);
        expect(row.responseB, expectedRemoteText);
      }
    }
  });

  test('reviewer output never contains agent-identity strings', () {
    final export = PairwiseExport.build(_results());
    for (final row in export.reviewRows) {
      final serialized = row.toJson().toString().toLowerCase();
      expect(serialized.contains('remote'), isFalse);
      expect(serialized.contains('deterministic'), isFalse);
      expect(serialized.contains('counseloragent'), isFalse);
    }
  });
}
