// Phase 9.2B: AggregateReport — hand-built synthetic ScenarioResult list,
// asserting agreement rates/stratified counts exactly against hand-computed
// expected values.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/aggregate_report.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_runner.dart';

CounselorDecision _decision({
  DialogueAct action = DialogueAct.socraticQuestion,
  String? goalId,
}) => CounselorDecision(
  selectedAction: action,
  selectedGoalId: goalId,
  reflectionTarget: const ReflectionTarget.text('target'),
);

void main() {
  test('agreement/disagreement counts and stratification are exact', () {
    final results = <ScenarioResult>[
      // 1: single-option, remote agrees.
      ScenarioResult(
        scenarioId: 's1',
        scenarioLabel: 'l1',
        category: 'checkIn',
        multiOptionActual: false,
        deterministicDecision: _decision(),
        remoteDecision: _decision(),
        parseSucceeded: true,
        remoteValidationPassed: true,
        remoteMaterializationSucceeded: true,
        failureCategory: 'none',
        latencyMs: 100,
      ),
      // 2: multi-option, remote differs (goal id).
      ScenarioResult(
        scenarioId: 's2',
        scenarioLabel: 'l2',
        category: 'reflect_goal_evidence',
        multiOptionActual: true,
        deterministicDecision: _decision(goalId: 'evidence'),
        remoteDecision: _decision(goalId: 'alternative'),
        parseSucceeded: true,
        remoteValidationPassed: true,
        remoteMaterializationSucceeded: true,
        failureCategory: 'none',
        latencyMs: 200,
      ),
      // 3: multi-option, personalization-sensitive, remote fails validation.
      ScenarioResult(
        scenarioId: 's3',
        scenarioLabel: 'l3',
        category: 'personalization_helpfulActivity',
        multiOptionActual: true,
        deterministicDecision: _decision(),
        remoteDecision: _decision(goalId: 'outside_boundary'),
        parseSucceeded: true,
        remoteValidationPassed: false,
        remoteValidationFailureReason: 'out of bounds',
        remoteMaterializationSucceeded: false,
        failureCategory: 'none',
        latencyMs: 300,
      ),
      // 4: no remote agent at all.
      ScenarioResult(
        scenarioId: 's4',
        scenarioLabel: 'l4',
        category: 'intervention_balancedThought_success',
        multiOptionActual: false,
        deterministicDecision: _decision(),
        failureCategory: 'noRemoteAgent',
      ),
      // 5: remote transport failure.
      ScenarioResult(
        scenarioId: 's5',
        scenarioLabel: 'l5',
        category: 'reflect_goal_exhausted_repeat',
        multiOptionActual: true,
        deterministicDecision: _decision(),
        failureCategory: 'timeout',
        latencyMs: 5000,
      ),
    ];

    final report = AggregateReport.compute(results);

    // Overall: 5 scenarios, 4 remote-attempted (s4 excluded), 3 succeeded
    // (s1,s2,s3 have failureCategory 'none'; s5 is 'timeout').
    expect(report.overall.count, 5);
    expect(report.overall.remoteAttempted, 4);
    expect(report.overall.remoteSucceeded, 3);
    expect(report.overall.parseSucceeded, 3);
    expect(report.overall.validationPassed, 2); // s1, s2
    expect(report.overall.materializationSucceeded, 2); // s1, s2
    expect(report.overall.decisionsAgree, 1); // s1
    expect(report.overall.decisionsDiffer, 2); // s2, s3
    expect(report.overall.failureCategoryHistogram['timeout'], 1);
    expect(report.overall.failureCategoryHistogram['none'], 3);
    expect(report.overall.latencyMeanMs, (100 + 200 + 300 + 5000) / 4);

    // singleOption: s1, s4 (multiOptionActual == false).
    expect(report.singleOption.count, 2);
    expect(report.singleOption.remoteAttempted, 1); // s1 only (s4 excluded)
    expect(report.singleOption.decisionsAgree, 1);

    // multiOption: s2, s3, s5.
    expect(report.multiOption.count, 3);
    expect(report.multiOption.remoteAttempted, 3);
    expect(report.multiOption.decisionsDiffer, 2); // s2, s3

    // personalizationSensitive: s3 only.
    expect(report.personalizationSensitive.count, 1);
    expect(report.personalizationSensitive.validationPassed, 0);

    // interventionSensitive: s4 only.
    expect(report.interventionSensitive.count, 1);
    expect(report.interventionSensitive.remoteAttempted, 0);

    // goalExhaustion: s5 only.
    expect(report.goalExhaustion.count, 1);
    expect(report.goalExhaustion.remoteAttempted, 1);
    expect(report.goalExhaustion.remoteSucceeded, 0);

    // toJson round-trips without throwing and preserves key values.
    final json = report.toJson();
    expect(json['overall'], isA<Map<String, Object?>>());
    expect(
      (json['overall'] as Map<String, Object?>)['count'],
      5,
    );
  });

  test('empty result list produces zeroed stats without dividing by zero', () {
    final report = AggregateReport.compute(const []);
    expect(report.overall.count, 0);
    expect(report.overall.remoteSuccessRate, isNull);
    expect(report.overall.agreementRate, isNull);
    expect(report.overall.latencyMeanMs, isNull);
  });
}
