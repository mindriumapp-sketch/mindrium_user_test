// Phase 9.2C: ActivationGateEvaluator — verifies each gate is computed from
// AggregateReport/HumanReviewSummary correctly, that gates needing data not
// yet supplied report `pending` (null) rather than false, and that
// `readyForActivation` requires every gate to be an explicit pass.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/activation_gate_evaluator.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/aggregate_report.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/human_review.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/pairwise_export.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_runner.dart';

CounselorDecision _decision() => const CounselorDecision(
  selectedAction: DialogueAct.socraticQuestion,
  reflectionTarget: ReflectionTarget.text('x'),
);

ScenarioResult _result({
  required String id,
  bool multiOption = false,
  String category = 'checkIn',
  bool parseSucceeded = true,
  bool validationPassed = true,
  bool materializationSucceeded = true,
  String failureCategory = 'none',
  int? latencyMs = 100,
}) => ScenarioResult(
  scenarioId: id,
  scenarioLabel: id,
  category: category,
  multiOptionActual: multiOption,
  deterministicDecision: _decision(),
  remoteDecision: _decision(),
  parseSucceeded: parseSucceeded,
  remoteValidationPassed: validationPassed,
  remoteMaterializationSucceeded: materializationSucceeded,
  failureCategory: failureCategory,
  latencyMs: latencyMs,
);

