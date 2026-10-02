// Phase 14.X: the Bounded LLM-led path — boundary before the call, validator
// after it, mapping onto turn metadata, and fallback to the deterministic
// path on anything not accepted.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/llm_led/llm_led_contract.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

late LocalCbtKnowledgeRepository _repo;
late LocalAppGuideRepository _guide;

Map<String, dynamic> _out({
  String domain = 'counseling',
  List<String> moves = const ['acknowledge', 'ask_evidence'],
  String? interventionId,
  String? step,
  List<String> userIds = const [],
  List<String> appIds = const [],
  String action = 'continue',
  String text = '그 생각을 사실이라고 느끼게 하는 경험이 있을까요?',
}) => {
  'output': {
    'domain': domain, 'dialogue_moves': moves, 'intervention_id': interventionId,
    'intervention_step': step, 'used_user_fact_ids': userIds, 'used_app_fact_ids': appIds,
    'session_action': action, 'response_text': text,
  },
  'prompt_version': 'respond_v1',
};

class _Api implements CounselingRespondApi {
  final List<Map<String, dynamic>> answers;
  final Duration delay;
  final List<Map<String, dynamic>> bodies = [];
  _Api(this.answers, {this.delay = Duration.zero});

  @override
  Future<Map<String, dynamic>> respond(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 8)}) async {
    bodies.add(body);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return answers[(bodies.length - 1).clamp(0, answers.length - 1)];
  }
}

CounselingHarness _harness() => CounselingHarness.deterministic(
  llm: MockLlmService(), safetyGate: const KeywordSafetyGate(), knowledgeRepository: _repo);

CounselingSessionState _session({int week = 4, List<CounselingMessage> messages = const []}) {
  final s = CounselingSessionState(sessionId: 's', currentWeek: week);
  s.messages.addAll(messages);
  return s;
}

CounselingMessage _a(String t, {ClosingStep? closing, InterventionStep? step, List<String> cbt = const []}) =>
    CounselingMessage(id: t, role: 'assistant', text: t, createdAt: DateTime(2026),
        closingStep: closing, interventionStep: step, referencedCbtIds: cbt);
CounselingMessage _u(String t) => CounselingMessage(id: t, role: 'user', text: t, createdAt: DateTime(2026));

