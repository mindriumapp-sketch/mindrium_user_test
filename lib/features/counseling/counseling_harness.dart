import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'counseling_state.dart';
import 'llm_service.dart';
import 'output_parser.dart';
import 'prompt_builder.dart';
import 'safety_gate.dart';

/// 한 세션의 진행 상태. Step 1 은 메모리에만 둔다(DB 저장은 Step 4).
class CounselingSessionState {
  final String sessionId;

  /// 사용자가 현재 진행 중인 프로그램 주차. Step 2 에서 실제 값으로 채운다.
  final int currentWeek;

  /// 세션 시작 시 한 번 만들어 두는 사용자 컨텍스트.
  /// 턴마다 다시 조회하지 않고, 새 기록이 생긴 경우에만 명시적으로 갈아끼운다.
  MindriumCounselingContext? userContext;

  CounselingState state;
  int turnsInCurrentState;
  int totalTurns;
  final List<CounselingMessage> messages;
  String? summary;

  CounselingSessionState({
    required this.sessionId,
    required this.currentWeek,
    this.userContext,
    this.state = CounselingState.checkIn,
    this.turnsInCurrentState = 0,
    this.totalTurns = 0,
    List<CounselingMessage>? messages,
    this.summary,
  }) : messages = messages ?? [];
}

/// 한 턴을 처리한 결과.
class CounselingTurnResult {
  final CounselingMessage assistantMessage;

  /// 턴이 끝난 뒤의 상태.
  final CounselingState state;
  final SafetyResult safety;

  /// 안전 관문에 걸려 모델을 호출하지 않았는지.
  final bool handledBySafety;

  /// harness 가 사용자에게 제안하는 앱 동작. 모델이 정하지 않는다.
  final CounselingUiAction? uiAction;

  final String promptVersion;

  const CounselingTurnResult({
    required this.assistantMessage,
    required this.state,
    required this.safety,
    required this.handledBySafety,
    required this.promptVersion,
    this.uiAction,
  });
}

/// 앱 동작 제안. LLM 출력이 아니라 harness 정책에서 나온다.
enum CounselingUiAction {
  openRelaxation,
  openAbcDiary,
  recordSud,
}

/// 상담 한 턴의 파이프라인을 소유한다.
///
/// 여기에 DiariesApi / SudApi 를 넣지 않는다. 사용자 데이터 주입은 Step 2 의
/// MindriumContextBuilder 책임이다.
class CounselingHarness {
  final LlmService llm;
  final SafetyGate safetyGate;
  final CbtKnowledgeRepository knowledgeRepository;
  final PromptBuilder promptBuilder;
  final CounselingOutputParser outputParser;
  final SafetyResponseFactory safetyResponseFactory;
  final CounselingStatePolicy statePolicy;

  /// 한 턴에 제공할 CBT 근거 수. 창을 넘기지 않도록 적게 유지한다.
  static const int knowledgeLimit = 3;

  CounselingHarness({
    required this.llm,
    required this.safetyGate,
    required this.knowledgeRepository,
    this.promptBuilder = const PromptBuilder(),
    this.outputParser = const CounselingOutputParser(),
    this.safetyResponseFactory = const SafetyResponseFactory(),
    this.statePolicy = const CounselingStatePolicy(),
  });

  Future<CounselingTurnResult> handleTurn({
    required CounselingSessionState session,
    required String userMessage,
  }) async {
    // 1. 안전 관문. 정상이 아니면 여기서 끝내고 모델을 호출하지 않는다.
    final safety = await safetyGate.evaluate(userMessage);
    if (!safety.isNormal) {
      return _safetyTurn(session, safety);
    }

    // 2~4. 현재 상태에 맞는 CBT 근거를 찾는다.
    final knowledge = knowledgeRepository.search(
      query: userMessage,
      week: session.currentWeek,
      tags: session.state.retrievalTags,
      limit: knowledgeLimit,
    );

    // 5~6. 허용 행위를 정하고 프롬프트를 만든다.
    final bundle = promptBuilder.build(
      PromptContext(
        state: session.state,
        userMessage: userMessage,
        knowledge: knowledge,
        allowedDialogueActs: session.state.allowedActs,
        userContext: session.userContext,
        sessionSummary: session.summary,
        recentMessages: _recentMessages(session),
      ),
    );

    // 7. 모델 호출. 실패해도 대화가 끊기지 않게 안전한 응답으로 바꾼다.
    final LlmResponse response;
    try {
      response = await llm.generate(
        LlmRequest(
          systemPrompt: bundle.systemPrompt,
          userPrompt: bundle.userPrompt,
        ),
      );
    } on Object {
      return _errorTurn(session, safety, bundle.promptVersion);
    }

    // 8~9. 파싱하고 검증한다.
    final parsed = outputParser.parse(response.text);
    if (parsed.reply.trim().isEmpty) {
      return _errorTurn(session, safety, bundle.promptVersion);
    }

    final validated = _validate(parsed, bundle, session.state);

    // 10. 상태 전이. 모델이 아니라 정책이 정한다.
    final nextState = statePolicy.next(
      current: session.state,
      turnsInCurrentState: session.turnsInCurrentState,
      totalTurns: session.totalTurns,
      lastAct: validated.dialogueAct,
    );

    final message = CounselingMessage(
      id: '${session.sessionId}_${session.totalTurns}_assistant',
      role: 'assistant',
      text: validated.reply,
      createdAt: DateTime.now(),
      dialogueAct: validated.dialogueAct,
      referencedCbtIds: validated.referencedCbtIds,
      referencedUserContextIds: validated.referencedUserContextIds,
      parseStatus: validated.parseStatus,
      latency: response.latency,
    );

    _advance(session, nextState);

    return CounselingTurnResult(
      assistantMessage: message,
      state: nextState,
      safety: safety,
      handledBySafety: false,
      promptVersion: bundle.promptVersion,
      uiAction: _uiActionFor(nextState, validated),
    );
  }

