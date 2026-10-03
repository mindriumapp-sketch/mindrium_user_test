// Phase 14.3 (dogfood 2026-10-02, 32 shadow turns): progression rules that
// hold without the classifier.
//   P1 a contentful reply resets the no-progress pressure (no early wrap-up
//      right after the user said something substantive);
//   P2 a clarify answered with nothing new is not asked again — listen once,
//      then wrap up;
//   P3 at a closing proposal a refusal outranks continuing;
//   P4 a technique applies only to a worry thought; with none, wrap up and
//      quote nothing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/dialogue_progress_ledger.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

late LocalCbtKnowledgeRepository _repo;

Future<List<CounselingMessage>> _run(List<String> turns, {int week = 4}) async {
  final h = CounselingHarness.deterministic(
    llm: MockLlmService(),
    safetyGate: const KeywordSafetyGate(),
    knowledgeRepository: _repo,
  );
  final s = CounselingSessionState(sessionId: 'p143', currentWeek: week);
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

String _why(List<CounselingMessage> r) => r.map((m) => m.text).join('\n');

void main() {
  setUpAll(() async {
    _repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await _repo.initialize();
  });

  group('P1 contentful reply resets the closing pressure', () {
    test('a new worry after two clarifies is never answered with a wrap-up', () async {
      final r = await _run([
        '요즘 몸이 안좋은가봐', '7', '잠도 많이자는데 계속 피곤해',
        '일을 제대로 못해서 돈도 못 벌고 있어. 돈이 부족해서 걱정이야',
      ]);
      expect(r.last.earlyWrapUp, isNull, reason: _why(r));
      expect(r.last.closingStep, isNull, reason: _why(r));
    });

    test('the reply after it is not wrapped up for "no progress" either', () async {
      final r = await _run([
        '요즘 몸이 안좋은가봐', '7', '잠도 많이자는데 계속 피곤해',
        '일을 제대로 못해서 돈도 못 벌고 있어. 돈이 부족해서 걱정이야',
        '월세 낼 날이 다가오는데 통장이 비어 있어',
      ]);
      expect(r.map((m) => m.earlyWrapUp), everyElement(isNull), reason: _why(r));
    });
  });

  group('P2 no repeated clarify without progress', () {
    test('clarify → nothing new → listen (no question), not another clarify', () async {
      final r = await _run(['그냥', '0', '마음에 걸리는게 없다니까', '없어']);
      expect(r[2].isClarify, isTrue, reason: _why(r));
      expect(r[3].isClarify, isFalse, reason: _why(r));
      expect(r[3].goalExhaustionRecovery, GoalExhaustionRecovery.listenWithoutQuestion, reason: _why(r));
      expect(r[3].text.contains('?'), isFalse);
    });

    test('then a further reply without content offers to wrap up', () async {
      final r = await _run(['그냥', '0', '마음에 걸리는게 없다니까', '없어', '뭘 더 얘기해']);
      expect(r.last.earlyWrapUp, EarlyWrapUp.noProgress, reason: _why(r));
    });

    test('a clarify answered with new content may be asked again', () async {
      final r = await _run(['내일 면접이 있어', '9', '무슨 계기', '면접이 다가오는게 상황이지']);
      expect(r[3].isClarify, isTrue, reason: _why(r));
    });
  });

  group('P3 refusal outranks continuing at a closing proposal', () {
    Future<CounselingMessage> answer(String reply) async {
      final r = await _run(['그냥', '0', '마음에 걸리는게 없다니까', '없어', '뭘 더 얘기해', reply]);
      expect(r[4].closingStep, ClosingStep.proposed, reason: _why(r));
      return r.last;
    }

    test('"아니 싫어 그만해" finalizes', () async {
      expect((await answer('아니 싫어 그만해')).closingStep, ClosingStep.finalized);
    });
    test('"그만할래" finalizes', () async {
      expect((await answer('그만할래')).closingStep, ClosingStep.finalized);
    });
    test('a strong continue cue still continues: "아직 끝내지 말자"', () async {
      expect((await answer('아직 끝내지 말자')).closingStep, ClosingStep.continued);
    });
    test('"좀 더 하고 그만할래" continues', () async {
      expect((await answer('좀 더 하고 그만할래')).closingStep, ClosingStep.continued);
    });
    test('a bare "아니" (to "정리할까요, 아니면 더?") still continues', () async {
      expect((await answer('아니')).closingStep, ClosingStep.continued);
    });
  });

  group('P4 a technique needs a worry thought', () {
    test('with no worry thought the technique wraps up and quotes nothing', () async {
      // reflect reaches its cap on replies the rules don't recognize as
      // non-answers; week 6 (behavior technique) used to quote them
      final r = await _run(['그냥', '5', '머리가 하얘요', '그런 건 생각 안 해봤어요', '딱히 안 떠오르네요ㅎ', '없을걸요 아마', '음'], week: 6);
      for (final m in r) {
        expect(m.text.contains('“머리가 하얘요”'), isFalse, reason: _why(r));
        expect(m.text.contains('“없을걸요 아마”'), isFalse, reason: _why(r));
        expect(m.text.contains('“딱히 안 떠오르네요ㅎ”'), isFalse, reason: _why(r));
      }
      expect(r.where((m) => m.interventionStep == InterventionStep.prompt), isEmpty, reason: _why(r));
    });

    test('with a worry thought the technique still applies', () async {
      final r = await _run([
        '내일 발표가 있어서 불안해요', '7', '발표하다가 말을 못 하면 어떡하지',
        '예전에 발표하다 말이 막힌 적이 있어요', '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
      ]);
      expect(r.where((m) => m.interventionStep == InterventionStep.prompt), isNotEmpty, reason: _why(r));
    });
  });

  group('ledger', () {
    CounselingMessage u(String t) => CounselingMessage(id: t, role: 'user', text: t, createdAt: DateTime(2026));
    CounselingMessage a({bool clarify = false, InteractionRepairReason? repair}) => CounselingMessage(
          id: 'a', role: 'assistant', text: 'q?', createdAt: DateTime(2026),
          isClarify: clarify, interactionRepairReason: repair);

    test('counts clarify turns answered without content, newest first', () {
      expect(DialogueProgressLedger.stagnantClarifyRun([a(clarify: true), u('몰라'), a(clarify: true)], '응'), 2);
    });
    test('a contentful reply stops the run', () {
      expect(
        DialogueProgressLedger.stagnantClarifyRun(
          [a(clarify: true), u('월세 낼 돈이 없어서 걱정이야'), a(clarify: true)], '응'),
        1,
      );
      expect(DialogueProgressLedger.stagnantClarifyRun([a(clarify: true)], '월세 낼 돈이 없어서 걱정이야'), 0);
    });
    test('a reply answered as a repair is not progress', () {
      expect(
        DialogueProgressLedger.stagnantClarifyRun(
          [a(clarify: true), u('그게 무슨 말이에요 정말로'), a(repair: InteractionRepairReason.assistantNotUnderstood), u('몰라'), a(clarify: true)],
          '응'),
        2,
      );
    });
  });
}
