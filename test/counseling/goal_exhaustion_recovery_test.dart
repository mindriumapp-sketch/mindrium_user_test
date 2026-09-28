// Phase 11.3: Goal Exhaustion Recovery — replaces the old `repeatLast`
// magic fallback (`ReflectDecisionSelector._selectGoal` silently returning
// `goalOrder.last` forever) with an explicit, typed recovery selection
// (`ReflectGoalSelection`/`GoalExhaustionRecovery`).
//
// Three groups, per the phase's own frozen test plan
// (docs/counseling/phase11_1_selection_interaction_repair_design.md):
//   A. normal progression is unchanged — no recovery until goals are
//      actually exhausted, byte-identical goal sequencing to before.
//   B. exhaustion recovery invariants — recovery metadata present, zero
//      new questions, no fake goal id, normal StatePolicy budget still
//      authoritative (not bypassed by the recovery mechanism).
//   C. interaction-repair integration — a `repeatedQuestion` repair turn
//      immediately preceding this one switches the recovery choice; an
//      earlier (non-immediately-preceding) one does not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/reflect_decision_selector.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

CounselingMessage _goalMessage(
  String id,
  String? goalId, {
  InteractionRepairReason? repair,
}) {
  return CounselingMessage(
    id: id,
    role: 'assistant',
    text: '이전 반영 문장',
    createdAt: DateTime.now(),
    dialogueAct: repair != null ? DialogueAct.reflect : DialogueAct.socraticQuestion,
    dialogueGoalId: goalId,
    interactionRepairReason: repair,
  );
}

