// Phase 8.3: equivalence tests between
//   (A) legacy DeterministicCounselingTurnPlanner
//   (B) DeterministicPolicyBoundaryBuilder -> DeterministicCounselorAgent -> TurnPlanAdapter
//
// For each scenario both paths must agree on the fields that matter for
// production behavior: requiredAct, reflectionTarget, questionGoal /
// progressGoalId, selected intervention, allowedActsForTurn, and the
// question-count-relevant constraints.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/deterministic_counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/turn_plan_adapter.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

MindriumCounselingContext _diaryContext() => MindriumCounselingContext(
  currentWeek: 4,
  relevantItems: [
    UserContextItem(
      id: 'diary:abc123',
      type: UserContextType.diary,
      text: '상황: 연구 발표 / 생각: 질문에 답을 못하면 무능해 보일 것이다',
      occurredAt: DateTime(2026, 9, 1),
      sud: 7,
    ),
  ],
);

MindriumCounselingContext _unrelatedDiaryContext() => MindriumCounselingContext(
  currentWeek: 2,
  relevantItems: [
    UserContextItem(
      id: 'diary:unrelated1',
      type: UserContextType.diary,
      text: '상황: 친구와 다툼 / 생각: 다시는 연락하지 않을 것이다',
      occurredAt: DateTime(2026, 8, 1),
      sud: 5,
    ),
  ],
);

MindriumCounselingContext _effectiveInterventionContext() =>
    MindriumCounselingContext(
      currentWeek: 8,
      effectiveInterventions: const [
        EffectiveIntervention(
          id: 'effective:abc',
          type: 'relaxation',
          label: '호흡 이완법',
          preSud: 7,
          postSud: 3,
        ),
      ],
    );

CbtKnowledgeItem _cbtItem({
  required String id,
  int week = 4,
  String type = 'technique',
  List<String> tags = const ['alternative_thought', 'cognitive_restructuring'],
  bool guidance = true,
}) => CbtKnowledgeItem(
  id: id,
  week: week,
  type: type,
  title: id,
  paragraphs: const ['검증용 문단'],
  tags: tags,
  source: 'test',
  conversationalGuidanceAvailable: guidance,
);

/// Runs both pipelines for [context] and returns (legacyPlan, newPlan).
/// newPlan comes from Boundary -> Agent -> Adapter; the Agent's decision is
/// also asserted (via [DeterministicCounselorAgent]'s internal asserts,
/// which run under `flutter test`'s default assert-enabled mode) to fit
/// inside the boundary.
(CounselingTurnPlan?, CounselingTurnPlan?) _runBoth(TurnPlanningContext context) {
  const legacy = DeterministicCounselingTurnPlanner();
  final legacyPlan = legacy.plan(context);

  final request = PolicyBoundaryRequest(
    currentState: context.state,
    userMessage: context.userMessage,
    userContext: context.userContext,
    recentMessages: context.recentMessages,
    currentWeek: context.currentWeek,
    interventionRegistry: const ApprovedInterventionRegistry(),
    knowledge: context.knowledge,
    retrievalSummary: context.retrievalSummary,
  );

  const builder = DeterministicPolicyBoundaryBuilder();
  const CounselorAgent agent = DeterministicCounselorAgent();
  const adapter = TurnPlanAdapter();

  final boundary = builder.build(request);
  if (boundary == null) {
    return (legacyPlan, null);
  }

  // The agent's decision is what the adapter now materializes into the
  // actual plan (Phase 8.4B) — no more re-invoking the legacy planner.
  final decision = agent.decide(context: request, policy: boundary);

  final newPlan = adapter.build(
    request: request,
    policy: boundary,
    decision: decision,
  );
  return (legacyPlan, newPlan);
}

