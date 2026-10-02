// Phase 14.2B: selective causal activation of two classifier signals
// (stop_questioning, assistant_not_understood), rules OR guarded model.
//
// Allowed causal differences: those two repairs only. Forbidden: safety,
// CBT selection, app-guide routing, unrelated state/closing decisions.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_classify_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/perception/shadow_perception.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

/// Returns the given signal for listed utterances, `none` otherwise.
class _ScriptedApi implements CounselingClassifyApi {
  final Map<String, String> signals;
  final Duration delay;
  final List<String> calls = [];
  _ScriptedApi(this.signals, {this.delay = Duration.zero});

  @override
  Future<Map<String, dynamic>> classify({
    required String requestId,
    required String userText,
    String? assistantPrev,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    calls.add(userText);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return {
      'labels': {
        'content_type': 'meta_interaction',
        'interaction_signal': signals[userText] ?? 'none',
        'open_content': 'none',
        'confidence': {'content_type': 1, 'interaction_signal': 1, 'open_content': 1},
      },
    };
  }
}

late LocalCbtKnowledgeRepository _repo;

Future<List<CounselingMessage>> _run(
  List<String> script, {
  CounselingClassifyApi? api,
  bool causal = true,
  Duration timeout = const Duration(seconds: 2),
  int week = 4,
}) async {
  final p = CounselingProvider(
    knowledgeRepository: _repo,
    currentWeek: week,
    instantEmpathy: false,
    shadowPerception: api == null ? null : ShadowPerception(api: api, sink: (_) {}),
    causalPerception: causal,
    perceptionTimeout: timeout,
    harness: CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: _repo,
    ),
  );
  await p.initialize();
  for (final t in script) {
    await p.sendMessage(t);
  }
  return p.messages.where((m) => !m.isUser).skip(1).toList(); // drop greeting
}

String _sig(CounselingMessage m) => jsonEncode({
  't': m.text, 'act': m.dialogueAct?.name, 'goal': m.dialogueGoalId,
  'repair': m.interactionRepairReason?.name, 'step': m.interventionStep?.name,
  'closing': m.closingStep?.name, 'early': m.earlyWrapUp?.name, 'cbt': m.referencedCbtIds,
});

String _why(List<CounselingMessage> r) => r.map((m) => m.text).join('\n');

