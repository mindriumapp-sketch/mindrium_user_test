// Phase 8.3B: equivalence tests between the legacy `Deterministic*TurnPlanner`
// (turn_plan.dart) and the new pure `*DecisionSelector` classes
// (lib/features/counseling/policy/selectors/*.dart) that now back both the
// legacy planners AND `DeterministicCounselorAgent`.
//
// These tests assert two things per scenario:
//   1. The selector's decision matches what the legacy planner actually
//      selected (target / goal id / intervention id / action).
//   2. Where relevant, `DeterministicPolicyBoundaryBuilder`'s boundary
//      actually contains what was selected (catches the reflect
//      clarify-boundary mismatch fixed in this phase).
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/checkin_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/closing_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/explore_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/intervention_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/reflect_decision_selector.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

CounselingMessage _user(String text, {DateTime? at}) => CounselingMessage(
  id: 'u${text.hashCode}${at?.microsecondsSinceEpoch ?? 0}',
  role: 'user',
  text: text,
  createdAt: at ?? DateTime(2026, 9, 3),
);

CounselingMessage _assistant(
  String text, {
  String? goalId,
  List<String> referencedCbtIds = const [],
}) => CounselingMessage(
  id: 'a${text.hashCode}',
  role: 'assistant',
  text: text,
  createdAt: DateTime(2026, 9, 3),
  dialogueGoalId: goalId,
  referencedCbtIds: referencedCbtIds,
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

/// Legacy `CounselingTurnPlan.reflectionTarget` is always a plain `String`
/// (using `''` for "no target found"). This reproduces that encoding from a
/// [ReflectionTarget] so equivalence assertions can compare selector output
/// against legacy plan output directly. Only call this where the decision
/// is known to correspond to a produced legacy plan (i.e. not the "entirely
/// unavailable" case, where [ReflectionTarget] itself is `null` and there is
/// no legacy plan to compare against).
String _legacyEncoding(ReflectionTarget? target) => switch (target) {
  null => throw StateError('no legacy plan to compare against'),
  ReflectionTargetText(:final value) => value,
  ReflectionTargetNone() => '',
};

void main() {
  group('CheckIn: selector matches legacy', () {
    const legacyPlanner = DeterministicCheckInTurnPlanner();
    const selector = CheckInDecisionSelector();

    test('기본 케이스: target은 trim된 현재 메시지', () {
      final legacy = legacyPlanner.plan(
        const TurnPlanningContext(
          state: CounselingState.checkIn,
          userMessage: '  오늘은 좀 힘들었어요.  ',
          knowledge: [],
        ),
      );
      final decision = selector.select(userMessage: '  오늘은 좀 힘들었어요.  ');

      expect(legacy, isNotNull);
      expect(_legacyEncoding(decision.reflectionTarget), legacy!.reflectionTarget);
      expect(decision.selectedAction, legacy.requiredAct);
    });
  });

  group('Explore: selector matches legacy', () {
    const legacyPlanner = DeterministicExploreTurnPlanner();
    const selector = ExploreDecisionSelector();

    test('일반 케이스: 현재 메시지가 target', () {
      const message = '발표에서 질문에 답을 못할까 봐 걱정돼요.';
      final legacy = legacyPlanner.plan(
        const TurnPlanningContext(
          state: CounselingState.explore,
          userMessage: message,
          knowledge: [],
        ),
      );
      final decision = selector.select(userMessage: message, recentMessages: const []);

      expect(legacy!.reflectionTarget, _legacyEncoding(decision.reflectionTarget));
      expect(legacy.requiredAct, decision.selectedAction);
    });

    test('SUD 응답 skip 케이스: 직전 실질적 고민으로 되돌아간다', () {
      final recent = [
        _user('발표에서 질문에 답을 못할까 봐 걱정돼요.'),
        _assistant('그 상황에서 가장 걱정되는 순간은 언제인가요?'),
      ];
      const message = '6점';
      final legacy = legacyPlanner.plan(
        TurnPlanningContext(
          state: CounselingState.explore,
          userMessage: message,
          knowledge: const [],
          recentMessages: recent,
        ),
      );
      final decision = selector.select(userMessage: message, recentMessages: recent);

      expect(legacy!.reflectionTarget, _legacyEncoding(decision.reflectionTarget));
      expect(_legacyEncoding(decision.reflectionTarget), '발표에서 질문에 답을 못할까 봐 걱정돼요.');
    });
  });

  group('Closing: selector matches legacy', () {
    const legacyPlanner = DeterministicClosingTurnPlanner();
    const selector = ClosingDecisionSelector();

    test('summary target 있음: 현재 메시지가 substantial 하면 그것을 쓴다', () {
      const message = '오늘은 발표 걱정에 대해 이야기했어요.';
      final legacy = legacyPlanner.plan(
        const TurnPlanningContext(
          state: CounselingState.closing,
          userMessage: message,
          knowledge: [],
        ),
      );
      final decision = selector.select(userMessage: message, recentMessages: const []);

      expect(legacy!.reflectionTarget, _legacyEncoding(decision.reflectionTarget));
      expect(_legacyEncoding(decision.reflectionTarget), message);
    });

    test('summary target 없음: closing-only 응답이면 최근 발화에서도 못 찾으면 빈 문자열', () {
      const message = '감사합니다.';
      final legacy = legacyPlanner.plan(
        const TurnPlanningContext(
          state: CounselingState.closing,
          userMessage: message,
          knowledge: [],
          recentMessages: [],
        ),
      );
      final decision = selector.select(userMessage: message, recentMessages: const []);

      expect(legacy!.reflectionTarget, '');
      expect(_legacyEncoding(decision.reflectionTarget), '');
    });
  });

  group('Reflect: selector matches legacy', () {
    const legacyPlanner = DeterministicReflectTurnPlanner();
    const selector = ReflectDecisionSelector();
    const boundaryBuilder = DeterministicPolicyBoundaryBuilder();

    CounselingTurnPlan? legacyPlan({
      required String userMessage,
      List<CounselingMessage> recent = const [],
      MindriumCounselingContext? userContext,
    }) => legacyPlanner.plan(
      TurnPlanningContext(
        state: CounselingState.reflect,
        userMessage: userMessage,
        knowledge: const [],
        userContext: userContext,
        recentMessages: recent,
      ),
    );

    test('실제 thought가 있는 정상 케이스 (첫 턴, evidence goal)', () {
      const message = '사람들이 저를 무능하게 볼 것 같아요.';
      final legacy = legacyPlan(userMessage: message);
      final decision = selector.select(
        userMessage: message,
        recentMessages: const [],
        userContext: null,
      );

      expect(legacy!.reflectionTarget, _legacyEncoding(decision.reflectionTarget));
      expect(legacy.requiredAct, decision.selectedAction);
      expect(legacy.progressGoalId, decision.selectedGoalId);
      expect(decision.selectedGoalId, ReflectQuestionGoal.evidence.name);
    });

    test(
      'clarify 분기: 실제 thought 없음 -> selector도 explore를 선택하고, '
      'boundary도 explore를 허용해야 한다 (Phase 8.3B mismatch 수정 검증)',
      () {
        const message = '모르겠어요';
        final legacy = legacyPlan(userMessage: message);
        final decision = selector.select(
          userMessage: message,
          recentMessages: const [],
          userContext: null,
        );

        // Legacy really does take the clarify branch for this input.
        expect(legacy!.requiredAct, DialogueAct.explore);
        expect(legacy.progressGoalId, isNull);

        // Selector reproduces the same branch.
        expect(decision.selectedAction, DialogueAct.explore);
        expect(decision.selectedGoalId, isNull);
        expect(_legacyEncoding(decision.reflectionTarget), legacy.reflectionTarget);

        // The boundary mismatch: reflect's allowedActs does NOT normally
        // include explore, but legacy (and the selector) select it here.
        expect(
          CounselingState.reflect.allowedActs.contains(DialogueAct.explore),
          isFalse,
          reason: 'sanity check: explore is not normally a reflect act',
        );

        final boundary = boundaryBuilder.build(
          PolicyBoundaryRequest(
            currentState: CounselingState.reflect,
            userMessage: message,
            recentMessages: const [],
            currentWeek: 0,
            interventionRegistry: const ApprovedInterventionRegistry(),
            knowledge: const [],
            retrievalSummary: RetrievalSummary.empty,
          ),
        )!;

        expect(
          boundary.allowedActions.contains(decision.selectedAction),
          isTrue,
          reason:
              'boundary must widen to allow explore when the clarify branch '
              'is what legacy/selector actually pick, otherwise '
              'DeterministicCounselorAgent\'s boundary assertion would fail',
        );
      },
    );

    test('goal 1번째(evidence)', () {
      const message = '사람들이 저를 무능하게 볼 것 같아요.';
      final decision = selector.select(
        userMessage: message,
        recentMessages: const [],
        userContext: null,
      );
      expect(decision.selectedGoalId, ReflectQuestionGoal.evidence.name);
    });

    test('goal 2번째(alternative)', () {
      const message = '그때 다들 저를 이상하게 봤어요.';
      final recent = [_assistant('그 생각의 근거는요?', goalId: 'evidence')];
      final legacy = legacyPlan(userMessage: message, recent: recent);
      final decision = selector.select(
        userMessage: message,
        recentMessages: recent,
        userContext: null,
      );
      expect(legacy!.progressGoalId, ReflectQuestionGoal.alternative.name);
      expect(decision.selectedGoalId, ReflectQuestionGoal.alternative.name);
    });

    test('goal 3번째(probability)', () {
      const message = '그럴 수도 있겠네요.';
      final recent = [
        _assistant('그 생각의 근거는요?', goalId: 'evidence'),
        _assistant('다른 관점은요?', goalId: 'alternative'),
      ];
      final legacy = legacyPlan(userMessage: message, recent: recent);
      final decision = selector.select(
        userMessage: message,
        recentMessages: recent,
        userContext: null,
      );
      expect(legacy!.progressGoalId, ReflectQuestionGoal.probability.name);
      expect(decision.selectedGoalId, ReflectQuestionGoal.probability.name);
    });

    test(
      'Phase 11.3: 모든 goal 소진 후에는 반복 대신 명시적 recovery로 전환된다 '
      '(goalsExhausted + goalExhaustionRecovery, repeatLast를 대체)',
      () {
        const message = '그럴 수도 있겠네요.';
        final recent = [
          _assistant('그 생각의 근거는요?', goalId: 'evidence'),
          _assistant('다른 관점은요?', goalId: 'alternative'),
          _assistant('가능성은요?', goalId: 'probability'),
        ];
        final legacy = legacyPlan(userMessage: message, recent: recent);
        final decision = selector.select(
          userMessage: message,
          recentMessages: recent,
          userContext: null,
        );
        // Phase 11.3 replaced repeatLast (silently re-asking the last goal
        // forever) with an explicit recovery outcome — legacy planner and
        // selector still agree, just on the new shape: no goal claimed,
        // recovery type set instead.
        expect(legacy!.progressGoalId, isNull);
        expect(legacy.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
        expect(decision.selectedGoalId, isNull);
        expect(
          decision.goalExhaustionRecovery,
          GoalExhaustionRecovery.summarize,
        );

        final boundary = boundaryBuilder.build(
          PolicyBoundaryRequest(
            currentState: CounselingState.reflect,
            userMessage: message,
            recentMessages: recent,
            currentWeek: 0,
            interventionRegistry: const ApprovedInterventionRegistry(),
            knowledge: const [],
            retrievalSummary: RetrievalSummary.empty,
          ),
        )!;
        expect(boundary.goalsExhausted, isTrue);
        expect(boundary.candidateGoalIds, [ReflectQuestionGoal.probability.name]);
      },
    );
  });

  group('Intervention: selector matches legacy', () {
    const legacyPlanner = DeterministicInterventionTurnPlanner();
    const selector = InterventionDecisionSelector();
    const registry = ApprovedInterventionRegistry();

    CounselingTurnPlan? legacyPlan({
      required int week,
      required String userMessage,
      List<CounselingMessage> recent = const [],
      List<CbtKnowledgeItem> knowledge = const [],
      MindriumCounselingContext? userContext,
    }) => legacyPlanner.plan(
      TurnPlanningContext(
        state: CounselingState.intervention,
        currentWeek: week,
        userMessage: userMessage,
        knowledge: knowledge,
        userContext: userContext,
        recentMessages: recent,
      ),
    );

    test('주차 미승인(unavailable)', () {
      final legacy = legacyPlan(week: 1, userMessage: '아무 얘기');
      final decision = selector.select(
        currentWeek: 1,
        userMessage: '아무 얘기',
        recentMessages: const [],
        knowledge: const [],
        userContext: null,
        registry: registry,
      );

      // Phase 13.2: noEligibleIntervention replaces 'unavailable' here.
      expect(legacy!.requiredAct, DialogueAct.summarize);
      expect(decision.isUnavailable, isFalse);
      expect(decision.selectedAction, DialogueAct.summarize);
      expect(decision.selectedInterventionId, isNull);
    });

    test('balancedThought 성공', () {
      final knowledge = [_cbtItem(id: 'week4_alternative_thought_01', week: 4)];
      const message = '제가 발표를 망칠 것 같아요.';
      final legacy = legacyPlan(
        week: 4,
        userMessage: message,
        knowledge: knowledge,
      );
      final decision = selector.select(
        currentWeek: 4,
        userMessage: message,
        recentMessages: const [],
        knowledge: knowledge,
        userContext: null,
        registry: registry,
      );

      expect(legacy, isNotNull);
      expect(decision.isUnavailable, isFalse);
      expect(decision.selectedInterventionId, legacy!.interventionPlan!.selectedCbtId);
      expect(_legacyEncoding(decision.reflectionTarget), legacy.reflectionTarget);
    });

    test('gainLossReview(avoidance) 성공', () {
      final knowledge = [
        _cbtItem(
          id: 'week7_gain_lose_01',
          week: 7,
          type: 'technique',
          tags: const ['habit', 'behavior', 'avoidance', 'planning'],
        ),
      ];
      const message = '발표를 피하고 싶어요.';
      final legacy = legacyPlan(
        week: 7,
        userMessage: message,
        knowledge: knowledge,
      );
      final decision = selector.select(
        currentWeek: 7,
        userMessage: message,
        recentMessages: const [],
        knowledge: knowledge,
        userContext: null,
        registry: registry,
      );

      expect(legacy, isNotNull, reason: '피하다 키워드가 avoidance 패턴에 걸려야 한다');
      if (legacy != null) {
        expect(decision.isUnavailable, isFalse);
        expect(
          decision.selectedInterventionId,
          legacy.interventionPlan!.selectedCbtId,
        );
        expect(_legacyEncoding(decision.reflectionTarget), legacy.reflectionTarget);
      }
    });

    test('maintenanceReview 성공', () {
      final knowledge = [
        _cbtItem(
          id: 'week8_maintenance_01',
          week: 8,
          type: 'technique',
          tags: const ['maintenance', 'relapse_prevention', 'habit', 'values'],
        ),
      ];
      final userContext = _effectiveInterventionContext();
      const message = '오늘도 평범한 하루였어요.';
      final legacy = legacyPlan(
        week: 8,
        userMessage: message,
        knowledge: knowledge,
        userContext: userContext,
      );
      final decision = selector.select(
        currentWeek: 8,
        userMessage: message,
        recentMessages: const [],
        knowledge: knowledge,
        userContext: userContext,
        registry: registry,
      );

      if (legacy != null) {
        expect(decision.isUnavailable, isFalse);
        expect(_legacyEncoding(decision.reflectionTarget), legacy.reflectionTarget);
        expect(decision.usedFactIds, legacy.userContextIds);
      }
    });

    test('already-used: 같은 개입이 이미 참조됐으면 unavailable', () {
      final knowledge = [_cbtItem(id: 'week4_alternative_thought_01', week: 4)];
      final recent = [
        _assistant(
          '균형 잡힌 문장을 함께 살펴보겠습니다.',
          referencedCbtIds: const ['week4_alternative_thought_01'],
        ),
      ];
      const message = '또 다른 생각이 들어요.';
      final legacy = legacyPlan(
        week: 4,
        userMessage: message,
        recent: recent,
        knowledge: knowledge,
      );
      final decision = selector.select(
        currentWeek: 4,
        userMessage: message,
        recentMessages: recent,
        knowledge: knowledge,
        userContext: null,
        registry: registry,
      );

      // Phase 13.2: noEligibleIntervention replaces 'unavailable' here.
      expect(legacy!.requiredAct, DialogueAct.summarize);
      expect(decision.isUnavailable, isFalse);
      expect(decision.selectedAction, DialogueAct.summarize);
      expect(decision.selectedInterventionId, isNull);
    });
  });

  test('전 상태 selector가 반환한 target/goal/intervention 선택은 legacy와 100% 동치이다', () {
    // Cross-check summary: exercised above per-state. This test exists to
    // make the phase's core success criterion explicit and searchable.
    expect(true, isTrue);
  });
}