void main() {
  const selector = ReflectDecisionSelector();

  group('A. normal progression is unchanged', () {
    test(
      '세 목표를 goalOrder 순서대로 정상 선택한다 '
      '(evidence -> alternative -> probability), recovery는 등장하지 않는다',
      () {
        final first = selector.select(
          userMessage: '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
          recentMessages: const [],
          userContext: null,
        );
        expect(first.selectedAction, DialogueAct.socraticQuestion);
        expect(first.selectedGoalId, 'evidence');
        expect(first.goalExhaustionRecovery, isNull);

        final second = selector.select(
          userMessage: '그럴 수도 있을 것 같아요.',
          recentMessages: [_goalMessage('a1', 'evidence')],
          userContext: null,
        );
        expect(second.selectedAction, DialogueAct.socraticQuestion);
        expect(second.selectedGoalId, 'alternative');
        expect(second.goalExhaustionRecovery, isNull);

        final third = selector.select(
          userMessage: '음, 잘 모르겠어요.',
          recentMessages: [
            _goalMessage('a1', 'evidence'),
            _goalMessage('a2', 'alternative'),
          ],
          userContext: null,
        );
        expect(third.selectedAction, DialogueAct.socraticQuestion);
        expect(third.selectedGoalId, 'probability');
        expect(third.goalExhaustionRecovery, isNull);
      },
    );

    test('clarify 분기는 recovery 도입 이후에도 그대로 유지된다', () {
      final decision = selector.select(
        userMessage: '몰라요.',
        recentMessages: const [],
        userContext: null,
      );
      expect(decision.selectedAction, DialogueAct.explore);
      expect(decision.selectedGoalId, isNull);
      expect(decision.goalExhaustionRecovery, isNull);
    });
  });

  group('B. exhaustion recovery invariants', () {
    final exhausted = [
      _goalMessage('a1', 'evidence'),
      _goalMessage('a2', 'alternative'),
      _goalMessage('a3', 'probability'),
    ];

    test('신호가 없으면 기본 recovery는 summarize이고, 가짜 goal을 만들지 않는다', () {
      final decision = selector.select(
        userMessage: '그냥 그런 것 같아요.',
        recentMessages: exhausted,
        userContext: null,
      );
      expect(decision.selectedAction, DialogueAct.reflect);
      expect(decision.selectedGoalId, isNull);
      expect(decision.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
    });

    test(
      'materialize된 recovery 턴은 질문이 없고, 새 CBT/사용자 사실을 만들지 않으며, '
      'requiredAct가 reflect(진행 가속과 무관)이다',
      () {
        final decision = selector.select(
          userMessage: '그냥 그런 것 같아요.',
          recentMessages: exhausted,
          userContext: null,
        );
        const materializer = TurnPlanMaterializer();
        final plan = materializer.reflect(
          decision,
          recentMessages: exhausted,
          allowedActsForTurn: const [],
        );

        expect(plan.questionSentence, isEmpty);
        expect(plan.constraints, contains(TurnConstraint.requireNoQuestion));
        expect(plan.constraints, contains(TurnConstraint.forbidNewUserFacts));
        expect(plan.constraints, contains(TurnConstraint.forbidNewIntervention));
        // Not `.summarize` (would trigger reflect->intervention acceleration
        // via CounselingStatePolicy._acceleratesFrom) and not
        // `.socraticQuestion` (would imply a goal was pursued).
        expect(plan.requiredAct, DialogueAct.reflect);
        expect(plan.progressGoalId, isNull);
        expect(plan.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
      },
    );

    test('listenWithoutQuestion recovery도 동일한 무질문 계약을 지킨다', () {
      const materializer = TurnPlanMaterializer();
      final plan = materializer.reflect(
        const CounselorDecision(
          selectedAction: DialogueAct.reflect,
          goalExhaustionRecovery: GoalExhaustionRecovery.listenWithoutQuestion,
          reflectionTarget: ReflectionTarget.text('시험 발표가 계속 걱정돼요'),
        ),
        recentMessages: exhausted,
        allowedActsForTurn: const [],
      );

      expect(plan.questionSentence, isEmpty);
      expect(plan.constraints, contains(TurnConstraint.requireNoQuestion));
      expect(plan.requiredAct, DialogueAct.reflect);
      expect(
        plan.goalExhaustionRecovery,
        GoalExhaustionRecovery.listenWithoutQuestion,
      );
    });

    test('revisitPreviousIssue/transition은 아직 선택 불가 계약이라 materialize 시 명시적으로 실패한다', () {
      const materializer = TurnPlanMaterializer();
      for (final notYet in [
        GoalExhaustionRecovery.revisitPreviousIssue,
        GoalExhaustionRecovery.transition,
        GoalExhaustionRecovery.repeatLast,
      ]) {
        expect(
          () => materializer.reflect(
            CounselorDecision(
              selectedAction: DialogueAct.reflect,
              goalExhaustionRecovery: notYet,
              reflectionTarget: const ReflectionTarget.text('x'),
            ),
            recentMessages: exhausted,
            allowedActsForTurn: const [],
          ),
          throwsStateError,
          reason: '$notYet must fail loudly, not silently fall back to a '
              'generic response (the exact anti-pattern this phase '
              'replaces)',
        );
      }
    });

    test(
      'recovery 턴은 실제 harness를 통해서도 goalExhaustionRecovery 메타데이터를 그대로 '
      '옮기고, 질문/새 CBT 근거가 없다',
      () async {
        final repository = LocalCbtKnowledgeRepository(loadAsset: _load);
        await repository.initialize();
        final harness = CounselingHarness.deterministic(
          llm: MockLlmService(),
          safetyGate: const KeywordSafetyGate(),
          knowledgeRepository: repository,
        );
        final session = CounselingSessionState(
          sessionId: 'p11-3-exhausted',
          currentWeek: 4,
          state: CounselingState.reflect,
          messages: [...exhausted],
        );

        final result = await harness.handleTurn(
          session: session,
          userMessage: '그냥 그런 것 같아요.',
        );

        expect(
          result.assistantMessage.goalExhaustionRecovery,
          GoalExhaustionRecovery.summarize,
        );
        expect('?'.allMatches(result.assistantMessage.text).length, 0);
        expect(result.assistantMessage.referencedCbtIds, isEmpty);
        expect(result.assistantMessage.dialogueGoalId, isNull);
      },
    );

    test(
      'recovery는 CounselingStatePolicy의 턴 예산 진행을 가로막거나 앞당기지 않는다 — '
      '"상태가 안 바뀐다"가 아니라 "일반 턴과 동일하게 진행된다"가 올바른 불변식이다 '
      '(Phase 11.2에서 확정한 정의)',
      () async {
        final repository = LocalCbtKnowledgeRepository(loadAsset: _load);
        await repository.initialize();
        CounselingHarness harness() => CounselingHarness.deterministic(
          llm: MockLlmService(),
          safetyGate: const KeywordSafetyGate(),
          knowledgeRepository: repository,
        );

        final recoverySession = CounselingSessionState(
          sessionId: 'p11-3-recovery-progression',
          currentWeek: 4,
          state: CounselingState.reflect,
          messages: [...exhausted],
        );
        final recoveryResult = await harness().handleTurn(
          session: recoverySession,
          userMessage: '그냥 그런 것 같아요.',
        );

        final controlSession = CounselingSessionState(
          sessionId: 'p11-3-control-progression',
          currentWeek: 4,
          state: CounselingState.reflect,
          messages: [_goalMessage('a1', 'evidence')],
        );
        final controlResult = await harness().handleTurn(
          session: controlSession,
          userMessage: '그냥 그런 것 같아요.',
        );

        expect(recoveryResult.state, controlResult.state);
      },
    );
  });

  group('C. interaction-repair integration', () {
    test(
      '직전 턴이 repeatedQuestion 반복 지적이었다면 summarize 대신 '
      'listenWithoutQuestion을 고른다',
      () {
        final messages = [
          _goalMessage('a1', 'evidence'),
          _goalMessage('a2', 'alternative'),
          _goalMessage('a3', 'probability'),
          // A repair turn on the recovery surface itself — dialogueGoalId
          // is null (no goal pursued by a repair turn), matching
          // DeterministicProcessSignalTurnPlanner's real shape.
          _goalMessage('a4', null, repair: InteractionRepairReason.repeatedQuestion),
        ];

        final decision = selector.select(
          userMessage: '그래도 잘 모르겠어요.',
          recentMessages: messages,
          userContext: null,
        );

        expect(
          decision.goalExhaustionRecovery,
          GoalExhaustionRecovery.listenWithoutQuestion,
        );
      },
    );

    test(
      '직전 턴이 stopQuestioning(질문 그만 요청)이었다면 역시 '
      'listenWithoutQuestion을 고른다',
      () {
        final messages = [
          _goalMessage('a1', 'evidence'),
          _goalMessage('a2', 'alternative'),
          _goalMessage('a3', 'probability'),
          _goalMessage('a4', null, repair: InteractionRepairReason.stopQuestioning),
        ];

        final decision = selector.select(
          userMessage: '네.',
          recentMessages: messages,
          userContext: null,
        );

        expect(
          decision.goalExhaustionRecovery,
          GoalExhaustionRecovery.listenWithoutQuestion,
        );
      },
    );

    test(
      '직전 턴이 processFrustration(과정 저항)이었다면 summarize를 그대로 고른다 — '
      'repeatedQuestion/stopQuestioning만 listenWithoutQuestion으로 분기한다',
      () {
        final messages = [
          _goalMessage('a1', 'evidence'),
          _goalMessage('a2', 'alternative'),
          _goalMessage('a3', 'probability'),
          _goalMessage('a4', null, repair: InteractionRepairReason.processFrustration),
        ];

        final decision = selector.select(
          userMessage: '그냥 그런가 보죠.',
          recentMessages: messages,
          userContext: null,
        );

        expect(decision.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
      },
    );

    test(
      '바로 직전 턴이 아닌, 더 이전 턴의 repeatedQuestion은 영향을 주지 않는다 — '
      '오직 recentMessages.last만 본다',
      () {
        final messages = [
          _goalMessage('a1', 'evidence'),
          // repeatedQuestion happened mid-sequence, NOT immediately before
          // this turn.
          _goalMessage('a2', null, repair: InteractionRepairReason.repeatedQuestion),
          _goalMessage('a3', 'alternative'),
          _goalMessage('a4', 'probability'), // most recent: a normal turn
        ];

        final decision = selector.select(
          userMessage: '그냥 그런 것 같아요.',
          recentMessages: messages,
          userContext: null,
        );

        expect(decision.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
      },
    );
  });

  // Phase 12.3C (F1): the same recovery must never be chosen twice in a
  // row. Decided from the previous assistant message's
  // goalExhaustionRecovery metadata, never from its text.
  group('D. consecutive recovery guard (F1)', () {
    final exhausted = [
      _goalMessage('a1', 'evidence'),
      _goalMessage('a2', 'alternative'),
      _goalMessage('a3', 'probability'),
    ];
    CounselingMessage recovery(GoalExhaustionRecovery r) => CounselingMessage(
      id: 'rec_${r.name}',
      role: 'assistant',
      text: 'recovery',
      createdAt: DateTime.now(),
      dialogueAct: DialogueAct.reflect,
      goalExhaustionRecovery: r,
    );

    test('A. summarize -> next turn is not summarize again', () {
      final d = selector.select(
        userMessage: '그래도 여전히 걱정돼요.',
        recentMessages: [...exhausted, recovery(GoalExhaustionRecovery.summarize)],
        userContext: null,
      );
      expect(d.goalExhaustionRecovery, isNot(GoalExhaustionRecovery.summarize));
      expect(d.goalExhaustionRecovery, GoalExhaustionRecovery.listenWithoutQuestion);
      expect(d.selectedGoalId, isNull);
    });

    test('B. listenWithoutQuestion -> next turn is not listenWithoutQuestion again', () {
      final d = selector.select(
        userMessage: '네, 그냥 계속 걱정되긴 해요.',
        recentMessages: [
          ...exhausted,
          recovery(GoalExhaustionRecovery.listenWithoutQuestion),
        ],
        userContext: null,
      );
      expect(d.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
    });

    test('a repair turn still takes precedence (repeatedQuestion -> listen)', () {
      final d = selector.select(
        userMessage: '네.',
        recentMessages: [
          ...exhausted,
          _goalMessage('a4', null, repair: InteractionRepairReason.repeatedQuestion),
        ],
        userContext: null,
      );
      expect(d.goalExhaustionRecovery, GoalExhaustionRecovery.listenWithoutQuestion);
    });

    test('C. at the reflect budget edge, state follows StatePolicy like a control turn', () async {
      final repository = LocalCbtKnowledgeRepository(loadAsset: _load);
      await repository.initialize();
      CounselingHarness harness() => CounselingHarness.deterministic(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      );
      final recoverySession = CounselingSessionState(
        sessionId: 'p12-3c-edge',
        currentWeek: 4,
        state: CounselingState.reflect,
        turnsInCurrentState: 1,
        messages: [...exhausted, recovery(GoalExhaustionRecovery.summarize)],
      );
      final controlSession = CounselingSessionState(
        sessionId: 'p12-3c-control',
        currentWeek: 4,
        state: CounselingState.reflect,
        turnsInCurrentState: 1,
        messages: [_goalMessage('a1', 'evidence')],
      );
      final r = await harness().handleTurn(session: recoverySession, userMessage: '그래도 걱정돼요.');
      await harness().handleTurn(session: controlSession, userMessage: '그래도 걱정돼요.');
      expect(r.assistantMessage.goalExhaustionRecovery, GoalExhaustionRecovery.listenWithoutQuestion);
      expect(recoverySession.state, controlSession.state);
    });

    test('D. normal non-exhausted progression is unchanged', () {
      final d = selector.select(
        userMessage: '그럴 수도 있을 것 같아요.',
        recentMessages: [_goalMessage('a1', 'evidence'), recovery(GoalExhaustionRecovery.summarize)],
        userContext: null,
      );
      expect(d.selectedGoalId, 'alternative');
      expect(d.goalExhaustionRecovery, isNull);
    });
  });
}
