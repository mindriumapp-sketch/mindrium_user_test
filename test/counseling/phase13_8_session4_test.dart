// Phase 13.8: dogfood session 4 (week 4, 2026-09-29), replayed on the
// deterministic harness. On device the reflect turns were realized by the
// remote realizer, but every decision below is deterministic.
//   P2: "너가 무슨말 하는지 모르겠어" was chosen as the round's worry and
//       quoted as "the thought" for the balanced-thought technique. The
//       round worry was simply the message before the first goal question.
//   P1: "무슨 말이야", "너가 무슨말 하는지 모르겠어", "뭐라는거야" (the user
//       not understanding the counselor) were treated as worry content.
//       "뭐라는거야" was even credited as the answer to the technique
//       question ("그렇게 보면 … 현실적으로 바라볼 수 있겠네요").
//   P4: after continuing at closing, "잘 모르겠어 / 모르겠어 / 모르겠다니까"
//       got three near-identical clarify questions until the user wrote
//       "짜증나게". Two non-answers in a row now get a no-pressure wrap-up
//       proposal instead of another question.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

/// The user turns of session 4, in order, up to the first closing proposal.
const session4 = [
  '오늘 시험을 못본것 같아',
  '7',
  '문제를 많이 못풀었어',
  '왜 같은 말을 해?',
  '무슨 말이야',
  '너가 무슨말 하는지 모르겠어',
  '지금 무슨 이야기를 하는거야?',
  '뭐라는거야',
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
    final s = CounselingSessionState(sessionId: 'p13_8', currentWeek: 4);
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

  group('P2: target eligibility contract', () {
    const cases = {
      // actual worry thought → eligible
      '발표하다가 말을 못 하면 어떡하지': TargetEligibility.worryThought,
      '오늘 시험을 못본것 같아': TargetEligibility.worryThought,
      '내가 찍은 문제가 다 틀려서 망할까봐 걱정돼': TargetEligibility.worryThought,
      // situation description → not a thought target
      '문제를 많이 못풀었어': TargetEligibility.situation,
      '내일 발표시험이 있어': TargetEligibility.situation,
      // low-information answer → ineligible
      '잘 모르겠어': TargetEligibility.lowInformation,
      '모르겠다니까': TargetEligibility.lowInformation,
      '응': TargetEligibility.lowInformation,
      '7': TargetEligibility.lowInformation,
    };
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      test('$text → ${expected.name}', () {
        expect(UserThoughtExtractor.targetEligibility(text), expected);
      });
    }

    test('an utterance answered with a repair is excluded as interaction', () {
      final messages = [
        CounselingMessage(id: 'u0', role: 'user', text: '오늘 시험을 못본것 같아', createdAt: DateTime(2026)),
        CounselingMessage(id: 'a0', role: 'assistant', text: '…', createdAt: DateTime(2026)),
        CounselingMessage(id: 'u1', role: 'user', text: '왜 같은 말을 해?', createdAt: DateTime(2026)),
        CounselingMessage(
          id: 'a1',
          role: 'assistant',
          text: '…',
          createdAt: DateTime(2026),
          interactionRepairReason: InteractionRepairReason.repeatedQuestion,
        ),
      ];
      final content = UserThoughtExtractor.semanticContent(messages);
      expect(content.where((m) => m.isUser).map((m) => m.text), ['오늘 시험을 못본것 같아']);
    });
  });

  // With P1 the session 4 meta turns are repaired, so the replay never
  // reaches a technique. The target rule must hold on its own, though, for
  // a meta variant the detector misses: build that history directly.
  group('P2: the round worry skips utterances that are not a worry thought', () {
    CounselingMessage u(String t) => CounselingMessage(id: t, role: 'user', text: t, createdAt: DateTime(2026));
    CounselingMessage a({String? goal}) => CounselingMessage(
      id: 'a${goal ?? ''}${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      text: '…?',
      createdAt: DateTime(2026),
      dialogueGoalId: goal,
    );

    test('no goal question at all (reflect ended on clarify/repair turns)', () {
      final history = [
        u('오늘 시험을 못본것 같아'), a(),
        u('7'), a(),
        u('문제를 많이 못풀었어'), a(),
        u('너가 무슨말 하는지 모르겠어'), a(), // an undetected meta variant
        u('지금 무슨 이야기를 하는거야?'), a(),
      ];
      expect(UserThoughtExtractor.roundWorryThought(history), '오늘 시험을 못본것 같아');
    });

    test('the message right before the first goal question is not a thought', () {
      final history = [
        u('오늘 시험을 못본것 같아'), a(),
        u('7'), a(),
        u('뭔 소린지 잘'), a(goal: 'evidence'),
        u('예전에도 망친 적이 있어'), a(goal: 'alternative'),
      ];
      expect(UserThoughtExtractor.roundWorryThought(history), '오늘 시험을 못본것 같아');
    });

    test('low-info and situation utterances are never the worry', () {
      final history = [u('문제를 많이 못풀었어'), a(), u('몰라'), a(goal: 'evidence')];
      expect(UserThoughtExtractor.roundWorryThought(history), isNull);
    });
  });

  group('P1: assistant-not-understood detection (cue composition)', () {
    InteractionRepairReason? detect(String m, [CounselingState state = CounselingState.reflect]) =>
        const PolicyPipelineTurnPlanner()
            .plan(TurnPlanningContext(state: state, userMessage: m, knowledge: const []))
            ?.interactionRepairReason;

    const understoodNot = [
      // session 4, verbatim
      '무슨 말이야',
      '너가 무슨말 하는지 모르겠어',
      '지금 무슨 이야기를 하는거야?',
      '뭐라는거야',
      // same meaning, other surfaces (dev set)
      '그게 무슨 뜻이야?',
      '방금 한 말이 이해가 안 돼요',
      '무슨 소리예요',
      '질문이 헷갈려',
    ];
    const notAboutAssistant = [
      '잘 모르겠어', // low-info answer, not confusion about the counselor
      '모르겠다니까',
      '선생님이 무슨 말 하는지 모르겠어', // third party: worry content
      '무슨 말을 해야 할지 모르겠어', // the user can't find words
      '시험 문제가 무슨 뜻인지 몰라서 못 풀었어',
      '발표 때 무슨 말을 할지 헷갈려요',
    ];
    for (final m in understoodNot) {
      test('detected: $m', () => expect(detect(m), InteractionRepairReason.assistantNotUnderstood));
    }
    for (final m in notAboutAssistant) {
      test('not detected: $m', () => expect(detect(m), isNot(InteractionRepairReason.assistantNotUnderstood)));
    }
    test('repetition complaints keep their own reason', () {
      expect(detect('왜 같은 말을 해?'), InteractionRepairReason.repeatedQuestion);
    });
  });

  test('P1: each not-understood turn is repaired with a simpler re-ask, never content', () async {
    final replies = await run(session4);
    for (final (i, t) in session4.indexed) {
      if (!{'무슨 말이야', '너가 무슨말 하는지 모르겠어', '지금 무슨 이야기를 하는거야?', '뭐라는거야'}.contains(t)) {
        continue;
      }
      final r = replies[i];
      expect(r.interactionRepairReason, InteractionRepairReason.assistantNotUnderstood, reason: '$t -> ${r.text}');
      // The first one re-asks plainly; from the second on (P4) it's the
      // wrap-up proposal, then the proposal asked again plainly.
      if (t == '무슨 말이야') {
        expect(r.text, startsWith('제 말이 헷갈리게 들렸나 봐요.'), reason: r.text);
      }
      expect(r.text.trim().endsWith('?'), isTrue, reason: 'no re-ask: ${r.text}');
      expect(r.interventionStep, isNot(InterventionStep.integration), reason: r.text);
    }
  });

  test('P1: a not-understood reply to the technique question is not credited; the next real answer is', () async {
    final replies = await run([
      '내일 발표가 있어서 불안해요',
      '7점이요',
      '발표하다가 말을 못 하면 어떡하지',
      '예전에 발표하다 말이 막힌 적이 있어요',
      '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
      '뭐라는거야',
      '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
    ]);
    final confused = replies[5];
    expect(replies[4].interventionStep, InterventionStep.prompt);
    expect(confused.interactionRepairReason, InteractionRepairReason.assistantNotUnderstood);
    expect(confused.interventionStep, isNull);
    expect(confused.text, contains('균형'), reason: 'the re-ask is about the same technique: ${confused.text}');
    expect(replies[6].interventionStep, InterventionStep.integration);
  });

  group('P4: two non-answers in a row offer to wrap up', () {
    const cooperative = [
      '오늘 시험을 봤는데 잘 못본 것 같아',
      '9',
      '내가 찍은 문제가 다 틀려서 망할까봐 걱정돼',
      '딱히 없어. 그냥 불안해',
      '공부를 열심히 했으면 잘 봤겠지만 그렇지 못해서 망한 것 같아',
      '문제를 다 틀려도 망한 것은 아니야. 다음에도 기회가 있어',
    ];

    test('session 4 after continuing: the second non-answer gets the proposal, not a third question', () async {
      final replies = await run([
        ...cooperative,
        '더 이야기 하자',
        '잘 모르겠어',
        '모르겠어',
        '모르겠다니까',
      ]);
      final reopen = replies.indexWhere((m) => m.closingStep == ClosingStep.continued);
      expect(reopen, 6);
      final first = replies[reopen + 1];
      expect(first.earlyWrapUp, isNull, reason: 'one more try after the first non-answer');
      expect(first.text.trim().endsWith('?'), isTrue);
      final second = replies[reopen + 2];
      expect(second.earlyWrapUp, EarlyWrapUp.lowInformation, reason: second.text);
      expect(second.closingStep, ClosingStep.proposed);
      expect(second.text, contains('오늘은 여기까지 정리해 볼까요'));
      expect(replies.last.closingStep, ClosingStep.finalized, reason: replies.last.text);
    });

    test('a number (the SUD answer) does not start a streak', () async {
      final replies = await run(['내일 시험이 있어', '7', '몰라']);
      expect(replies.last.earlyWrapUp, isNull, reason: replies.last.text);
    });

    test('two not-understood turns in a row offer to wrap up', () async {
      final replies = await run(session4.take(6).toList());
      expect(replies[4].interactionRepairReason, InteractionRepairReason.assistantNotUnderstood);
      expect(replies[4].earlyWrapUp, isNull);
      expect(replies[5].earlyWrapUp, EarlyWrapUp.notUnderstood, reason: replies[5].text);
      expect(replies[5].closingStep, ClosingStep.proposed);
    });

    test('not understanding the proposal re-asks it plainly; then an answer finalizes', () async {
      final replies = await run([...session4.take(6), '무슨 말이야', '응']);
      final reask = replies[6];
      expect(reask.interactionRepairReason, InteractionRepairReason.assistantNotUnderstood);
      expect(reask.closingStep, ClosingStep.proposed, reason: reask.text);
      expect(reask.text.trim().endsWith('?'), isTrue);
      expect(replies.last.closingStep, ClosingStep.finalized, reason: replies.last.text);
    });

    for (final (answer, step) in [
      ('몰라', ClosingStep.finalized),
      ('잘 모르겠어', ClosingStep.finalized),
      ('아니, 조금 더 할래', ClosingStep.continued),
    ]) {
      test('answer to a proposal "$answer" → ${step.name}', () async {
        final replies = await run([...cooperative, answer]);
        expect(replies[replies.length - 2].closingStep, ClosingStep.proposed);
        expect(replies.last.closingStep, step, reason: replies.last.text);
      });
    }
  });
}