void main() {
  group('CheckIn', () {
    test('legacy와 new pipeline이 requiredAct/target에서 일치한다', () {
      const context = TurnPlanningContext(
        state: CounselingState.checkIn,
        userMessage: '요즘 회사 일 때문에 계속 불안해요.',
        knowledge: [],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy, isNotNull);
      expect(fresh, isNotNull);
      expect(fresh!.requiredAct, legacy!.requiredAct);
      expect(fresh.reflectionTarget, legacy.reflectionTarget);
      expect(fresh.questionGoal, legacy.questionGoal);
      expect(fresh.constraints, legacy.constraints);
    });
  });

  group('Explore', () {
    test('일반: 발표 불안 fixture', () {
      const context = TurnPlanningContext(
        state: CounselingState.explore,
        userMessage: '발표할 때 질문을 받으면 대답을 못할까봐 걱정돼요.',
        knowledge: [],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(fresh!.requiredAct, legacy!.requiredAct);
      expect(fresh.allowedActsForTurn, legacy.allowedActsForTurn);
      expect(fresh.reflectionTarget, legacy.reflectionTarget);
    });

    test('SUD 응답 특수 경로: 숫자 응답은 직전 실질 발화를 target으로 쓴다', () {
      final context = TurnPlanningContext(
        state: CounselingState.explore,
        userMessage: '6점이에요.',
        knowledge: const [],
        recentMessages: [
          CounselingMessage(
            id: 'u1',
            role: 'user',
            text: '발표할 때 질문을 받으면 대답을 못할까봐 걱정돼요.',
            createdAt: DateTime(2026, 9, 1),
          ),
          CounselingMessage(
            id: 'a1',
            role: 'assistant',
            text: '지금 느끼는 불안을 0에서 10 사이로 표현하면 어느 정도인가요?',
            createdAt: DateTime(2026, 9, 1),
          ),
        ],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(fresh!.reflectionTarget, legacy!.reflectionTarget);
      expect(fresh.reflectionTarget, contains('발표'));
      expect(fresh.requiredAct, legacy.requiredAct);
    });
  });

  group('Reflect', () {
    test('첫 goal(evidence)', () {
      const context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '질문에 답을 못하면 무능해 보일 것 같아요.',
        knowledge: [],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.progressGoalId, 'evidence');
      expect(fresh!.progressGoalId, legacy.progressGoalId);
      expect(fresh.requiredAct, legacy.requiredAct);
    });

    test('두번째 goal(alternative): evidence 이미 질문됨', () {
      final context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '그 생각이 맞다고 느꼈던 순간이 있었어요.',
        knowledge: const [],
        recentMessages: [
          CounselingMessage(
            id: 'asked-evidence',
            role: 'assistant',
            text: '그 생각을 사실이라고 느끼게 하는 근거나 경험이 무엇인지 하나 떠올려볼까요?',
            createdAt: DateTime(2026, 9, 1),
            dialogueGoalId: 'evidence',
          ),
        ],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.progressGoalId, 'alternative');
      expect(fresh!.progressGoalId, legacy.progressGoalId);
    });

    test('세번째 goal(probability): evidence+alternative 이미 질문됨', () {
      final context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '다르게 보면 꼭 그렇지 않을 수도 있을 것 같아요.',
        knowledge: const [],
        recentMessages: [
          CounselingMessage(
            id: 'asked-evidence',
            role: 'assistant',
            text: '근거 질문',
            createdAt: DateTime(2026, 9, 1),
            dialogueGoalId: 'evidence',
          ),
          CounselingMessage(
            id: 'asked-alternative',
            role: 'assistant',
            text: '대안 질문',
            createdAt: DateTime(2026, 9, 1),
            dialogueGoalId: 'alternative',
          ),
        ],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.progressGoalId, 'probability');
      expect(fresh!.progressGoalId, legacy.progressGoalId);
    });

    test('goal 소진: 모두 질문된 후 마지막 goal(probability) 반복', () {
      final context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '그럴 가능성은 낮은 것 같아요.',
        knowledge: const [],
        recentMessages: [
          CounselingMessage(
            id: 'asked-evidence',
            role: 'assistant',
            text: '근거 질문',
            createdAt: DateTime(2026, 9, 1),
            dialogueGoalId: 'evidence',
          ),
          CounselingMessage(
            id: 'asked-alternative',
            role: 'assistant',
            text: '대안 질문',
            createdAt: DateTime(2026, 9, 1),
            dialogueGoalId: 'alternative',
          ),
          CounselingMessage(
            id: 'asked-probability',
            role: 'assistant',
            text: '확률 질문',
            createdAt: DateTime(2026, 9, 1),
            dialogueGoalId: 'probability',
          ),
        ],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.progressGoalId, 'probability');
      expect(fresh!.progressGoalId, 'probability');

      // Boundary-level verification of the Step 0 exhaustion semantics.
      final request = PolicyBoundaryRequest(
        currentState: context.state,
        userMessage: context.userMessage,
        userContext: context.userContext,
        recentMessages: context.recentMessages,
        currentWeek: context.currentWeek,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: context.knowledge,
        retrievalSummary: context.retrievalSummary,
      );
      const builder = DeterministicPolicyBoundaryBuilder();
      final boundary = builder.build(request)!;
      expect(boundary.goalsExhausted, isTrue);
      expect(boundary.candidateGoalIds, ['probability']);
    });

    test('일기 기반 target 사용', () {
      final context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '모르겠어요.',
        knowledge: const [],
        userContext: _diaryContext(),
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.userContextIds, contains('diary:abc123'));
      expect(fresh!.reflectionTarget, legacy.reflectionTarget);
      expect(fresh.userContextIds, legacy.userContextIds);
    });

    test('회귀 가드: 무관한 과거 기록은 target으로 쓰지 않는다', () {
      final context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '발표에서 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
        knowledge: const [],
        userContext: _unrelatedDiaryContext(),
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.reflectionTarget, isNot(contains('친구')));
      expect(fresh!.reflectionTarget, legacy.reflectionTarget);
      expect(fresh.userContextIds, legacy.userContextIds);
    });
  });

  group('Intervention', () {
    final approvedBalanced = _cbtItem(id: 'week4_alternative_thought_01');

    test('주차 미승인: unavailable', () {
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 2,
        userMessage: '아무 생각이 안 나요.',
        knowledge: [approvedBalanced],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.planningStatus, TurnPlanningStatus.unavailable);
      expect(fresh!.planningStatus, TurnPlanningStatus.unavailable);
      expect(fresh.requiredAct, legacy.requiredAct);
    });

    test('balancedThought 성공', () {
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 4,
        userMessage: '발표에서 질문에 답을 못하면 무능해 보일 것 같아요.',
        knowledge: [approvedBalanced],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.planningStatus, TurnPlanningStatus.planned);
      expect(fresh!.interventionPlan!.selectedCbtId, legacy.interventionPlan!.selectedCbtId);
      expect(fresh.interventionPlan!.type, legacy.interventionPlan!.type);
      expect(fresh.reflectionTarget, legacy.reflectionTarget);
    });

    test('maintenanceReview 성공', () {
      final approvedMaintenance = _cbtItem(
        id: 'week8_maintenance_01',
        week: 8,
        tags: const ['maintenance', 'relapse_prevention', 'habit', 'values'],
      );
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 8,
        userMessage: '별다른 이야기는 없어요.',
        knowledge: [approvedMaintenance],
        userContext: _effectiveInterventionContext(),
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.planningStatus, TurnPlanningStatus.planned);
      expect(legacy.interventionPlan!.type, InterventionType.maintenanceReview);
      expect(fresh!.interventionPlan!.selectedCbtId, legacy.interventionPlan!.selectedCbtId);
      expect(fresh.userContextIds, legacy.userContextIds);
    });

    test('이미 사용된 개입: unavailable', () {
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 4,
        userMessage: '발표에서 질문에 답을 못하면 무능해 보일 것 같아요.',
        knowledge: [approvedBalanced],
        recentMessages: [
          CounselingMessage(
            id: 'used-week4',
            role: 'assistant',
            text: '이 생각을 조금 더 균형 있게 바꾼 문장을 만들어보겠습니다.',
            createdAt: DateTime(2026, 9, 3),
            referencedCbtIds: const ['week4_alternative_thought_01'],
          ),
        ],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.planningStatus, TurnPlanningStatus.unavailable);
      expect(fresh!.planningStatus, TurnPlanningStatus.unavailable);
    });
  });

  group('Closing', () {
    test('summary target 있음', () {
      const context = TurnPlanningContext(
        state: CounselingState.closing,
        userMessage: '오늘 발표 불안에 대해 많이 이야기한 것 같아요.',
        knowledge: [],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.reflectionTarget, isNotEmpty);
      expect(fresh!.reflectionTarget, legacy.reflectionTarget);
      expect(fresh.reflectionSentence, legacy.reflectionSentence);

      final request = PolicyBoundaryRequest(
        currentState: context.state,
        userMessage: context.userMessage,
        recentMessages: context.recentMessages,
        currentWeek: context.currentWeek,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: context.knowledge,
        retrievalSummary: context.retrievalSummary,
      );
      const builder = DeterministicPolicyBoundaryBuilder();
      final boundary = builder.build(request)!;
      expect(boundary.hasClosingSummaryTarget, isTrue);
    });

    test('summary target 없음', () {
      const context = TurnPlanningContext(
        state: CounselingState.closing,
        userMessage: '감사합니다.',
        knowledge: [],
      );
      final (legacy, fresh) = _runBoth(context);
      expect(legacy!.reflectionTarget, isEmpty);
      expect(fresh!.reflectionTarget, legacy.reflectionTarget);

      final request = PolicyBoundaryRequest(
        currentState: context.state,
        userMessage: context.userMessage,
        recentMessages: context.recentMessages,
        currentWeek: context.currentWeek,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: context.knowledge,
        retrievalSummary: context.retrievalSummary,
      );
      const builder = DeterministicPolicyBoundaryBuilder();
      final boundary = builder.build(request)!;
      expect(boundary.hasClosingSummaryTarget, isFalse);
    });
  });

  group('Hard Guard bypass', () {
    test('InputGuard/ProcessSignal은 Agent 호출 전에 완전히 처리되어 우회한다', () {
      // The Agent/boundary pipeline has no InputGuard/ProcessSignal
      // equivalent by design (see PHASE8_PLANNER_INVENTORY.md — both stay
      // outside Agent scope as Hard Guard). Feeding a gibberish/process
      // message into the boundary builder produces a normal state-shaped
      // boundary (e.g. checkIn's fixed explore boundary) rather than the
      // guard's unknown/unavailable shape — proving the guard runs, if at
      // all, strictly before this pipeline is invoked, never inside it.
      const context = TurnPlanningContext(
        state: CounselingState.checkIn,
        userMessage: 'ㅁㄴㅇㄹㅁㄴㅇㄹ',
        knowledge: [],
      );
      const legacy = DeterministicCounselingTurnPlanner();
      final legacyPlan = legacy.plan(context)!;
      expect(legacyPlan.planningStatus, TurnPlanningStatus.unavailable);
      expect(legacyPlan.requiredAct, DialogueAct.unknown);

      final request = PolicyBoundaryRequest(
        currentState: context.state,
        userMessage: context.userMessage,
        recentMessages: context.recentMessages,
        currentWeek: context.currentWeek,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: context.knowledge,
        retrievalSummary: context.retrievalSummary,
      );
      const builder = DeterministicPolicyBoundaryBuilder();
      final boundary = builder.build(request)!;
      // The boundary builder has no guard concept: it always returns
      // checkIn's normal fixed boundary regardless of gibberish input.
      expect(boundary.allowedActions, [DialogueAct.explore]);
      expect(boundary.isAvailable, isTrue);
    });
  });
}