void main() {
  setUpAll(() async {
    _repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await _repo.initialize();
    _guide = LocalAppGuideRepository(loadAsset: (p) => File(p).readAsString());
    await _guide.initialize();
  });

  LlmLedContext ctx(CounselingSessionState s, String u) =>
      LlmLedContext.build(requestId: 'r', session: s, userMessage: u, knowledge: _repo, appGuide: _guide);

  group('boundary before the call', () {
    test('techniques are cumulative up to the current week, never a future week', () {
      expect(ctx(_session(week: 4), 'x').techniqueIds, {'week4_alternative_thought_01'});
      final w6 = ctx(_session(week: 6), 'x').techniqueIds;
      expect(w6, containsAll(['week4_alternative_thought_01', 'week5_confront_avoid_01', 'week6_short_long_term_01']));
      expect(w6.any((id) => id.startsWith('week7') || id.startsWith('week8')), isFalse);
      expect(ctx(_session(week: 2), 'x').techniqueIds, isEmpty);
    });

    test('the conversation is at most 12 messages and ends with this user message', () {
      final many = [for (var i = 0; i < 20; i++) i.isEven ? _u('u$i') : _a('a$i')];
      final conv = ctx(_session(messages: many), '지금 이거').body['conversation'] as List;
      expect(conv.length, 12);
      expect((conv.last as Map)['text'], '지금 이거');
    });

    test('the app catalog goes with ids', () {
      final c = ctx(_session(), 'x');
      expect(c.appFactIds, contains('feature:relaxation'));
      expect(c.appFactIds.any((id) => id.startsWith('screen:')), isTrue);
    });
  });

  group('validator', () {
    List<String> v(Map<String, dynamic> raw, {CounselingSessionState? s}) =>
        LlmLedValidator.validate(LlmLedOutput.tryParse(raw['output'])!, ctx(s ?? _session(), 'x'));

    test('a clean answer passes', () => expect(v(_out()), isEmpty));
    test('a technique outside the list', () {
      expect(v(_out(interventionId: 'week7_gain_lose_01', step: 'prompt')), contains('unauthorized_intervention'));
      expect(v(_out(interventionId: 'exposure_therapy', step: 'prompt')), contains('unauthorized_intervention'));
    });
    test('a user fact not given', () => expect(v(_out(userIds: ['diary:made-up'])), contains('unsupported_user_fact')));
    test('an app fact not given', () => expect(v(_out(domain: 'app_guide', appIds: ['screen:nope'])), contains('unsupported_app_fact')));
    test('naming a screen without an app fact', () {
      expect(v(_out(domain: 'app_guide', moves: ['answer_app'], text: '홈 화면에서 설정 메뉴로 들어가 보세요.')),
          contains('app_claim_without_fact'));
    });
    test('two questions', () => expect(v(_out(text: '어떤가요? 그리고 언제인가요?')), contains('too_many_questions')));
    test('outcome guarantee and diagnosis and directive', () {
      expect(v(_out(text: '분명 잘될 거예요.')), contains('outcome_guarantee'));
      expect(v(_out(text: '공황장애가 있는 것 같아요.')), contains('diagnosis'));
      expect(v(_out(text: '오늘은 꼭 운동을 해야 합니다.')), contains('directive'));
    });
    test('finalize without a closing proposal', () {
      expect(v(_out(moves: ['finalize'], action: 'finalize', text: '오늘 이야기 고마워요.')), contains('finalize_without_proposal'));
      final proposed = _session(messages: [_a('정리할까요?', closing: ClosingStep.proposed)]);
      expect(v(_out(moves: ['finalize'], action: 'finalize', text: '오늘 이야기 고마워요.'), s: proposed), isEmpty);
    });
    test('bad shape is not parsed', () {
      expect(LlmLedOutput.tryParse({..._out()['output'] as Map, 'domain': 'chitchat'}), isNull);
      expect(LlmLedOutput.tryParse({..._out()['output'] as Map, 'dialogue_moves': ['give_advice']}), isNull);
    });
  });

  group('harness turn', () {
    test('accepted: metadata and stage follow the answer', () async {
      final s = _session(messages: [_a('안녕하세요'), _u('발표가 걱정돼'), _a('0~10?'), _u('7')]);
      s.state = CounselingState.explore;
      final t = await _harness().handleLlmLedTurn(
          session: s, userMessage: '사람들이 비웃을 것 같아', api: _Api([_out()]), appGuide: _guide);
      expect(t.status, 'success');
      final m = t.result!.assistantMessage;
      expect(m.dialogueGoalId, 'evidence');
      expect(t.result!.state, CounselingState.reflect);
      expect(s.state, CounselingState.reflect);
    });

    test('technique prompt → intervention; integration credits by code rules', () async {
      const id = 'week4_alternative_thought_01';
      final s = _session(messages: [_u('발표가 걱정돼')]);
      s.state = CounselingState.reflect;
      final p = await _harness().handleLlmLedTurn(session: s, userMessage: '예전에 막혔어',
          api: _Api([_out(moves: ['intervention_question'], interventionId: id, step: 'prompt', text: '균형 있게 바꾼다면?')]),
          appGuide: _guide);
      expect(p.result!.assistantMessage.interventionStep, InterventionStep.prompt);
      expect(s.state, CounselingState.intervention);
      s.messages..add(_u('예전에 막혔어'))..add(p.result!.assistantMessage);
      final i = await _harness().handleLlmLedTurn(session: s, userMessage: '막혀도 다시 이어가면 될 수도 있어',
          api: _Api([_out(moves: ['integrate', 'offer_close'], step: 'integration', action: 'offer_close', text: '그렇게 보면 조금 가벼워지네요. 여기까지 정리해 볼까요?')]),
          appGuide: _guide);
      final m = i.result!.assistantMessage;
      expect(m.interventionStep, InterventionStep.integration);
      expect(m.referencedCbtIds, [id]);
      expect(m.interventionCredited, isTrue);
      expect(m.closingStep, ClosingStep.proposed);
      expect(s.state, CounselingState.closing);
    });

    for (final (name, api, status) in [
      ('rejected by the validator', _Api([_out(text: '분명 잘될 거예요.')]), 'rejected'),
      ('bad shape', _Api([{'output': {'nope': 1}}]), 'schema_reject'),
      ('timeout', _Api([_out()], delay: const Duration(milliseconds: 200)), 'timeout'),
    ]) {
      test('$name: no result, the session is untouched', () async {
        final s = _session(messages: [_u('발표가 걱정돼')]);
        s.state = CounselingState.reflect;
        final before = (s.state, s.turnsInCurrentState, s.totalTurns);
        final t = await _harness().handleLlmLedTurn(session: s, userMessage: '음', api: api, appGuide: _guide,
            timeout: const Duration(milliseconds: 50));
        expect(t.status, status);
        expect(t.result, isNull);
        expect((s.state, s.turnsInCurrentState, s.totalTurns), before);
      });
    }

    test('crisis: the fixed safety reply, and the model is not called', () async {
      final api = _Api([_out()]);
      final t = await _harness().handleLlmLedTurn(session: _session(), userMessage: '죽고 싶어', api: api, appGuide: _guide);
      expect(t.status, 'safety');
      expect(t.result!.handledBySafety, isTrue);
      expect(api.bodies, isEmpty);
    });
  });

  group('provider', () {
    Future<CounselingProvider> make(CounselingRespondApi api, {bool alternate = false}) async {
      final p = CounselingProvider(
        knowledgeRepository: _repo, appGuideRepository: _guide, currentWeek: 4, instantEmpathy: false,
        llmLedApi: api, llmLedAlternate: alternate, harness: _harness());
      await p.initialize();
      return p;
    }

    test('an app question mid-session is answered as app guidance', () async {
      final p = await make(_Api([
        _out(moves: ['acknowledge', 'open_question'], text: '그렇군요. 어떤 점이 걱정되나요?'),
        _out(domain: 'app_guide', moves: ['answer_app'], appIds: ['feature:relaxation'],
            text: '이완 훈련은 교육 탭의 주차별 이완 세션에서 시작할 수 있어요.'),
      ]));
      await p.sendMessage('발표가 있어');
      await p.sendMessage('이완은 어떻게 해?');
      expect(p.messages.last.text, contains('이완 훈련'));
    });

    test('a rejected answer falls back to the deterministic reply for that turn', () async {
      final p = await make(_Api([_out(text: '분명 잘될 거예요.')]));
      await p.sendMessage('내일 발표가 걱정돼');
      expect(p.messages.last.text, isNot(contains('잘될 거')));
      expect(p.messages.last.text, contains('0에서 10')); // the deterministic check-in
    });

    test('A/B: every other session uses the LLM-led path', () async {
      final api = _Api([_out(moves: ['acknowledge', 'open_question'], text: 'B 경로 응답이에요. 어떤 점이 걱정되나요?')]);
      final p = await make(api, alternate: true); // session 1 → B
      await p.sendMessage('발표가 있어');
      expect(p.messages.last.text, startsWith('B 경로'));
      await p.reset(); // session 2 → A
      await p.sendMessage('발표가 있어');
      expect(p.messages.last.text, isNot(startsWith('B 경로')));
      expect(api.bodies, hasLength(1));
    });
  });
}
