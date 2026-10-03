// Phase 13.3–13.5: completion-driven progression.
//   13.3 intervention: ask → user answers → integrate → complete.
//   13.4 reflect: min 2 / max 4 turns, complete once a reflective goal was
//        answered (clarify turns no longer crowd out the goals).
//   13.5 closing handshake: proposal → agree (finalize) or continue (once).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

class _Step {
  final String user;
  final CounselingState before;
  final CounselingState after;
  final CounselingMessage reply;
  _Step(this.user, this.before, this.after, this.reply);
}

void main() {
  late LocalCbtKnowledgeRepository repo;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
  });

  Future<List<_Step>> run(int week, List<String> turns) async {
    final h = CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repo,
    );
    final s = CounselingSessionState(sessionId: 'p13-$week', currentWeek: week);
    final steps = <_Step>[];
    for (final (i, t) in turns.indexed) {
      final before = s.state;
      final r = await h.handleTurn(session: s, userMessage: t);
      s.messages
        ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
        ..add(r.assistantMessage);
      steps.add(_Step(t, before, s.state, r.assistantMessage));
    }
    return steps;
  }

  const base = [
    '내일 발표가 있어서 불안해요',
    '7점이요',
    '발표하다가 말을 못 하면 어떡하지',
    '예전에 발표하다 말이 막힌 적이 있어요',
    '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
  ];

  group('13.3 intervention completion', () {
    test('week 4: the answer to the technique question is integrated before closing', () async {
      final steps = await run(4, [
        ...base,
        '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
        '네 좋아요',
      ]);
      final prompt = steps.firstWhere((s) => s.reply.interventionStep == InterventionStep.prompt);
      expect(prompt.after, CounselingState.intervention, reason: 'question sent ≠ intervention done');

      final i = steps.indexOf(prompt);
      final integration = steps[i + 1];
      expect(integration.before, CounselingState.intervention);
      expect(integration.reply.interventionStep, InterventionStep.integration);
      expect(integration.reply.text.contains('긴장해도 준비한 만큼은'), isFalse, reason: 'not quoted verbatim');
      expect(integration.reply.closingStep, ClosingStep.proposed);
      expect(integration.after, CounselingState.closing);

      final last = steps.last;
      expect(last.reply.closingStep, ClosingStep.finalized);
    });

    test('a repair turn between question and answer does not drop the answer', () async {
      final steps = await run(4, [
        ...base,
        '왜 똑같은 말을해?',
        '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
      ]);
      final repair = steps[base.length];
      expect(repair.reply.interactionRepairReason, isNotNull);
      expect(repair.after, CounselingState.intervention);
      expect(steps.last.reply.interventionStep, InterventionStep.integration);
    });

    // Phase 4: asking to end ends the session (no second confirmation), and
    // the stop is still never credited with a technique outcome.
    test('an answer asking to stop ends the session, not credited with a technique outcome', () async {
      final steps = await run(4, [...base, '오늘은 여기까지 할게요']);
      expect(steps.last.reply.closingStep, ClosingStep.finalized);
      expect(steps.last.reply.interventionCredited, isNot(true));
      expect(steps.last.reply.text.contains('현실적으로'), isFalse);
    });

    test('low-information answer gets a no-pressure acknowledgment', () async {
      final steps = await run(4, [...base, '모르겠어. 그냥 불안해']);
      expect(steps.last.reply.interventionStep, InterventionStep.integration);
      expect(steps.last.reply.text, contains('바로 떠오르지 않아도 괜찮아요'));
    });
  });

  group('13.4 reflect completion', () {
    test('clarify turns no longer exhaust reflect before a goal is answered', () async {
      final steps = await run(4, [
        '내일 발표가 있어서 불안해요',
        '7점이요',
        '그냥 그래요',
        '발표하다가 말을 못 하면 어떡하지',
        '예전에 막힌 적이 있어요',
        '매번 그런 건 아닐 수도 있어요',
      ]);
      final reflect = steps.where((s) => s.before == CounselingState.reflect).toList();
      expect(reflect.length, greaterThanOrEqualTo(3));
      expect(reflect.map((s) => s.reply.dialogueGoalId), containsAll(['evidence', 'alternative']));
    });

    test('never more than 4 reflect turns', () async {
      final steps = await run(4, ['불안해요', '7', '그냥요', '몰라요', '글쎄요', '네', '음']);
      expect(steps.where((s) => s.before == CounselingState.reflect).length, lessThanOrEqualTo(4));
    });
  });

  group('13.5 closing handshake', () {
    test('continue once, then the next proposal finalizes', () async {
      final steps = await run(4, [
        ...base,
        '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
        '아니요, 조금 더 이야기하고 싶어요',
        '사실 교수님 반응이 제일 걱정돼요',
        '교수님이 실망하실 것 같아요',
        '그래도 잘 해볼게요',
        '네',
        '네',
      ]);
      final cont = steps.firstWhere((s) => s.reply.closingStep == ClosingStep.continued);
      expect(cont.before, CounselingState.closing);
      expect(cont.after, CounselingState.reflect);
      expect(steps.where((s) => s.reply.closingStep == ClosingStep.continued), hasLength(1));
      expect(steps.last.reply.closingStep, ClosingStep.finalized);
    });

    test('"왜 벌써 상담을 끝내?" at the proposal continues instead of being summarized', () async {
      final steps = await run(4, [
        ...base,
        '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
        '왜 벌써 상담을 끝내?',
      ]);
      expect(steps.last.reply.closingStep, ClosingStep.continued);
      expect(steps.last.reply.text.contains('왜 벌써'), isFalse);
    });

    test('final closing does not quote the user verbatim', () async {
      final steps = await run(4, [...base, '긴장해도 준비한 만큼은 할 수 있을 것 같아요', '네']);
      expect(steps.last.reply.closingStep, ClosingStep.finalized);
      expect(steps.last.reply.text.contains('“'), isFalse);
    });
  });

  group('week × progression: no deadlock, no premature end', () {
    // Adaptive user: answers a closing proposal with "네", otherwise answers
    // whatever was asked. Every week must reach a finalized closing through
    // exactly one proposal, answered by the very next turn.
    for (var week = 1; week <= 8; week++) {
      test('week $week', () async {
        final h = CounselingHarness.deterministic(
          llm: MockLlmService(),
          safetyGate: const KeywordSafetyGate(),
          knowledgeRepository: repo,
        );
        final s = CounselingSessionState(sessionId: 'w$week', currentWeek: week);
        final steps = <_Step>[];
        Future<void> send(String t) async {
          final before = s.state;
          final r = await h.handleTurn(session: s, userMessage: t);
          s.messages
            ..add(CounselingMessage(id: 'u${steps.length}', role: 'user', text: t, createdAt: DateTime(2026)))
            ..add(r.assistantMessage);
          steps.add(_Step(t, before, s.state, r.assistantMessage));
        }

        for (final t in base) {
          await send(t);
        }
        for (var i = 0; i < 4 && steps.last.reply.closingStep != ClosingStep.finalized; i++) {
          await send(steps.last.reply.closingStep == ClosingStep.proposed
              ? '네'
              : '준비한 만큼은 할 수 있을 것 같아요');
        }

        expect(steps.last.reply.closingStep, ClosingStep.finalized);
        expect(steps.last.after, CounselingState.closing);
        final proposals = [
          for (final (i, st) in steps.indexed)
            if (st.reply.closingStep == ClosingStep.proposed) i,
        ];
        expect(proposals, hasLength(1));
        expect(steps[proposals.single].after, CounselingState.closing);
        expect(steps[proposals.single + 1].reply.closingStep, ClosingStep.finalized);
        for (var i = 1; i < steps.length; i++) {
          expect(steps[i].reply.text, isNot(steps[i - 1].reply.text));
        }
        for (final st in steps.where((st) => st.before == CounselingState.intervention)) {
          expect(st.reply.dialogueAct, isNot(DialogueAct.unknown));
        }
        if (week >= 4) {
          expect(
            steps.map((st) => st.reply.interventionStep),
            containsAllInOrder([InterventionStep.prompt, InterventionStep.integration]),
            reason: 'weeks with an approved technique must integrate the answer',
          );
        }
      });
    }
  });
}
