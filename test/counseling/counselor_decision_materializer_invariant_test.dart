// Phase 9.2A.1: proves the "validator PASS -> materializer FAIL" gap
// discovered in Phase 9.2A's shadow runner tests is NOT reachable through
// any consistently-built (PolicyBoundary, PolicyBoundaryRequest) pair.
//
// Root cause (traced directly in this phase, no production code changed):
// `DeterministicPolicyBoundaryBuilder._buildInterventionBoundary` computes
// `eligibleInterventionIds` as `matchedKnowledge.map((item) => item.id)`,
// where `matchedKnowledge = request.knowledge.where(policy.accepts)`. As
// long as the SAME `request` object is used to (a) build the boundary and
// (b) later materialize the plan, `eligibleInterventionIds` is guaranteed by
// construction to be a subset of the ids present in `request.knowledge` —
// `TurnPlanMaterializer.intervention`'s `firstWhere` can never miss.
//
// The gap only manifests when a caller hand-builds a `PolicyBoundary` and a
// `PolicyBoundaryRequest` that disagree with each other (see
// `remote_counselor_shadow_runner_test.dart`'s "F. Materialization dry-run
// failure" test, which does exactly this on purpose to exercise the shadow
// runner's defensive exception handling). This file proves the invariant
// holds for every *real* (boundary, request) pair the production builder
// can produce, across representative states/scenarios — including several
// intervention types — so a decision chosen from within the boundary always
// materializes.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision_validator.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/turn_plan_adapter.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

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

