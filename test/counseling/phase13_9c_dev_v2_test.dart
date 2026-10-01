// Phase 13.9C: dev set v2 for the semantic-category detectors. Holdout v1
// failed and has been seen, so the categories it exposed are widened here
// on new phrasings written for this purpose (not copied from v1). The gate
// moves to a fresh blind holdout v2. Each positive has a worry-content
// counterpart that must stay content.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

InteractionRepairReason? _detect(String m) => const PolicyPipelineTurnPlanner()
    .plan(TurnPlanningContext(state: CounselingState.reflect, userMessage: m, knowledge: const []))
    ?.interactionRepairReason;

const _notUnderstood = [
  '무슨 뜻인지 잘 모르겠어요 다시 말씀해 주실래요?', // rephrase request
  '좀 더 쉽게 물어봐 줄 수 있어?',
  '다시 설명해 줘',
  '뭘 말하라는 건지 모르겠네', // what do you want from me
  '그러니까 내가 뭘 하면 되는데?',
  '이해가 잘 안 가요', // short reaction
  '뭔 소린지',
  '근거라는 게 뭐예요?', // a term the counselor used
  '질문이 너무 어려워요', // evaluating the question
  '어떻게 대답해야 할지 모르겠어 질문이 뭐야',
  '짧게 좀 말해 줘', // 13.9D: a request about how the counselor talks
];

const _repetition = [
  '같은 거 계속 물어보네',
  '그건 아까 다 말했잖아',
  '또 똑같은 질문이야',
  '몇 번을 말해야 돼',
  '벌써 얘기했는데요',
];

const _stopOrFrustration = [
  '그냥 내 말 들어주면 좋겠어',
  '묻지 말고 들어만 줘',
  '이런 거 해봤자 소용없어',
  '이 상담 별로 도움 안 돼요',
  '이거 해서 뭐가 바뀌는데',
  '이런 얘기는 별로 와닿지 않네요', // 13.9D: "doesn't land"
];

const _nonAnswers = [
  '생각 안 나요',
  '없어요',
  '음 그냥요',
  '딱히 없는데요',
  '아무것도 안 떠올라',
  'ㅇㅋ',
  '그런 거 없어',
];

/// Worry content that shares words with the categories above.
const _worryContent = [
  '시험 문제를 다시 풀어봐도 이해가 안 돼서 걱정이에요',
  '교수님 질문이 너무 어려워서 대답을 못 할까 봐 무서워요',
  '발표 때 다시 설명해 달라고 하면 어떡하지',
  '친구가 자꾸 같은 거 물어봐서 짜증나',
  '공부를 해봤자 소용없을 것 같아요',
  '부모님이 내 말을 안 들어줘요',
  '시험이 없어서 다행인데 다음 주가 걱정돼',
  '면접에서 뭘 말해야 할지 몰라서 불안해',
  '강의 내용이 와닿지 않아서 시험이 걱정돼요',
];

