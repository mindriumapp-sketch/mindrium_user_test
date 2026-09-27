import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'compact_prompt_builder.dart';
import 'counseling_state.dart';
import 'hybrid_turn_router.dart';
import 'llm_service.dart';
import 'output_parser.dart';
import 'policy/production_turn_planner.dart';
import 'policy/realization/semantic_deterministic_realizer.dart';
import 'policy/rollout/realization_telemetry.dart';
import 'policy/rollout/rollout_config.dart';
import 'prompt_builder.dart';
import 'response_realizer.dart';
import 'safety_gate.dart';
import 'turn_plan.dart';
import 'turn_plan_prompt_builder.dart';

/// `handleTurn()`이 CBT 검색과 `RetrievalSummary` 계산을 다시 하지 않도록
/// 미리 계산해 넘기는 값. `MindRiumAssistantHarness`가 이미 같은 조회를
/// 끝냈을 때만 채운다 — Phase 5(Personal Context v2 + Precomputed Context
/// Bridge)에서 두 경로(assistant 계층/harness 내부)가 같은 retrieval을
/// 중복 계산하던 문제를 없애기 위한 다리다.
///
/// `null`이면(기존 `CounselingHarness`를 직접 생성해 쓰는 모든 호출부·
/// 테스트) 이전과 완전히 동일하게 harness가 직접 조회한다 — 이 필드가
/// 생기기 전의 동작을 그대로 보존한다.
class PrecomputedTurnContext {
  final List<CbtKnowledgeItem> knowledge;
  final RetrievalSummary retrievalSummary;

  const PrecomputedTurnContext({
    required this.knowledge,
    required this.retrievalSummary,
  });
}

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

  /// 이번 턴에 planner가 확정한 행동 계획. planning 미적용/안전 턴이면 null이다.
  final CounselingTurnPlan? turnPlan;

  /// 이번 턴을 어떻게 실현하기로 했는지.
  final TurnRoutingDecision? routing;

  /// 최종 사용자 문장을 만든 구현. 향후 D/local/remote 비교의 기준이다.
  final RealizationSource realizationSource;

  /// 이번 턴의 응답을 구성하는 데 실제로 사용한 사용자 기록 id.
  ///
  /// 모델이 "인용했다고 신고한" id(`referencedUserContextIds`)와 다르다.
  /// 이쪽은 harness 가 무엇을 근거로 문장을 만들었는지의 기록이다.
  final List<String> retrievalProvenanceIds;

  /// 턴이 끝난 뒤의 상태.
  final CounselingState state;
  final SafetyResult safety;

  /// 안전 관문에 걸려 모델을 호출하지 않았는지.
  final bool handledBySafety;

  /// harness 가 사용자에게 제안하는 앱 동작. 모델이 정하지 않는다.
  final CounselingUiAction? uiAction;

  final String promptVersion;

  /// 턴 시작 시점의 상태. 전이가 일어났는지 보려면 [state] 와 비교한다.
  final CounselingState stateBefore;

  /// 이번 턴에 프롬프트로 제공한 근거 id 수.
  ///
  /// 모델이 실제로 인용한 수(assistantMessage.referenced*)와 함께 보면
  /// 문제가 retrieval 인지, 프롬프트인지, 모델이 근거를 무시한 것인지 구분된다.
  final int offeredCbtIdCount;
  final int offeredUserContextIdCount;

  /// GPT가 [turnPlan]의 requiredAct 대신 allowedActsForTurn 안의 다른 행위를
  /// 선택했고, 그 선택이 실제로 채택됐는지. Adaptive Dialogue Policy Phase 1
  /// 선택 분포를 벤치마크로 확인하기 위한 필드다.
  final bool actChosenByModel;

  const CounselingTurnResult({
    required this.assistantMessage,
    required this.state,
    required this.stateBefore,
    required this.safety,
    required this.handledBySafety,
    required this.promptVersion,
    this.turnPlan,
    this.uiAction,
    this.offeredCbtIdCount = 0,
    this.offeredUserContextIdCount = 0,
    this.retrievalProvenanceIds = const [],
    this.routing,
    this.realizationSource = RealizationSource.deterministic,
    this.actChosenByModel = false,
  });
}