void main() {
  const builder = DeterministicPolicyBoundaryBuilder();
  const validator = CounselorDecisionValidator();
  const adapter = TurnPlanAdapter();

  /// Asserts the core invariant for one (request) fixture: build the real
  /// boundary from it, construct [decision] using only ids the boundary
  /// actually allows, confirm the validator agrees, then confirm the SAME
  /// request/boundary pair materializes without throwing.
  void expectValidDecisionMaterializes(
    PolicyBoundaryRequest request,
    CounselorDecision Function(dynamic policy) makeDecision,
  ) {
    final policy = builder.build(request);
    expect(policy, isNotNull, reason: 'expected an available boundary');
    final decision = makeDecision(policy);

    final violation = validator.validate(decision: decision, policy: policy!);
    expect(violation, isNull, reason: 'decision should fit the boundary');

    expect(
      () => adapter.build(request: request, policy: policy, decision: decision),
      returnsNormally,
    );
  }

  group('CheckIn', () {
    test('explore action from boundary materializes', () {
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.checkIn,
        userMessage: '오늘은 좀 힘들었어요.',
        recentMessages: const [],
        currentWeek: 4,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: const [],
        retrievalSummary: RetrievalSummary.empty,
      );
      expectValidDecisionMaterializes(
        request,
        (policy) => CounselorDecision(
          selectedAction: policy.allowedActions.first,
          reflectionTarget: const ReflectionTarget.text('오늘은 좀 힘들었어요'),
        ),
      );
    });
  });

  group('Explore', () {
    test('boundary-allowed action materializes', () {
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.explore,
        userMessage: '발표가 걱정돼요.',
        recentMessages: const [],
        currentWeek: 4,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: const [],
        retrievalSummary: RetrievalSummary.empty,
      );
      expectValidDecisionMaterializes(
        request,
        (policy) => CounselorDecision(
          selectedAction: policy.allowedActions.first,
          reflectionTarget: const ReflectionTarget.text('발표가 걱정돼요'),
        ),
      );
    });
  });

  group('Reflect', () {
    test('each candidate goal id materializes', () {
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.reflect,
        userMessage: '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
        recentMessages: const [],
        currentWeek: 4,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: const [],
        retrievalSummary: RetrievalSummary.empty,
      );
      final policy = builder.build(request);
      expect(policy, isNotNull);
      expect(policy!.candidateGoalIds, isNotEmpty);

      // Every candidate goal id the boundary offers must materialize.
      // Deliberately `DialogueAct.socraticQuestion` (the action a goal
      // actually pairs with), not `policy.allowedActions.first` — since
      // Phase 11.3, reflect's allowedActions also contains
      // `DialogueAct.reflect` (the goal-exhaustion recovery branch, which
      // forbids a goal id), so `.first` is no longer a safe stand-in for
      // "any valid action" here.
      for (final goalId in policy.candidateGoalIds.toSet()) {
        final decision = CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedGoalId: goalId,
          reflectionTarget: const ReflectionTarget.text(
            '질문에 답을 못할까 봐 걱정돼요',
          ),
        );
        expect(
          validator.validate(decision: decision, policy: policy),
          isNull,
          reason: 'goal $goalId should be a valid choice',
        );
        expect(
          () => adapter.build(
            request: request,
            policy: policy,
            decision: decision,
          ),
          returnsNormally,
          reason: 'goal $goalId should materialize',
        );
      }
    });

    test(
      'Phase 11.3: goal-exhausted recovery decision materializes '
      '(replaces the old repeat-last-goal decision, which the boundary no '
      'longer expects a selector to make)',
      () {
        final askedAll = [
          for (final goal in DeterministicReflectTurnPlanner.goalOrder)
            CounselingMessage(
              id: 'a_${goal.name}',
              role: 'assistant',
              text: goal.question,
              createdAt: DateTime(2026, 9, 1),
              dialogueGoalId: goal.name,
            ),
        ];
        final request = PolicyBoundaryRequest(
          currentState: CounselingState.reflect,
          userMessage: '그래도 여전히 걱정돼요.',
          recentMessages: askedAll,
          currentWeek: 4,
          interventionRegistry: const ApprovedInterventionRegistry(),
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        );
        final policy = builder.build(request);
        expect(policy, isNotNull);
        expect(policy!.goalsExhausted, isTrue);

        final decision = const CounselorDecision(
          selectedAction: DialogueAct.reflect,
          goalExhaustionRecovery: GoalExhaustionRecovery.summarize,
          reflectionTarget: ReflectionTarget.text('여전히 걱정돼요'),
        );
        expect(validator.validate(decision: decision, policy: policy), isNull);
        expect(
          () =>
              adapter.build(request: request, policy: policy, decision: decision),
          returnsNormally,
        );
      },
    );
  });

  group('Intervention', () {
    test('balancedThought: selectedInterventionId from boundary materializes', () {
      final knowledge = [_cbtItem(id: 'week4_alternative_thought_01')];
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.intervention,
        userMessage: '생각을 바꾸는 게 잘 안 돼요.',
        recentMessages: const [],
        currentWeek: 4,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: knowledge,
        userContext: _diaryContext(),
        retrievalSummary: RetrievalSummary.empty,
      );
      expectValidDecisionMaterializes(
        request,
        (policy) => CounselorDecision(
          selectedAction: policy.allowedActions.first,
          selectedInterventionId: policy.eligibleInterventionIds.first,
          reflectionTarget: const ReflectionTarget.text('질문에 답을 못할 것 같다는 생각'),
        ),
      );
    });

    test('gainLossReview: selectedInterventionId from boundary materializes', () {
      final knowledge = [
        _cbtItem(
          id: 'week7_gain_lose_01',
          week: 7,
          tags: const ['habit', 'behavior', 'avoidance', 'planning'],
        ),
      ];
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.intervention,
        userMessage: '발표 자리를 피하고 싶어요.',
        recentMessages: const [],
        currentWeek: 7,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: knowledge,
        retrievalSummary: RetrievalSummary.empty,
      );
      expectValidDecisionMaterializes(
        request,
        (policy) => CounselorDecision(
          selectedAction: policy.allowedActions.first,
          selectedInterventionId: policy.eligibleInterventionIds.first,
          reflectionTarget: const ReflectionTarget.text('발표 자리를 피하고 싶다는 생각'),
        ),
      );
    });

    test('unavailable week policy: isUnavailable decision needs no materialization', () {
      final request = PolicyBoundaryRequest(
        currentState: CounselingState.intervention,
        userMessage: '아무거나요.',
        recentMessages: const [],
        currentWeek: 99,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: const [],
        retrievalSummary: RetrievalSummary.empty,
      );
      final policy = builder.build(request);
      expect(policy, isNotNull);
      expect(policy!.isAvailable, isFalse);
      expect(policy.eligibleInterventionIds, isEmpty);

      const decision = CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        isUnavailable: true,
      );
      expect(validator.validate(decision: decision, policy: policy), isNull);
    });
  });

  group('Closing', () {
    test('closing action materializes with and without a summary target', () {
      for (final message in ['발표 준비에 대해 이야기했어요.', '네.']) {
        final request = PolicyBoundaryRequest(
          currentState: CounselingState.closing,
          userMessage: message,
          recentMessages: const [],
          currentWeek: 4,
          interventionRegistry: const ApprovedInterventionRegistry(),
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        );
        expectValidDecisionMaterializes(
          request,
          (policy) => CounselorDecision(
            selectedAction: policy.allowedActions.first,
            reflectionTarget:
                policy.hasClosingSummaryTarget
                    ? ReflectionTarget.text(message)
                    : const ReflectionTarget.none(),
          ),
        );
      }
    });
  });
}