void main() {
  group('not understood', () {
    for (final m in _notUnderstood) {
      test(m, () => expect(_detect(m), InteractionRepairReason.assistantNotUnderstood));
    }
  });
  group('repetition complaint', () {
    for (final m in _repetition) {
      test(m, () => expect(_detect(m), InteractionRepairReason.repeatedQuestion));
    }
  });
  group('stop or frustration', () {
    for (final m in _stopOrFrustration) {
      test(m, () => expect(_detect(m), isIn([
            InteractionRepairReason.stopQuestioning,
            InteractionRepairReason.processFrustration,
          ])));
    }
  });
  group('non-answers are low information', () {
    for (final m in _nonAnswers) {
      test(m, () => expect(UserThoughtExtractor.isLowInformation(m), isTrue));
    }
  });
  group('worry content stays content', () {
    for (final m in _worryContent) {
      test(m, () {
        expect(_detect(m), isNull);
        expect(UserThoughtExtractor.isLowInformation(m), isFalse);
      });
    }
  });

  // Holdout v1 has been seen, so it can't certify these detectors; its
  // worry-that-looks-meta lines are kept only as a false-positive
  // regression.
  group('holdout v1 worry lines stay content (regression only)', () {
    final raw = jsonDecode(
      File('test/counseling/evaluation/fixtures/phase13_9b_holdout.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final m in (raw['worry_that_looks_meta'] as List).cast<String>()) {
      test(m, () => expect(_detect(m), isNull));
    }
  });

  // Phase 13.9D (a)/(c): found by holdout v2. A worry thought stated only in
  // the opening message was never picked up by reflect, so a cooperative
  // user got clarify questions, and the no-progress net (S3) then offered to
  // wrap up. New phrasings, not v2's.
  group('13.9D: the opening worry is the thought reflect works on', () {
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
      final s = CounselingSessionState(sessionId: 'd9', currentWeek: 4);
      final replies = <CounselingMessage>[];
      for (final (i, t) in turns.indexed) {
        final r = await h.handleTurn(session: s, userMessage: t);
        s.messages
          ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        replies.add(r.assistantMessage);
      }
      return replies;
    }

    test('a cooperative user who only said the worry up front gets goal questions, not a wrap-up', () async {
      final replies = await run([
        '다음 달 실기 시험에서 손이 떨려서 망칠 것 같아',
        '8',
        '연습 때도 손이 떨려서 실수한 적이 있어',
        '그래도 연습을 계속하면 좀 나아질 수도 있겠지',
        '작년엔 결국 통과했으니까',
      ]);
      expect(replies.map((m) => m.earlyWrapUp), everyElement(isNull),
          reason: replies.map((m) => m.text).join('\n'));
      expect(replies.map((m) => m.dialogueGoalId), contains('evidence'),
          reason: replies.map((m) => m.text).join('\n'));
    });

    test('with nothing usable in the round, the no-progress net still offers to wrap up', () async {
      final replies = await run(['요즘 좀 그래', '5', '글쎄 뭐', '그냥 그렇다니까', '딱히 뭐 없어']);
      expect(replies.map((m) => m.earlyWrapUp).whereType<EarlyWrapUp>(), isNotEmpty,
          reason: replies.map((m) => m.text).join('\n'));
    });
  });

  group('13.9D: what counts as an answer to a technique question', () {
    const answers = [
      '떨려도 끝까지 해내면 그걸로 충분하다',
      '망친다고 다 끝나는 건 아니겠지..?',
      '점수가 안 나와도 다시 준비하면 돼요',
    ];
    const talkingBack = [
      '균형 있게라는 게 무슨 기준인데',
      '그러면 정답이 있는 거예요?',
      '자꾸 어려운 것만 시키시네요',
    ];
    for (final m in answers) {
      test('answer: $m', () => expect(UserThoughtExtractor.isTechniqueAnswer(m), isTrue));
    }
    for (final m in talkingBack) {
      test('not an answer: $m', () => expect(UserThoughtExtractor.isTechniqueAnswer(m), isFalse));
    }
  });

  group('13.9E: technique credit needs evidence of the technique', () {
    const reframes = ['긴장돼도 연습한 만큼은 할 수 있을 거야', '한 번 떨어진다고 끝은 아니지'];
    const noMove = ['오늘 따라 좀 피곤하네요', '이상하게 대화가 계속 겉도는 느낌'];
    for (final m in reframes) {
      test('reframe: $m', () => expect(UserThoughtExtractor.showsTechniqueMove(m, 'balancedThought'), isTrue));
    }
    for (final m in noMove) {
      test('no reframe: $m', () => expect(UserThoughtExtractor.showsTechniqueMove(m, 'balancedThought'), isFalse));
    }
    test('a question back in the first sentence is not an answer', () {
      expect(UserThoughtExtractor.isTechniqueAnswer('그게 정확히 뭔데요? 잘 모르겠네'), isFalse);
    });
  });

  group('13.9E: a wish to continue at the proposal is not a complaint', () {
    InteractionRepairReason? closingGuard(String m) => const DeterministicProcessSignalTurnPlanner()
        .plan(TurnPlanningContext(
          state: CounselingState.closing,
          userMessage: m,
          knowledge: const [],
          recentMessages: [
            CounselingMessage(
              id: 'p',
              role: 'assistant',
              text: '오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?',
              createdAt: DateTime(2026),
              closingStep: ClosingStep.proposed,
            ),
          ],
        ))
        ?.interactionRepairReason;
    test('continue: 끝내지 말고 조금 더 내 얘기 들어줘', () => expect(closingGuard('끝내지 말고 조금 더 내 얘기 들어줘'), isNull));
    test('complaint still ends: 계속 똑같은 거만 물어보고 짜증나네', () => expect(closingGuard('계속 똑같은 거만 물어보고 짜증나네'), isNotNull));
  });

  group('13.10 dogfood (2026-10-02)', () {
    late LocalCbtKnowledgeRepository repo;
    setUpAll(() async {
      repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
      await repo.initialize();
    });
    Future<List<CounselingMessage>> run(List<String> turns) async {
      final h = CounselingHarness.deterministic(
        llm: MockLlmService(), safetyGate: const KeywordSafetyGate(), knowledgeRepository: repo);
      final s = CounselingSessionState(sessionId: 'd10', currentWeek: 4);
      final out = <CounselingMessage>[];
      for (final (i, t) in turns.indexed) {
        final r = await h.handleTurn(session: s, userMessage: t);
        s.messages
          ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        out.add(r.assistantMessage);
      }
      return out;
    }

    test('a complaint in the wrap-up turn is acknowledged', () async {
      final r = await run(['내일 회의때 발표를 해야되는데 긴장돼', '8', '모르겠어', '아니 이유를 딱히 모르겠다고', '모른다니까 왜 계속 물어봐']);
      final wrap = r.lastWhere((m) => m.earlyWrapUp != null, orElse: () => r.last);
      expect(wrap.earlyWrapUp, isNotNull, reason: r.map((m) => m.text).join('\n'));
      expect(wrap.text, startsWith('계속 질문이 이어져서 답답하셨을 것 같아요.'));
    });

    test('asking for more after the one continuation ends with that wish acknowledged', () async {
      final h = CounselingHarness.deterministic(
        llm: MockLlmService(), safetyGate: const KeywordSafetyGate(), knowledgeRepository: repo);
      final s = CounselingSessionState(sessionId: 'd10b', currentWeek: 4);
      final answers = [
        '내일 발표가 있어서 불안해요', '7점이요', '발표하다가 말을 못 하면 어떡하지',
        '예전에 발표하다 말이 막힌 적이 있어요', '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
        '교수님이 실망하실 것 같아', '전에 한 번 지적받은 적 있어', '실수해도 다음에 만회할 수 있어',
      ];
      var a = 0;
      var proposals = 0;
      CounselingMessage? last;
      for (var t = 0; t < 18; t++) {
        final String text;
        if (last?.closingStep == ClosingStep.proposed) {
          proposals++;
          text = proposals == 1 ? '더 이야기하고 싶어' : '너가 예시로 설명해주면 도움이 될 것 같아';
        } else {
          text = answers[a++ % answers.length];
        }
        final r = await h.handleTurn(session: s, userMessage: text);
        s.messages
          ..add(CounselingMessage(id: 'u$t', role: 'user', text: text, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        last = r.assistantMessage;
        if (last.closingStep == ClosingStep.finalized) break;
      }
      expect(proposals, 2);
      expect(last!.closingStep, ClosingStep.finalized);
      expect(last.text, startsWith('더 이야기 나누고 싶은 마음 잘 알겠어요.'));
    });
  });

  // 13.10 dogfood session 2 (2026-10-02): a cooperative user who stated a
  // doubt-form worry ("…건 아닐까 걱정되네") was offered a wrap-up twice.
  group('13.10: doubt-form worries are worries', () {
    for (final m in [
      '계속 피곤한게 건강에 문제가 생긴건 아닐까 걱정되네',
      '요즘 피곤한데 몸이 안좋은게 아닐까 걱정된다고',
      '요즘 너무 피곤해, 내 몸이 안좋은걸까',
      '이번에도 떨어지는 건 아닌가 싶어요',
    ]) {
      test(m, () => expect(UserThoughtExtractor.thoughtShaped(m), isNotNull));
    }
    for (final m in ['오늘 날씨가 좋을까', '점심 뭐 먹을까']) {
      test('not a worry: $m', () => expect(UserThoughtExtractor.thoughtShaped(m), isNull));
    }

    late LocalCbtKnowledgeRepository repo;
    setUpAll(() async {
      repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
      await repo.initialize();
    });
    test('the device session is not cut off', () async {
      final h = CounselingHarness.deterministic(
        llm: MockLlmService(), safetyGate: const KeywordSafetyGate(), knowledgeRepository: repo);
      final s = CounselingSessionState(sessionId: 'd10c', currentWeek: 4);
      final out = <CounselingMessage>[];
      for (final (i, t) in [
        '요즘 너무 피곤해, 내 몸이 안좋은걸까', '7', '잠을 많이 자는데도 피곤하고 일에 집중을 잘 못해',
        '모르겠어', '계속 피곤한게 건강에 문제가 생긴건 아닐까 걱정되네',
      ].indexed) {
        final r = await h.handleTurn(session: s, userMessage: t);
        s.messages
          ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        out.add(r.assistantMessage);
      }
      expect(out.map((m) => m.earlyWrapUp).whereType<EarlyWrapUp>(), isEmpty,
          reason: out.map((m) => m.text).join('\n'));
    });
  });
}
