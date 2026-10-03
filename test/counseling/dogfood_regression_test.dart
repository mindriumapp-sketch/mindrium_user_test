// Phase 13.7 device dogfood, session 1 (week 4), replayed on the
// deterministic harness. On device the reflect turns were realized by the
// remote realizer, but every decision below is deterministic.
//   D1: a real balanced thought containing "다음에" was treated as a
//       request to stop and got the no-pressure acknowledgment.
//   D2: "정리해보자" at the closing proposal reopened the session instead
//       of finalizing it.
//   D3: "혼날것같아" (no space in "것 같") wasn't recognized as a thought, so
//       reflect clarified once more.
// Sessions 2 and 3 (same day):
//   E1: two low-info answers in a row got the same opening sentence twice.
//   E2: a two-sentence worry message was quoted whole as "the thought".
//   E3: after a closing continuation the reflect goals were already used up
//       session-wide, so the new round jumped to a no-question recovery that
//       quoted "잘 모르겠어" (a 반말 low-info reply the detector missed); the
//       user could only answer "네?".
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

    // Phase 4: an explicit end ends the session; "다음에 이야기할게요" (a
    // postponement) still gets the no-pressure acknowledgment.
    for (final t in ['오늘은 여기까지 할게요', '그만할래요']) {
      test('end: $t', () async => expect(await integrationFor(t), startsWith('오늘 이야기 나눠 주셔서 감사합니다')));
    }
    test('stop: 다음에 이야기할게요', () async => expect(await integrationFor('다음에 이야기할게요'), contains('바로 떠오르지 않아도')));
    for (final t in ['다음에는 더 잘할 수 있을 것 같아요', '한 번 실수해도 그만큼 배울 수 있어요']) {
      test('answer: $t', () async => expect((await integrationFor(t)).contains('바로 떠오르지 않아도'), isFalse));
    }
  });

  // Session 2: the second low-info answer, and the worry quote.
  const session2 = [
    '내일 발표시험이 있어',
    '8',
    '처음 해보는 발표 시험이라 너무 긴장되고 떨려. 실수할까봐 걱정돼',
    '내가 사람들한테 집중당하는걸 무서워해서 발표를 잘 못해. 그런데 이런 발표로 시험까지 봐야하니까 너무 걱정돼',
    '몰라',
    '모르겠어',
    '정리하자',
  ];

  String firstSentence(String text) => text.split(RegExp(r'(?<=[.!?])\s')).first;

  test('E1: consecutive low-info answers do not get the same opening twice', () async {
    final replies = await run(session2);
    final prompt = replies.firstWhere((m) => m.interventionStep == InterventionStep.prompt);
    final integration = replies.firstWhere((m) => m.interventionStep == InterventionStep.integration);
    expect(firstSentence(integration.text), isNot(firstSentence(prompt.text)),
        reason: '${prompt.text}\n${integration.text}');
    expect(replies.last.closingStep, ClosingStep.finalized);
  });

  test('E2: only the thought sentence of a multi-sentence worry is quoted', () async {
    final replies = await run(session2);
    final prompt = replies.firstWhere((m) => m.interventionStep == InterventionStep.prompt);
    expect(prompt.text, contains('“실수할까봐 걱정돼”'), reason: prompt.text);
  });

  // Session 3: continue at closing, then a new round.
  const session3 = [
    '오늘 시험을 봤는데 잘 못본 것 같아',
    '9',
    '모르는 문제가 너무 많아서 못풀었어',
    '내가 찍은 문제가 다 틀려서 망할까봐 걱정돼',
    '딱히 없어. 그냥 불안해',
    '공부를 열심히 했으면 잘 봤겠지만 그렇지 못해서 망한 것 같아',
    '문제를 다 틀려도 망한 것은 아니야. 다음에도 기회가 있어',
    '더 이야기하자',
    '내일 시험은 잘 볼 수 있을까',
    '잘 모르겠어',
    '내일 시험도 망할까봐 무서워',
    '예전에도 연달아 망친 적이 있어',
    '한 번 망쳤다고 내일도 망하는 건 아니야',
    '정리하자',
  ];

  test('E3: a reopened round asks its own questions, never a dead-end statement', () async {
    final replies = await run(session3);
    final reopen = replies.indexWhere((m) => m.closingStep == ClosingStep.continued);
    expect(reopen, greaterThan(0));
    final after = replies.skip(reopen + 1).toList();
    for (final (i, m) in after.indexed) {
      if (m.closingStep == ClosingStep.finalized) continue;
      // Phase 14.3: the one question-less turn allowed is the listening turn
      // that replaces a repeated clarify (right after a clarify question).
      if (m.goalExhaustionRecovery == GoalExhaustionRecovery.listenWithoutQuestion &&
          i > 0 && after[i - 1].isClarify) {
        continue;
      }
      expect(m.goalExhaustionRecovery, isNull, reason: m.text);
      expect(m.text.trim().endsWith('?'), isTrue, reason: 'no question: ${m.text}');
    }
    expect(replies.last.closingStep, ClosingStep.finalized, reason: replies.last.text);
  });

  test('E3: a 반말 low-info reply is never quoted', () async {
    final replies = await run(session3);
    for (final m in replies) {
      expect(m.text.contains('잘 모르겠어”'), isFalse, reason: m.text);
    }
  });

  // Since 13.9D the first round is one turn shorter (the opening worry is
  // recognized), so this replay's later turns land differently; what E3
  // guards is that the reopened round never falls back on the first
  // round's worry, and that it ends with a proposal.
  test('E3: the reopened round works on its own worry', () async {
    final replies = await run(session3);
    final reopen = replies.indexWhere((m) => m.closingStep == ClosingStep.continued);
    expect(reopen, greaterThan(0));
    final after = replies.skip(reopen + 1).toList();
    for (final m in after) {
      expect(m.text.contains('찍은 문제가'), isFalse, reason: m.text);
    }
    expect(after.map((m) => m.closingStep), contains(ClosingStep.proposed),
        reason: after.map((m) => m.text).join('\n'));
  });
}
