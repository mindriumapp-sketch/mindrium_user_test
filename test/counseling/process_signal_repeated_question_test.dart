// Phase 11.2: DeterministicProcessSignalTurnPlanner's new
// InteractionRepairReason.repeatedQuestion coverage — extends detection
// only, per docs/counseling/chatbot_system.md.
//
// Four groups, per the phase's own test plan:
//   A. existing process-signal behavior is unchanged
//   B. new repeated-question positives are detected
//   C. worry content that merely mentions repetition is NOT misdetected
//   D. end-to-end through the real production harness
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

void main() {
  const planner = DeterministicProcessSignalTurnPlanner();

  group('A. existing process-signal behavior unchanged', () {
    test('질문 그만 요청은 여전히 stopQuestioning으로 잡힌다', () {
      final plan = planner.plan(
        const TurnPlanningContext(
          state: CounselingState.explore,
          userMessage: '왜 자꾸 물어보기만 해요, 그냥 공감 좀 해주시면 안 돼요?',
          knowledge: [],
        ),
      )!;

      expect(plan.interactionRepairReason, InteractionRepairReason.stopQuestioning);
      expect('?'.allMatches(plan.deterministicReply).length, 0);
      expect(plan.questionSentence, isEmpty);
    });

    test('과정 저항 반응은 여전히 processFrustration으로 잡힌다', () {
      final plan = planner.plan(
        const TurnPlanningContext(
          state: CounselingState.checkIn,
          userMessage: '이런 거 한다고 뭐가 달라질까 싶어요.',
          knowledge: [],
        ),
      )!;

      expect(plan.interactionRepairReason, InteractionRepairReason.processFrustration);
      expect(plan.constraints, contains(TurnConstraint.requireNoQuestion));
    });

    test('실제 상담 내용에는 여전히 반응하지 않는다', () {
      final plan = planner.plan(
        const TurnPlanningContext(
          state: CounselingState.explore,
          userMessage: '그래도 한 번 해볼게요, 요즘 발표 때문에 계속 신경 쓰이긴 해요.',
          knowledge: [],
        ),
      );

      expect(plan, isNull);
    });
  });

  group('B. repeated-question positives are detected', () {
    const positives = [
      '왜 똑같은 말을 반복하지?',
      '왜 같은 질문을 계속 해요?',
      '아까도 물어봤잖아요.',
      '방금도 그 질문 했는데요.',
      '또 같은 걸 물어보네요.',
      '아까 말한 거랑 똑같잖아요.',
      '왜 계속 비슷한 질문만 해요?',
      '그 얘기 방금도 했어요.',
    ];

    for (final message in positives) {
      test('"$message" -> repeatedQuestion으로 잡힌다', () {
        final plan = planner.plan(
          TurnPlanningContext(
            state: CounselingState.reflect,
            userMessage: message,
            knowledge: const [],
          ),
        );

        expect(plan, isNotNull, reason: '감지되지 않음: $message');
        expect(
          plan!.interactionRepairReason,
          InteractionRepairReason.repeatedQuestion,
        );
        expect(plan.questionSentence, isEmpty);
        expect('?'.allMatches(plan.deterministicReply).length, 0);
        expect(plan.constraints, contains(TurnConstraint.requireNoQuestion));
      });
    }
  });

  group('C. worry content mentioning repetition is NOT misdetected', () {
    const negatives = [
      '같은 생각이 계속 반복돼요.',
      '매일 똑같은 걱정을 해요.',
      '또 실수할까 봐 걱정돼요.',
      '아까도 그 사람이 그렇게 말했어요.',
      '같은 일이 다시 생길 것 같아요.',
      '왜 자꾸 이런 생각이 드는지 모르겠어요.',
      '계속 비슷한 상황이 반복돼요.',
    ];

    for (final message in negatives) {
      test('"$message" -> 상담 내용으로 취급되어 이 planner는 관여하지 않는다', () {
        final plan = planner.plan(
          TurnPlanningContext(
            state: CounselingState.reflect,
            userMessage: message,
            knowledge: const [],
          ),
        );

        expect(
          plan,
          isNull,
          reason: '오탐: "$message"이 interaction-repair로 잘못 분류됨',
        );
      });
    }
  });

  group('D. end-to-end through the real production harness', () {
    late LocalCbtKnowledgeRepository repository;

    setUpAll(() async {
      repository = LocalCbtKnowledgeRepository(loadAsset: _load);
      await repository.initialize();
    });

    CounselingHarness harness() => CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
    );

    test(
      '정상 걱정 진행 후 "아까도 물어봤잖아"가 나오면 interaction repair로 전환되고 '
      '상태/CBT는 오염되지 않는다',
      () async {
        final h = harness();
        final session = CounselingSessionState(
          sessionId: 'p11-2-repeated-question',
          currentWeek: 4,
          state: CounselingState.reflect,
        );

        final first = await h.handleTurn(
          session: session,
          userMessage: '사람들이 나를 무능하게 볼 것 같다는 생각이 들어요.',
        );
        session.messages.add(first.assistantMessage);
        final cbtIdsAfterFirst = first.assistantMessage.referencedCbtIds;

        final second = await h.handleTurn(
          session: session,
          userMessage: '아까도 물어봤잖아요.',
        );

        expect(
          second.assistantMessage.interactionRepairReason,
          InteractionRepairReason.repeatedQuestion,
        );
        // Phase 11.2 guarantee: acknowledgment only, no new question.
        expect('?'.allMatches(second.assistantMessage.text).length, 0);
        // No CBT intervention introduced by a repair turn.
        expect(second.assistantMessage.referencedCbtIds, isEmpty);
        expect(cbtIdsAfterFirst, isEmpty); // sanity: first turn had none either

        // "No unauthorized state jump" does NOT mean "state never moves" —
        // reflect's turn budget is 2, and this is the 2nd reflect-state
        // turn, so CounselingStatePolicy._advance()'s ordinary
        // budget-exhaustion rule (turnsInCurrentState + 1 >= budgetFor)
        // fires regardless of which planner produced the turn. What must
        // NOT happen is the repair mechanism causing an *extra*,
        // premature jump beyond that normal rule (the
        // `_acceleratesFrom` path, which fires for specific acts like
        // `summarize`/reflect-from-explore) — verified below by checking
        // an ordinary reflect turn at the same budget position advances
        // identically, so the repair turn's transition is unremarkable,
        // not special-cased.
        final control = CounselingSessionState(
          sessionId: 'p11-2-control',
          currentWeek: 4,
          state: CounselingState.reflect,
        );
        final controlFirst = await harness().handleTurn(
          session: control,
          userMessage: '사람들이 나를 무능하게 볼 것 같다는 생각이 들어요.',
        );
        control.messages.add(controlFirst.assistantMessage);
        final controlSecond = await harness().handleTurn(
          session: control,
          userMessage: '잘 모르겠어요, 그냥 그런 것 같아요.',
        );
        // Phase 13.4: a repair turn no longer counts toward completing
        // reflect, so it stays while the control advances. The Phase 11
        // invariant is "never faster than a control turn", and this is slower.
        expect(session.state.index, lessThanOrEqualTo(control.state.index));
        expect(session.state, CounselingState.reflect);
        expect(controlSecond.assistantMessage.interactionRepairReason, isNull);
      },
    );

    test('interaction-repair 턴도 explore/reflect 라우팅 규칙을 그대로 따른다', () async {
      // Phase 11.1's own investigation: HybridTurnRouter.route() only
      // checks session.state, never which planner produced the plan — so
      // a repeatedQuestion repair turn must be gated exactly like any
      // other explore/reflect turn, not specially allowed or blocked.
      final h = CounselingHarness.remoteGpt(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
        responseRealizer: _CountingRealizer(),
      );
      final session = CounselingSessionState(
        sessionId: 'p11-2-routing',
        currentWeek: 4,
        state: CounselingState.checkIn,
      );

      final result = await h.handleTurn(
        session: session,
        userMessage: '왜 자꾸 같은 질문을 반복해요?',
      );

      // checkIn never allows Remote, regardless of which planner fired.
      expect(result.routing?.allowLlm, isFalse);
    });
  });
}

class _CountingRealizer implements ResponseRealizer {
  int callCount = 0;

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    callCount++;
    return RealizationResult(
      reply: '스파이 응답입니다.',
      source: RealizationSource.remoteLlm,
      latency: Duration.zero,
      validationResult: RealizationValidationResult.valid,
      chosenAct: request.requiredAct,
    );
  }
}
