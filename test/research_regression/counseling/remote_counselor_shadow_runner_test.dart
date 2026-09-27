// Phase 9.2A: RemoteCounselorShadowRunner — proves shadow evaluation is
// fully isolated from production: flag OFF makes zero network calls (by
// construction), transport/validation/materialization failures never
// escape as exceptions, and shadow eligibility mirrors existing Hard
// Guard/Safety/Intent signals rather than inventing new conditions.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/counseling_decide_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/assistant_intent.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_agent.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_shadow_runner.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

class _ExplodingApi implements CounselingDecideApi {
  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, dynamic> requestBody,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    throw StateError('decideAsync must not be called when shadow flag is OFF');
  }
}

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

PolicyBoundaryRequest _reflectContext() => PolicyBoundaryRequest(
  currentState: CounselingState.reflect,
  userMessage: '발표가 걱정돼요',
  recentMessages: const [],
  currentWeek: 4,
  interventionRegistry: const ApprovedInterventionRegistry(),
  knowledge: const [],
  retrievalSummary: RetrievalSummary.empty,
);

PolicyBoundary _reflectPolicy() => PolicyBoundary(
  currentState: CounselingState.reflect,
  allowedActions: const [DialogueAct.socraticQuestion],
  candidateGoalIds: const ['evidence', 'alternative'],
  eligibleInterventionIds: const [],
  allowedFactIds: const [],
  forbiddenConstraints: const [],
  progressInfo: DialogueProgressInfo.empty(),
);

CounselorDecision _deterministicReflectDecision() => const CounselorDecision(
  selectedAction: DialogueAct.socraticQuestion,
  selectedGoalId: 'evidence',
  reflectionTarget: ReflectionTarget.text('발표가 걱정돼요'),
);

