// Phase 13.8 P3: remote realization is decided by what the turn is, not by
// the state it happens in. Dogfood session 4 (2026-09-29): in reflect,
// "왜 같은 말을 해?" was answered with "같은 질문을 반복하셨다는 점을
// 인정하며, 이제는 말씀하신 내용을 바탕으로 진행하겠다는 의지를
// 보이셨습니다." The router allowed the remote realizer for every
// explore/reflect turn, so it rewrote the deterministic repair sentence.
// Repair and goal-exhaustion recovery turns must stay deterministic.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

/// Answers every request with the sentence seen on device, in the
/// required act, so it would be accepted wherever it is attempted.
class _DeviceParaphraseApi implements CounselingRealizeApi {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs = const [],
    String? affect,
    String tone = 'warm, calm, concise',
    List<Map<String, String>> recentConversation = const [],
    List<String> allowedCbtFacts = const [],
    List<String> forbiddenBehaviors = const [],
    String promptVersion = 'remote-realizer-v1',
    Duration timeout = const Duration(seconds: 8),
    int? sudRatingValue,
  }) async {
    calls++;
    return {
      'request_id': requestId,
      'reply': '같은 질문을 반복하셨다는 점을 인정하며, 이제는 말씀하신 내용을 바탕으로 진행하겠다는 의지를 보이셨습니다.',
      'chosen_act': requiredAct,
      'model': 'device-paraphrase-fake',
      'prompt_version': promptVersion,
      'latency_ms': 1,
    };
  }
}

void main() {
  late LocalCbtKnowledgeRepository repo;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
  });

  CounselingHarness remote(_DeviceParaphraseApi api) => CounselingHarness.remoteGpt(
    llm: MockLlmService(),
    safetyGate: const KeywordSafetyGate(),
    knowledgeRepository: repo,
    responseRealizer: RemoteLlmRealizer(api: api),
    rolloutConfig: const RolloutConfig(enabled: true, stage: RolloutStage.internalOnly),
    isInternalAccount: true,
  );

  Future<List<CounselingTurnResult>> run(
    CounselingHarness h,
    CounselingSessionState s,
    List<String> turns,
  ) async {
    final results = <CounselingTurnResult>[];
    for (final (i, t) in turns.indexed) {
      final r = await h.handleTurn(session: s, userMessage: t);
      s.messages
        ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
        ..add(r.assistantMessage);
      results.add(r);
    }
    return results;
  }

  test('P3: the session 4 repair turn in reflect is not sent to the remote realizer', () async {
    final api = _DeviceParaphraseApi();
    final s = CounselingSessionState(sessionId: 'p3', currentWeek: 4);
    final results = await run(remote(api), s, [
      '오늘 시험을 못본것 같아',
      '7',
      '문제를 많이 못풀었어',
      '왜 같은 말을 해?',
    ]);
    final repair = results.last;
    expect(repair.stateBefore, CounselingState.reflect);
    expect(repair.assistantMessage.interactionRepairReason, isNotNull);
    expect(repair.routing!.allowLlm, isFalse);
    expect(repair.realizationSource, RealizationSource.deterministic);
    expect(repair.assistantMessage.text, repair.turnPlan!.deterministicReply);
    expect(repair.assistantMessage.text.contains('의지를 보이셨습니다'), isFalse);
  });

  test('P3: a goal-exhaustion recovery turn is not sent to the remote realizer', () async {
    final api = _DeviceParaphraseApi();
    final s = CounselingSessionState(
      sessionId: 'p3r',
      currentWeek: 4,
      state: CounselingState.reflect,
      messages: [
        for (final (i, g) in ['evidence', 'alternative', 'probability'].indexed)
          CounselingMessage(
            id: 'g$i',
            role: 'assistant',
            text: 'goal:$g',
            createdAt: DateTime(2026),
            dialogueAct: DialogueAct.socraticQuestion,
            dialogueGoalId: g,
          ),
      ],
    );
    final results = await run(remote(api), s, ['그래도 여전히 걱정돼요.']);
    final recovery = results.single;
    expect(recovery.assistantMessage.goalExhaustionRecovery, isNotNull);
    expect(recovery.routing!.allowLlm, isFalse);
    expect(recovery.realizationSource, RealizationSource.deterministic);
  });

  test('control: an ordinary reflect question is still offered to the remote realizer', () async {
    final api = _DeviceParaphraseApi();
    final s = CounselingSessionState(sessionId: 'p3c', currentWeek: 4);
    final results = await run(remote(api), s, [
      '오늘 시험을 못본것 같아',
      '7',
      '시험을 망쳐서 혼날 것 같아',
    ]);
    final reflect = results.last;
    expect(reflect.stateBefore, CounselingState.reflect);
    expect(reflect.assistantMessage.dialogueGoalId, isNotNull);
    expect(reflect.routing!.allowLlm, isTrue);
    expect(api.calls, greaterThan(0));
  });
}