void main() {
  group('materialization_no_regression', () {
    test('passes when validationPassed count == materializationSucceeded count', () {
      final report = AggregateReport.compute([
        _result(id: 's1'),
        _result(id: 's2'),
      ]);
      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
      );
      final gate = evaluation.gates.firstWhere(
        (g) => g.name == 'materialization_no_regression',
      );
      expect(gate.passed, isTrue);
    });

    test('fails when a validated decision fails to materialize', () {
      final report = AggregateReport.compute([
        _result(id: 's1'),
        _result(id: 's2', materializationSucceeded: false),
      ]);
      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
      );
      final gate = evaluation.gates.firstWhere(
        (g) => g.name == 'materialization_no_regression',
      );
      expect(gate.passed, isFalse);
      expect(evaluation.hasAnyFailure, isTrue);
      expect(evaluation.readyForActivation, isFalse);
    });
  });

  group('critical_failure_count_zero', () {
    test('passes only when criticalFailureCount is exactly 0', () {
      final report = AggregateReport.compute([_result(id: 's1')]);
      final zero = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
      );
      final nonzero = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 1,
      );
      expect(
        zero.gates.firstWhere((g) => g.name == 'critical_failure_count_zero').passed,
        isTrue,
      );
      expect(
        nonzero.gates
            .firstWhere((g) => g.name == 'critical_failure_count_zero')
            .passed,
        isFalse,
      );
    });
  });

  group('remote_success_rate_minimum', () {
    test('passes at exactly the threshold and fails just below it', () {
      // 98/100 successes = 0.98, meets the default 0.98 threshold.
      final atThreshold = [
        for (var i = 0; i < 98; i++) _result(id: 'ok$i'),
        for (var i = 0; i < 2; i++)
          _result(id: 'fail$i', failureCategory: 'timeout'),
      ];
      final report = AggregateReport.compute(atThreshold);
      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
      );
      expect(
        evaluation.gates
            .firstWhere((g) => g.name == 'remote_success_rate_minimum')
            .passed,
        isTrue,
      );

      final belowThreshold = [
        for (var i = 0; i < 90; i++) _result(id: 'ok$i'),
        for (var i = 0; i < 10; i++)
          _result(id: 'fail$i', failureCategory: 'timeout'),
      ];
      final belowReport = AggregateReport.compute(belowThreshold);
      final belowEvaluation = const ActivationGateEvaluator().evaluate(
        report: belowReport,
        criticalFailureCount: 0,
      );
      expect(
        belowEvaluation.gates
            .firstWhere((g) => g.name == 'remote_success_rate_minimum')
            .passed,
        isFalse,
      );
    });
  });

  group('pending gates (data not yet supplied)', () {
    test('p95 latency and human review gates are pending (null), not false, '
        'when their inputs are omitted', () {
      final report = AggregateReport.compute([_result(id: 's1')]);
      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
      );

      final decideP95 = evaluation.gates.firstWhere(
        (g) => g.name == 'decide_p95_latency_operational',
      );
      final endToEndP95 = evaluation.gates.firstWhere(
        (g) => g.name == 'end_to_end_p95_latency_operational',
      );
      final human = evaluation.gates.firstWhere(
        (g) => g.name == 'human_pairwise_better_than_worse',
      );

      expect(decideP95.passed, isNull);
      expect(endToEndP95.passed, isNull);
      expect(human.passed, isNull);
      expect(evaluation.hasAnyPending, isTrue);
      // Pending gates block readiness just as failures do — an incomplete
      // evaluation must never look like a pass.
      expect(evaluation.readyForActivation, isFalse);
      expect(evaluation.hasAnyFailure, isFalse);
    });
  });

  group('computePairedEndToEndP95Ms', () {
    test('computes p95 of the SUMS, not the sum of two independent p95s', () {
      // 20 pairs designed so p95(decide)+p95(realize) would differ from the
      // true p95 of the paired sums if computed independently.
      final pairs = [
        for (var i = 0; i < 20; i++) (decideMs: 1000 + i * 10, realizeMs: 2000),
      ];
      final result = computePairedEndToEndP95Ms(pairs);
      // 20 entries, p95 index = round(0.95*19) = 18 (0-indexed, sorted).
      final sums = pairs.map((p) => p.decideMs + p.realizeMs).toList()..sort();
      expect(result, sums[18]);
    });

    test('throws on an empty list rather than returning a misleading value', () {
      expect(() => computePairedEndToEndP95Ms(const []), throwsArgumentError);
    });
  });

  group('latency gates: decide-only vs end-to-end (decide + realizer)', () {
    test('end-to-end gate sums decide + realizer p95, not just decide', () {
      final report = AggregateReport.compute([_result(id: 's1')]);

      // Decide alone is well within its own 2500ms budget, but decide +
      // realizer together exceed the 8000ms end-to-end budget.
      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
        decideP95LatencyMs: 2000,
        realizerP95LatencyMs: 6500,
      );

      final decideGate = evaluation.gates.firstWhere(
        (g) => g.name == 'decide_p95_latency_operational',
      );
      final endToEndGate = evaluation.gates.firstWhere(
        (g) => g.name == 'end_to_end_p95_latency_operational',
      );

      expect(decideGate.passed, isTrue);
      expect(endToEndGate.passed, isFalse);
      expect(evaluation.hasAnyFailure, isTrue);
    });

    test(
      'paired end-to-end latency takes priority over the summed-p95s proxy',
      () {
        final report = AggregateReport.compute([_result(id: 's1')]);

        // If the proxy (2000+6500=8500) were used, this would FAIL the
        // 8000ms threshold. The paired figure (7000) must win and PASS.
        final evaluation = const ActivationGateEvaluator().evaluate(
          report: report,
          criticalFailureCount: 0,
          decideP95LatencyMs: 2000,
          realizerP95LatencyMs: 6500,
          pairedEndToEndP95LatencyMs: 7000,
        );

        final gate = evaluation.gates.firstWhere(
          (g) => g.name == 'end_to_end_p95_latency_operational',
        );
        expect(gate.passed, isTrue);
        expect(gate.detail, contains('paired_p95'));
      },
    );

    test('both latency gates pass when within their frozen budgets', () {
      final report = AggregateReport.compute([_result(id: 's1')]);
      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
        decideP95LatencyMs: 1500,
        realizerP95LatencyMs: 4000,
      );

      expect(
        evaluation.gates
            .firstWhere((g) => g.name == 'decide_p95_latency_operational')
            .passed,
        isTrue,
      );
      expect(
        evaluation.gates
            .firstWhere((g) => g.name == 'end_to_end_p95_latency_operational')
            .passed,
        isTrue,
      );
    });
  });

  group('readyForActivation requires every gate to explicitly pass', () {
    test('all gates passing (including supplied p95/human review) -> ready', () {
      final report = AggregateReport.compute([
        for (var i = 0; i < 10; i++) _result(id: 's$i'),
        // At least one multi-option scenario, or that gate stays pending.
        _result(id: 'm0', multiOption: true),
      ]);
      final humanReview = HumanReviewSummary.merge(
        reviews: [
          const PairwiseReview(
            scenarioId: 's0',
            preference: PairwisePreference.aBetter,
          ),
        ],
        mapping: const [PairwiseMappingRow(scenarioId: 's0', aIsRemote: true)],
      );

      final evaluation = const ActivationGateEvaluator().evaluate(
        report: report,
        criticalFailureCount: 0,
        humanReview: humanReview,
        decideP95LatencyMs: 500,
        realizerP95LatencyMs: 3000,
      );

      expect(evaluation.readyForActivation, isTrue);
      expect(evaluation.hasAnyFailure, isFalse);
      expect(evaluation.hasAnyPending, isFalse);
    });
  });
}
