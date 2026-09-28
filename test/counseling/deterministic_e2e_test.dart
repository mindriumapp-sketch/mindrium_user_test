import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';
import 'package:gad_app_team/features/counseling/turn_plan_prompt_builder.dart';

Future<String> _load(String path) => File(path).readAsString();

class _ForbiddenLlm implements LlmService {
  int calls = 0;

  @override
  Future<LlmResponse> generate(LlmRequest request) {
    calls++;
    throw StateError('P8 deterministic scenario must not call the LLM');
  }
}

void main() {
  test('P8 발표 불안 시나리오가 전 상태를 결정론적으로 통과한다', () async {
    final repository = LocalCbtKnowledgeRepository(loadAsset: _load);
    await repository.initialize();
    final llm = _ForbiddenLlm();
    final harness = CounselingHarness(
      llm: llm,
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      turnPlanner: const DeterministicCounselingTurnPlanner(),
      promptBuilder: const TurnPlanPromptBuilder(),
    );
    final session = CounselingSessionState(
      sessionId: 'p8-presentation-anxiety',
      currentWeek: 4,
    );
    final results = <CounselingTurnResult>[];

    Future<CounselingTurnResult> send(String text) async {
      final result = await harness.handleTurn(
        session: session,
        userMessage: text,
      );
      session.messages
        ..add(
          CounselingMessage(
            id: '${session.sessionId}_${session.messages.length}_user',
            role: 'user',
            text: text,
            createdAt: DateTime(2026, 9, 4),
          ),
        )
        ..add(result.assistantMessage);
      results.add(result);
      return result;
    }

    await send('내일 발표가 있어서 불안해요.');
    await send('7 정도예요. 특히 질문을 받는 순간이 걱정돼요.');
    await send('질문에 답하지 못하면 사람들이 저를 무능하게 볼 것 같아요.');
    await send('예전에 답을 못하고 당황했던 경험이 있어요.');
    await send('그래도 한 번 답하지 못한다고 항상 무능한 건 아닐 것 같아요.');
    await send('조금 정리가 된 것 같아요. 감사합니다.');

    expect(results.map((result) => result.stateBefore), [
      CounselingState.checkIn,
      CounselingState.explore,
      CounselingState.reflect,
      CounselingState.reflect,
      CounselingState.intervention,
      CounselingState.closing,
    ]);
    expect(results.map((result) => result.state), [
      CounselingState.explore,
      CounselingState.reflect,
      CounselingState.reflect,
      CounselingState.intervention,
      CounselingState.closing,
      CounselingState.closing,
    ]);
    expect(llm.calls, 0);

    for (var index = 0; index < results.length; index++) {
      final result = results[index];
      final reply = result.assistantMessage.text;
      expect(result.handledBySafety, isFalse);
      expect(result.turnPlan, isNotNull);
      expect(result.turnPlan!.planningStatus, TurnPlanningStatus.planned);
      expect(reply, isNotEmpty);
      expect(reply, isNot(contains('\uFFFD')));
      expect(reply, isNot(contains('<|')));
      expect(reply, isNot(contains('<think>')));
      expect('?'.allMatches(reply).length, index == results.length - 1 ? 0 : 1);
      if (index > 0) {
        expect(reply, isNot(results[index - 1].assistantMessage.text));
      }
    }

    expect(results[2].assistantMessage.text, isNot(contains('같아요라는')));
    expect(results[2].assistantMessage.text, contains('무능하게 볼 것 같다는 생각'));
    expect(results[2].assistantMessage.text, contains('근거나 경험'));
    expect(results[3].assistantMessage.text, contains('다른 관점'));

    final intervention = results[4];
    expect(intervention.assistantMessage.referencedCbtIds, [
      DeterministicInterventionTurnPlanner.balancedThoughtCbtId,
    ]);
    expect(intervention.assistantMessage.referencedUserContextIds, isEmpty);
    expect(intervention.turnPlan!.interventionPlan, isNotNull);
    // 4주차 개입은 대안적 생각 찾기다. 걱정 일기가 아니라 해당 화면으로 잇는다.
    expect(intervention.uiAction, CounselingActivity.alternativeThought);
    expect(
      intervention.turnPlan!.interventionPlan!.recommendation.activity,
      CounselingActivity.alternativeThought,
    );

    final closing = results.last;
    expect(closing.assistantMessage.dialogueAct, DialogueAct.closing);
    expect(closing.assistantMessage.text, contains('조금 정리가 된 것 같아요'));
    expect(closing.assistantMessage.referencedCbtIds, isEmpty);
    expect(closing.assistantMessage.referencedUserContextIds, isEmpty);
  });
}
