// Phase 13.8: dogfood session 4 (week 4, 2026-09-29), replayed on the
// deterministic harness. On device the reflect turns were realized by the
// remote realizer, but every decision below is deterministic.
//   P2: "너가 무슨말 하는지 모르겠어" was chosen as the round's worry and
//       quoted as "the thought" for the balanced-thought technique. The
//       round worry was simply the message before the first goal question.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
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

const _meta = {
  '왜 같은 말을 해?',
  '무슨 말이야',
  '너가 무슨말 하는지 모르겠어',
  '지금 무슨 이야기를 하는거야?',
  '뭐라는거야',
};

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

  test('P2: the technique targets the worry thought, never a meta utterance', () async {
    final replies = await run(session4);
    final prompt = replies.firstWhere(
      (m) => m.interventionStep == InterventionStep.prompt,
      orElse: () => fail('no technique prompt in ${replies.map((m) => m.text).join('\n')}'),
    );
    for (final meta in _meta) {
      expect(prompt.text.contains(meta.replaceFirst(RegExp(r'[?.]$'), '')), isFalse, reason: prompt.text);
    }
    expect(prompt.text, contains('“오늘 시험을 못본것 같아”'), reason: prompt.text);
  });
}
