import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'assistant_intent.dart';
import 'intent/assistant_intent_router.dart';
import 'retrieval/app_guide_knowledge_retriever.dart';
import 'retrieval/counseling_knowledge_retriever.dart';
import 'retrieval/user_context_retriever.dart';
import 'response/app_guide_response.dart';
import 'response/app_guide_response_builder.dart';
import 'response/mixed_response_composer.dart';

export 'assistant_intent.dart';
export 'intent/assistant_intent_router.dart';
export 'retrieval/app_guide_knowledge_retriever.dart';
export 'retrieval/counseling_knowledge_retriever.dart';
export 'retrieval/previous_session_context.dart';
export 'retrieval/user_context_retriever.dart';
export 'response/app_guide_response.dart';
export 'response/app_guide_response_builder.dart';
export 'response/mixed_response_composer.dart';

/// `ChatPage`/`CounselingProvider` 위에 놓이는 최상위 진입점.
///
/// Phase 5 현재: 세 retrieval 경계(user/counseling/appGuide)로
/// [AssistantContext]를 만들고, 그중 상담에 쓰는 두 결과
/// (`RetrievalSummary`/CBT knowledge)를 [PrecomputedTurnContext]로
/// [CounselingHarness.handleTurn]에 그대로 넘긴다 — harness가 같은
/// 조회를 다시 하지 않는다. `PersonalContextSummary`/App Guide 결과는
/// 아직 상담 응답에 반영되지 않는다(그 결과는 [AssistantIntent]가 여전히
/// `counselingOnly`뿐이라서 소비할 곳이 없다) — 그래서 사용자에게 보이는
/// 동작은 기존과 100% 동일하다.
///
/// `CounselingHarness` 내부 로직(`retrievalSummaryBuilder`,
/// `knowledgeRepository.search`) 자체는 건드리지 않았다 — `handleTurn`을
/// 직접 생성해 쓰는 기존 호출부·테스트는 `precomputedContext`를 넘기지
/// 않으므로 이전과 완전히 동일하게 동작한다.
class MindRiumAssistantHarness {
  final CounselingHarness counselingHarness;
  final UserContextRetriever userContextRetriever;
  final CounselingKnowledgeRetriever counselingKnowledgeRetriever;
  final AppGuideKnowledgeRetriever appGuideKnowledgeRetriever;
  final AssistantIntentRouter intentRouter;
  final AppGuideResponseBuilder appGuideResponseBuilder;
  final MixedResponseComposer mixedResponseComposer;

  MindRiumAssistantHarness({
    required this.counselingHarness,
    UserContextRetriever? userContextRetriever,
    CounselingKnowledgeRetriever? counselingKnowledgeRetriever,
    this.appGuideKnowledgeRetriever = const NoOpAppGuideKnowledgeRetriever(),
    AssistantIntentRouter? intentRouter,
    this.appGuideResponseBuilder = const DeterministicAppGuideResponseBuilder(),
    this.mixedResponseComposer = const DeterministicMixedResponseComposer(),
  }) : userContextRetriever =
           userContextRetriever ?? const MindriumUserContextRetriever(),
       counselingKnowledgeRetriever =
           counselingKnowledgeRetriever ??
           LocalCbtKnowledgeAdapter(
             repository: counselingHarness.knowledgeRepository,
           ),
       intentRouter =
           intentRouter ?? const DeterministicAssistantIntentRouter();

  /// 이번 턴에 필요한 도메인을 판단한다.
  ///
  /// Phase 7A: 판정 결과는 [AssistantContext.intent]에 실려 로그/검증
  /// 목적으로만 쓰인다(shadow routing) — 아직 이 결과로 최종 응답 경로를
  /// 바꾸지 않는다. `hasMatch`(knowledge 존재 여부)와는 무관하게, "무엇을
  /// 원하는가"만 판정한다 — [AssistantIntentRouter] 문서 참고.
  AssistantIntent detectIntent(
    String userMessage, {
    bool counselingInProgress = false,
  }) => intentRouter.detect(
    userMessage,
    counselingInProgress: counselingInProgress,
  );