/// 앱 동작 제안. LLM 출력이 아니라 harness 정책에서 나온다.
/// 이번 턴에 **추천**하는 앱 활동.
///
/// 화면 이동 명령이 아니다. 상담은 활동을 알려줄 뿐이고, 수행 여부와 시점은
/// 사용자가 앱에서 스스로 정한다. **추천했다는 사실이 수행했다는 뜻은 아니다.**
/// 수행 여부는 서버 기록에 실제로 남았을 때만 인정한다.
typedef CounselingUiAction = CounselingActivity;

/// 상담 한 턴의 파이프라인을 소유한다.
///
/// 여기에 DiariesApi / SudApi 를 넣지 않는다. 사용자 데이터 주입은 Step 2 의
/// MindriumContextBuilder 책임이다.
class CounselingHarness {
  final LlmService llm;
  final SafetyGate safetyGate;
  final CbtKnowledgeRepository knowledgeRepository;
  final CounselingPromptBuilder promptBuilder;
  final CounselingOutputParser outputParser;
  final SafetyResponseFactory safetyResponseFactory;
  final CounselingStatePolicy statePolicy;
  final CounselingTurnPlanner? turnPlanner;

  /// 턴 복잡도를 보고 모델 사용 여부를 정한다.
  final HybridTurnRouter turnRouter;
  final TurnPlanAdherenceValidator turnPlanValidator;
  final ResponseRealizer responseRealizer;

  /// 검색 결과를 상담 맥락으로 압축한다.
  final RetrievalSummaryBuilder retrievalSummaryBuilder;

  /// Phase 10.6B: canary rollout gate, additive to (never a replacement
  /// for) `turnRouter.route(...).allowLlm`. `null` (every existing call
  /// site, including `.deterministic()` and `.remoteGpt()`) means "no
  /// rollout gate at all" — `routing.allowLlm` alone still decides,
  /// exactly as before this phase. A non-null [RolloutConfig] additionally
  /// requires `evaluateRollout(...).attemptRemote`. Actually constructing
  /// a non-default `RolloutConfig` and wiring it into a harness instance
  /// is Phase 10.6C's job, not built by this phase.
  final RolloutConfig? rolloutConfig;

  /// Phase 10.6B: whether this session's caller has already determined it
  /// belongs to the internal/dev cohort — this harness has no concept of
  /// user accounts or auth, so it never computes this itself.
  final bool isInternalAccount;

  /// Phase 10.6B: structural-metadata-only telemetry sink (see
  /// `RealizationTelemetryEvent`'s own doc for what it may/may not
  /// contain). `null` (the default) emits nothing — behavior-neutral.
  final RealizationTelemetrySink? telemetrySink;

  /// 한 턴에 제공할 CBT 근거 수. 창을 넘기지 않도록 적게 유지한다.
  static const int knowledgeLimit = 3;

  /// 즉시 공감 메시지까지 포함된 원본 세션에서 충분한 실제 대화 턴을 보존한다.
  /// 최종 프롬프트 길이는 각 PromptBuilder가 다시 제한한다.
  static const int recentSessionMessageWindow = 18;

  CounselingHarness({
    required this.llm,
    required this.safetyGate,
    required this.knowledgeRepository,
    this.promptBuilder = const CompactPromptBuilder(),
    this.outputParser = const CounselingOutputParser(),
    this.safetyResponseFactory = const SafetyResponseFactory(),
    this.statePolicy = const CounselingStatePolicy(),
    this.turnPlanner,
    this.turnRouter = const HybridTurnRouter(),
    this.turnPlanValidator = const TurnPlanAdherenceValidator(),
    this.responseRealizer = const DeterministicResponseRealizer(),
    this.retrievalSummaryBuilder = const RetrievalSummaryBuilder(),
    this.rolloutConfig,
    this.isInternalAccount = false,
    this.telemetrySink,
  });

