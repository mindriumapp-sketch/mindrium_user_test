// Phase 14.2A-4: the shadow classifier never changes a counseling decision,
// never blocks a turn, never logs raw text, and its label guards reject the
// false-positive families seen on frozen_v1 (now a diagnostic set).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_classify_api.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/perception/shadow_perception.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

class _Sessions implements CounselingSessionsApi {
  final List<Map<String, Object?>> saved = [];

  @override
  Future<Map<String, dynamic>> upsertSession({
    required String sessionId,
    required int week,
    required String completionStatus,
    required DateTime startedAt,
    required DateTime endedAt,
    String? finalState,
    String? safetyLevel,
    String? mainConcern,
    String? coreThought,
    String? coreThoughtSource,
    String? alternativeThought,
    String? affect,
    int? sudStart,
    int? sudEnd,
    String? interventionUsed,
    String? activityRecommended,
    String? unfinishedIssue,
    String? interventionOutcome,
    List<String> provenanceIds = const [],
    int turnCount = 0,
  }) async {
    final row = {
      'week': week, 'completion_status': completionStatus, 'final_state': finalState,
      'safety_level': safetyLevel, 'main_concern': mainConcern, 'core_thought': coreThought,
      'alternative_thought': alternativeThought, 'sud_start': sudStart,
      'intervention_used': interventionUsed, 'intervention_outcome': interventionOutcome,
      'unfinished_issue': unfinishedIssue, 'turn_count': turnCount,
    };
    saved.add(row);
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> listSessions({int limit = 5, String? completionStatus}) async =>
      const [];
}

/// Always the worst labels for the policy: every turn "not understood", a
/// new worry, stop questioning, low information.
class _AdversarialApi implements CounselingClassifyApi {
  int calls = 0;
  final Duration delay;
  _AdversarialApi({this.delay = Duration.zero});

