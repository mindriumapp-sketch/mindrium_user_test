import 'counseling_state.dart';
import 'llm_service.dart';

/// 실제 모델 없이 harness 를 끝까지 돌리기 위한 결정적(deterministic) 구현.
///
/// 단순 echo 가 아니라 state 별 fixture 를 돌려준다. 그래야 state 전이,
/// provenance 검증, 파싱 실패 경로까지 모델 없이 테스트할 수 있다.
class MockLlmService implements LlmService {
  /// 프롬프트에서 읽어낸 state 이름 → 원문 응답.
  final Map<String, String> responses;

  /// 어느 fixture 에도 걸리지 않을 때 쓸 응답.
  final String defaultResponse;

  /// 호출될 때마다 던질지 여부. 오류 경로 테스트용.
  final bool throwOnGenerate;

  /// harness 가 LLM 을 호출했는지 확인하기 위한 기록.
  final List<LlmRequest> receivedRequests = [];

  MockLlmService({
    Map<String, String>? responses,
    String? defaultResponse,
    this.throwOnGenerate = false,
  }) : responses = responses ?? defaultFixtures,
       defaultResponse = defaultResponse ?? _defaultReply;

  static const String _defaultReply = '''
{
  "reply": "지금 어떤 점이 가장 신경 쓰이는지 한 가지만 이야기해 주실 수 있을까요?",
  "dialogue_act": "explore",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
''';

  /// state 이름별 기본 fixture. 키는 CounselingState.wireName 과 같다.
  static final Map<String, String> defaultFixtures = {
    'check_in': '''
{
  "reply": "오늘은 어떤 마음으로 오셨어요? 지금 느끼는 불안이 어느 정도인지부터 들려주세요.",
  "dialogue_act": "explore",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
''',
    'explore': '''
{
  "reply": "그 상황에서 특히 어떤 순간이 가장 걱정되셨나요?",
  "dialogue_act": "explore",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
''',
    'reflect': '''```json
{
  "reply": "말씀을 들어보니 '실수하면 사람들이 나를 무능하게 볼 것이다'라는 생각이 반복되는 것 같아요. 지금도 비슷한 걱정에 가까울까요?",
  "dialogue_act": "reflect",
  "referenced_cbt_ids": ["week3_thought_examples"],
  "referenced_user_context_ids": []
}
```''',
    'intervention': '''
{
  "reply": "그 생각을 조금 더 균형 잡힌 문장으로 바꿔본다면 어떻게 적어볼 수 있을까요?",
  "dialogue_act": "socratic_question",
  "referenced_cbt_ids": ["week4_alternative_thought_01"],
  "referenced_user_context_ids": []
}
''',
    'closing': '''
{
  "reply": "오늘 이야기한 내용을 정리하면, 발표 상황에서 떠오르는 생각을 한 번 더 살펴보셨어요. 여기까지 하고 마무리할까요?",
  "dialogue_act": "closing",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
''',
  };

  /// 파싱 실패 경로를 테스트할 때 쓰는 fixture 모음.
  static const String malformedJson = '{ "reply": "따옴표가 닫히지 않았어요';
  static const String plainText = '오늘 하루는 어떠셨나요?';
  static const String emptyOutput = '   ';

  @override
  Future<LlmResponse> generate(LlmRequest request) async {
    receivedRequests.add(request);

    if (throwOnGenerate) {
      throw const LlmException('mock 런타임이 의도적으로 실패했습니다');
    }

    return LlmResponse(
      text: _fixtureFor(request) ?? defaultResponse,
      latency: Duration.zero,
    );
  }

  /// 프롬프트에서 현재 상태를 알아내 해당 fixture 를 고른다.
  ///
  /// 프롬프트 프로파일마다 상태를 드러내는 방식이 다르다. verbose 는 CURRENT_STATE
  /// 를 그대로 적고, compact 는 상태 머신 대신 이번 턴의 할 일만 적는다.
  /// 둘 다 지원해야 같은 fixture 로 두 프로파일을 비교할 수 있다.
  String? _fixtureFor(LlmRequest request) {
    final prompt = request.userPrompt;

    final explicit = RegExp(r'CURRENT_STATE:\s*(\w+)').firstMatch(prompt);
    if (explicit != null) return responses[explicit.group(1)];

    for (final state in CounselingState.values) {
      if (prompt.contains(state.currentTask)) return responses[state.wireName];
    }
    return null;
  }

  /// 편의 생성자: 모든 state 에 같은 원문을 돌려준다.
  factory MockLlmService.alwaysReturns(String raw) {
    return MockLlmService(
      responses: {
        for (final state in CounselingState.values) state.wireName: raw,
      },
      defaultResponse: raw,
    );
  }
}