  /// 제품 기본 deterministic 상담 구성.
  ///
  /// 표시 계층이 planner나 prompt builder의 구체 타입을 알지 않도록 조립 책임을
  /// counseling 계층에 둔다.
  factory CounselingHarness.deterministic({
    required LlmService llm,
    required SafetyGate safetyGate,
    required CbtKnowledgeRepository knowledgeRepository,
  }) {
    return CounselingHarness(
      llm: llm,
      safetyGate: safetyGate,
      knowledgeRepository: knowledgeRepository,
      // Phase 8.4: production counseling turns go through
      // PolicyBoundaryBuilder -> DeterministicCounselorAgent ->
      // TurnPlanAdapter instead of calling the legacy composite planner
      // directly. See lib/features/counseling/policy/production_turn_planner.dart.
      turnPlanner: const PolicyPipelineTurnPlanner(),
      promptBuilder: const TurnPlanPromptBuilder(),
    );
  }

  /// TurnPlan이 정한 결정론 초안을 GPT(backend `/counseling/realize`)로 다듬는
  /// 구성. 상담 전략(반영 대상·질문 목표·CBT 선택·state 전이)은 계속
  /// `DeterministicCounselingTurnPlanner`가 정하고, GPT는 그 결과를 자연스러운
  /// 한국어로 표현만 바꾼다. 검증 실패나 네트워크 오류 시 항상 `deterministic
  /// draft`로 되돌아간다. 자세한 경계는
  /// docs/counseling/remote_gpt_realizer_integration.md 참고.
  factory CounselingHarness.remoteGpt({
    required LlmService llm,
    required SafetyGate safetyGate,
    required CbtKnowledgeRepository knowledgeRepository,
    required ResponseRealizer responseRealizer,
    // Phase 10.6B: plumbed through so Phase 10.6C's activation work is a
    // config change at the call site, not a new factory. Leaving all
    // three at their defaults (`null`/`false`/`null`) keeps this factory's
    // behavior byte-identical to before this phase.
    RolloutConfig? rolloutConfig,
    bool isInternalAccount = false,
    RealizationTelemetrySink? telemetrySink,
  }) {
    return CounselingHarness(
      llm: llm,
      safetyGate: safetyGate,
      knowledgeRepository: knowledgeRepository,
      turnPlanner: const PolicyPipelineTurnPlanner(),
      promptBuilder: const TurnPlanPromptBuilder(),
      responseRealizer: responseRealizer,
      // llmEnabled: true 없이는 HybridTurnRouter가 explore/reflect 턴에서도
      // allowLlm: false를 반환해 [responseRealizer]가 아예 호출되지 않는다
      // (바로 위 handleTurn의 routing.allowLlm 게이트). checkIn/closing/
      // intervention은 이 값과 무관하게 여전히 always-deterministic이다 —
      // HybridTurnRouter.route()의 나머지 분기 참고.
      turnRouter: const HybridTurnRouter(llmEnabled: true),
      rolloutConfig: rolloutConfig,
      isInternalAccount: isInternalAccount,
      telemetrySink: telemetrySink,
    );
  }

