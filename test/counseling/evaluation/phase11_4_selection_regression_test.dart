// Phase 11.4 — Frozen Scenario Evaluation (selection regression, not an
// LLM-wording evaluation). See docs/counseling/phase11_4_selection_regression.md.
//
// Runs the full frozen_v1 corpus (phase9_2b_frozen_v1, 89 scenarios, all
// five states) through the real production entry point
// (`PolicyPipelineTurnPlanner` — Hard Guard + boundary/agent/validator/
// adapter, exactly what `CounselingHarness` calls) and asserts the four
// zero-tolerance metrics frozen in Phase 11.1:
//
//   A. same-goal-repeated == 0 and unauthorized-state-jump == 0
//      (per scenario, all 89)
//   B. meta-feedback-ignored == 0
//      (interaction-repair phrasings x every state the Hard Guard covers)
//   C. CBT/safety regression == 0
//      (validator/materializer agreement — Phase 9.2D's own definition of
//      a regression for this pipeline — per scenario, all 89)
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision_validator.dart';
import 'package:gad_app_team/features/counseling/policy/deterministic_counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/frozen_scenarios.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/scenario_fixture.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/policy/turn_plan_adapter.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

TurnPlanningContext _contextFor(PolicyBoundaryRequest request) =>
    TurnPlanningContext(
      state: request.currentState,
      currentWeek: request.currentWeek,
      userMessage: request.userMessage,
      knowledge: request.knowledge,
      userContext: request.userContext,
      recentMessages: request.recentMessages,
      retrievalSummary: request.retrievalSummary,
    );

CounselingTurnPlan? _plan(PolicyBoundaryRequest request) =>
    PolicyPipelineTurnPlanner(
      interventionRegistry: request.interventionRegistry,
    ).plan(_contextFor(request));

Set<String> _askedGoalIds(List<CounselingMessage> messages) =>
    messages
        .where((m) => !m.isUser)
        .map((m) => m.dialogueGoalId)
        .whereType<String>()
        .toSet();

const _allGoals = {'evidence', 'alternative', 'probability'};

/// Mirrors `CounselingStatePolicy._acceleratesFrom` (private): the one act,
/// per state, that advances state early instead of on the turn budget.
DialogueAct? _acceleratingAct(CounselingState state) => switch (state) {
  CounselingState.explore => DialogueAct.reflect,
  CounselingState.reflect => DialogueAct.summarize,
  CounselingState.checkIn ||
  CounselingState.intervention ||
  CounselingState.closing => null,
};

void _expectNoUnauthorizedJump(
  CounselingState state,
  CounselingTurnPlan plan,
  String label,
) {
  final isRepairOrRecovery =
      plan.goalExhaustionRecovery != null ||
      plan.interactionRepairReason != null;
  if (!isRepairOrRecovery) return;
  final forbidden = _acceleratingAct(state);
  if (forbidden == null) return;
  expect(
    plan.requiredAct,
    isNot(forbidden),
    reason:
        '$label: repair/recovery turn uses $forbidden, which would '
        'accelerate $state early via CounselingStatePolicy._acceleratesFrom',
  );
}

void main() {
  test('corpus is the frozen 89-scenario, all-state set', () {
    expect(frozenScenariosVersion, 'phase9_2b_frozen_v1');
    expect(frozenScenarios, hasLength(89));
    expect(
      frozenScenarios.map((f) => f.request.currentState).toSet(),
      CounselingState.values.toSet(),
    );
  });

  group('A. same-goal-repeated == 0 / unauthorized-state-jump == 0', () {
    for (final ScenarioFixture fixture in frozenScenarios) {
      test(fixture.id, () {
        final request = fixture.request;
        final plan = _plan(request);
        if (plan == null) return;

        if (request.currentState == CounselingState.reflect) {
          final asked = _askedGoalIds(request.recentMessages);
          if (plan.progressGoalId != null) {
            expect(
              asked,
              isNot(contains(plan.progressGoalId)),
              reason: '${fixture.id}: re-selected already-asked goal',
            );
          }
          if (_allGoals.every(asked.contains)) {
            expect(plan.progressGoalId, isNull, reason: fixture.id);
            expect(plan.goalExhaustionRecovery, isNotNull, reason: fixture.id);
            expect(plan.questionSentence, isEmpty, reason: fixture.id);
          }
        }

        _expectNoUnauthorizedJump(request.currentState, plan, fixture.id);
      });
    }
  });

  group('B. meta-feedback-ignored == 0', () {
    const phrasings = {
      InteractionRepairReason.repeatedQuestion: [
        '왜 똑같은 말을 반복하지?',
        '왜 같은 질문을 계속 해요?',
        '아까도 물어봤잖아요.',
        '방금도 그 질문 했는데요.',
        '또 같은 걸 물어보네요.',
        '아까 말한 거랑 똑같잖아요.',
        '왜 계속 비슷한 질문만 해요?',
        '그 얘기 방금도 했어요.',
      ],
      InteractionRepairReason.stopQuestioning: [
        '질문 그만하고 그냥 들어주세요.',
      ],
      InteractionRepairReason.processFrustration: [
        '이런 거 한다고 뭐가 달라질까 싶어요.',
      ],
    };
    // Closing is excluded by DeterministicProcessSignalTurnPlanner itself.
    const states = [
      CounselingState.checkIn,
      CounselingState.explore,
      CounselingState.reflect,
      CounselingState.intervention,
    ];

    for (final state in states) {
      for (final entry in phrasings.entries) {
        for (final message in entry.value) {
          test('${state.name}: "$message"', () {
            final request = PolicyBoundaryRequest(
              currentState: state,
              userMessage: message,
              recentMessages: const [],
              currentWeek: 4,
              interventionRegistry: const ApprovedInterventionRegistry(),
              knowledge: const [],
              retrievalSummary: RetrievalSummary.empty,
            );
            final plan = _plan(request);
            expect(plan, isNotNull);
            expect(plan!.interactionRepairReason, entry.key);
            expect(plan.questionSentence, isEmpty);
            expect(plan.cbtContextIds, isEmpty);
            _expectNoUnauthorizedJump(state, plan, '$state/$message');
          });
        }
      }
    }
  });

  group('C. CBT/safety regression == 0 (validator/materializer agreement)', () {
    const boundaryBuilder = DeterministicPolicyBoundaryBuilder();
    const agent = DeterministicCounselorAgent();
    const validator = CounselorDecisionValidator();
    const adapter = TurnPlanAdapter();

    for (final ScenarioFixture fixture in frozenScenarios) {
      test(fixture.id, () {
        final policy = boundaryBuilder.build(fixture.request);
        if (policy == null) return;
        final decision = agent.decide(context: fixture.request, policy: policy);
        expect(
          validator.validate(decision: decision, policy: policy),
          isNull,
          reason: '${fixture.id}: deterministic decision rejected',
        );
        final plan = adapter.build(
          request: fixture.request,
          policy: policy,
          decision: decision,
        );
        if (plan == null) return;
        expect(
          plan.cbtContextIds.toSet().difference(
            policy.eligibleInterventionIds.toSet(),
          ),
          isEmpty,
          reason: '${fixture.id}: plan cites CBT outside the eligible set',
        );
        if (fixture.request.currentState != CounselingState.intervention) {
          expect(
            plan.interventionPlan,
            isNull,
            reason: '${fixture.id}: intervention outside intervention state',
          );
        }
      });
    }
  });
}