  @override
  Future<Map<String, dynamic>> classify({
    required String requestId,
    required String userText,
    String? assistantPrev,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return {
      'labels': {
        'content_type': 'low_information',
        'interaction_signal': 'assistant_not_understood',
        'open_content': 'new_worry',
        'confidence': {'content_type': 1, 'interaction_signal': 1, 'open_content': 1},
      },
    };
  }
}

class _FailingApi implements CounselingClassifyApi {
  @override
  Future<Map<String, dynamic>> classify({
    required String requestId,
    required String userText,
    String? assistantPrev,
    Duration timeout = const Duration(seconds: 6),
  }) =>
      Future.error(StateError('upstream down'));
}

const _scripts = {
  'cooperative': [
    '내일 발표가 있어서 불안해요', '7', '발표하다가 말을 못 하면 어떡하지',
    '예전에 발표하다 말이 막힌 적이 있어요', '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
    '긴장해도 준비한 만큼은 할 수 있을 것 같아요', '네 정리할게요',
  ],
  'confused': [
    '시험 망칠 것 같아', '8', '무슨 말이야', '뭐라는거야', '그게 뭔데', '몰라', '응',
  ],
  'low_info_and_continue': [
    '요즘 그냥 불안해', '5', '몰라', '그냥', '아직 더 얘기하고 싶어', '친구랑 싸울까봐 걱정돼', '네',
  ],
  'repeat_and_stop': [
    '면접에서 떨어질 것 같아', '6', '아까도 물어봤잖아', '질문 좀 그만해', '그냥 들어줘', '고마워', '응',
  ],
  'crisis': ['요즘 너무 힘들어', '죽고 싶어', '그냥 다 끝내고 싶어'],
};

late LocalCbtKnowledgeRepository _repo;

Future<(List<String>, List<Map<String, Object?>>)> _run(
  List<String> script, {
  ShadowPerception? shadow,
}) async {
  final sessions = _Sessions();
  final p = CounselingProvider(
    knowledgeRepository: _repo,
    currentWeek: 6,
    sessionsApi: sessions,
    instantEmpathy: false,
    shadowPerception: shadow,
    harness: CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: _repo,
    ),
  );
  await p.initialize();
  final trace = <String>[];
  for (final t in script) {
    await p.sendMessage(t);
    trace.add('state=${p.state.name}');
  }
  await p.finalizeIfIncomplete();
  for (final m in p.messages) {
    trace.add(jsonEncode({
      'role': m.role, 'text': m.text, 'act': m.dialogueAct?.name,
      'goal': m.dialogueGoalId, 'repair': m.interactionRepairReason?.name,
      'recovery': m.goalExhaustionRecovery?.name, 'step': m.interventionStep?.name,
      'closing': m.closingStep?.name, 'early': m.earlyWrapUp?.name, 'clarify': m.isClarify,
      'credited': m.interventionCredited, 'cbt': m.referencedCbtIds,
    }));
  }
  return (trace, sessions.saved);
}

void main() {
  setUpAll(() async {
    _repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await _repo.initialize();
  });

  group('causal isolation: decisions are identical with or without the shadow', () {
    for (final MapEntry(key: name, value: script) in _scripts.entries) {
      test(name, () async {
        final (base, baseSaved) = await _run(script);
        final events = <ShadowPerceptionEvent>[];
        final adversarial = _AdversarialApi();
        final (withShadow, shadowSaved) = await _run(
          script,
          shadow: ShadowPerception(api: adversarial, sink: events.add),
        );
        final (withFailing, failingSaved) = await _run(
          script,
          shadow: ShadowPerception(api: _FailingApi(), sink: (_) {}),
        );
        final (withSlow, slowSaved) = await _run(
          script,
          shadow: ShadowPerception(
            api: _AdversarialApi(delay: const Duration(milliseconds: 30)),
            sink: (_) {},
          ),
        );
        // state, move/act, goal, CBT, closing, safety-path text and saved summary
        expect(withShadow, base);
        expect(withFailing, base);
        expect(withSlow, base);
        expect(shadowSaved, baseSaved);
        expect(failingSaved, baseSaved);
        expect(slowSaved, baseSaved);
        // the shadow really ran on every user turn
        await Future<void>.delayed(Duration.zero);
        expect(adversarial.calls, script.length);
        expect(events, hasLength(script.length));
      });
    }
  });

  test('a failing or hanging classifier never surfaces and is recorded as a fallback', () async {
    final events = <ShadowPerceptionEvent>[];
    final hang = Completer<Map<String, dynamic>>();
    final s = ShadowPerception(
      api: _HangingApi(hang.future),
      sink: events.add,
      timeout: const Duration(milliseconds: 20),
    );
    await s.observe(sessionId: 's', turnIndex: 1, userText: 'x', assistantPrev: null, ruleSignal: 'none');
    await ShadowPerception(api: _FailingApi(), sink: events.add)
        .observe(sessionId: 's', turnIndex: 2, userText: 'x', assistantPrev: null, ruleSignal: 'none');
    expect(events.map((e) => e.fallbackReason), ['timeout', 'request_failed']);
  });

  test('unknown label values are rejected as a whole', () {
    expect(ModelUserAct.tryParse({'content_type': 'worry_thought', 'interaction_signal': 'none', 'open_content': 'x'}), isNull);
    expect(ModelUserAct.tryParse({'content_type': 'worry_thought', 'interaction_signal': 'next_move', 'open_content': 'none'}), isNull);
    expect(ModelUserAct.tryParse('nope'), isNull);
  });

  test('log entries carry no raw text', () async {
    final entries = <String>[];
    const utterance = '교수님한테 혼날까봐 너무 무서워요';
    const prev = '그 상황에서 가장 걱정되는 순간은 언제인가요?';
    await ShadowPerception(
      api: _AdversarialApi(),
      sink: (e) => entries.add(jsonEncode(e.toLogEntry())),
    ).observe(sessionId: 'session_123', turnIndex: 3, userText: utterance, assistantPrev: prev, ruleSignal: 'none');
    expect(entries, hasLength(1));
    expect(entries.single.contains('교수님'), isFalse);
    expect(entries.single.contains('무서워'), isFalse);
    expect(entries.single.contains('가장 걱정'), isFalse);
    expect(entries.single.contains('session_123'), isFalse);
  });

  group('label guards (false-positive families from frozen_v1, now diagnostic)', () {
    GuardedSignals g(String content, String signal, String open, String text) =>
        ShadowGuards.apply(ModelUserAct(content, signal, open), text);

    for (final text in [
      '팀장님이 자꾸 같은 말 반복하시는데 제가 뭘 잘못한 건가 싶어요',
      '선배가 그만 좀 물어보라고 할까봐요',
      '교수님이질문을이해못하셨다고하면어떡하지',
      '친구가 무슨 말 하는지 모르겠어',
    ]) {
      test('third party: $text', () {
        final r = g('worry_thought', 'assistant_not_understood', 'none', text);
        expect(r.assistantNotUnderstood, isFalse);
        expect(r.guardReasons, contains('not_understood:third_party'));
      });
    }

    for (final text in [
      '걱정일기쓰는법모르겠어 쓰려고해도 머리가 하얘져',
      '이 기능 어떻게 쓰는지 모르겠어',
      '알림 설정이 뭔지 모르겠어요',
    ]) {
      test('app usage: $text', () {
        final r = g('mixed', 'assistant_not_understood', 'none', text);
        expect(r.assistantNotUnderstood, isFalse);
        expect(r.guardReasons, contains('not_understood:app_usage'));
      });
    }

    for (final text in ['그게 무슨 뜻이야', '뭔소린지1도모르겠음', '균형 있게가 뭔데', '질문이 너무 어려워요']) {
      test('about the assistant passes: $text', () {
        expect(g('meta_interaction', 'assistant_not_understood', 'none', text).assistantNotUnderstood, isTrue);
      });
    }

    test('open content: a worry is normal content, not vetoed', () {
      final r = g('worry_thought', 'none', 'new_worry', '그리고 요즘 돈 문제도 걱정돼');
      expect(r.openContent, 'new_worry');
      expect(r.guardReasons, isEmpty);
    });

    test('open content: app-guide or no-content turns are vetoed', () {
      expect(g('app_guide', 'none', 'new_worry', '일정 추가 어디서 해').openContent, isNull);
      expect(g('low_information', 'none', 'new_evidence', '몰라').openContent, isNull);
      expect(g('meta_interaction', 'none', 'new_evidence', '아까 말했잖아').openContent, isNull);
    });

    test('unused signals never produce a guarded value', () {
      for (final s in ['stop_questioning', 'repeated_question', 'process_resistance']) {
        final r = g('meta_interaction', s, 'elaboration', '그냥 들어줘');
        expect(r.assistantNotUnderstood, isFalse);
        expect(r.openContent, isNull);
      }
    });
  });

  test('pseudonymize is stable and hides the id', () {
    expect(pseudonymize('session_1'), pseudonymize('session_1'));
    expect(pseudonymize('session_1'), isNot(pseudonymize('session_2')));
    expect(pseudonymize('session_1').contains('session'), isFalse);
  });
}

class _HangingApi implements CounselingClassifyApi {
  final Future<Map<String, dynamic>> never;
  _HangingApi(this.never);

  @override
  Future<Map<String, dynamic>> classify({
    required String requestId,
    required String userText,
    String? assistantPrev,
    Duration timeout = const Duration(seconds: 6),
  }) =>
      never;
}