  /// 모델 출력에서 근거 없는 내용을 걷어낸다.
  ///
  /// - 이번 턴에 제공하지 않은 id 는 지운다. 실재하는 id 라도 마찬가지다.
  ///   모델이 지어낸 근거와 실제로 제공한 근거를 구분하는 것이 provenance 검증이다.
  /// - 허용되지 않은 발화 행위는 unknown 으로 내린다.
  CounselingModelOutput _validate(
    CounselingModelOutput output,
    PromptBundle bundle,
    CounselingState state,
  ) {
    final act = state.allowedActs.contains(output.dialogueAct)
        ? output.dialogueAct
        : DialogueAct.unknown;

    return CounselingModelOutput(
      reply: output.reply,
      dialogueAct: act,
      referencedCbtIds: output.referencedCbtIds
          .where(bundle.offeredCbtIds.contains)
          .toList(),
      referencedUserContextIds: output.referencedUserContextIds
          .where(bundle.offeredUserContextIds.contains)
          .toList(),
      parseStatus: output.parseStatus,
    );
  }

  List<CounselingMessage> _recentMessages(CounselingSessionState session) {
    final messages = session.messages;
    if (messages.length <= PromptBuilder.recentMessageWindow) return messages;
    return messages.sublist(
      messages.length - PromptBuilder.recentMessageWindow,
    );
  }

  CounselingTurnResult _safetyTurn(
    CounselingSessionState session,
    SafetyResult safety,
  ) {
    final message = CounselingMessage(
      id: '${session.sessionId}_${session.totalTurns}_safety',
      role: 'assistant',
      text: safetyResponseFactory.create(safety),
      createdAt: DateTime.now(),
      dialogueAct: DialogueAct.unknown,
      parseStatus: null,
    );

    // 안전 대응 턴은 상담 단계를 진행시키지 않는다.
    session.totalTurns += 1;

    return CounselingTurnResult(
      assistantMessage: message,
      state: session.state,
      safety: safety,
      handledBySafety: true,
      promptVersion: PromptBuilder.promptVersion,
      uiAction: safety.level == SafetyLevel.elevated
          ? CounselingUiAction.openRelaxation
          : null,
    );
  }

  CounselingTurnResult _errorTurn(
    CounselingSessionState session,
    SafetyResult safety,
    String promptVersion,
  ) {
    final message = CounselingMessage(
      id: '${session.sessionId}_${session.totalTurns}_error',
      role: 'assistant',
      text: '지금은 답변을 만들지 못했어요. 잠시 후 다시 이야기해 주시겠어요?',
      createdAt: DateTime.now(),
      dialogueAct: DialogueAct.unknown,
      parseStatus: ParseStatus.empty,
    );

    // 실패한 턴은 단계를 진행시키지 않는다.
    session.totalTurns += 1;

    return CounselingTurnResult(
      assistantMessage: message,
      state: session.state,
      safety: safety,
      handledBySafety: false,
      promptVersion: promptVersion,
    );
  }

  void _advance(CounselingSessionState session, CounselingState nextState) {
    session.totalTurns += 1;
    if (nextState == session.state) {
      session.turnsInCurrentState += 1;
    } else {
      session.state = nextState;
      session.turnsInCurrentState = 0;
    }
  }

  /// 단계에 맞는 앱 동작 제안. 모델의 suggested_action 을 쓰지 않는 이유가 여기 있다.
  CounselingUiAction? _uiActionFor(
    CounselingState state,
    CounselingModelOutput output,
  ) {
    if (state != CounselingState.intervention) return null;

    final mentionsRelaxation = output.referencedCbtIds.any(
      (id) => id.contains('relaxation'),
    );
    return mentionsRelaxation
        ? CounselingUiAction.openRelaxation
        : CounselingUiAction.openAbcDiary;
  }
}