void main() {
  group('A. Flag OFF — zero network calls', () {
    test('decideAsync is never invoked when config.enabled is false', () async {
      final agent = RemoteCounselorAgent(api: _ExplodingApi());
      final runner = RemoteCounselorShadowRunner(
        agent: agent,
        config: const ShadowEvaluationConfig(enabled: false),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(result.remoteDecision, isNull);
      expect(result.parseSucceeded, isFalse);
      expect(result.failureCategory, 'disabled');
    });

    test('default ShadowEvaluationConfig() is disabled', () {
      expect(const ShadowEvaluationConfig().enabled, isFalse);
    });
  });

  group('B. Flag ON — normal success case', () {
    test('valid remote decision -> validationPassed and materializationSucceeded', () async {
      final api = _FakeDecideApi(
        onCall: () => {
          'selectedAction': 'socratic_question',
          'selectedGoalId': 'evidence',
          'selectedInterventionId': null,
          'reflectionTarget': {'type': 'text', 'text': '발표가 걱정돼요'},
        },
      );
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(api.callCount, 1);
      expect(result.parseSucceeded, isTrue);
      expect(result.validationPassed, isTrue);
      expect(result.materializationSucceeded, isTrue);
      expect(result.failureCategory, 'none');
    });

    test(
      'Phase 9.2A.1: model/prompt/token metadata flows through to the result',
      () async {
        final api = _FakeDecideApi(
          onCall: () => {
            'selectedAction': 'socratic_question',
            'selectedGoalId': 'evidence',
            'selectedInterventionId': null,
            'reflectionTarget': {'type': 'text', 'text': '발표가 걱정돼요'},
            'modelIdentifier': 'gpt-4o-2024-08-06',
            'promptVersion': 'decide_v1',
            'inputTokens': 500,
            'outputTokens': 30,
          },
        );
        final runner = RemoteCounselorShadowRunner(
          agent: RemoteCounselorAgent(api: api),
          config: const ShadowEvaluationConfig(enabled: true),
        );

        final result = await runner.evaluate(
          request: _reflectContext(),
          policy: _reflectPolicy(),
          personalContext: PersonalContextSummary.empty,
          deterministicDecision: _deterministicReflectDecision(),
        );

        expect(result.modelIdentifier, 'gpt-4o-2024-08-06');
        expect(result.promptVersion, 'decide_v1');
        expect(result.inputTokens, 500);
        expect(result.outputTokens, 30);
      },
    );
  });

  group('C. Remote decision differs from deterministic but is valid', () {
    test('decisionsDiffer is true and it is not treated as failure', () async {
      final api = _FakeDecideApi(
        onCall: () => {
          'selectedAction': 'socratic_question',
          'selectedGoalId': 'alternative',
          'selectedInterventionId': null,
          'reflectionTarget': {'type': 'text', 'text': '다른 대상'},
        },
      );
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(result.decisionsDiffer, isTrue);
      expect(result.validationPassed, isTrue);
      expect(result.failureCategory, 'none');
    });
  });

  group('D. Invalid remote decision (out of policy bounds)', () {
    test('goal outside candidateGoalIds -> validationPassed false with reason', () async {
      final api = _FakeDecideApi(
        onCall: () => {
          'selectedAction': 'socratic_question',
          'selectedGoalId': 'probability_not_offered',
          'selectedInterventionId': null,
          'reflectionTarget': {'type': 'text', 'text': '대상'},
        },
      );
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(result.parseSucceeded, isTrue);
      expect(result.validationPassed, isFalse);
      expect(result.validationFailureReason, isNotNull);
      expect(result.materializationSucceeded, isFalse);
    });
  });

  group('E. Transport failures — absorbed, never thrown', () {
    test('timeout is captured in result, not thrown', () async {
      final api = _FakeDecideApi(
        throwError: DioException(
          requestOptions: RequestOptions(path: '/counseling/decide'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(result.remoteDecision, isNull);
      expect(result.parseSucceeded, isFalse);
      expect(result.failureCategory, 'timeout');
    });

    test('malformed response body is captured, not thrown', () async {
      final api = _FakeDecideApi(onCall: () => {'not_a_valid_shape': true});
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(result.parseSucceeded, isFalse);
      expect(result.failureCategory, 'malformedResponse');
    });

    test('empty response body is captured as emptyResponse', () async {
      final api = _FakeDecideApi(onCall: () => const {});
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      final result = await runner.evaluate(
        request: _reflectContext(),
        policy: _reflectPolicy(),
        personalContext: PersonalContextSummary.empty,
        deterministicDecision: _deterministicReflectDecision(),
      );

      expect(result.failureCategory, 'emptyResponse');
    });
  });

  group('F. Materialization dry-run failure (defensive robustness)', () {
    // Phase 9.2A.1 traced this: `DeterministicPolicyBoundaryBuilder`
    // constructs `eligibleInterventionIds` directly from `request.knowledge`
    // (see `_buildInterventionBoundary`), so for any (policy, request) pair
    // produced consistently from the SAME request, this gap cannot occur —
    // proven for representative states/intervention types in
    // `counselor_decision_materializer_invariant_test.dart`.
    //
    // This test instead exercises a caller-supplied MISMATCHED pair (a
    // hand-built `policy` claiming `cbt_x` is eligible, paired with a
    // `request` whose `knowledge` is empty) — an edge case that should never
    // arise from a boundary the production builder actually computed, but
    // that `RemoteCounselorShadowRunner` must still survive without
    // crashing, since a `CounselorAgent` decision is caller/network-derived
    // and the runner cannot assume its inputs are internally consistent.
    test(
      'a mismatched (policy, request) pair is caught and recorded as a '
      'materialization failure, not an uncaught exception',
      () async {
        final policy = PolicyBoundary(
          currentState: CounselingState.intervention,
          allowedActions: const [DialogueAct.socraticQuestion],
          candidateGoalIds: const [],
          eligibleInterventionIds: const ['cbt_x'],
          allowedFactIds: const [],
          forbiddenConstraints: const [],
          progressInfo: DialogueProgressInfo.empty(),
        );
        final request = PolicyBoundaryRequest(
          currentState: CounselingState.intervention,
          userMessage: '피하고 싶어요',
          recentMessages: const [],
          currentWeek: 4,
          interventionRegistry: const ApprovedInterventionRegistry(),
          // Deliberately inconsistent with `policy` above: knowledge is
          // empty, so 'cbt_x' cannot be found even though `policy` (hand-built,
          // not derived from this request) claims it's eligible. A real
          // boundary built from this same request would never produce such
          // a policy — see this file's class doc comment.
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        );
        final api = _FakeDecideApi(
          onCall: () => {
            'selectedAction': 'socratic_question',
            'selectedGoalId': null,
            'selectedInterventionId': 'cbt_x',
            'reflectionTarget': {'type': 'text', 'text': '피하고 싶은 상황'},
          },
        );
        final runner = RemoteCounselorShadowRunner(
          agent: RemoteCounselorAgent(api: api),
          config: const ShadowEvaluationConfig(enabled: true),
        );

        final result = await runner.evaluate(
          request: request,
          policy: policy,
          personalContext: PersonalContextSummary.empty,
          deterministicDecision: const CounselorDecision(
            selectedAction: DialogueAct.socraticQuestion,
            selectedInterventionId: 'cbt_x',
            reflectionTarget: ReflectionTarget.text('피하고 싶은 상황'),
          ),
        );

        expect(result.validationPassed, isTrue);
        expect(result.materializationSucceeded, isFalse);
      },
    );
  });

  group('G. shouldRunShadow eligibility', () {
    test('false when Hard Guard already handled the turn', () {
      expect(
        shouldRunShadow(
          intent: AssistantIntent.counselingOnly,
          handledByHardGuard: true,
        ),
        isFalse,
      );
    });

    test('false when safety level is elevated', () {
      expect(
        shouldRunShadow(
          intent: AssistantIntent.counselingOnly,
          handledByHardGuard: false,
          safetyLevel: SafetyLevel.elevated,
        ),
        isFalse,
      );
    });

    test('false when safety level is crisis', () {
      expect(
        shouldRunShadow(
          intent: AssistantIntent.counselingOnly,
          handledByHardGuard: false,
          safetyLevel: SafetyLevel.crisis,
        ),
        isFalse,
      );
    });

    test('false for appGuideOnly intent', () {
      expect(
        shouldRunShadow(
          intent: const AssistantIntent(
            needsCounseling: false,
            needsAppGuidance: true,
          ),
          handledByHardGuard: false,
        ),
        isFalse,
      );
    });

    test('true for a normal counselingOnly turn', () {
      expect(
        shouldRunShadow(
          intent: AssistantIntent.counselingOnly,
          handledByHardGuard: false,
        ),
        isTrue,
      );
    });

    test('true for a mixed turn', () {
      expect(
        shouldRunShadow(
          intent: const AssistantIntent(
            needsCounseling: true,
            needsAppGuidance: true,
          ),
          handledByHardGuard: false,
        ),
        isTrue,
      );
    });
  });

  group('I. Logging serialization has no sensitive data', () {
    test('toLogEntry contains only structural metadata', () async {
      final api = _FakeDecideApi(
        onCall: () => {
          'selectedAction': 'socratic_question',
          'selectedGoalId': 'evidence',
          'selectedInterventionId': null,
          'reflectionTarget': {
            'type': 'text',
            'text': '민감한 원본 사용자 발화 텍스트입니다',
          },
        },
      );
      final runner = RemoteCounselorShadowRunner(
        agent: RemoteCounselorAgent(api: api),
        config: const ShadowEvaluationConfig(enabled: true),
      );

      const sensitiveUserMessage = '민감한 원본 사용자 발화 텍스트입니다';
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.reflect,
        userMessage: sensitiveUserMessage,
        recentMessages: const [],
        currentWeek: 4,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: const [],
        retrievalSummary: RetrievalSummary.empty,
      );
      const personalContext = PersonalContextSummary(
        currentRelatedIssue: '개인 컨텍스트 원문 텍스트',
      );

      final result = await runner.evaluate(
        request: request,
        policy: _reflectPolicy(),
        personalContext: personalContext,
        deterministicDecision: _deterministicReflectDecision(),
      );

      final logEntry = result.toLogEntry();
      final serialized = logEntry.toString();

      expect(serialized.contains(sensitiveUserMessage), isFalse);
      expect(serialized.contains('개인 컨텍스트 원문 텍스트'), isFalse);
      expect(logEntry.containsKey('user_message'), isFalse);
      expect(logEntry.containsKey('personal_context'), isFalse);
      expect(logEntry.containsKey('transcript'), isFalse);

      // Allowed structural fields are present.
      expect(logEntry['validation_passed'], isTrue);
      expect(logEntry['failure_category'], 'none');
      expect(logEntry.containsKey('latency_ms'), isTrue);
    });
  });
}
