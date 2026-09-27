// Phase 9.1: RemoteCounselorAgent — decideAsync behavior against a fake API,
// plus regression proof that production still defaults to
// DeterministicCounselorAgent and never touches RemoteCounselorAgent.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/counseling_decide_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/deterministic_counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_agent.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

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

PolicyBoundaryRequest _context() => PolicyBoundaryRequest(
  currentState: CounselingState.reflect,
  userMessage: '걱정돼요',
  recentMessages: const [],
  currentWeek: 4,
  interventionRegistry: const ApprovedInterventionRegistry(),
  knowledge: const [],
  retrievalSummary: RetrievalSummary.empty,
);

PolicyBoundary _policy() => PolicyBoundary(
  currentState: CounselingState.reflect,
  allowedActions: const [DialogueAct.socraticQuestion],
  candidateGoalIds: const ['evidence'],
  eligibleInterventionIds: const [],
  allowedFactIds: const [],
  forbiddenConstraints: const [],
  progressInfo: DialogueProgressInfo.empty(),
);

void main() {
  group('RemoteCounselorAgent.decide() (sync interface)', () {
    test('throws UnsupportedError — not usable as a sync call path this phase', () {
      final agent = RemoteCounselorAgent(api: _FakeDecideApi());
      expect(
        () => agent.decide(context: _context(), policy: _policy()),
        throwsUnsupportedError,
      );
    });
  });

  group('RemoteCounselorAgent.decideAsync — success', () {
    test('returns a CounselorDecision parsed from a well-formed response', () async {
      final api = _FakeDecideApi(
        onCall: () => {
          'selectedAction': 'socratic_question',
          'selectedGoalId': 'evidence',
          'selectedInterventionId': null,
          'reflectionTarget': {'type': 'text', 'text': '대상 문장'},
        },
      );
      final agent = RemoteCounselorAgent(api: api);
      final outcome = await agent.decideAsync(
        context: _context(),
        policy: _policy(),
        personalContext: PersonalContextSummary.empty,
      );
      expect(outcome.decision.selectedAction, DialogueAct.socraticQuestion);
      expect(outcome.decision.selectedGoalId, 'evidence');
      expect(api.callCount, 1);
    });
  });

  group('RemoteCounselorAgent.decideAsync — failure modes (fail-closed)', () {
    test('malformed JSON body raises RemoteCounselorFailure.malformedResponse', () async {
      final api = _FakeDecideApi(onCall: () => {'not_a_valid_shape': true});
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(
          isA<RemoteCounselorFailure>().having(
            (e) => e.kind,
            'kind',
            RemoteCounselorFailureKind.malformedResponse,
          ),
        ),
      );
    });

    test('unknown action raises malformedResponse failure', () async {
      final api = _FakeDecideApi(
        onCall: () => {
          'selectedAction': 'not_a_real_action',
          'reflectionTarget': {'type': 'none'},
        },
      );
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(isA<RemoteCounselorFailure>()),
      );
    });

    test('empty response body raises emptyResponse failure', () async {
      final api = _FakeDecideApi(onCall: () => const {});
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(
          isA<RemoteCounselorFailure>().having(
            (e) => e.kind,
            'kind',
            RemoteCounselorFailureKind.emptyResponse,
          ),
        ),
      );
    });

    test('DioException timeout raises RemoteCounselorFailure.timeout', () async {
      final requestOptions = RequestOptions(path: '/counseling/decide');
      final api = _FakeDecideApi(
        throwError: DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(
          isA<RemoteCounselorFailure>().having(
            (e) => e.kind,
            'kind',
            RemoteCounselorFailureKind.timeout,
          ),
        ),
      );
    });

    test('DioException with 5xx response raises httpError failure', () async {
      final requestOptions = RequestOptions(path: '/counseling/decide');
      final api = _FakeDecideApi(
        throwError: DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 502),
          type: DioExceptionType.badResponse,
        ),
      );
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(
          isA<RemoteCounselorFailure>().having(
            (e) => e.kind,
            'kind',
            RemoteCounselorFailureKind.httpError,
          ),
        ),
      );
    });

    test('DioException with 4xx response raises httpError failure', () async {
      final requestOptions = RequestOptions(path: '/counseling/decide');
      final api = _FakeDecideApi(
        throwError: DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      );
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(isA<RemoteCounselorFailure>()),
      );
    });

    test('generic network error (no response) raises networkError failure', () async {
      final requestOptions = RequestOptions(path: '/counseling/decide');
      final api = _FakeDecideApi(
        throwError: DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        ),
      );
      final agent = RemoteCounselorAgent(api: api);
      await expectLater(
        agent.decideAsync(
          context: _context(),
          policy: _policy(),
          personalContext: PersonalContextSummary.empty,
        ),
        throwsA(
          isA<RemoteCounselorFailure>().having(
            (e) => e.kind,
            'kind',
            RemoteCounselorFailureKind.networkError,
          ),
        ),
      );
    });
  });

  group('Regression: production still defaults to DeterministicCounselorAgent', () {
    test('PolicyPipelineTurnPlanner() default counselorAgent is DeterministicCounselorAgent', () {
      const planner = PolicyPipelineTurnPlanner();
      expect(planner.counselorAgent, isA<DeterministicCounselorAgent>());
      expect(planner.fallbackAgent, isA<DeterministicCounselorAgent>());
    });

    test('no RemoteCounselorAgent/network code executes when planning a normal turn', () {
      const planner = PolicyPipelineTurnPlanner();
      final plan = planner.plan(
        TurnPlanningContext(
          state: CounselingState.checkIn,
          userMessage: '안녕하세요',
          recentMessages: const [],
          currentWeek: 1,
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        ),
      );
      // If this reached RemoteCounselorAgent at all it would either throw
      // UnsupportedError (sync decide()) or hang on a real network call
      // (decideAsync()) — neither happened, proving the default pipeline
      // never touches it.
      expect(plan, isNotNull);
    });
  });
}
