// Phase 9.2C: EvaluationManifest round-trips through JSON without losing
// any provenance field.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/evaluation_manifest.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/frozen_scenarios.dart';

void main() {
  test('toJson/fromJson round-trips every field', () {
    final manifest = EvaluationManifest(
      datasetVersion: frozenScenariosVersion,
      scenarioCount: frozenScenarios.length,
      modelIdentifier: 'gpt-4o-2024-08-06',
      promptVersion: 'decide_v1',
      sampling: const {'temperature': 0.0},
      runnerVersion: 'abc1234',
      runId: 'run-2026-09-22-001',
      timestamp: DateTime.utc(2026, 9, 22, 3, 0, 0),
    );

    final json = manifest.toJson();
    final restored = EvaluationManifest.fromJson(json);

    expect(restored.datasetVersion, manifest.datasetVersion);
    expect(restored.scenarioCount, manifest.scenarioCount);
    expect(restored.modelIdentifier, manifest.modelIdentifier);
    expect(restored.promptVersion, manifest.promptVersion);
    expect(restored.sampling, manifest.sampling);
    expect(restored.runnerVersion, manifest.runnerVersion);
    expect(restored.runId, manifest.runId);
    expect(restored.timestamp, manifest.timestamp);
  });

  test('scenarioCount should match frozenScenarios.length for a real run', () {
    // Not enforced by the class itself (a manifest describes a past run,
    // which may have used a different dataset version) — but this is the
    // expected relationship for any run claiming frozenScenariosVersion.
    expect(frozenScenarios.length, 89);
    expect(frozenScenariosVersion, 'phase9_2b_frozen_v1');
  });
}