  Future<CounselingTurnResult> handleTurn({
    required CounselingSessionState session,
    required String userMessage,
    PrecomputedTurnContext? precomputedContext,
    /// Phase 10.6B: stable rollout cohort key for this session. Defaults
    /// to `session.sessionId` — pass explicitly only if some other stable
    /// identifier (e.g. a user id, once this call site has one) should
    /// drive cohort assignment instead.
    String? cohortKey,
  }) async {
    // 1. 안전 관문. 정상이 아니면 여기서 끝내고 모델을 호출하지 않는다.
    final stateBefore = session.state;

    final safety = await safetyGate.evaluate(userMessage);
    if (!safety.isNormal) {
      return _safetyTurn(session, safety);
    }

    // 2~4. 현재 상태에 맞는 CBT 근거를 찾는다.
    // precomputedContext가 있으면(MindRiumAssistantHarness가 이미 같은
    // 조회를 끝냈다는 뜻) 재조회하지 않는다 — 같은 retrieval을 두 번 계산
    // 하지 않기 위한 Phase 5 bridge. 없으면(기존 CounselingHarness를 직접
    // 쓰는 호출부·테스트) 이전과 완전히 동일하게 직접 조회한다.
    final knowledge = precomputedContext?.knowledge ??
        knowledgeRepository.search(
          query: userMessage,
          week: session.currentWeek,
          tags: session.state.retrievalTags,
          limit: knowledgeLimit,
        );

    // 5~6. 허용 행위를 정하고 프롬프트를 만든다.
    final recentMessages = _recentMessages(session);

    // 검색 결과를 상담에서 쓸 수 있는 사실로 한 번 압축한 뒤 planner 에 넘긴다.
    // planner 마다 같은 추출을 반복하지 않게 하고, 어떤 기록을 근거로 썼는지도
    // 여기서 한곳에 모인다.
    final planningContext = TurnPlanningContext(
      state: session.state,
      currentWeek: session.currentWeek,
      userMessage: userMessage,
      knowledge: knowledge,
      userContext: session.userContext,
      recentMessages: recentMessages,
      retrievalSummary: precomputedContext?.retrievalSummary ??
          retrievalSummaryBuilder.build(
            userMessage: userMessage,
            context: session.userContext,
            recentMessages: recentMessages,
          ),
    );

    final turnPlan = turnPlanner?.plan(planningContext);
    final bundle = promptBuilder.build(
      PromptContext(
        state: session.state,
        userMessage: userMessage,
        knowledge: knowledge,
        allowedDialogueActs: session.state.allowedActs,
        userContext: session.userContext,
        sessionSummary: session.summary,
        recentMessages: recentMessages,
        turnPlan: turnPlan,
      ),
    );

    // 7. 이번 턴에 모델을 써도 되는지 라우터가 정한다.
    // 임상적으로 중요하거나 승인된 개입을 실행하는 턴은 모델을 부르지 않는다.
    final routing = turnRouter.route(
      state: session.state,
      safetyLevel: safety.level,
      plan: turnPlan,
    );

    // Phase 10.6B: canary rollout gate, additive to `routing.allowLlm` —
    // never widens it, only narrows it further. `rolloutConfig == null`
    // (every call site as of this phase) skips this entirely, so
    // `effectiveAllowLlm == routing.allowLlm` exactly, byte-for-byte the
    // same as before this phase.
    final resolvedCohortKey = cohortKey ?? session.sessionId;
    final rolloutDecision =
        rolloutConfig == null
            ? null
            : evaluateRollout(
              config: rolloutConfig!,
              routerAllowsLlm: routing.allowLlm,
              cohortKey: resolvedCohortKey,
              isInternalAccount: isInternalAccount,
            );
    final effectiveAllowLlm =
        routing.allowLlm && (rolloutDecision?.attemptRemote ?? true);

    // Planner가 설치된 안전 경로에서 계획 수립에 실패하면 자유 생성으로
    // 우회하지 않는다. 승인된 행동이 없으므로 모델 호출 없이 종료한다.
    if (turnPlanner != null && turnPlan == null) {
      return _errorTurn(session, safety, bundle.promptVersion, bundle);
    }

    // P2-D는 LLM을 호출하지 않는다. P2-L은 제약 위반이나 runtime 실패 시
    // planner가 이미 완성한 deterministic 문장으로 물러선다.
    LlmResponse response;
    CounselingModelOutput parsed;
    var realizationSource = RealizationSource.deterministic;
    var actChosenByModel = false;
    if (turnPlan != null) {
      // `effectiveAllowLlm`이 false면(승인된 개입 실행 턴, 그 밖에 라우터가
      // 고위험으로 표시한 턴, 또는 canary rollout이 이 턴/세션을 아직 포함
      //하지 않음) responseRealizer가 무엇으로 구성됐든 절대 호출하지 않는다
      // — 이 턴은 이미 확정된 deterministic 문장 그대로 나간다.
      final realizationRequest =
          effectiveAllowLlm
              ? RealizationRequest.fromPlan(
                plan: turnPlan,
                retrievalSummary: planningContext.retrievalSummary,
                recentConversation: recentMessages,
                allowedCbtFacts: knowledge,
              )
              : null;
      final realization =
          effectiveAllowLlm
              ? await responseRealizer.realize(realizationRequest!)
              : RealizationResult(
                reply: turnPlan.deterministicReply,
                source: RealizationSource.deterministic,
                latency: Duration.zero,
                validationResult: RealizationValidationResult.valid,
                chosenAct: turnPlan.requiredAct,
              );
      final accepted =
          realization.validationResult.isValid &&
          realization.reply.trim().isNotEmpty;
      // Phase 10.6C-DOGFOOD: when Remote was attempted but rejected, the
      // user-visible fallback used to be `turnPlan.deterministicReply` —
      // the legacy, verbatim-quoting template (Phase 10.1's R1 defect).
      // That was fine while Remote realization was purely evaluated, but
      // once real users could actually hit it in Stage 1 dogfooding, it
      // ships the exact mechanical wording Phase 10 exists to remove, on
      // every turn Remote happens to fail. Route the fallback through the
      // already-built, already-evaluated `SemanticDeterministicResponseRealizer`
      // (Phase 10.3/10.3B) instead — no quoting, same question, still a
      // deterministic/no-network reply. Only reachable when
      // `effectiveAllowLlm` was true (i.e. `realizationRequest != null`);
      // the router-disallowed path above is untouched.
      final reply =
          accepted
              ? realization.reply
              : (realizationRequest == null
                  ? turnPlan.deterministicReply
                  : (await const SemanticDeterministicResponseRealizer()
                          .realize(realizationRequest))
                      .reply);
      response = LlmResponse(
        text: reply,
        latency: accepted ? realization.latency : Duration.zero,
      );
      realizationSource =
          accepted ? realization.source : RealizationSource.deterministic;
      // realizer가 allowedActsForTurn 안에서 실제로 고른 행위를 검증 단계로
      // 넘긴다. 검증 실패(비수용)면 항상 planner의 requiredAct로 되돌아간다.
      actChosenByModel = accepted && realization.chosenAct != turnPlan.requiredAct;

      // Phase 10.6B: structural-only telemetry, emitted whenever a rollout
      // gate actually ran this turn's realization decision (attempted or
      // not) — never includes reply/user text, see RealizationTelemetryEvent.
      if (telemetrySink != null) {
        final violations = realization.validationResult.violations;
        telemetrySink!(
          RealizationTelemetryEvent(
            rolloutStage: rolloutConfig?.stage ?? RolloutStage.off,
            cohortBucket: stableBucket(resolvedCohortKey),
            state: session.state,
            rolloutReason:
                rolloutDecision?.reason ??
                (routing.allowLlm ? 'no_rollout_gate' : 'router_disallowed'),
            remoteAttempted: effectiveAllowLlm,
            remoteAccepted: effectiveAllowLlm && accepted,
            fallbackReason:
                effectiveAllowLlm && !accepted
                    ? (violations.isNotEmpty ? violations.first : 'unknown')
                    : null,
            questionCountMismatch: violations.contains(
              'question_count_mismatch',
            ),
            latencyMs: realization.latency.inMilliseconds,
            modelIdentifier: realization.modelIdentifier,
            promptVersion: realization.promptVersion,
          ),
        );
      }

      parsed = _deterministicOutput(
        turnPlan,
        reply: reply,
        dialogueAct: accepted ? realization.chosenAct : null,
      );
    } else {
      realizationSource = RealizationSource.localLlm;
      try {
        response = await llm.generate(
          LlmRequest(
            systemPrompt: bundle.systemPrompt,
            userPrompt: bundle.userPrompt,
            // 한국어 반영 + 질문이 잘리지 않을 정도만 허용한다.
            maxTokens: 128,
            temperature: 0.2,
          ),
        );
        parsed = outputParser.parse(response.text);

        // 작은 모델은 "반복하지 말라"는 지시만으로는 직전 문형을 그대로
        // 재생성할 수 있다. 최근 상담사 답변과 실질적으로 같은 경우에만 한 번
        // 다시 생성해, 사용자의 새 정보에 반응할 기회를 준다.
        if (bundle.acceptsPlainText &&
            (_isRepetitiveReply(parsed.reply, recentMessages) ||
                _repeatsPreviousQuestion(parsed.reply, recentMessages) ||
                _isLeakedModelInstruction(parsed.reply) ||
                _isEchoingUserMessage(parsed.reply, userMessage))) {
          final first = response;
          final retry = await llm.generate(
            LlmRequest(
              systemPrompt: bundle.systemPrompt,
              userPrompt: '''${bundle.userPrompt}

<REWRITE_REQUIRED>
첫 초안이 최근 상담사 답변을 반복했거나 사용자의 말을 그대로 되풀이했습니다.
같은 표현과 같은 질문을 쓰지 말고, CURRENT_USER에서 새로 드러난 내용에 직접 반응해 완전히 다시 작성하세요.
사용자의 문장을 그대로 옮기지 말고 상담사 자신의 말로 반영하세요.
반복하면 안 되는 첫 초안: ${parsed.reply}
</REWRITE_REQUIRED>''',
              maxTokens: 128,
              temperature: 0.35,
            ),
          );
          response = LlmResponse(
            text: retry.text,
            latency: first.latency + retry.latency,
          );
          parsed = outputParser.parse(retry.text);
          if (_isRepetitiveReply(parsed.reply, recentMessages) ||
              _repeatsPreviousQuestion(parsed.reply, recentMessages) ||
              _isLeakedModelInstruction(parsed.reply) ||
              _isEchoingUserMessage(parsed.reply, userMessage)) {
            if (turnPlan == null) {
              return _errorTurn(session, safety, bundle.promptVersion, bundle);
            }
            parsed = _deterministicOutput(turnPlan);
            realizationSource = RealizationSource.deterministic;
          }
        }
      } on Object {
        if (turnPlan == null) {
          return _errorTurn(session, safety, bundle.promptVersion, bundle);
        }
        response = const LlmResponse(text: '', latency: Duration.zero);
        parsed = _deterministicOutput(turnPlan);
        realizationSource = RealizationSource.deterministic;
      }
      if (turnPlan != null &&
          !turnPlanValidator.isAdherent(parsed.reply, turnPlan)) {
        parsed = _deterministicOutput(turnPlan);
        realizationSource = RealizationSource.deterministic;
      } else if (turnPlan != null) {
        parsed = CounselingModelOutput(
          reply: parsed.reply,
          dialogueAct: turnPlan.requiredAct,
          referencedCbtIds: turnPlan.cbtContextIds,
          referencedUserContextIds: turnPlan.userContextIds,
          parseStatus: parsed.parseStatus,
        );
      }
    }

    // 8~9. 파싱하고 provenance를 검증한다.
    if (parsed.reply.trim().isEmpty) {
      return _errorTurn(session, safety, bundle.promptVersion, bundle);
    }

    final validated = _validate(
      parsed,
      bundle,
      session.state,
      actOverride: actChosenByModel ? parsed.dialogueAct : null,
    );

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
      // planner가 정한 목표 ID를 그대로 옮긴다. 문장이 GPT마다 달라져도
      // 다음 턴의 DeterministicReflectTurnPlanner._selectGoal이 텍스트가
      // 아니라 이 ID로 "이미 물은 목표"를 판단할 수 있게 한다.
      dialogueGoalId: turnPlan?.progressGoalId,
    );

