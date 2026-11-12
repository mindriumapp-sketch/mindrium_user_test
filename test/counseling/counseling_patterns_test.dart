import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/data/counseling/counseling_patterns.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

class Source implements MindriumDataSource {
  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() async => [];
  @override
  Future<List<Map<String, dynamic>>> listWorryGroups() async => [];
  @override
  Future<List<Map<String, dynamic>>> listRelaxationTasks() async => [];
}

class IntentApi implements CounselingPatternIntentApi {
  final bool result;
  int calls = 0;
  IntentApi(this.result);
  @override
  Future<bool> isPatternRequest(String message) async {
    calls++;
    return result;
  }
}

class ForgedApi implements CounselingRespondApi {
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<Map<String, dynamic>> respond(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    bodies.add(body);
    return {
      'output': {
        'domain': 'counseling',
        'dialogue_moves': ['acknowledge'],
        'intervention': null,
        'used_user_fact_ids': ['pattern:place:1'],
        'used_app_fact_ids': [],
        'definition_id': null,
        'session_action': 'continue',
        'statement': '최근 일기 4건 모두 학교에서 작성했어요.',
        'question': null,
      },
      'prompt_version': 'test',
    };
  }
}

class NaturalApi implements CounselingRespondApi {
  @override
  Future<Map<String, dynamic>> respond(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 8),
  }) async => {
    'output': {
      'domain': 'counseling',
      'dialogue_moves': ['acknowledge', 'open_question'],
      'intervention': null,
      'used_user_fact_ids': [
        'pattern:scope',
        'pattern:time:1',
        'pattern:place:1',
        'pattern:score:mean',
        'pattern:topic:1',
      ],
      'used_app_fact_ids': [],
      'definition_id': null,
      'session_action': 'continue',
      'statement':
          '최근 28일 일기 5건에서 일기에 적은 시간 기준 오후 3건, 장소 학교 2건이었고, 상황 발표 걱정 3건이 기록됐어요. 마지막 불안 점수 4건의 평균은 6.5점이었어요.',
      'question': '기록된 발표 상황 중 어떤 일이 있었는지 살펴보고 싶으세요?',
    },
    'prompt_version': 'test',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<String> load(String p) => File(p).readAsString();
  const patterns = CounselingPatterns(
    windowDays: 28,
    diaryCount: 4,
    topics: ['학교 발표'],
    patterns: [
      CounselingPattern(
        id: 'place:1',
        kind: 'place',
        label: '학교',
        text: '최근 28일 일기 4건 중 3건에 장소 학교가 기록됐습니다.',
      ),
      CounselingPattern(
        id: 'time:recorded:오후',
        kind: 'time',
        label: '오후',
        text: '최근 28일 일기 4건 중 3건은 일기에 적은 시간 기준 오후에 해당합니다.',
      ),
    ],
  );
  late LocalCbtKnowledgeRepository repo;
  late LocalAppGuideRepository guide;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: load);
    await repo.initialize();
    guide = LocalAppGuideRepository(loadAsset: load);
    await guide.initialize();
  });
  CounselingProvider create(
    Future<CounselingPatterns> Function() loader, {
    CounselingRespondApi? api,
    CounselingPatternIntentApi? intentApi,
  }) => CounselingProvider(
    knowledgeRepository: repo,
    appGuideRepository: guide,
    currentWeek: 4,
    llmLedApi: api,
    patternIntentApi: intentApi,
    contextBuilder: MindriumContextBuilder(
      dataSource: Source(),
      loadPatterns: loader,
    ),
    harness: CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repo,
    ),
  );

  test('관련 발화에서만 기록을 참고하고 매 턴 재조회하지 않는다', () async {
    var loads = 0;
    final p = create(() async {
      loads++;
      return patterns;
    });
    await p.initialize();
    await p.sendMessage('학교에 가면 걱정돼요');
    expect(p.messages.last.text, isNot(contains('일기 4건 중 3건')));
    expect(p.messages.last.text, isNot(contains('실제 알림이 울')));
    await p.sendMessage('다른 이야기를 하고 싶어요');
    expect(p.messages.last.text, isNot(contains('장소 학교')));
    expect(loads, 1);
  });
  test('직접 요청하면 기록에 근거한 집계를 안내한다', () async {
    final p = create(() async => patterns);
    await p.initialize();
    await p.sendMessage('내 불안 패턴을 분석해줘');
    expect(p.messages.last.text, contains('일기 4건 중 3건'));
  });
  test('스크린샷의 상태 질문은 AI 분류 없이도 기록을 안내한다', () async {
    final p = create(() async => patterns);
    await p.initialize();
    await p.sendMessage('요즘 내 상태 어떤것 같아?');
    expect(p.messages.last.text, contains('장소 학교'));
    expect(p.messages.last.text, contains('오후'));
  });
  test('AI가 넓은 의미의 상태 질문으로 판단하면 분석 근거를 전달한다', () async {
    final api = ForgedApi();
    final intent = IntentApi(true);
    final p = create(() async => patterns, api: api, intentApi: intent);
    await p.initialize();
    await p.sendMessage('요즘 내가 어떤 것 같아?');
    expect(intent.calls, 1);
    final facts = api.bodies.single['user_facts'] as List;
    expect(facts.any((f) => f['id'] == 'pattern:scope'), isTrue);
    expect(facts.any((f) => f['id'] == 'pattern:place:1'), isTrue);
    expect(facts.any((f) => f['id'] == 'pattern:time:recorded:오후'), isTrue);
  });
  test('AI가 일반 질문으로 판단하면 전체 패턴을 넘기지 않는다', () async {
    final api = ForgedApi();
    final intent = IntentApi(false);
    final p = create(() async => patterns, api: api, intentApi: intent);
    await p.initialize();
    await p.sendMessage('안녕하세요');
    expect(intent.calls, 1);
    final facts = api.bodies.single['user_facts'] as List;
    expect(facts.any((f) => f['id'] == 'pattern:scope'), isFalse);
  });
  test('분석 거부에는 AI 분류를 실행하지 않는다', () async {
    final api = ForgedApi();
    final intent = IntentApi(true);
    final p = create(() async => patterns, api: api, intentApi: intent);
    await p.initialize();
    await p.sendMessage('상태 분석하지 마');
    expect(intent.calls, 0);
    final facts = api.bodies.single['user_facts'] as List;
    expect(facts.any((f) => (f['id'] as String).startsWith('pattern:')), isFalse);
  });
  test('다양한 상태 분석 요청을 인식한다', () {
    for (final text in [
      '상태 분석해줘',
      '내 상태를 분석해 줘',
      '요즘 내 상태가 어떤지 알려줘',
      '요즘 내 상태 어떤것 같아?',
      '요즘 내 상태 어떤 것 같아?',
      '최근 내 감정 경향을 살펴봐줘',
      '지금까지 기록을 보고 마음 상태를 정리해줘',
      '내가 언제 가장 불안한지 알려줘',
      '내 불안 점수 알려줘',
      '불안 패턴 분석해줘',
    ]) {
      expect(
        CounselingPatterns.explicitlyRequested(text),
        isTrue,
        reason: text,
      );
    }
  });
  test('일반 상담과 사용법 질문, 분석 거부는 분석 요청이 아니다', () {
    for (final text in [
      '오늘 발표 때문에 너무 불안해요',
      '요즘 기분이 좋지 않아요',
      '불안 분석 기능은 어디서 볼 수 있어?',
      '상태 분석 메뉴를 어떻게 사용해?',
      '내 상태는 분석하지 마',
      '불안 패턴을 분석하지 말아줘',
      '과거 기록 언급하지 마',
    ]) {
      expect(
        CounselingPatterns.explicitlyRequested(text),
        isFalse,
        reason: text,
      );
    }
  });
  test('상태 분석 요청도 AI에 패턴 근거를 전달한다', () async {
    final api = ForgedApi();
    final p = create(() async => patterns, api: api);
    await p.initialize();
    await p.sendMessage('요즘 내 상태가 어떤지 알려줘');
    final facts = api.bodies.single['user_facts'] as List;
    expect(facts.any((f) => f['id'] == 'pattern:place:1'), isTrue);
    expect(facts.any((f) => f['id'] == 'pattern:time:recorded:오후'), isTrue);
    expect(p.messages.last.text, contains('장소 학교'));
  });
  test('기록 언급 중단 요청 뒤에는 관련 장소를 말하지 않는다', () async {
    final p = create(() async => patterns);
    await p.initialize();
    await p.sendMessage('과거 기록 언급하지 마');
    await p.sendMessage('학교에 가기가 걱정돼요');
    expect(
      p.messages.last.referencedUserContextIds,
      isNot(contains('pattern:place:1')),
    );
    expect(p.messages.last.text, isNot(contains('일기 4건 중 3건')));
  });
  test('패턴 조회 실패 시 상담을 계속한다', () async {
    final p = create(() async => throw StateError('offline'));
    await p.initialize();
    await p.sendMessage('학교에 가기가 걱정돼요');
    expect(p.messages.last.role, 'assistant');
    expect(p.userContext!.degraded, isTrue);
  });
  test('위기 발화는 기록 대신 안전 응답을 우선한다', () async {
    final p = create(() async => patterns);
    await p.initialize();
    await p.sendMessage('학교에서 자살하고 싶어요');
    expect(p.messages.last.text, isNot(contains('일기 4건 중 3건')));
    expect(p.lastSafetyLevel, SafetyLevel.crisis);
  });
  test('LLM에 관련 집계만 전달하고 숫자를 바꾼 응답은 거절한다', () async {
    final api = ForgedApi();
    final p = create(() async => patterns, api: api);
    await p.initialize();
    await p.sendMessage('학교에 가면 걱정돼요');
    final facts = api.bodies.single['user_facts'] as List;
    expect(facts.any((f) => f['id'] == 'pattern:place:1'), isTrue);
    expect(p.messages.last.text, isNot(contains('4건 중 3건')));
    expect(p.messages.last.text, isNot(contains('4건 모두')));
  });
  test('발표 고민과 관련된 주제라도 무관한 시간 통계를 답변으로 꺼내지 않는다', () async {
    const data = CounselingPatterns(
      windowDays: 28, diaryCount: 39, topics: ['발표 걱정'],
      patterns: [
        CounselingPattern(id: 'time:1', kind: 'time', label: '오후', text: '오후 20건'),
        CounselingPattern(id: 'topic:1', kind: 'topic', label: '발표 걱정', text: '발표 걱정 3건'),
      ],
    );
    const message = '다음 주에 발표를 해야하는데, 말을 더듬으면 사람들이 저를 무능하다고 생각할까봐 걱정돼요.';
    expect(data.relevant(message).map((p) => p.kind), ['topic']);
    final p = create(() async => data);
    await p.initialize();
    await p.sendMessage(message);
    expect(p.messages.last.text, isNot(contains('오후 20건')));
    expect(p.messages.last.text, isNot(contains('이 기록이 지금 이야기와 관련이 있을까요')));
  });
  test('무관한 발화에는 집계를 모델에 전달하지 않는다', () async {
    final api = ForgedApi();
    final p = create(() async => patterns, api: api);
    await p.initialize();
    await p.sendMessage('가족과 대화하는 게 힘들어요');
    final facts = api.bodies.single['user_facts'] as List;
    expect(
      facts.where((f) => (f['id'] as String).startsWith('pattern:')),
      isEmpty,
    );
  });

  test('전체 분석은 여러 시간대보다 장소와 점수를 우선 포함한다', () {
    const p = CounselingPatterns(
      windowDays: 28,
      diaryCount: 4,
      topics: [],
      patterns: [
        CounselingPattern(
          id: 'time:1',
          kind: 'time',
          label: '오전',
          text: '오전 3건',
        ),
        CounselingPattern(
          id: 'time:2',
          kind: 'time',
          label: '오후',
          text: '오후 3건',
        ),
        CounselingPattern(
          id: 'time:3',
          kind: 'time',
          label: '저녁',
          text: '저녁 3건',
        ),
        CounselingPattern(
          id: 'place:1',
          kind: 'place',
          label: '학교',
          text: '학교 1건',
        ),
        CounselingPattern(
          id: 'score:mean',
          kind: 'score',
          label: '불안 점수',
          text: '평균 6점',
        ),
      ],
    );
    final result = p.relevant('불안 분석해줘', explicit: true);
    expect(result.map((e) => e.kind), ['time', 'place', 'score']);
  });
  test('분석 요청은 AI API를 호출하고 오류가 나면 실제 집계로 대체한다', () async {
    final api = ForgedApi();
    final p = create(() async => patterns, api: api);
    await p.initialize();
    await p.sendMessage('불안 분석해줘');
    final facts = api.bodies.single['user_facts'] as List;
    expect(facts.any((f) => f['id'] == 'pattern:place:1'), isTrue);
    expect(facts.any((f) => f['id'] == 'pattern:time:recorded:오후'), isTrue);
    expect(p.messages.last.text, contains('장소 학교'));
  });

  test('AI가 근거를 정확히 사용하면 자연스러운 답변을 채택한다', () async {
    const ptn = CounselingPatterns(
      windowDays: 28,
      diaryCount: 5,
      topics: ['발표 걱정'],
      patterns: [
        CounselingPattern(
          id: 'time:1',
          kind: 'time',
          label: '오후',
          text: '시간 원본',
          aiText: '일기에 적은 시간 기준 오후 3건',
        ),
        CounselingPattern(
          id: 'place:1',
          kind: 'place',
          label: '학교',
          text: '장소 원본',
          aiText: '장소 학교 2건',
        ),
        CounselingPattern(
          id: 'score:mean',
          kind: 'score',
          label: '불안 점수',
          text: '점수 원본',
          aiText: '마지막 불안 점수 4건의 평균 6.5점',
        ),
        CounselingPattern(
          id: 'topic:1',
          kind: 'topic',
          label: '발표 걱정',
          text: '상황 원본',
          aiText: '상황 발표 걱정 3건',
        ),
      ],
    );
    final p = create(() async => ptn, api: NaturalApi());
    await p.initialize();
    await p.sendMessage('불안 분석해줘');
    expect(p.messages.last.text, contains('평균은 6.5점'));
    expect(p.messages.last.text, contains('기록된 발표 상황 중'));
    expect(
      p.messages.last.referencedUserContextIds,
      contains('pattern:place:1'),
    );
  });
}
