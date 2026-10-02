// Phase 8.4B: causal-wiring tests.
//
// Phase 8.4 wired `PolicyBoundaryBuilder -> CounselorAgent -> TurnPlanAdapter`
// together, but `PolicyPipelineTurnPlanner.plan()` discarded the agent's
// `CounselorDecision` and re-derived the plan from the legacy per-state
// planner instead — the agent's decision had zero causal effect on the
// actual production `CounselingTurnPlan`. Phase 8.4B fixes this.
//
// This file proves the fix the only way that actually matters: by injecting
// a `FakeCounselorAgent` that picks something DIFFERENT from what the
// deterministic selectors would pick (but still allowed by the independently
// computed `PolicyBoundary`) and asserting the real production
// `PolicyPipelineTurnPlanner.plan()` output reflects that choice.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision_validator.dart';
import 'package:gad_app_team/features/counseling/policy/deterministic_counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
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

/// A [CounselorAgent] that returns a fixed [CounselorDecision] for one
/// state and delegates everything else to a real [DeterministicCounselorAgent]
/// (so Hard Guard / other-state behavior in the same pipeline is untouched).
class FakeCounselorAgent implements CounselorAgent {
  final CounselingState forState;
  final CounselorDecision decision;
  final DeterministicCounselorAgent _fallback =
      const DeterministicCounselorAgent();

  FakeCounselorAgent({required this.forState, required this.decision});

  @override
  CounselorDecision decide({
    required PolicyBoundaryRequest context,
    required PolicyBoundary policy,
  }) {
    if (context.currentState == forState) return decision;
    return _fallback.decide(context: context, policy: policy);
  }
}

