// Phase 12.3 (N2 root cause): the realization request's recent conversation
// did not contain the user's current message. CounselingProvider only synced
// session.messages before the turn inside the instant-empathy branch, which
// Phase 10.6C-DOGFOOD disabled. The model then saw a conversation ending on
// its own previous question and repeated it (6/6 and 8/8 in replays of
// dogfood sessions 4 and 5; 0/6 once the current message is present).
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
import 'package:gad_app_team/features/counseling/safety_gate.dart';

class _CaptureApi implements CounselingRealizeApi {
  List<Map<String, String>> recent = const [];
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
    recent = recentConversation;
    return {'request_id': requestId, 'reply': deterministicDraft, 'chosen_act': requiredAct};
  }
}

CounselingMessage _m(String role, String text, int i) => CounselingMessage(
  id: '$role$i',
  role: role,
  text: text,
  createdAt: DateTime(2026, 9, 28),
);

void main() {
  late LocalCbtKnowledgeRepository repo;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
  });

  CounselingHarness harness(_CaptureApi api) => CounselingHarness.remoteGpt(
    llm: MockLlmService(),
    safetyGate: const KeywordSafetyGate(),
    knowledgeRepository: repo,
    responseRealizer: RemoteLlmRealizer(api: api),
    rolloutConfig: const RolloutConfig(enabled: true, stage: RolloutStage.internalOnly),
    isInternalAccount: true,
  );

  const current = '내일 시험인데 공부를 많이 못했어. 준비한 것보다 못볼까봐 걱정이야';
  const previousQuestion = '내일 시험이 있다는 사실이 불안하게 느껴지시는군요. 그 감정을 느끼게 된 구체적인 계기는 무엇인가요?';

  test('production sync (history appended after the turn): the current message reaches the realizer', () async {
    final api = _CaptureApi();
    final session = CounselingSessionState(
      sessionId: 's5',
      currentWeek: 4,
      state: CounselingState.reflect,
      totalTurns: 2,
      messages: [_m('user', '9', 0), _m('assistant', previousQuestion, 0)],
    );
    await harness(api).handleTurn(session: session, userMessage: current);
    expect(api.recent.last, {'role': 'user', 'text': current});
    expect(api.recent.first, {'role': 'assistant', 'text': previousQuestion});
  });

  test('instant-empathy sync (history already has the current message): not duplicated', () async {
    final api = _CaptureApi();
    final session = CounselingSessionState(
      sessionId: 's5b',
      currentWeek: 4,
      state: CounselingState.reflect,
      totalTurns: 2,
      messages: [
        _m('assistant', previousQuestion, 0),
        _m('user', current, 1),
      ],
    );
    await harness(api).handleTurn(session: session, userMessage: current);
    expect(api.recent.where((m) => m['text'] == current), hasLength(1));
  });

  test('selector view is unchanged: session history is not mutated', () async {
    final api = _CaptureApi();
    final session = CounselingSessionState(
      sessionId: 's5c',
      currentWeek: 4,
      state: CounselingState.reflect,
      totalTurns: 2,
      messages: [_m('user', '9', 0), _m('assistant', previousQuestion, 0)],
    );
    await harness(api).handleTurn(session: session, userMessage: current);
    expect(session.messages, hasLength(2));
    expect(session.messages.last.text, previousQuestion);
  });
}
