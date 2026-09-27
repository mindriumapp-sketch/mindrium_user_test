// Phase 8.2: Equivalence tests between the legacy deterministic planners
// (turn_plan.dart) and the new DeterministicPolicyBoundaryBuilder.
//
// These tests never assert on the *final* plan the agent would choose —
// only that whatever the legacy planner actually picked also fits inside
// the boundary the new builder computes for the same input. This is the
// contract Phase 8.3's agent will rely on.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
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

PolicyBoundaryRequest _requestFrom(TurnPlanningContext context) {
  return PolicyBoundaryRequest(
    currentState: context.state,
    userMessage: context.userMessage,
    userContext: context.userContext,
    recentMessages: context.recentMessages,
    currentWeek: context.currentWeek,
    interventionRegistry: const ApprovedInterventionRegistry(),
    knowledge: context.knowledge,
    retrievalSummary: RetrievalSummary.empty,
  );
}

void main() {
  const builder = DeterministicPolicyBoundaryBuilder();

  group('CheckIn boundary equivalence', () {
    test('legacy requiredAct is inside boundary.allowedActions', () {
      const context = TurnPlanningContext(
        state: CounselingState.checkIn,
        userMessage: '요즘 회사 일 때문에 계속 불안해요.',
        knowledge: [],
      );
      final plan = const DeterministicCheckInTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(boundary.allowedActions, contains(plan.requiredAct));
      expect(boundary.isAvailable, isTrue);
    });
  });

  group('Explore boundary equivalence', () {
    test(
      '발표 불안: legacy requiredAct와 allowedActsForTurn이 boundary와 일치',
      () {
        const context = TurnPlanningContext(
          state: CounselingState.explore,
          userMessage: '발표할 때 질문을 받으면 대답을 못할까봐 걱정돼요.',
          knowledge: [],
        );
        final plan = const DeterministicExploreTurnPlanner().plan(context)!;
        final boundary = builder.build(_requestFrom(context))!;

        expect(boundary.allowedActions, contains(plan.requiredAct));
        expect(boundary.allowedActions, plan.allowedActsForTurn);
      },
    );

    test('건강 걱정: 다른 주제에서도 boundary가 requiredAct를 포함한다', () {
      const context = TurnPlanningContext(
        state: CounselingState.explore,
        userMessage: '몸이 계속 안 좋을까봐 걱정돼요.',
        knowledge: [],
      );
      final plan = const DeterministicExploreTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(boundary.allowedActions, contains(plan.requiredAct));
      expect(boundary.allowedActions, plan.allowedActsForTurn);
    });
  });

  group('Reflect boundary equivalence', () {
    test('legacy가 선택한 goal이 candidateGoalIds에 포함된다 (첫 reflect 턴)', () {
      const context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '질문에 답을 못하면 무능해 보일 것 같아요.',
        knowledge: [],
      );
      final plan = const DeterministicReflectTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.progressGoalId, isNotNull);
      expect(boundary.candidateGoalIds, contains(plan.progressGoalId));
      expect(boundary.allowedActions, contains(plan.requiredAct));
    });

    test('이미 질문한 goal(evidence)은 이번 턴 candidateGoalIds에서 제외된다', () {
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
      final plan = const DeterministicReflectTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(boundary.candidateGoalIds, isNot(contains('evidence')));
      expect(boundary.progressInfo.askedGoalIds, contains('evidence'));
      expect(boundary.candidateGoalIds, contains(plan.progressGoalId));
    });

    test('diary가 target으로 쓰였을 때 boundary.allowedFactIds에 diary id가 포함된다', () {
      final context = TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: '모르겠어요.',
        knowledge: const [],
        userContext: _diaryContext(),
      );
      final plan = const DeterministicReflectTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.userContextIds, contains('diary:abc123'));
      expect(boundary.allowedFactIds, contains('diary:abc123'));
    });
  });

  group('Intervention boundary equivalence', () {
    final approvedBalanced = _cbtItem(id: 'week4_alternative_thought_01');

    test('주차 미승인 케이스: unavailabilityReason이 non-null', () {
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 2,
        userMessage: '아무 생각이 안 나요.',
        knowledge: [approvedBalanced],
      );
      final plan = const DeterministicInterventionTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.planningStatus, TurnPlanningStatus.unavailable);
      expect(boundary.unavailabilityReason, isNotNull);
      expect(boundary.isAvailable, isFalse);
    });

    test('정상 케이스 (balancedThought, week4): eligible + isAvailable true', () {
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 4,
        userMessage: '발표에서 질문에 답을 못하면 무능해 보일 것 같아요.',
        knowledge: [approvedBalanced],
      );
      final plan = const DeterministicInterventionTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.planningStatus, TurnPlanningStatus.planned);
      expect(
        boundary.eligibleInterventionIds,
        contains(plan.interventionPlan!.selectedCbtId),
      );
      expect(boundary.isAvailable, isTrue);
    });

    test('정상 케이스 (maintenanceReview, week8): eligible + isAvailable true', () {
      final approvedMaintenance = _cbtItem(
        id: 'week8_maintenance_01',
        week: 8,
        tags: const ['maintenance', 'relapse_prevention', 'habit', 'values'],
      );
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 8,
        userMessage: '호흡 연습을 계속하니 도움이 됐어요.',
        knowledge: [approvedMaintenance],
      );
      final plan = const DeterministicInterventionTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.planningStatus, TurnPlanningStatus.planned);
      expect(plan.interventionPlan!.type, InterventionType.maintenanceReview);
      expect(
        boundary.eligibleInterventionIds,
        contains(plan.interventionPlan!.selectedCbtId),
      );
      expect(boundary.isAvailable, isTrue);
    });

    test('이미 사용된 개입: unavailabilityReason이 non-null', () {
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
      final plan = const DeterministicInterventionTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.planningStatus, TurnPlanningStatus.unavailable);
      expect(boundary.unavailabilityReason, isNotNull);
    });

    test('지식 미매칭: unavailabilityReason이 non-null', () {
      final context = TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: 4,
        userMessage: '아무 생각이 안 나요.',
        knowledge: const [],
      );
      final plan = const DeterministicInterventionTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(plan.planningStatus, TurnPlanningStatus.unavailable);
      expect(boundary.unavailabilityReason, isNotNull);
    });
  });

  group('Closing boundary equivalence', () {
    test('target 있음: legacy requiredAct가 boundary.allowedActions에 포함', () {
      const context = TurnPlanningContext(
        state: CounselingState.closing,
        userMessage: '오늘 발표 불안에 대해 많이 이야기한 것 같아요.',
        knowledge: [],
      );
      final plan = const DeterministicClosingTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(boundary.allowedActions, contains(plan.requiredAct));
      expect(
        builder.hasClosingSummaryTarget(_requestFrom(context)),
        isTrue,
      );
    });

    test('target 없음: legacy requiredAct가 boundary.allowedActions에 포함', () {
      const context = TurnPlanningContext(
        state: CounselingState.closing,
        userMessage: '감사합니다.',
        knowledge: [],
      );
      final plan = const DeterministicClosingTurnPlanner().plan(context)!;
      final boundary = builder.build(_requestFrom(context))!;

      expect(boundary.allowedActions, contains(plan.requiredAct));
      expect(
        builder.hasClosingSummaryTarget(_requestFrom(context)),
        isFalse,
      );
    });
  });
}
