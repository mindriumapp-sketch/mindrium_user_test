import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

Future<String> loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  CounselingHarness harnessWith(MockLlmService llm) {
    return CounselingHarness(
      llm: llm,
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
    );
  }

  CounselingSessionState newSession({
    CounselingState state = CounselingState.explore,
    int week = 4,
    MindriumCounselingContext? userContext,
  }) {
    return CounselingSessionState(
      sessionId: 'test',
      currentWeek: week,
      state: state,
      userContext: userContext,
    );
  }

  /// 사용자 기록이 하나 있는 컨텍스트.
  MindriumCounselingContext contextWithDiary() {
    return MindriumCounselingContext(
      currentWeek: 4,
      relevantItems: [
        UserContextItem(
          id: 'diary:abc123',
          type: UserContextType.diary,
          text: '상황: 연구 발표 / 생각: 질문에 답을 못하면 무능해 보일 것이다',
          occurredAt: DateTime(2026, 8, 30),
          sud: 7,
        ),
      ],
      recentSud: const SudContext(
        latest: 7,
        weeklyAverage: 6.3,
        trend: 'increasing',
      ),
    );
  }

  test('T5 정상 입력이면 LLM 을 호출하고 답변을 만든다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);
    final session = newSession();

    final result = await harness.handleTurn(
      session: session,
      userMessage: '내일 발표인데 너무 불안해요.',
    );

    expect(llm.receivedRequests, hasLength(1));
    expect(result.handledBySafety, isFalse);
    expect(result.safety.level, SafetyLevel.normal);
    expect(result.assistantMessage.text, isNotEmpty);
    expect(result.assistantMessage.parseStatus, ParseStatus.strict);
  });

  test('T5 프롬프트에 현재 상태와 허용 행위가 실린다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    await harness.handleTurn(
      session: newSession(state: CounselingState.reflect),
      userMessage: '발표에서 실수할까 봐 걱정돼요.',
    );

    final prompt = llm.receivedRequests.single.userPrompt;
    expect(prompt, contains('CURRENT_STATE: reflect'));
    expect(prompt, contains('ALLOWED_DIALOGUE_ACTS: reflect, summarize, socratic_question'));
    expect(prompt, contains('USER_MESSAGE:'));
  });

  test('T5 프롬프트에 CBT 근거는 id 로만 들어가고 source 경로는 새지 않는다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    await harness.handleTurn(
      session: newSession(state: CounselingState.intervention),
      userMessage: '생각을 바꾸는 게 잘 안 돼요.',
    );

    final prompt = llm.receivedRequests.single.userPrompt;
    expect(prompt, contains('CBT_CONTEXT:'));
    expect(prompt, contains('[id=week'));
    expect(prompt, isNot(contains('lib/features/')));
    expect(prompt, isNot(contains('assets/')));
  });

  test('T6 위기 발화는 LLM 을 호출하지 않는다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);
    final session = newSession();

    final result = await harness.handleTurn(
      session: session,
      userMessage: '요즘 그냥 죽고 싶어요.',
    );

    expect(llm.receivedRequests, isEmpty);
    expect(result.handledBySafety, isTrue);
    expect(result.safety.level, SafetyLevel.crisis);
    expect(result.safety.reasonCode, 'keyword_crisis');
    expect(result.assistantMessage.text, contains('109'));
  });

  test('T6 주의 수준도 LLM 을 호출하지 않는다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(),
      userMessage: '요즘 공황이 와서 견딜 수 없어요.',
    );

    expect(llm.receivedRequests, isEmpty);
    expect(result.handledBySafety, isTrue);
    expect(result.safety.level, SafetyLevel.elevated);
    expect(result.uiAction, CounselingUiAction.openRelaxation);
  });

  test('T6 안전 대응 턴은 상담 단계를 진행시키지 않는다', () async {
    final harness = harnessWith(MockLlmService());
    final session = newSession(state: CounselingState.explore);

    final result = await harness.handleTurn(
      session: session,
      userMessage: '자해 생각이 들어요.',
    );

    expect(result.state, CounselingState.explore);
    expect(session.state, CounselingState.explore);
    expect(session.turnsInCurrentState, 0);
  });

  test('T7 상태마다 허용 행위가 달라진다', () {
    expect(
      CounselingState.explore.allowedActs,
      isNot(equals(CounselingState.closing.allowedActs)),
    );
    expect(
      CounselingState.closing.allowedActs,
      contains(DialogueAct.closing),
    );
    expect(
      CounselingState.explore.allowedActs,
      isNot(contains(DialogueAct.closing)),
    );
  });

  test('T7 허용되지 않은 발화 행위는 unknown 으로 내린다', () async {
    // explore 단계에서는 closing 이 허용되지 않는다.
    final llm = MockLlmService.alwaysReturns('''
{
  "reply": "오늘은 여기까지 할까요?",
  "dialogue_act": "closing",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
''');
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(state: CounselingState.explore),
      userMessage: '발표가 걱정돼요.',
    );

    expect(result.assistantMessage.dialogueAct, DialogueAct.unknown);
  });

  test('T8 이번 턴에 제공하지 않은 CBT id 는 제거한다', () async {
    // week8_gad7_01 은 실재하는 id 지만 이 턴의 CBT_CONTEXT 에는 없다.
    final llm = MockLlmService.alwaysReturns('''
{
  "reply": "그 생각을 조금 더 살펴볼까요?",
  "dialogue_act": "explore",
  "referenced_cbt_ids": ["week4_nonexistent_therapy", "week8_gad7_01"],
  "referenced_user_context_ids": []
}
''');
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(state: CounselingState.explore),
      userMessage: '발표가 걱정돼요.',
    );

    expect(result.assistantMessage.referencedCbtIds, isEmpty);
  });

  test('T8 제공한 id 는 그대로 남는다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    // reflect fixture 는 week3_thought_examples 를 인용하고,
    // 3주차 reflect 단계의 retrieval 은 그 항목을 상위로 올린다.
    final result = await harness.handleTurn(
      session: newSession(state: CounselingState.reflect, week: 3),
      userMessage: '사람들이 나를 무능하게 볼 것 같다는 생각이 들어요.',
    );

    expect(
      llm.receivedRequests.single.userPrompt,
      contains('[id=week3_thought_examples]'),
    );
    expect(
      result.assistantMessage.referencedCbtIds,
      ['week3_thought_examples'],
    );
  });

  test('T9 제공하지 않은 사용자 데이터 id 는 제거한다', () async {
    final llm = MockLlmService.alwaysReturns('''
{
  "reply": "이전에 적으신 일기와 비슷한 걱정이네요.",
  "dialogue_act": "reflect",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": ["diary:없는기록", "sud_11"]
}
''');
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(
        state: CounselingState.reflect,
        userContext: contextWithDiary(),
      ),
      userMessage: '또 같은 걱정이 들어요.',
    );

    expect(result.assistantMessage.referencedUserContextIds, isEmpty);
  });

  test('T9 제공한 사용자 데이터 id 는 그대로 남는다', () async {
    final llm = MockLlmService.alwaysReturns('''
{
  "reply": "이전에 '질문에 답을 못하면 무능해 보일 것이다'라고 적으셨네요.",
  "dialogue_act": "reflect",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": ["diary:abc123"]
}
''');
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(
        state: CounselingState.reflect,
        userContext: contextWithDiary(),
      ),
      userMessage: '또 같은 걱정이 들어요.',
    );

    expect(result.assistantMessage.referencedUserContextIds, ['diary:abc123']);
  });

  test('T9 컨텍스트가 없으면 사용자 데이터 id 를 전부 제거한다', () async {
    final llm = MockLlmService.alwaysReturns('''
{
  "reply": "이전 기록을 보니 비슷하네요.",
  "dialogue_act": "reflect",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": ["diary:abc123"]
}
''');
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(state: CounselingState.reflect),
      userMessage: '또 같은 걱정이 들어요.',
    );

    expect(result.assistantMessage.referencedUserContextIds, isEmpty);
  });

  test('T23 사용자 컨텍스트가 프롬프트에 id 와 함께 실린다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    await harness.handleTurn(
      session: newSession(
        state: CounselingState.reflect,
        userContext: contextWithDiary(),
      ),
      userMessage: '발표가 또 걱정돼요.',
    );

    final prompt = llm.receivedRequests.single.userPrompt;
    expect(prompt, contains('USER_CONTEXT:'));
    expect(prompt, contains('[id=diary:abc123]'));
    expect(prompt, contains('불안 점수(SUD): 최근 7, 평균 6.3, 추이 increasing'));
  });

  test('T23 컨텍스트가 없으면 과거 기록을 언급하지 말라고 지시한다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    await harness.handleTurn(
      session: newSession(state: CounselingState.reflect),
      userMessage: '발표가 또 걱정돼요.',
    );

    final prompt = llm.receivedRequests.single.userPrompt;
    expect(prompt, contains('참조할 사용자 기록이 없습니다'));
    expect(prompt, isNot(contains('[id=diary:')));
  });

  test('T13 모델이 예외를 던지면 안전한 오류 응답을 준다', () async {
    final llm = MockLlmService(throwOnGenerate: true);
    final harness = harnessWith(llm);
    final session = newSession(state: CounselingState.explore);

    final result = await harness.handleTurn(
      session: session,
      userMessage: '발표가 걱정돼요.',
    );

    expect(result.assistantMessage.text, contains('다시 이야기해'));
    expect(result.assistantMessage.dialogueAct, DialogueAct.unknown);
    expect(result.state, CounselingState.explore);
    expect(session.totalTurns, 1);
  });

  test('T14 빈 출력이면 오류 응답으로 물러선다', () async {
    final llm = MockLlmService.alwaysReturns(MockLlmService.emptyOutput);
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(),
      userMessage: '발표가 걱정돼요.',
    );

    expect(result.assistantMessage.parseStatus, ParseStatus.empty);
    expect(result.assistantMessage.text, contains('다시 이야기해'));
  });

  test('T14 깨진 JSON 이어도 대화는 이어진다', () async {
    final llm = MockLlmService.alwaysReturns(MockLlmService.malformedJson);
    final harness = harnessWith(llm);
    final session = newSession(state: CounselingState.explore);

    final result = await harness.handleTurn(
      session: session,
      userMessage: '발표가 걱정돼요.',
    );

    expect(result.assistantMessage.parseStatus, ParseStatus.fallback);
    expect(result.assistantMessage.text, isNotEmpty);
    // 무엇을 했는지 모르는 턴은 단계를 넘기지 않는다.
    expect(result.state, CounselingState.explore);
  });

  test('T15 한 턴이 끝나면 상태가 전이된다', () async {
    final harness = harnessWith(MockLlmService());
    final session = newSession(state: CounselingState.checkIn);

    final result = await harness.handleTurn(
      session: session,
      userMessage: '오늘은 좀 불안했어요.',
    );

    // 체크인은 한 번 주고받으면 탐색으로 넘어간다.
    expect(result.state, CounselingState.explore);
    expect(session.state, CounselingState.explore);
    expect(session.totalTurns, 1);
    expect(session.turnsInCurrentState, 0);
  });

  test('T15 한 단계에 오래 머물면 다음 단계로 넘어간다', () async {
    const policy = CounselingStatePolicy();

    var state = CounselingState.explore;
    state = policy.next(
      current: state,
      turnsInCurrentState: CounselingStatePolicy.maxTurnsPerState,
      totalTurns: 5,
      lastAct: DialogueAct.explore,
    );

    expect(state, CounselingState.reflect);
  });

  test('T15 세션 최대 턴을 넘으면 마무리로 보낸다', () {
    const policy = CounselingStatePolicy();

    final state = policy.next(
      current: CounselingState.explore,
      turnsInCurrentState: 0,
      totalTurns: CounselingStatePolicy.maxSessionTurns,
      lastAct: DialogueAct.explore,
    );

    expect(state, CounselingState.closing);
  });

  test('T15 상태는 모델 출력이 아니라 정책이 정한다', () async {
    // 모델이 closing 을 시도해도 explore 단계에서는 단계를 바꾸지 못한다.
    final llm = MockLlmService.alwaysReturns('''
{
  "reply": "마무리할까요?",
  "dialogue_act": "closing",
  "referenced_cbt_ids": [],
  "referenced_user_context_ids": []
}
''');
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(state: CounselingState.explore),
      userMessage: '발표가 걱정돼요.',
    );

    expect(result.state, isNot(CounselingState.closing));
  });
}
