// Phase 9.2B: ScenarioRunner — proves it collects both deterministic and
// remote decisions correctly, that a differing-but-boundary-legal remote
// decision is handled as a normal (non-failure) case, and that a missing
// or failing remote agent never crashes the run.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/counseling_decide_api.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_fixture.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_runner.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_agent.dart';

// Same fake pattern as remote_counselor_shadow_runner_test.dart's
// _FakeDecideApi — RemoteCounselorAgent takes an injectable
// CounselingDecideApi dependency, so that's what's faked here rather than
// subclassing RemoteCounselorAgent itself.
class _FakeDecideApi implements CounselingDecideApi {
  final Map<String, dynamic>? Function()? onCall;
  final Object? throwError;
  int callCount = 0;

  _FakeDecideApi({this.onCall, this.throwError});

  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, dynamic> requestBody,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    callCount++;
    if (throwError != null) throw throwError!;
    return onCall?.call() ?? const {};
  }
}

ScenarioFixture _reflectFixture() => ScenarioFixture(
  id: 'test_reflect_1',
  label: 'Test reflect',
  category: 'reflect_goal_evidence',
  request: PolicyBoundaryRequest(
    currentState: CounselingState.reflect,
    userMessage: '발표가 걱정돼요',
    recentMessages: const [],
    currentWeek: 4,
    interventionRegistry: const ApprovedInterventionRegistry(),
    knowledge: const [],
    retrievalSummary: RetrievalSummary.empty,
  ),
  multiOption: true,
);

void main() {
  group('missing remote agent', () {
    test('run() with no remoteAgent returns deterministic-only result', () async {
      const runner = ScenarioRunner();
      final result = await runner.run(_reflectFixture());

      expect(result.remoteDecision, isNull);
      expect(result.parseSucceeded, isFalse);
      expect(result.failureCategory, 'noRemoteAgent');
      expect(result.deterministicResponseText, isNotNull);
    });
  });

  group('remote agent produces a different-but-legal decision', () {
    test('both decisions collected, decisionsDiffer true, not a failure', () async {
      final api = _FakeDecideApi(
        onCall:
            () => {
              'selectedAction': 'socratic_question',
              'selectedGoalId': 'alternative',
              'selectedInterventionId': null,
              'reflectionTarget': {'type': 'text', 'text': '다른 대상'},
            },
      );
      const runner = ScenarioRunner();

      final result = await runner.run(
        _reflectFixture(),
        remoteAgent: RemoteCounselorAgent(api: api),
      );

      expect(result.remoteDecision, isNotNull);
      expect(result.remoteDecision!.selectedGoalId, 'alternative');
      expect(result.decisionsDiffer, isTrue);
      expect(result.parseSucceeded, isTrue);
      expect(result.remoteValidationPassed, isTrue);
      expect(result.remoteMaterializationSucceeded, isTrue);
      expect(result.failureCategory, 'none');
    });
  });

  group('failing remote agent does not crash the run', () {
    test('transport failure is captured, not thrown', () async {
      final api = _FakeDecideApi(
        throwError: DioException(
          requestOptions: RequestOptions(path: '/counseling/decide'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      const runner = ScenarioRunner();

      final result = await runner.run(
        _reflectFixture(),
        remoteAgent: RemoteCounselorAgent(api: api),
      );

      expect(result.remoteDecision, isNull);
      expect(result.parseSucceeded, isFalse);
      expect(result.failureCategory, 'timeout');
      // Deterministic side must still be fully populated.
      expect(result.deterministicDecision, isNotNull);
      expect(result.deterministicResponseText, isNotNull);
    });

    test('malformed response is captured, not thrown', () async {
      final api = _FakeDecideApi(onCall: () => {'not_valid': true});
      const runner = ScenarioRunner();

      final result = await runner.run(
        _reflectFixture(),
        remoteAgent: RemoteCounselorAgent(api: api),
      );

      expect(result.failureCategory, 'malformedResponse');
    });
  });

  group('runAll', () {
    test('one failing scenario does not abort the batch', () async {
      final failingApi = _FakeDecideApi(
        throwError: DioException(
          requestOptions: RequestOptions(path: '/counseling/decide'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      const runner = ScenarioRunner();

      final results = await runner.runAll(
        [_reflectFixture(), _reflectFixture()],
        remoteAgent: RemoteCounselorAgent(api: failingApi),
      );

      expect(results.length, 2);
      for (final r in results) {
        expect(r.failureCategory, 'timeout');
      }
    });

    test('runAll works with an empty fixture list', () async {
      const runner = ScenarioRunner();
      final results = await runner.runAll(const []);
      expect(results, isEmpty);
    });
  });
}
