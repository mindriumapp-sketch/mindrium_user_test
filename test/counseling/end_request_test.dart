// Phase 4: the deterministic path (A, also the fallback of the LLM-led path)
// ends the session when the user asks to end, from any stage, and takes a
// non-content answer to a closing proposal as agreeing to wrap up.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/closing_decision_selector.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

void main() {
  late LocalCbtKnowledgeRepository repo;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
  });

  Future<List<CounselingTurnResult>> run(List<String> turns) async {
    final h = CounselingHarness.deterministic(
        llm: MockLlmService(), safetyGate: const KeywordSafetyGate(), knowledgeRepository: repo);
    final s = CounselingSessionState(sessionId: 'p4', currentWeek: 4);
    final out = <CounselingTurnResult>[];
    for (final t in turns) {
      final r = await h.handleTurn(session: s, userMessage: t);
      s.messages
        ..add(CounselingMessage(id: 'u${s.messages.length}', role: 'user', text: t, createdAt: DateTime(2026)))
        ..add(r.assistantMessage);
      out.add(r);
      if (r.assistantMessage.closingStep == ClosingStep.finalized) break;
    }
    return out;
  }

  const base = ['발표가 너무 걱정돼요', '말이 막히면 다들 비웃을 것 같아요'];

  for (final end in ['종료', '오늘은 이쯤 할게요', '그만할래', '이제 정리해 주셔도 돼요', '끝', '이제 마무리할까요', '오늘은 여기까지요', '오늘은 여기까지 해도 될 거 같아요', '그만']) {
    test('mid-session "$end" ends the session', () async {
      final r = await run([...base, end]);
      expect(r.last.assistantMessage.closingStep, ClosingStep.finalized);
    });
  }

  test('words that only look like ending do not end the session', () async {
    final r = await run([...base, '그만큼 걱정이 커요', '여기까지 오는 데도 힘들었어요']);
    expect(r.every((t) => t.assistantMessage.closingStep != ClosingStep.finalized), isTrue);
    // "그만해" / "그만 물어봐" ask to stop the questions (a repair), not to end
    for (final t in ['그만큼 걱정이 커요', '이만큼 힘들어요', '여기까지 오는 데도 힘들었어요', '발표 끝나면 불안해요',
        '그만해', '이제 그만 물어봐']) {
      expect(ClosingDecisionSelector.isExplicitEnd(t), isFalse, reason: t);
    }
  });

  group('at a closing proposal', () {
    Future<ClosingStep?> answer(String a) async {
      final r = await run([...base, '모르겠어요', '모르겠어요', a]);
      expect(r[r.length - 2].assistantMessage.closingStep, ClosingStep.proposed);
      return r.last.assistantMessage.closingStep;
    }

    for (final a in ['종료', '종료요', 'ㅇㅇ', '그럴게요', '이쯤 할게요']) {
      test('"$a" finalizes', () async => expect(await answer(a), ClosingStep.finalized));
    }
    for (final a in ['아직 더 얘기하고 싶어요', '좀만 더 하자', '더 해줘', '사실 회사 계약 연장도 불확실해서 걱정돼요']) {
      test('"$a" continues', () async => expect(await answer(a), ClosingStep.continued));
    }
  });
}