  /// 세 retrieval 경계를 모두 호출해 [AssistantContext]를 만든다.
  ///
  /// `previousSessionContext`는 [CounselingSessionState]가 아니라
  /// [CounselingProvider]가 세션 시작 시 조회해 둔 지난 세션 기억을 그대로
  /// 받는다 — 기본값 [PreviousSessionContext.none]이면 지난 세션을
  /// 참조하지 않는다(기존 harness 내부 조회와 동일한 조건).
  Future<AssistantContext> buildContext({
    required CounselingSessionState session,
    required String userMessage,
    PreviousSessionContext previousSessionContext = PreviousSessionContext.none,
  }) async {
    // A session is "in progress" once the user has sent at least one turn.
    final intent = detectIntent(
      userMessage,
      counselingInProgress: session.totalTurns > 0,
    );

    final userContext = await userContextRetriever.retrieve(
      UserContextRequest(
        userMessage: userMessage,
        context: session.userContext,
        recentMessages: session.messages,
        previousSessionContext: previousSessionContext,
      ),
    );
    final counselingKnowledge = await counselingKnowledgeRetriever.retrieve(
      CounselingKnowledgeRequest(
        query: userMessage,
        week: session.currentWeek,
        tags: session.state.retrievalTags,
        limit: CounselingHarness.knowledgeLimit,
      ),
    );
    final appGuideKnowledge = await appGuideKnowledgeRetriever.retrieve(
      AppGuideKnowledgeRequest(query: userMessage),
    );

    return AssistantContext(
      userMessage: userMessage,
      intent: intent,
      userContext: userContext,
      counselingKnowledge: counselingKnowledge,
      appGuideKnowledge: appGuideKnowledge,
    );
  }

  Future<CounselingTurnResult> handleTurn({
    required CounselingSessionState session,
    required String userMessage,
    PreviousSessionContext previousSessionContext = PreviousSessionContext.none,
  }) async {
    final context = await buildContext(
      session: session,
      userMessage: userMessage,
      previousSessionContext: previousSessionContext,
    );

    assert(context.userMessage == userMessage);

    // Phase 7C: intent에 따라 경로를 분기한다.
    if (context.intent.isAppGuideOnly) {
      // appGuideOnly: App Guide 응답만 반환
      final appGuideResponse = appGuideResponseBuilder.build(
        userMessage,
        context.appGuideKnowledge!,
      );
      return _adaptAppGuideToTurnResult(session, appGuideResponse);
    }

    if (context.intent.isMixed) {
      // mixed: 상담 + 앱 가이드를 합친다.
      final counselingResult = await counselingHarness.handleTurn(
        session: session,
        userMessage: userMessage,
        precomputedContext: _makePrecomputedContext(context),
      );
      final appGuideResponse = appGuideResponseBuilder.build(
        userMessage,
        context.appGuideKnowledge!,
      );
      return mixedResponseComposer.compose(
        counseling: counselingResult,
        appGuide: appGuideResponse,
      );
    }

    // counselingOnly (또는 fallback): 기존 상담 경로
    return counselingHarness.handleTurn(
      session: session,
      userMessage: userMessage,
      precomputedContext: _makePrecomputedContext(context),
    );
  }

  /// AssistantContext에서 CounselingHarness용 precomputedContext를 만든다.
  ///
  /// Phase 5 bridge: 위에서 이미 조회한 CBT knowledge/RetrievalSummary를
  /// 그대로 넘겨 harness가 같은 조회를 다시 하지 않게 한다.
  PrecomputedTurnContext? _makePrecomputedContext(AssistantContext context) {
    final counselingKnowledge = context.counselingKnowledge;
    final userContext = context.userContext;
    return (counselingKnowledge != null && userContext != null)
        ? PrecomputedTurnContext(
            knowledge: counselingKnowledge.items,
            retrievalSummary: userContext.retrievalSummary,
          )
        : null;
  }

  /// App Guide 응답을 CounselingTurnResult로 변환한다 (adapter pattern).
  ///
  /// 기존 UI/Provider를 건드리지 않으면서 appGuide 경로의 결과를
  /// 기존 counseling 경로와 동일한 contract로 반환한다.
  CounselingTurnResult _adaptAppGuideToTurnResult(
    CounselingSessionState session,
    AppGuideResponse appGuideResponse,
  ) {
    // 간단한 메시지 id 생성. 향후 더 정교한 tracking이 필요하면 개선.
    final messageId = 'app_guide_${DateTime.now().millisecondsSinceEpoch}';

    return CounselingTurnResult(
      assistantMessage: CounselingMessage(
        id: messageId,
        role: 'assistant',
        text: appGuideResponse.text,
        createdAt: DateTime.now(),
      ),
      state: session.state,
      stateBefore: session.state,
      safety: SafetyResult.ok,
      handledBySafety: false,
      promptVersion: 'app_guide_v1',
      realizationSource: RealizationSource.deterministic,
      retrievalProvenanceIds: appGuideResponse.sourceRefs,
    );
  }
}
