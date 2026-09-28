// Phase 9.2D: decision-space invariant tests — table-driven over
// state x action x (goal shape) x (reflectionTarget shape) x (intervention
// shape). This is stronger than Phase 9.2A.1's invariant test, which only
// checked decisions the deterministic selectors actually produce (a narrow
// manifold). A real RemoteCounselorAgent evaluation run
// (phase9_2b_frozen_v1 / decide_v1) found combinations outside that
// manifold that passed the old validator and crashed materialization —
// this file locks down the fix: for every meaningful combination,
// CounselorDecisionValidator's verdict must agree with whether
// TurnPlanAdapter.build actually succeeds.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision_validator.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/turn_plan_adapter.dart';

void main() {
  const validator = CounselorDecisionValidator();
  const turnPlanAdapter = TurnPlanAdapter();

  /// Asserts the core invariant: validator's verdict on [decision] against
  /// [policy] must agree with whether materialization actually succeeds —
  /// in either direction. A "false accept" (validator says fine, adapter
  /// throws) is exactly the Phase 9.2D bug; a spurious "false reject"
  /// (validator too strict for something the adapter could handle) would
  /// also be a bug, just a safer-looking one.
  void expectAgreement({
    required String label,
    required PolicyBoundaryRequest request,
    required PolicyBoundary policy,
    required CounselorDecision decision,
    required bool expectValid,
  }) {
    final violation = validator.validate(decision: decision, policy: policy);
    final validatorSaysValid = violation == null;
    expect(
      validatorSaysValid,
      expectValid,
      reason: '$label: expected validator valid=$expectValid, got '
          'violation=$violation',
    );

    if (!validatorSaysValid) return; // adapter behavior irrelevant if rejected

    expect(
      () => turnPlanAdapter.build(
        request: request,
        policy: policy,
        decision: decision,
      ),
      returnsNormally,
      reason: '$label: validator accepted this decision, so materialization '
          'must not throw',
    );
  }

  group('CheckIn', () {
    final request = PolicyBoundaryRequest(
      currentState: CounselingState.checkIn,
      userMessage: '오늘은 좀 힘들었어요.',
      recentMessages: const [],
      currentWeek: 4,
      interventionRegistry: const ApprovedInterventionRegistry(),
      knowledge: const [],
      retrievalSummary: RetrievalSummary.empty,
    );
    final policy = const DeterministicPolicyBoundaryBuilder().build(request)!;

    test('text reflectionTarget -> valid', () {
      expectAgreement(
        label: 'checkIn text',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('오늘은 좀 힘들었어요'),
        ),
        expectValid: true,
      );
    });

    test('None reflectionTarget -> invalid (checkIn requires text)', () {
      expectAgreement(
        label: 'checkIn none',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.none(),
        ),
        expectValid: false,
      );
    });

    test('non-null goal -> invalid (checkIn forbids goal)', () {
      expectAgreement(
        label: 'checkIn with goal',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.explore,
          selectedGoalId: 'evidence',
          reflectionTarget: ReflectionTarget.text('오늘은 좀 힘들었어요'),
        ),
        expectValid: false,
      );
    });

    test('out-of-boundary action -> invalid', () {
      expectAgreement(
        label: 'checkIn wrong action',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.closing,
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: false,
      );
    });
  });

  group('Reflect', () {
    final request = PolicyBoundaryRequest(
      currentState: CounselingState.reflect,
      userMessage: '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
      recentMessages: const [],
      currentWeek: 4,
      interventionRegistry: const ApprovedInterventionRegistry(),
      knowledge: const [],
      retrievalSummary: RetrievalSummary.empty,
    );
    final policy = const DeterministicPolicyBoundaryBuilder().build(request)!;

    test('normal action + valid goal + text -> valid', () {
      expectAgreement(
        label: 'reflect normal valid',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedGoalId: 'evidence',
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: true,
      );
    });

    test(
      'normal action + null goal -> invalid (the exact real-world gap: '
      'gpt-4o-mini omitted selectedGoalId for a non-clarify reflect turn)',
      () {
        expectAgreement(
          label: 'reflect normal null goal',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.socraticQuestion,
            reflectionTarget: ReflectionTarget.text('x'),
          ),
          expectValid: false,
        );
      },
    );

    test('normal action + invalid goal id -> invalid', () {
      expectAgreement(
        label: 'reflect normal invalid goal',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedGoalId: 'not_a_real_goal',
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: false,
      );
    });

    test(
      'normal action + valid goal + None reflectionTarget -> invalid (the '
      'other real-world gap: gpt-4o-mini sent type=none for intervention/'
      'reflect, which always require text)',
      () {
        expectAgreement(
          label: 'reflect normal none target',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.socraticQuestion,
            selectedGoalId: 'evidence',
            reflectionTarget: ReflectionTarget.none(),
          ),
          expectValid: false,
        );
      },
    );

    // A separate, genuinely low-information fixture — clarify is only
    // offered by the boundary builder (Phase 8.3B's widening fix) when the
    // message actually lacks a usable thought; the "normal" fixture above
    // (a clear, thought-shaped message) never triggers it, so testing the
    // clarify branch needs its own request/policy pair.
    final clarifyRequest = PolicyBoundaryRequest(
      currentState: CounselingState.reflect,
      userMessage: '몰라요.',
      recentMessages: const [],
      currentWeek: 4,
      interventionRegistry: const ApprovedInterventionRegistry(),
      knowledge: const [],
      retrievalSummary: RetrievalSummary.empty,
    );
    final clarifyPolicy =
        const DeterministicPolicyBoundaryBuilder().build(clarifyRequest)!;

    test('clarify fixture actually offers the explore action', () {
      expect(clarifyPolicy.allowedActions, contains(DialogueAct.explore));
    });

    test('clarify branch (action=explore) + null goal -> valid', () {
      expectAgreement(
        label: 'reflect clarify null goal',
        request: clarifyRequest,
        policy: clarifyPolicy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: true,
      );
    });

    test('clarify branch (action=explore) + None target -> invalid', () {
      expectAgreement(
        label: 'reflect clarify none target',
        request: clarifyRequest,
        policy: clarifyPolicy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.none(),
        ),
        expectValid: false,
      );
    });

    // Phase 11.3: goal-exhaustion recovery branch (action=reflect) and its
    // XOR contract against selectedGoalId. `policy` here still has
    // `candidateGoalIds` populated (this fixture's message isn't actually
    // exhausted) — deliberately, since the XOR must hold on the DECISION's
    // shape alone, independent of whether the boundary itself currently
    // reports exhaustion.
    test(
      'recovery branch (action=reflect) + summarize + null goal + text '
      '-> valid',
      () {
        expectAgreement(
          label: 'reflect recovery summarize',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.reflect,
            goalExhaustionRecovery: GoalExhaustionRecovery.summarize,
            reflectionTarget: ReflectionTarget.text('x'),
          ),
          expectValid: true,
        );
      },
    );

    test(
      'recovery branch (action=reflect) + listenWithoutQuestion + null '
      'goal + text -> valid',
      () {
        expectAgreement(
          label: 'reflect recovery listenWithoutQuestion',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.reflect,
            goalExhaustionRecovery: GoalExhaustionRecovery.listenWithoutQuestion,
            reflectionTarget: ReflectionTarget.text('x'),
          ),
          expectValid: true,
        );
      },
    );

    test(
      'recovery branch (action=reflect) + no goalExhaustionRecovery + no '
      'goal -> invalid (recovery is required for this branch, not merely '
      'optional)',
      () {
        expectAgreement(
          label: 'reflect action=reflect with neither goal nor recovery',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.reflect,
            reflectionTarget: ReflectionTarget.text('x'),
          ),
          expectValid: false,
        );
      },
    );

    test(
      'recovery branch (action=reflect) + BOTH selectedGoalId and '
      'goalExhaustionRecovery set -> invalid (XOR violation: goal is '
      'forbidden once a recovery type is chosen)',
      () {
        expectAgreement(
          label: 'reflect recovery with goal also set',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.reflect,
            selectedGoalId: 'evidence',
            goalExhaustionRecovery: GoalExhaustionRecovery.summarize,
            reflectionTarget: ReflectionTarget.text('x'),
          ),
          expectValid: false,
        );
      },
    );

    test(
      'normal branch (action=socraticQuestion) + goalExhaustionRecovery set '
      '-> invalid (XOR violation, other direction: recovery is forbidden '
      'once a normal goal is pursued)',
      () {
        expectAgreement(
          label: 'reflect normal with recovery also set',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.socraticQuestion,
            selectedGoalId: 'evidence',
            goalExhaustionRecovery: GoalExhaustionRecovery.summarize,
            reflectionTarget: ReflectionTarget.text('x'),
          ),
          expectValid: false,
        );
      },
    );

    test(
      'recovery branch (action=reflect) + None reflectionTarget -> invalid '
      '(recovery still requires text, like every other reflect branch)',
      () {
        expectAgreement(
          label: 'reflect recovery none target',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.reflect,
            goalExhaustionRecovery: GoalExhaustionRecovery.summarize,
            reflectionTarget: ReflectionTarget.none(),
          ),
          expectValid: false,
        );
      },
    );
  });

  group('Intervention', () {
    final knowledge = [
      CbtKnowledgeItem(
        id: 'week4_alternative_thought_01',
        week: 4,
        type: 'technique',
        title: 'week4_alternative_thought_01',
        paragraphs: const ['검증용'],
        tags: const ['alternative_thought', 'cognitive_restructuring'],
        source: 'test',
      ),
    ];
    final request = PolicyBoundaryRequest(
      currentState: CounselingState.intervention,
      userMessage: '생각을 바꾸는 게 잘 안 돼요.',
      recentMessages: const [],
      currentWeek: 4,
      interventionRegistry: const ApprovedInterventionRegistry(),
      knowledge: knowledge,
      retrievalSummary: RetrievalSummary.empty,
    );
    final policy = const DeterministicPolicyBoundaryBuilder().build(request)!;

    test('valid intervention + text target -> valid', () {
      expectAgreement(
        label: 'intervention valid',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedInterventionId: 'week4_alternative_thought_01',
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: true,
      );
    });

    test(
      'valid intervention + None target -> invalid (the real-world gap: '
      'gpt-4o-mini sent type=none despite selecting a real intervention)',
      () {
        expectAgreement(
          label: 'intervention none target',
          request: request,
          policy: policy,
          decision: const CounselorDecision(
            selectedAction: DialogueAct.socraticQuestion,
            selectedInterventionId: 'week4_alternative_thought_01',
            reflectionTarget: ReflectionTarget.none(),
          ),
          expectValid: false,
        );
      },
    );

    test('null selectedInterventionId -> invalid (intervention requires one)', () {
      expectAgreement(
        label: 'intervention missing id',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: false,
      );
    });

    test('non-null goal -> invalid (intervention forbids goal)', () {
      expectAgreement(
        label: 'intervention with goal',
        request: request,
        policy: policy,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.socraticQuestion,
          selectedGoalId: 'evidence',
          selectedInterventionId: 'week4_alternative_thought_01',
          reflectionTarget: ReflectionTarget.text('x'),
        ),
        expectValid: false,
      );
    });
  });

  group('Closing', () {
    final requestWithTarget = PolicyBoundaryRequest(
      currentState: CounselingState.closing,
      userMessage: '발표 준비에 대해 이야기했어요.',
      recentMessages: const [],
      currentWeek: 4,
      interventionRegistry: const ApprovedInterventionRegistry(),
      knowledge: const [],
      retrievalSummary: RetrievalSummary.empty,
    );
    final policyWithTarget =
        const DeterministicPolicyBoundaryBuilder().build(requestWithTarget)!;

    test('text reflectionTarget -> valid', () {
      expectAgreement(
        label: 'closing text',
        request: requestWithTarget,
        policy: policyWithTarget,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.closing,
          reflectionTarget: ReflectionTarget.text('발표 준비에 대해 이야기했어요'),
        ),
        expectValid: true,
      );
    });

    test('None reflectionTarget -> ALSO valid (closing is the one state '
        'where "no target" is a normal outcome)', () {
      expectAgreement(
        label: 'closing none',
        request: requestWithTarget,
        policy: policyWithTarget,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.closing,
          reflectionTarget: ReflectionTarget.none(),
        ),
        expectValid: true,
      );
    });

    test('null reflectionTarget (isUnavailable=false) -> invalid', () {
      expectAgreement(
        label: 'closing null target without isUnavailable',
        request: requestWithTarget,
        policy: policyWithTarget,
        decision: const CounselorDecision(
          selectedAction: DialogueAct.closing,
        ),
        expectValid: false,
      );
    });
  });

  group('isUnavailable claims: accepted universally (backward compat), '
      'never crash materialization', () {
    for (final state in CounselingState.values) {
      test('$state: isUnavailable=true returns null gracefully', () {
        final request = PolicyBoundaryRequest(
          currentState: state,
          userMessage: '아무 말이나요.',
          recentMessages: const [],
          currentWeek: 4,
          interventionRegistry: const ApprovedInterventionRegistry(),
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        );
        final policy = const DeterministicPolicyBoundaryBuilder().build(request)!;
        const decision = CounselorDecision(
          selectedAction: DialogueAct.unknown,
          isUnavailable: true,
        );

        expect(validator.validate(decision: decision, policy: policy), isNull);
        expect(
          () => turnPlanAdapter.build(
            request: request,
            policy: policy,
            decision: decision,
          ),
          returnsNormally,
        );
      });
    }
  });
}
