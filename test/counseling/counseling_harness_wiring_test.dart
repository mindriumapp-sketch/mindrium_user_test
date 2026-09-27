// Phase 10.7B: extracted from phase8_4_production_switch_test.dart, which
// moved to test/research_regression/counseling/ (it's a legacy-vs-new
// equivalence proof, not a live invariant). This one assertion is
// different in kind: it's a standing guard that the real production
// factory wires the intended planner, not a historical migration proof —
// it belongs in the main suite.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  test(
    'CounselingHarness.deterministic() no longer wires the legacy composite planner',
    () {
      final harness = CounselingHarness.deterministic(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      );
      expect(harness.turnPlanner, isA<PolicyPipelineTurnPlanner>());
      expect(
        harness.turnPlanner,
        isNot(isA<DeterministicCounselingTurnPlanner>()),
      );
    },
  );
}