void main() {
  group('Causality: Reflect goal selection', () {
    test(
      'FakeAgent가 다른(허용된) selectedGoalId를 고르면 실제 production TurnPlan이 그 goal을 반영한다',
      () {
        const context = TurnPlanningContext(
          state: CounselingState.reflect,
          currentWeek: 3,
          userMessage: '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
          knowledge: [],
        );

        // Sanity check: without the fake agent, the deterministic pipeline
        // picks `evidence` (first unasked goal) — this is the baseline the
        // fake agent's choice must differ from.
        const baselinePlanner = PolicyPipelineTurnPlanner();
        final baseline = baselinePlanner.plan(context);
        expect(baseline, isNotNull);
        expect(baseline!.progressGoalId, ReflectQuestionGoal.evidence.name);

        // `alternative` is still a member of `policy.candidateGoalIds` for a
        // first reflect turn (all three goals are candidates), so this is a
        // boundary-legal choice the deterministic selector just wouldn't
        // have made on its own.
        const fakeTarget = '질문에 제대로 답하지 못할 것 같다는 생각';
        final fakeDecision = const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedGoalId: 'alternative',
          reflectionTarget: ReflectionTarget.text(fakeTarget),
        );
        final planner = PolicyPipelineTurnPlanner(
          counselorAgent: FakeCounselorAgent(
            forState: CounselingState.reflect,
            decision: fakeDecision,
          ),
        );

        final plan = planner.plan(context);

        expect(plan, isNotNull);
        // The causal chain: FakeAgent.selectedGoalId -> plan.progressGoalId
        // and plan.questionSentence, both for `alternative`, not `evidence`.
        expect(plan!.progressGoalId, 'alternative');
        expect(plan.progressGoalId, isNot(baseline.progressGoalId));
        expect(plan.questionSentence, ReflectQuestionGoal.alternative.question);
        expect(plan.questionSentence, isNot(baseline.questionSentence));
        // The reflection target the fake decision provided also flows
        // through, not the target the deterministic selector would compute.
        expect(plan.reflectionTarget, fakeTarget);
      },
    );
  });

  group('Causality: Intervention target selection', () {
    test(
      'FakeAgent가 다른(허용된) reflectionTarget/interventionId를 고르면 실제 production TurnPlan이 이를 반영한다',
      () {
        final knowledge = [_cbtItem(id: 'week4_alternative_thought_01')];
        // Phase 14.3: a technique needs the round's worry thought to apply
        // to (without one it wraps up instead), so the round states one.
        final context = TurnPlanningContext(
          state: CounselingState.intervention,
          currentWeek: 4,
          userMessage: '생각을 바꾸는 게 잘 안 돼요.',
          knowledge: knowledge,
          recentMessages: [
            CounselingMessage(
              id: 'u0', role: 'user', text: '발표하다가 말이 막히면 어떡하지', createdAt: DateTime(2026),
            ),
          ],
        );

        const baselinePlanner = PolicyPipelineTurnPlanner();
        final baseline = baselinePlanner.plan(context);
        expect(baseline, isNotNull);
        expect(baseline!.interventionPlan, isNotNull);

        // The only eligible intervention id this week is
        // week4_alternative_thought_01 — that part of the selection space is
        // a singleton, so causality is demonstrated here via the
        // reflectionTarget the fake decision supplies instead (still the
        // authoritative input the materializer must use verbatim, and still
        // a legal choice: any non-empty target is representable).
        const fakeTarget = '발표에서 완전히 실패할 것 같다는 생각';
        final fakeDecision = const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedInterventionId: 'week4_alternative_thought_01',
          reflectionTarget: ReflectionTarget.text(fakeTarget),
        );
        final planner = PolicyPipelineTurnPlanner(
          counselorAgent: FakeCounselorAgent(
            forState: CounselingState.intervention,
            decision: fakeDecision,
          ),
        );

        final plan = planner.plan(context);

        expect(plan, isNotNull);
        expect(plan!.reflectionTarget, fakeTarget);
        expect(plan.reflectionTarget, isNot(baseline.reflectionTarget));
        expect(plan.interventionPlan, isNotNull);
        expect(plan.interventionPlan!.target, fakeTarget);
        expect(
          plan.reflectionSentence,
          isNot(baseline.reflectionSentence),
          reason: 'reflection sentence is built from the (now different) target',
        );
      },
    );
  });

  group('Invalid decision detection (release-safe validation)', () {
    test('policy.allowedActions 밖의 action은 validator가 감지한다', () {
      const boundary = PolicyBoundary(
        currentState: CounselingState.checkIn,
        allowedActions: [DialogueAct.explore],
        candidateGoalIds: [],
        eligibleInterventionIds: [],
        allowedFactIds: [],
        forbiddenConstraints: [],
        progressInfo: DialogueProgressInfo(
          askedGoalIds: {},
          usedInterventionIds: {},
          recentUserThoughts: [],
          conversationTopics: {},
          isFirstReflectTurn: true,
        ),
      );
      const badDecision = CounselorDecision(
        selectedAction: DialogueAct.closing, // not allowed for checkIn
        reflectionTarget: ReflectionTarget.text('아무 말'),
      );

      const validator = CounselorDecisionValidator();
      final violation = validator.validate(
        decision: badDecision,
        policy: boundary,
      );
      expect(violation, isNotNull);
      expect(validator.isValid(decision: badDecision, policy: boundary), isFalse);
    });

    test('policy.eligibleInterventionIds 밖의 intervention은 validator가 감지한다', () {
      const boundary = PolicyBoundary(
        currentState: CounselingState.intervention,
        allowedActions: [DialogueAct.socraticQuestion],
        candidateGoalIds: [],
        eligibleInterventionIds: ['week4_alternative_thought_01'],
        allowedFactIds: [],
        forbiddenConstraints: [],
        progressInfo: DialogueProgressInfo(
          askedGoalIds: {},
          usedInterventionIds: {},
          recentUserThoughts: [],
          conversationTopics: {},
          isFirstReflectTurn: true,
        ),
      );
      const badDecision = CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        selectedInterventionId: 'not_an_eligible_id',
        reflectionTarget: ReflectionTarget.text('아무 말'),
      );

      const validator = CounselorDecisionValidator();
      expect(
        validator.validate(decision: badDecision, policy: boundary),
        isNotNull,
      );
    });

    test('policy.candidateGoalIds 밖의 goal은 validator가 감지한다', () {
      const boundary = PolicyBoundary(
        currentState: CounselingState.reflect,
        allowedActions: [DialogueAct.socraticQuestion],
        candidateGoalIds: ['evidence'],
        eligibleInterventionIds: [],
        allowedFactIds: [],
        forbiddenConstraints: [],
        progressInfo: DialogueProgressInfo(
          askedGoalIds: {},
          usedInterventionIds: {},
          recentUserThoughts: [],
          conversationTopics: {},
          isFirstReflectTurn: true,
        ),
      );
      const badDecision = CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        selectedGoalId: 'probability', // not a candidate this turn
        reflectionTarget: ReflectionTarget.text('아무 말'),
      );

      const validator = CounselorDecisionValidator();
      expect(
        validator.validate(decision: badDecision, policy: boundary),
        isNotNull,
      );
    });

    test(
      'production pipeline은 invalid decision을 감지하면 deterministic fallback으로 대체한다',
      () {
        const context = TurnPlanningContext(
          state: CounselingState.checkIn,
          userMessage: '오늘은 좀 힘들었어요.',
          knowledge: [],
        );

        // Returns an out-of-boundary action for checkIn no matter what.
        final invalidAgent = _AlwaysInvalidAgent();
        final planner = PolicyPipelineTurnPlanner(counselorAgent: invalidAgent);

        // Must not throw, and must still produce the deterministic plan
        // (fallback), not a plan built from the invalid decision.
        final plan = planner.plan(context);
        const fallbackPlanner = PolicyPipelineTurnPlanner();
        final fallbackPlan = fallbackPlanner.plan(context);

        expect(plan, isNotNull);
        expect(plan!.requiredAct, fallbackPlan!.requiredAct);
        expect(plan.reflectionTarget, fallbackPlan.reflectionTarget);
      },
    );
  });
}

class _AlwaysInvalidAgent implements CounselorAgent {
  @override
  CounselorDecision decide({
    required PolicyBoundaryRequest context,
    required PolicyBoundary policy,
  }) {
    // `closing` is never in checkIn's allowedActions.
    return const CounselorDecision(
      selectedAction: DialogueAct.closing,
      reflectionTarget: ReflectionTarget.text('아무 말'),
    );
  }
}
