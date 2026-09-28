import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

/// Adaptive Dialogue Policy Phase 1 통합 검증.
///
/// docs/counseling/adaptive_dialogue_policy.md 4절: turnPlan이
/// allowedActsForTurn을 제공하면, realizer(GPT)가 그 안에서 requiredAct와
/// 다른 행위를 골라도 harness가 그 선택을 최종 메시지와 state 전이에 그대로
/// 반영해야 한다. 반대로 검증에 실패한 선택은 항상 requiredAct/deterministic
/// draft로 되돌아가야 한다.
class _FixedResponseRealizer implements ResponseRealizer {
  final String reply;
  final DialogueAct chosenAct;
  final bool isValid;

  const _FixedResponseRealizer({
    required this.reply,
    required this.chosenAct,
    this.isValid = true,
  });

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    return RealizationResult(
      reply: reply,
      source: RealizationSource.remoteLlm,
      latency: const Duration(milliseconds: 5),
      chosenAct: chosenAct,
      validationResult:
          isValid
              ? RealizationValidationResult.valid
              : const RealizationValidationResult(
                isValid: false,
                violations: ['act_not_allowed'],
              ),
    );
  }
}

Future<String> _loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _loadFromDisk);
    await repository.initialize();
  });

  CounselingHarness harnessWith(ResponseRealizer responseRealizer) {
    return CounselingHarness.remoteGpt(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      responseRealizer: responseRealizer,
    );
  }

  CounselingSessionState exploreSession() {
    return CounselingSessionState(
      sessionId: 'test',
      currentWeek: 4,
      state: CounselingState.explore,
    );
  }

  test('검증을 통과한 다른 허용 행위를 고르면 최종 메시지에 반영된다', () async {
    final harness = harnessWith(
      const _FixedResponseRealizer(
        reply: '오늘은 그냥 지친 마음을 그대로 두고 싶으신 것 같아요.',
        chosenAct: DialogueAct.reflect,
      ),
    );

    final result = await harness.handleTurn(
      session: exploreSession(),
      userMessage: '오늘은 그냥 너무 지쳐서 아무것도 생각하기 싫어요.',
    );

    expect(result.assistantMessage.dialogueAct, DialogueAct.reflect);
    expect(result.actChosenByModel, isTrue);
    expect(result.realizationSource, RealizationSource.remoteLlm);
    // explore 상태에서 reflect 행위가 나오면 다음 단계로 앞당겨진다
    // (CounselingStatePolicy._acceleratesFrom, 기존 정책 그대로).
    expect(result.state, CounselingState.reflect);
  });

  test('GPT가 표현을 바꿔도 reflect 목표가 반복되지 않는다', () async {
    // 실제로 실기기에서 재현된 버그: reflect 1턴째 질문을 GPT가 고정 문구와
    // 다르게 표현하면, 2턴째 planner가 텍스트만 보고 "아직 안 물었다"고
    // 오판해 같은(evidence) 목표를 또 골랐다. dialogueGoalId가 그 문장을
    // 만든 harness.handleTurn을 통해 실제로 세션 메시지에 남아야 한다.
    final harness = harnessWith(
      const _FixedResponseRealizer(
        reply: '그 생각이 계속 마음에 걸리시는군요. 그렇게 느끼시게 된 계기가 있었을까요?',
        chosenAct: DialogueAct.socraticQuestion,
      ),
    );
    final session = CounselingSessionState(
      sessionId: 'test',
      currentWeek: 4,
      state: CounselingState.reflect,
    );

    final first = await harness.handleTurn(
      session: session,
      userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
    );
    session.messages.add(
      CounselingMessage(
        id: 'u1',
        role: 'user',
        text: '사람들이 저를 무능하게 볼 것 같아요.',
        createdAt: DateTime.now(),
      ),
    );
    session.messages.add(first.assistantMessage);

    // GPT가 만든 문장이 harness를 거쳐 session에 goal ID와 함께 남았다.
    expect(first.assistantMessage.dialogueGoalId, 'evidence');

    final second = await harness.handleTurn(
      session: session,
      userMessage: '예전에 한 번 막힌 적이 있어요.',
    );

    // 두 번째 턴은 evidence를 반복하지 않고 alternative 목표로 넘어간다.
    expect(second.assistantMessage.dialogueGoalId, 'alternative');
  });

  test('검증에 실패한 선택은 requiredAct/deterministic draft로 되돌아간다', () async {
    final harness = harnessWith(
      const _FixedResponseRealizer(
        reply: 'CBT 기법을 하나 설명해 드릴게요.',
        chosenAct: DialogueAct.psychoeducation,
        isValid: false,
      ),
    );

    final result = await harness.handleTurn(
      session: exploreSession(),
      userMessage: '내일 발표인데 너무 불안해요.',
    );

    expect(result.assistantMessage.dialogueAct, DialogueAct.explore);
    expect(result.actChosenByModel, isFalse);
    expect(result.realizationSource, RealizationSource.deterministic);
  });
}