void main() {
  setUpAll(() async {
    _repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await _repo.initialize();
  });

  const reflectStart = ['요즘 몸이 안좋은가봐', '7', '잠도 많이자는데 계속 피곤해'];

  group('allowed: the two repairs', () {
    test('not understood the rules miss → the deterministic not-understood repair', () async {
      const u = '그게 무슨 상관이야';
      final base = await _run([...reflectStart, u]);
      final r = await _run([...reflectStart, u], api: _ScriptedApi({u: 'assistant_not_understood'}));
      expect(base.last.interactionRepairReason, isNull, reason: 'rules miss it: ${base.last.text}');
      expect(r.last.interactionRepairReason, InteractionRepairReason.assistantNotUnderstood, reason: _why(r));
      expect(r.last.text, startsWith('제 말이'), reason: r.last.text);
      // turns before the signal are untouched
      expect(r.take(3).map(_sig), base.take(3).map(_sig));
    });

    test('a stop request the rules miss → stop-questioning repair, no question', () async {
      const u = '아니 싫어 그만해';
      final r = await _run([...reflectStart, u], api: _ScriptedApi({u: 'stop_questioning'}));
      expect(r.last.interactionRepairReason, InteractionRepairReason.stopQuestioning, reason: _why(r));
      expect(r.last.text.contains('?'), isFalse, reason: r.last.text);
      // a repair, not an ended session
      expect(r.last.closingStep, isNot(ClosingStep.finalized));
    });

    test('precedence: stop asking outranks the rules\' repeated-question', () async {
      const u = '왜 또 같은 거 물어봐 이제 그만해';
      final r = await _run([...reflectStart, u], api: _ScriptedApi({u: 'stop_questioning'}));
      expect(r.last.interactionRepairReason, InteractionRepairReason.stopQuestioning, reason: _why(r));
    });

    test('at a closing proposal a perceived stop finalizes', () async {
      const proposalScript = ['그냥', '0', '마음에 걸리는게 없다니까', '없어', '뭘 더 얘기해'];
      const u = '아니 더는 묻지 마';
      final r = await _run([...proposalScript, u], api: _ScriptedApi({u: 'stop_questioning'}));
      expect(r[4].closingStep, ClosingStep.proposed, reason: _why(r));
      expect(r.last.closingStep, ClosingStep.finalized, reason: _why(r));
    });
  });

  group('forbidden: everything else', () {
    test('a model that says "none" changes nothing', () async {
      const s = [
        '내일 발표가 있어서 불안해요', '7', '발표하다가 말을 못 하면 어떡하지',
        '예전에 발표하다 말이 막힌 적이 있어요', '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
        '긴장해도 준비한 만큼은 할 수 있을 것 같아요', '네 정리할게요',
      ];
      final base = await _run(s);
      final r = await _run(s, api: _ScriptedApi(const {}));
      expect(r.map(_sig), base.map(_sig));
    });

    test('other labels never act (repeated_question, process_resistance, closing)', () async {
      const s = [...reflectStart, '일을 제대로 못해서 돈도 못 벌고 있어. 돈이 부족해서 걱정이야'];
      final base = await _run(s);
      final r = await _run(s, api: _ScriptedApi({s.last: 'process_resistance'}));
      expect(r.map(_sig), base.map(_sig));
    });

    test('safety: a crisis turn is unchanged and the classifier is not called', () async {
      const u = '죽고 싶어';
      final api = _ScriptedApi({u: 'stop_questioning'});
      final base = await _run(['요즘 너무 힘들어', u]);
      final r = await _run(['요즘 너무 힘들어', u], api: api);
      expect(r.map(_sig), base.map(_sig));
      expect(api.calls, isNot(contains(u)));
    });

    test('app-guide-only turns do not call the classifier', () async {
      const u = '지난 기록 어디서 봐?';
      final api = _ScriptedApi({u: 'assistant_not_understood'});
      final base = await _run(['내일 발표가 있어서 불안해요', u]);
      final r = await _run(['내일 발표가 있어서 불안해요', u], api: api);
      expect(r.map(_sig), base.map(_sig));
      expect(api.calls, isNot(contains(u)));
    });

    test('guards: third-party and app-usage look-alikes do not act', () async {
      for (final (u, sig) in [
        ('엄마가 그만 좀 물어보래서 짜증났어', 'stop_questioning'),
        ('선배가 그만 좀 물어보라고 할까봐 걱정돼', 'stop_questioning'),
        ('친구가 무슨 말 하는지 모르겠어서 불안해', 'assistant_not_understood'),
        ('지난 기록 보는 화면이 어디 있는지 모르겠어', 'assistant_not_understood'),
        // the intent router keeps this one in counseling; the app-usage guard
        // still keeps the model from acting on it
        ('걱정일기는 어디서 써?', 'stop_questioning'),
      ]) {
        final base = await _run([...reflectStart, u]);
        final r = await _run([...reflectStart, u], api: _ScriptedApi({u: sig}));
        expect(r.map(_sig), base.map(_sig), reason: u);
      }
    });

    test('rules already caught it: the classifier is not called', () async {
      const u = '무슨 말이야';
      final api = _ScriptedApi({u: 'stop_questioning'});
      final r = await _run([...reflectStart, u], api: api);
      expect(api.calls, isNot(contains(u)));
      expect(r.last.interactionRepairReason, InteractionRepairReason.assistantNotUnderstood);
    });

    test('a slow classifier times out to the rules and the turn goes on', () async {
      const u = '그게 무슨 상관이야';
      final base = await _run([...reflectStart, u]);
      final sw = Stopwatch()..start();
      final r = await _run(
        [...reflectStart, u],
        api: _ScriptedApi({u: 'assistant_not_understood'}, delay: const Duration(seconds: 3)),
        timeout: const Duration(milliseconds: 50),
      );
      expect(r.map(_sig), base.map(_sig));
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('causal off: the same signal is shadow-only', () async {
      const u = '그게 무슨 상관이야';
      final base = await _run([...reflectStart, u]);
      final r = await _run([...reflectStart, u],
          api: _ScriptedApi({u: 'assistant_not_understood'}), causal: false);
      expect(r.map(_sig), base.map(_sig));
    });
  });

  test('the not-understood repair keeps the meta reply out of later targets', () async {
    const u = '그게 무슨 상관이야';
    final r = await _run([...reflectStart, u, '돈 때문에 집세를 못 낼까봐 걱정돼', '전에도 밀린 적이 있어'],
        api: _ScriptedApi({u: 'assistant_not_understood'}));
    for (final m in r) {
      expect(m.text.contains('“그게 무슨 상관이야”'), isFalse, reason: _why(r));
    }
  });
}