    _advance(session, nextState);

    return CounselingTurnResult(
      assistantMessage: message,
      state: nextState,
      stateBefore: stateBefore,
      safety: safety,
      handledBySafety: false,
      promptVersion: bundle.promptVersion,
      turnPlan: turnPlan,
      // 개입 턴이 성공해 다음 상태가 closing이 되더라도, 이번 턴에서 선택한
      // 앱 동작은 사라지지 않아야 한다.
      uiAction: _uiActionFor(stateBefore, turnPlan),
      offeredCbtIdCount: bundle.offeredCbtIds.length,
      offeredUserContextIdCount: bundle.offeredUserContextIds.length,
      retrievalProvenanceIds: planningContext.retrievalSummary.provenanceIds,
      routing: routing,
      realizationSource: realizationSource,
      actChosenByModel: actChosenByModel,
    );
  }

  bool _isRepetitiveReply(
    String reply,
    List<CounselingMessage> recentMessages,
  ) {
    final candidate = _normalizedForSimilarity(reply);
    // 짧은 한국어 질문도 "최근에 어떤 일이 생겼나요?"처럼 충분히 완결된
    // 반복일 수 있다. 12자로 자르면 이런 대표적인 재질문을 놓친다.
    if (candidate.length < 8) return false;

    final previous = recentMessages
        .where((message) => !message.isUser)
        .map((message) => _normalizedForSimilarity(message.text))
        .where((text) => text.length >= 8)
        .toList()
        .reversed
        .take(4);

    for (final text in previous) {
      if (candidate == text) return true;
      final shorter =
          candidate.length < text.length ? candidate.length : text.length;
      final longer =
          candidate.length > text.length ? candidate.length : text.length;
      if (shorter / longer >= 0.75 &&
          (candidate.contains(text) || text.contains(candidate))) {
        return true;
      }
      if (_bigramDice(candidate, text) >= 0.82) return true;
    }
    return false;
  }

  /// 앞 문장의 반영 표현이 달라도 질문만 같으면 대화는 제자리에 머문다.
  /// 전체 답변 유사도 검사와 별도로 마지막 질문끼리 비교한다.
  bool _repeatsPreviousQuestion(
    String reply,
    List<CounselingMessage> recentMessages,
  ) {
    final candidate = _lastQuestion(reply);
    if (candidate == null || candidate.length < 6) return false;
    for (final message in recentMessages.reversed) {
      if (message.isUser) continue;
      final previous = _lastQuestion(message.text);
      if (previous == null || previous.length < 6) continue;
      if (candidate == previous || _bigramDice(candidate, previous) >= 0.82) {
        return true;
      }
    }
    return false;
  }

  String? _lastQuestion(String value) {
    final matches = RegExp(r'[^.!?\n]*\?').allMatches(value).toList();
    if (matches.isEmpty) return null;
    return _normalizedForSimilarity(matches.last.group(0) ?? '');
  }

  /// 상담사가 사용자의 말을 되묻지 않고 그대로(또는 거의 그대로) 돌려주는
  /// 경우를 잡는다. `_isRepetitiveReply` 는 직전 상담사 발화만 비교하므로,
  /// 특히 첫 턴처럼 비교할 상담사 발화가 없을 때 이 패턴을 놓친다. 첫 턴에서
  /// 한 번 새어 나가면 그 문장이 대화 이력에 남아 다음 턴에도 같은 문장을
  /// 반복하게 만드는 것을 실기기 시험(Kanana-2-3B)에서 확인했다.
  bool _isEchoingUserMessage(String reply, String userMessage) {
    final candidate = _normalizedForSimilarity(reply);
    final user = _normalizedForSimilarity(userMessage);
    if (candidate.length < 8 || user.length < 8) return false;

    if (candidate == user) return true;
    final shorter =
        candidate.length < user.length ? candidate.length : user.length;
    final longer =
        candidate.length > user.length ? candidate.length : user.length;
    if (shorter / longer >= 0.75 &&
        (candidate.contains(user) || user.contains(candidate))) {
      return true;
    }
    return _bigramDice(candidate, user) >= 0.82;
  }

  bool _isLeakedModelInstruction(String reply) {
    final text = reply.trimLeft();
    return RegExp(
          r'^(사용자|상담사|assistant|system)\s*:',
          caseSensitive: false,
        ).hasMatch(text) ||
        text.contains('<NEW_INFORMATION>') ||
        text.contains('<NEXT_FOCUS>') ||
        text.contains('<CONVERSATION>') ||
        text.contains('<user_turn>') ||
        text.contains('<counselor_turn>') ||
        text.contains('/no_think') ||
        text.contains('RESPONSE_TASK') ||
        text.contains('CURRENT_USER');
  }

  String _normalizedForSimilarity(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣]+'), '');

  double _bigramDice(String left, String right) {
    if (left.length < 2 || right.length < 2) return 0;

    final leftCounts = <String, int>{};
    for (var i = 0; i < left.length - 1; i++) {
      final gram = left.substring(i, i + 2);
      leftCounts[gram] = (leftCounts[gram] ?? 0) + 1;
    }

    var intersection = 0;
    for (var i = 0; i < right.length - 1; i++) {
      final gram = right.substring(i, i + 2);
      final remaining = leftCounts[gram] ?? 0;
      if (remaining == 0) continue;
      intersection++;
      leftCounts[gram] = remaining - 1;
    }

    return (2 * intersection) / (left.length + right.length - 2);
  }

  CounselingModelOutput _deterministicOutput(
    CounselingTurnPlan plan, {
    String? reply,
    DialogueAct? dialogueAct,
  }) {
    return CounselingModelOutput(
      reply: reply ?? plan.deterministicReply,
      dialogueAct: dialogueAct ?? plan.requiredAct,
      referencedCbtIds: plan.cbtContextIds,
      referencedUserContextIds: plan.userContextIds,
      parseStatus: ParseStatus.strict,
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
    CounselingState state, {
    DialogueAct? actOverride,
  }) {
    // 압축 프로파일에서는 harness 가 행위를 정하고 모델은 문장만 쓴다.
    // 분류까지 시키면 작은 모델이 정작 문장 생성에 쓸 여력을 잃는다.
    //
    // 다만 구조화 출력을 읽어내지 못한 턴에는 요구 행위를 붙이지 않는다.
    // 평문으로 물러선 응답은 무엇을 했는지 알 수 없고, 그걸 "요구한 행위를
    // 수행했다"고 기록하면 상태가 근거 없이 진행된다.
    final structured =
        output.parseStatus == ParseStatus.strict ||
        output.parseStatus == ParseStatus.extracted ||
        bundle.acceptsPlainText;
    final required = structured ? bundle.requiredDialogueAct : null;

    // actOverride는 RemoteLlmRealizer가 이미 allowedActsForTurn 안에서
    // 검증한 GPT의 선택이다. 여기서도 state.allowedActs로 다시 확인해 이중
    // 방어선을 둔다 — Adaptive Dialogue Policy Phase 1
    // (docs/counseling/adaptive_dialogue_policy.md 4절).
    final act =
        (actOverride != null && state.allowedActs.contains(actOverride))
            ? actOverride
            : (required ??
                (state.allowedActs.contains(output.dialogueAct)
                    ? output.dialogueAct
                    : DialogueAct.unknown));

    return CounselingModelOutput(
      reply: output.reply,
      dialogueAct: act,
      referencedCbtIds:
          output.referencedCbtIds.where(bundle.offeredCbtIds.contains).toList(),
      referencedUserContextIds:
          output.referencedUserContextIds
              .where(bundle.offeredUserContextIds.contains)
              .toList(),
      parseStatus: output.parseStatus,
    );
  }

  List<CounselingMessage> _recentMessages(CounselingSessionState session) {
    final messages = session.messages;
    if (messages.length <= recentSessionMessageWindow) return messages;
    return messages.sublist(messages.length - recentSessionMessageWindow);
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
      stateBefore: session.state,
      safety: safety,
      handledBySafety: true,
      promptVersion: promptBuilder.promptVersion,
      // 주의 수준의 고정 안내가 이미 이완을 언급한다. 위기 수준에서는 추천하지 않는다.
      uiAction:
          safety.level == SafetyLevel.elevated
              ? CounselingActivity.relaxation
              : null,
    );
  }

  CounselingTurnResult _errorTurn(
    CounselingSessionState session,
    SafetyResult safety,
    String promptVersion,
    PromptBundle bundle,
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
      stateBefore: session.state,
      safety: safety,
      handledBySafety: false,
      promptVersion: promptVersion,
      offeredCbtIdCount: bundle.offeredCbtIds.length,
      offeredUserContextIdCount: bundle.offeredUserContextIds.length,
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
  /// 이번 턴에 제안할 앱 동작.
  ///
  /// 모델 출력이 아니라 planner 의 승인 정책 결과를 쓴다. 모델이 신고한 CBT id 로
  /// 화면을 고르면 결정론 경로에서는 id 가 비어 근거 없이 기본값이 나가고,
  /// 모델 경로에서는 지어낸 id 로 엉뚱한 화면이 열릴 수 있다.
  CounselingUiAction? _uiActionFor(
    CounselingState state,
    CounselingTurnPlan? plan,
  ) {
    if (state != CounselingState.intervention) return null;

    return plan?.interventionPlan?.recommendation.activity;
  }
}
