// Standing guard: the real production factory wires the intended planner.
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
