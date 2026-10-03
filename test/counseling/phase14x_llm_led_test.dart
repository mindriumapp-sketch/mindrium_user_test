// Phase 14.X: the Bounded LLM-led path — boundary before the call, validator
// after it, mapping onto turn metadata, and fallback to the deterministic
// path on anything not accepted.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/llm_led/llm_led_contract.dart';
import 'package:gad_app_team/features/counseling/llm_led/term_glossary.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

late LocalCbtKnowledgeRepository _repo;
late LocalAppGuideRepository _guide;
late TermGlossary _glossary;

Map<String, dynamic> _out({
  String domain = 'counseling',
  List<String> moves = const ['acknowledge', 'ask_evidence'],
  String? interventionId,
  String? step,
  List<String> userIds = const [],
  List<String> appIds = const [],
  String action = 'continue',
  String? definitionId,
  String text = '그런 생각이 드셨군요. 그 생각을 사실이라고 느끼게 하는 경험이 있을까요?',
}) {
  // split like respond_v2: everything up to the last question is the statement
  final m = RegExp(r'^(.*?)([^.!?]*\?)\s*$').firstMatch(text);
  final statement = m == null ? text : m.group(1)!.trim();
  final question = m == null ? null : m.group(2)!.trim();
  return {
  'output': {
    'domain': domain, 'dialogue_moves': moves,
    'intervention': interventionId == null ? null : {'id': interventionId, 'step': step ?? 'prompt'},
    'used_user_fact_ids': userIds, 'used_app_fact_ids': appIds,
    'session_action': action, 'definition_id': definitionId,
    'statement': statement.isEmpty ? '네.' : statement, 'question': question,
  },
  'prompt_version': 'respond_v2',
  };
}

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

