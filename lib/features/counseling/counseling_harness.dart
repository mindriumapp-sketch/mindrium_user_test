import 'dart:async';

import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/closing_decision_selector.dart';
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/app_guide/app_guide_repository.dart';

import 'compact_prompt_builder.dart';
import 'llm_led/llm_led_contract.dart';
import 'llm_led/term_glossary.dart';
import 'counseling_state.dart';
import 'hybrid_turn_router.dart';
import 'intervention_registry.dart';
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

  /// Phase 13.2: approved techniques the intervention state may draw on.
  /// Must match the registry the turn planner uses (both default to
  /// [ApprovedInterventionRegistry.defaults]).
  final ApprovedInterventionRegistry interventionRegistry;

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
    this.interventionRegistry = const ApprovedInterventionRegistry(),
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
  /// docs/counseling/chatbot_system.md 9절 참고.
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
    /// Phase 14.2B: guarded semantic repair signal (see TurnPlanningContext).
    InteractionRepairReason? perceivedRepair,
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
    final retrieved = precomputedContext?.knowledge ??
        knowledgeRepository.search(
          query: userMessage,
          week: session.currentWeek,
          tags: session.state.retrievalTags,
          limit: knowledgeLimit,
        );
    final knowledge = _withApprovedInterventions(retrieved, session);

    // Phase 4: an end-only message ends the session from any stage. In
    // closing with no pending proposal the closing selector finalizes.
    if (session.state != CounselingState.closing && ClosingDecisionSelector.isEndOnly(userMessage)) {
      session.state = CounselingState.closing;
    }

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
      perceivedRepair: perceivedRepair,
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

    // `turnPlanner`는 두 production factory(`.deterministic`/`.remoteGpt`)
    // 모두 항상 채운다 — planner 없이 harness를 쓰는 경로는 production에
    // 존재하지 않는다. planner가 설치된 안전 경로에서 계획 수립에 실패해도
    // 자유 생성으로 우회하지 않는다: 승인된 행동이 없으므로 모델 호출 없이
    // 종료한다. (2026-09-28: 예전에는 `turnPlanner == null`인 경우를 위한
    // 별도의 raw LLM 생성 경로가 있었으나, 그 경로는 두 production factory
    // 어디서도 도달하지 않는다는 게 확인되어 제거했다 — 이제 `turnPlan`이
    // null이면 이유와 무관하게 항상 이 error turn으로 끝난다.)
    if (turnPlan == null) {
      return _errorTurn(session, safety, bundle.promptVersion, bundle);
    }

    // P2-D는 LLM을 호출하지 않는다. P2-L은 제약 위반이나 runtime 실패 시
    // planner가 이미 완성한 deterministic 문장으로 물러선다.
    LlmResponse response;
    CounselingModelOutput parsed;
    var realizationSource = RealizationSource.deterministic;
    var actChosenByModel = false;
    {
      // `effectiveAllowLlm`이 false면(승인된 개입 실행 턴, 그 밖에 라우터가
      // 고위험으로 표시한 턴, 또는 canary rollout이 이 턴/세션을 아직 포함
      //하지 않음) responseRealizer가 무엇으로 구성됐든 절대 호출하지 않는다
      // — 이 턴은 이미 확정된 deterministic 문장 그대로 나간다.
      final realizationRequest =
          effectiveAllowLlm
              ? RealizationRequest.fromPlan(
                plan: turnPlan,
                retrievalSummary: planningContext.retrievalSummary,
                recentConversation: _withCurrentUserTurn(
                  recentMessages,
                  userMessage,
                  session.sessionId,
                ),
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
      progress: turnPlan.stageProgress,
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
      dialogueGoalId: turnPlan.progressGoalId,
      interactionRepairReason: turnPlan.interactionRepairReason,
      goalExhaustionRecovery: turnPlan.goalExhaustionRecovery,
      interventionStep: turnPlan.interventionStep,
      closingStep: turnPlan.closingStep,
      earlyWrapUp: turnPlan.earlyWrapUp,
      isClarify: turnPlan.isClarify,
      interventionCredited: turnPlan.interventionCredited,
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
    // (docs/counseling/chatbot_system.md 4절).
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

  /// Phase 13.2: search only covers the current week, but intervention may
  /// use any approved technique up to the current week. In intervention,
  /// add those approved items by id (never future weeks) so the policy can
  /// actually choose them.
  List<CbtKnowledgeItem> _withApprovedInterventions(
    List<CbtKnowledgeItem> retrieved,
    CounselingSessionState session,
  ) {
    if (session.state != CounselingState.intervention) return retrieved;
    final ids = {for (final item in retrieved) item.id};
    final extra = <CbtKnowledgeItem>[];
    for (final policy in interventionRegistry.policiesUpTo(session.currentWeek)) {
      if (ids.contains(policy.requiredId)) continue;
      final item = knowledgeRepository.getById(policy.requiredId);
      if (item != null) extra.add(item);
    }
    return extra.isEmpty ? retrieved : [...retrieved, ...extra];
  }

  /// Phase 12.3 (N2 root cause): the realizer must see what the user just
  /// said. `session.messages` only contains the current turn when the
  /// provider synced it early (instant empathy, now disabled), so without
  /// this the model saw a conversation ending on its own previous question
  /// and repeated it. Only the realization request gets this view; selectors
  /// keep reading history that ends on the previous assistant reply.
  List<CounselingMessage> _withCurrentUserTurn(
    List<CounselingMessage> history,
    String userMessage,
    String sessionId,
  ) {
    final current = userMessage.trim();
    final alreadyThere = history.reversed
        .where((m) => m.isUser)
        .take(1)
        .any((m) => m.text.trim() == current);
    if (current.isEmpty || alreadyThere) return history;
    return [
      ...history,
      CounselingMessage(
        id: '${sessionId}_current_user',
        role: 'user',
        text: current,
        createdAt: DateTime.now(),
      ),
    ];
  }

  List<CounselingMessage> _recentMessages(CounselingSessionState session) {
    final messages = session.messages;
    if (messages.length <= recentSessionMessageWindow) return messages;
    return messages.sublist(messages.length - recentSessionMessageWindow);
  }

  /// Phase 14.X: one turn on the Bounded LLM-led path. Safety first (no call
  /// on a crisis); then one call with the narrowed context; the validator
  /// decides. Returns a result only when the turn is fully accepted (or was
  /// a safety turn); otherwise [LlmLedTurn.result] is null and the caller
  /// runs the deterministic path for this turn. Nothing in [session] changes
  /// unless a result is returned.
  Future<LlmLedTurn> handleLlmLedTurn({
    required CounselingSessionState session,
    required String userMessage,
    required CounselingRespondApi api,
    required AppGuideRepository appGuide,
    TermGlossary glossary = TermGlossary.empty,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final safety = await safetyGate.evaluate(userMessage);
    if (!safety.isNormal) {
      return LlmLedTurn(result: _safetyTurn(session, safety), status: 'safety');
    }
    final requestId = '${session.sessionId}_${session.totalTurns}';
    final buildWatch = Stopwatch()..start();
    final ctx = LlmLedContext.build(
      requestId: requestId,
      session: session,
      userMessage: userMessage,
      knowledge: knowledgeRepository,
      appGuide: appGuide,
      glossary: glossary,
    );
    final contextMs = buildWatch.elapsedMilliseconds;
    final sw = Stopwatch()..start();
    Map<String, dynamic> res;
    try {
      res = await api.respond(ctx.body, timeout: timeout).timeout(timeout);
    } on TimeoutException {
      return LlmLedTurn(
          status: 'timeout', latencyMs: sw.elapsedMilliseconds, failure: const CounselingRespondFailure('timeout'));
    } on CounselingRespondFailure catch (f) {
      return LlmLedTurn(
        status: switch (f.requestStatus) {
          'timeout' => 'timeout',
          'schema_reject' => 'schema_reject',
          _ => 'http_error',
        },
        latencyMs: sw.elapsedMilliseconds,
        failure: f,
        detail: f.toString(),
      );
    } on Object catch (e) {
      final detail = e.toString();
      return LlmLedTurn(
        status: 'http_error',
        latencyMs: sw.elapsedMilliseconds,
        failure: const CounselingRespondFailure('unknown'),
        detail: detail.length > 160 ? detail.substring(0, 160) : detail,
      );
    }
    final latency = sw.elapsedMilliseconds;
    final timing = {
      'context_ms': contextMs,
      'request_ms': latency,
      'model_ms': (res['latency_ms'] as num?)?.toInt(),
      'prompt_tokens': (res['prompt_tokens'] as num?)?.toInt(),
      'completion_tokens': (res['completion_tokens'] as num?)?.toInt(),
    };
    final out = LlmLedOutput.tryParse(res['output']);
    if (out == null) return LlmLedTurn(status: 'schema_reject', latencyMs: latency, timing: timing);
    final validateWatch = Stopwatch()..start();
    final violations = LlmLedValidator.validate(out, ctx);
    timing['validate_ms'] = validateWatch.elapsedMilliseconds;
    if (violations.isNotEmpty) {
      return LlmLedTurn(
          status: 'rejected', latencyMs: latency, output: out, violations: violations, timing: timing);
    }

    final stateBefore = session.state;
    final map = LlmLedMapping.of(out, ctx, stateBefore, userMessage);
    final message = CounselingMessage(
      id: '${session.sessionId}_${session.totalTurns}_assistant',
      role: 'assistant',
      text: out.text,
      createdAt: DateTime.now(),
      dialogueAct: map.act,
      referencedCbtIds: map.cbtIds,
      referencedUserContextIds: out.usedUserFactIds,
      parseStatus: ParseStatus.strict,
      latency: Duration(milliseconds: latency),
      dialogueGoalId: map.goalId,
      interventionStep: map.interventionStep,
      closingStep: map.closingStep,
      isClarify: map.isClarify,
      interventionCredited: map.credited,
    );
    _advance(session, map.nextState);
    return LlmLedTurn(
      status: 'success',
      latencyMs: latency,
      timing: timing,
      output: out,
      result: CounselingTurnResult(
        assistantMessage: message,
        state: map.nextState,
        stateBefore: stateBefore,
        safety: safety,
        handledBySafety: false,
        promptVersion: (res['prompt_version'] ?? 'respond').toString(),
        realizationSource: RealizationSource.remoteLlm,
        offeredCbtIdCount: ctx.techniqueIds.length,
        offeredUserContextIdCount: ctx.userFactIds.length,
      ),
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

/// Phase 14.X: outcome of one LLM-led attempt. [status]: success | safety |
/// timeout | http_error | schema_reject | rejected (validator).
class LlmLedTurn {
  final CounselingTurnResult? result;
  final String status;
  final int? latencyMs;
  final LlmLedOutput? output;
  final List<String> violations;

  /// Error detail for http_error (status code / backend reason; no user text).
  final String? detail;

  /// The classified transport/API failure, when the call did not answer.
  final CounselingRespondFailure? failure;

  /// success | the failure's request status | 'success' also for a reply the
  /// validator rejected (the request itself succeeded).
  String get requestStatus => failure?.requestStatus ?? 'success';

  /// direct (B shown) | content_fallback (B answered, rejected) |
  /// transport_fallback (no usable answer) | safety.
  String get group => switch (status) {
        'success' => 'direct',
        'safety' => 'safety',
        'rejected' || 'schema_reject' => 'content_fallback',
        _ => 'transport_fallback',
      };

  /// The most serious validator reason (grounding and safety first).
  String? get primaryRejection {
    if (violations.isEmpty) return null;
    for (final r in _rejectionPriority) {
      if (violations.contains(r)) return r;
    }
    return violations.first;
  }

  static const _rejectionPriority = [
    'definition_mismatch', 'unknown_term_defined', 'definition_without_request',
    'unauthorized_intervention', 'prompt_without_intervention', 'integration_without_prompt',
    'unsupported_user_fact', 'unsupported_app_fact', 'app_claim_without_fact',
    'diagnosis', 'outcome_guarantee', 'directive', 'advice', 'premature_example', 'finalize_without_proposal',
    'question_after_no_question_promise', 'too_many_questions', 'question_shape',
    'repeated_question', 'exploring_after_closed', 'banmal_reply', 'second_person', 'too_long',
  ];

  const LlmLedTurn({
    this.result,
    required this.status,
    this.latencyMs,
    this.output,
    this.violations = const [],
    this.detail,
    this.failure,
    this.timing = const {},
  });

  /// Latency breakdown (ms): context build, request (network + model), model
  /// alone (backend-reported), validation; plus prompt tokens.
  final Map<String, int?> timing;
}
