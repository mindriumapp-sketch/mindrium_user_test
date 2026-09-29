// Phase 13.7 device dogfood, session 1 (week 4), replayed on the
// deterministic harness. On device the reflect turns were realized by the
// remote realizer, but every decision below is deterministic.
//   D1: a real balanced thought containing "다음에" was treated as a
//       request to stop and got the no-pressure acknowledgment.
//   D2: "정리해보자" at the closing proposal reopened the session instead
//       of finalizing it.
//   D3: "혼날것같아" (no space in "것 같") wasn't recognized as a thought, so
//       reflect clarified once more.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

// On device an extra turn, "선생님한테 혼날 것 같아", answered the clarify
// question D3 caused. With D3 fixed that question isn't asked, so the
// replay leaves the turn out and the later answers line up with the
// questions they answered on device.
const _session = [
  '내일 시험이 있는데 걱정돼',
  '7',
  '내일 시험을 못봐서 혼날것같아',
  '저번 중간고사때 시험을 못봐서 혼났어',
  '앞으로 더 열심히 준비해야겠다는 생각이 들어',
  '선생님한테 혼나도 괜찮아, 다음에 더 열심히 하면 돼',
  '정리해보자',
];

void main() {
  late LocalCbtKnowledgeRepository repo;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
  });

  Future<List<CounselingMessage>> run(List<String> turns) async {
    final h = CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repo,
    );
    final s = CounselingSessionState(sessionId: 'p13_7', currentWeek: 4);
    final replies = <CounselingMessage>[];
    for (final (i, t) in turns.indexed) {
      final r = await h.handleTurn(session: s, userMessage: t);
      s.messages
        ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
        ..add(r.assistantMessage);
      replies.add(r.assistantMessage);
      if (r.assistantMessage.closingStep == ClosingStep.finalized) break;
    }
    return replies;
  }

  test('D3: "것같" without a space is a thought', () {
    expect(UserThoughtExtractor.thoughtShaped('내일 시험을 못봐서 혼날것같아'), isNotNull);
  });

  test('D3: the unspaced thought is reflected on, not clarified again', () async {
    final replies = await run(_session.take(3).toList());
    expect(replies[2].dialogueGoalId, 'evidence', reason: replies[2].text);
  });

  test('D1: a balanced thought mentioning "다음에" is integrated as an answer', () async {
    final replies = await run(_session);
    final integration = replies.firstWhere(
      (m) => m.interventionStep == InterventionStep.integration,
    );
    expect(integration.text.contains('바로 떠오르지 않아도'), isFalse, reason: integration.text);
  });

  test('D2: "정리해보자" at the closing proposal finalizes the session', () async {
    final replies = await run(_session);
    expect(replies.last.closingStep, ClosingStep.finalized, reason: replies.last.text);
    expect(replies.where((m) => m.closingStep == ClosingStep.continued), isEmpty);
  });

  group('closing answers', () {
    Future<ClosingStep?> answer(String text) async {
      final replies = await run([
        '내일 발표가 있어서 불안해요',
        '7점이요',
        '발표하다가 말을 못 하면 어떡하지',
        '예전에 발표하다 말이 막힌 적이 있어요',
        '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
        '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
        text,
      ]);
      expect(replies[replies.length - 2].closingStep, ClosingStep.proposed);
      return replies.last.closingStep;
    }

    for (final t in ['정리해보자', '정리할게요', '이제 마무리하자', '오늘은 여기까지 할게', '그래 끝내자']) {
      test('finalizes: $t', () async => expect(await answer(t), ClosingStep.finalized));
    }
    for (final t in ['아니요, 조금 더 이야기하고 싶어요', '아직 정리하기엔 이른 것 같아요', '사실 교수님 반응이 제일 걱정돼요']) {
      test('continues: $t', () async => expect(await answer(t), ClosingStep.continued));
    }
  });

  group('stop requests vs "다음에" in an answer', () {
    Future<String> integrationFor(String answer) async {
      final replies = await run([
        '내일 발표가 있어서 불안해요',
        '7점이요',
        '발표하다가 말을 못 하면 어떡하지',
        '예전에 발표하다 말이 막힌 적이 있어요',
        '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
        answer,
      ]);
      return replies.last.text;
    }

    for (final t in ['오늘은 여기까지 할게요', '그만할래요', '다음에 이야기할게요']) {
      test('stop: $t', () async => expect(await integrationFor(t), contains('바로 떠오르지 않아도')));
    }
    for (final t in ['다음에는 더 잘할 수 있을 것 같아요', '한 번 실수해도 그만큼 배울 수 있어요']) {
      test('answer: $t', () async => expect((await integrationFor(t)).contains('바로 떠오르지 않아도'), isFalse));
    }
  });
}