class _FailApi implements CounselingRespondApi {
  final Object error;
  _FailApi(this.error);
  @override
  Future<Map<String, dynamic>> respond(Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 8)}) =>
      Future.error(error);
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
    _glossary = await TermGlossary.load((p) => File(p).readAsString());
  });

  LlmLedContext ctx(CounselingSessionState s, String u) =>
      LlmLedContext.build(requestId: 'r', session: s, userMessage: u, knowledge: _repo, appGuide: _guide, glossary: _glossary);

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

  group('term grounding (code resolves the term)', () {
    String? id(String u) => _glossary.resolve(u, _repo)?.termId;
    TermRequest? r(String u) => _glossary.resolve(u, _repo);

    test('exact name and alias', () {
      expect(id('ABC 모델이 뭐예요?'), 'abc_model');
      expect(id('자동적 사고라는 게 정확히 뭔데요'), 'automatic_thought');
      expect(id('SUD가 무슨 뜻이야'), 'sud');
    });
    test('mixed with a worry', () {
      expect(id('발표가 걱정되는데 균형 잡힌 생각이 뭐예요?'), 'balanced_thought');
    });
    test('different terms in nearby turns resolve separately', () {
      expect(id('노출 요법은 뭐예요?'), 'exposure');
      expect(id('그럼 인지적 재구성은 뭔데요?'), 'cognitive_restructuring');
    });
    test('a term not in the glossary is unknown, never mapped to a near one', () {
      final t = r('탈파국화? 그건 또 뭐예요 ㅋㅋ');
      expect(t, isNotNull);
      expect(t!.approved, isFalse);
      expect(t.name, '탈파국화');
      expect(r("'탈파국화'는 무슨 뜻이에요?")!.approved, isFalse);
    });
    test('a quoted sentence is asked as meaning (clarify), not as a term', () {
      expect(r("'가능성을 따져본다'는 게 무슨 뜻이에요?"), isNull);
      expect(r("제가 '이번 학기 망했다'고 했는데 그게 무슨 뜻이냐면요"), isNull);
    });
    test('a mention that is not a question is not a term request', () {
      expect(r('요즘 자꾸 회피하게 돼서 힘들어'), isNull);
      expect(r('발표가 너무 걱정돼요'), isNull);
    });
    test('the definition comes from the approved corpus item', () {
      expect(r('ABC 모델이 뭐예요?')!.definition, contains('ABC 모델'));
    });

    LlmLedContext withTerm(String u) => ctx(_session(), u);
    List<String> vt(String u, Map<String, dynamic> raw) =>
        LlmLedValidator.validate(LlmLedOutput.tryParse(raw['output'])!, withTerm(u));

    test('approved: the definition id must be the requested term', () {
      expect(vt('탈파국화 말고 노출 요법이 뭐예요?', _out(moves: ['clarify'], definitionId: 'exposure',
          text: '노출 요법은 불안한 상황을 피하지 않고 마주하는 연습이에요.')), isEmpty);
      expect(vt('노출 요법이 뭐예요?', _out(moves: ['clarify'], definitionId: 'cognitive_restructuring',
          text: '생각을 바꾸는 연습이에요.')), contains('definition_mismatch'));
      expect(vt('노출 요법이 뭐예요?', _out(moves: ['clarify'], text: '피하지 않는 연습이에요.')),
          contains('definition_mismatch'));
    });
    test('unknown: no definition id and no definition', () {
      expect(vt('탈파국화가 뭐예요?', _out(moves: ['clarify'],
          text: '탈파국화는 불안한 상황에 직접 마주하는 연습을 말합니다.')), contains('unknown_term_defined'));
      expect(vt('탈파국화가 뭐예요?', _out(moves: ['clarify'], definitionId: 'exposure', text: 'x예요.')),
          contains('definition_without_request'));
      expect(vt('탈파국화가 뭐예요?', _out(moves: ['clarify'],
          text: '그 표현을 제가 정확히 정의해서 설명하기는 어려워요. 쉽게 말하면 걱정이 커질 때 한 걸음 물러서 보자는 이야기였어요.')),
          isEmpty);
    });
    test('no term asked: no definition id', () {
      expect(vt('발표가 걱정돼', _out(definitionId: 'abc_model')), contains('definition_without_request'));
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
    test('a non-Korean question mark is never shown', () {
      final raw = Map<String, dynamic>.from(_out()['output'] as Map)
        ..['statement'] = '그렇군요. 어떤 기분이 드셨나요؟'
        ..['question'] = null;
      expect(LlmLedValidator.validate(LlmLedOutput.tryParse(raw)!, ctx(_session(), 'x')), contains('foreign_question_mark'));
    });
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
    test('respond_v2: second person, question after a no-question promise, repeated question', () {
      expect(v(_out(text: '당신의 마음이 이해돼요.')), contains('second_person'));
      expect(v(_out(text: '알겠어요, 더 묻지 않을게요. 어떤 이야기를 하고 싶으세요?')),
          contains('question_after_no_question_promise'));
      final asked = _session(messages: [_a('그 생각을 사실이라고 느끼게 하는 경험이 있을까요?')]);
      expect(v(_out(), s: asked), contains('repeated_question'));
      expect(v(_out(text: '알겠어요. 더 묻지 않을게요.')), isEmpty);
    });
    test('respond_v3: banmal, unlisted directive, term without a concept, exploring after closed', () {
      expect(v(_out(text: '그 상황을 물어본 거야. 이해가 됐어?')), contains('banmal_reply'));
      expect(v(_out(text: '그 생각을 한번 적어 보세요.')), contains('directive'));
      final closed = _session(messages: [
        _u('발표하다 말이 막히면 어떡하지'),
        _a('어떤 근거가 있나요?'), _u('예전에 막혔어'),
        _a('다른 관점은 어떤가요?'), _u('다들 긴장해'),
        _a('가능성은 어느 정도일까요?'), _u('반반'),
      ]);
      expect(ctx(closed, '음 그렇네').exploreClosed, isTrue);
      expect(v(_out(text: '그렇군요. 그 외에 또 어떤 준비를 해볼 수 있을까요?'), s: closed), contains('exploring_after_closed'));
      expect(v(_out(moves: ['offer_close'], action: 'offer_close',
          text: '오늘 이야기 잘 정리됐어요. 오늘은 여기까지 정리해 볼까요?'), s: closed), isEmpty);
    });
    test('respond_v5: the user asking to end allows finalize without a proposal', () {
      List<String> vu(String u, Map<String, dynamic> raw) =>
          LlmLedValidator.validate(LlmLedOutput.tryParse(raw['output'])!, ctx(_session(), u));
      final fin = _out(moves: ['summarize', 'finalize'], action: 'finalize', text: '오늘 이야기 고마워요.');
      for (final u in ['오늘은 여기까지 할게요', '그만할래', '종료', '이제 끝', '오늘은 이쯤 할게요',
          '이제 정리해 주셔도 돼요', '이제 마무리할까요']) {
        expect(vu(u, fin), isEmpty, reason: u);
      }
      for (final u in ['아직 끝내지 말고 좀 더 얘기할래', '발표가 끝나면 불안해']) {
        expect(vu(u, fin), contains('finalize_without_proposal'), reason: u);
      }
    });
    test('respond_v5: directives are domain-aware', () {
      expect(v(_out(domain: 'app_guide', moves: ['answer_app'], appIds: ['feature:relaxation'],
          text: '이완 훈련 메뉴에서 시작 버튼을 눌러 보세요.')), isNot(contains('directive')));
      expect(v(_out(domain: 'counseling', text: '그 생각을 한번 적어 보세요.')), contains('directive'));
      expect(v(_out(domain: 'app_guide', moves: ['answer_app'], text: '그냥 푹 쉬어 보세요.')), contains('directive'));
    });
    test('respond_v5: after exploration closed, a new worry or a repair may still ask', () {
      final closed = _session(messages: [
        _u('발표하다 말이 막히면 어떡하지'),
        _a('어떤 근거가 있나요?'), _u('예전에 막혔어'),
        _a('다른 관점은 어떤가요?'), _u('다들 긴장해'),
        _a('가능성은 어느 정도일까요?'), _u('반반'),
      ]);
      List<String> vc(String u, Map<String, dynamic> raw) =>
          LlmLedValidator.validate(LlmLedOutput.tryParse(raw['output'])!, ctx(closed, u));
      final ask = _out(text: '그 일도 마음이 쓰이셨겠어요. 어떤 점이 가장 걱정되세요?');
      expect(ctx(closed, '사실 엄마 건강검진 결과가 더 걱정돼요').newTopic, isTrue);
      expect(vc('사실 엄마 건강검진 결과가 더 걱정돼요', ask), isEmpty);
      expect(vc('발표 때 또 막힐 것 같아요', ask), contains('exploring_after_closed'));
      expect(vc('대화가 자꾸 겉도는 것 같아요',
          _out(moves: ['repair'], text: '답답하셨겠어요. 지금 가장 이야기하고 싶은 건 무엇인가요?')), isEmpty);
    });
    test('respond_v2: an intervention step always carries an id', () {
      final raw = Map<String, dynamic>.from(_out()['output'] as Map)..['intervention'] = {'step': 'prompt'};
      expect(LlmLedOutput.tryParse(raw), isNull);
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
          api: _Api([_out(moves: ['integrate', 'offer_close'], interventionId: id, step: 'integration', action: 'offer_close', text: '그렇게 보면 조금 가벼워지네요. 여기까지 정리해 볼까요?')]),
          appGuide: _guide);
      expect(i.status, 'success', reason: '${i.violations}');
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

    test('a classified API failure: transport fallback with its status, no session change', () async {
      final s = _session();
      final t = await _harness().handleLlmLedTurn(
          session: s, userMessage: '발표가 걱정돼요', api: _FailApi(const CounselingRespondFailure('http_429',
              httpStatus: 429, retryAfter: true)), appGuide: _guide);
      expect(t.result, isNull);
      expect(t.status, 'http_error');
      expect(t.group, 'transport_fallback');
      expect(t.requestStatus, 'http_429');
      expect(t.failure!.retryAfter, isTrue);
      expect(s.messages, isEmpty);
      expect(CounselingRespondFailure.fromResponse(502, {'detail': {'reason': 'http_5xx', 'upstream_status': 503}}).httpStatus, 503);
      expect(CounselingRespondFailure.fromResponse(401, {'detail': 'x'}).requestStatus, 'http_4xx_other');
    });

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

    test('A/B: balanced hidden assignment (2 A + 2 B per block of four sessions)', () async {
      final api = _Api([_out(moves: ['acknowledge', 'open_question'], text: 'B 경로 응답이에요. 어떤 점이 걱정되나요?')]);
      final p = CounselingProvider(
        knowledgeRepository: _repo, appGuideRepository: _guide, currentWeek: 4, instantEmpathy: false,
        llmLedApi: api, llmLedAlternate: true, random: Random(7), harness: _harness());
      await p.initialize();
      final paths = <String>[];
      for (var i = 0; i < 8; i++) {
        if (i > 0) await p.reset();
        await p.sendMessage('발표가 있어');
        final b = p.messages.last.text.startsWith('B 경로');
        expect(p.experimentPath, b ? 'B' : 'A');
        paths.add(p.experimentPath);
      }
      expect(paths.where((x) => x == 'B').length, 4, reason: '$paths');
      expect(paths.take(4).where((x) => x == 'B').length, 2, reason: '$paths');
    });
  });
}
