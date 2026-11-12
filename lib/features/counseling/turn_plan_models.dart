part of 'turn_plan.dart';

/// LLM 호출 전에 harness가 결정한 이번 턴의 상담 행동.
///
/// 모델은 이 값을 선택하거나 분류하지 않고 자연스러운 문장으로 표현만 한다.
class CounselingTurnPlan {
  final String reflectionTarget;
  final String questionGoal;
  final String reflectionSentence;
  final String questionSentence;
  final List<String> forbidden;
  final List<TurnConstraint> constraints;
  final DialogueAct requiredAct;
  final List<String> userContextIds;
  final List<String> cbtContextIds;
  final InterventionPlan? interventionPlan;
  final TurnPlanningStatus planningStatus;

  /// 이번 턴에 [requiredAct] 대신 realizer(GPT)가 자연스럽다고 판단하는 다른
  /// 행위를 골라도 되는 후보 집합. 비어 있으면(기본값) 기존과 동일하게
  /// [requiredAct] 하나로 고정된다 — Adaptive Dialogue Policy Phase 1 설계
  /// (docs/counseling/chatbot_system.md 4절) 에서만 채운다.
  /// 여기 담기는 값은 항상 [requiredAct] 자체 또는 해당 state의
  /// `allowedActs` 부분집합이어야 한다.
  final List<DialogueAct> allowedActsForTurn;

  /// 이번 턴이 다룬 대화 목표의 안정적인 ID. [CounselingMessage.dialogueGoalId]
  /// 로 그대로 옮겨져, 다음 턴 planner가 "이미 물은 목표인가"를 텍스트 표현이
  /// 아니라 이 ID로 판단할 수 있게 한다. 목표 개념이 없는 planner는 비워
  /// 둔다.
  final String? progressGoalId;

  /// Phase 10.2: the semantic realization contract for this turn, produced
  /// alongside (never instead of) [reflectionSentence]/[questionSentence]/
  /// [deterministicReply] — see `docs/counseling/chatbot_system.md`.
  /// `null` for plans built by the legacy `Deterministic*TurnPlanner`
  /// classes below, which predate this contract and are not part of this
  /// phase's scope. No current `ResponseRealizer` reads this field; it
  /// exists so a future one can, without changing what any user sees today.
  final CounselingRealizationSpec? realizationSpec;

  /// Phase 11.2: set only by `DeterministicProcessSignalTurnPlanner` when
  /// this turn is a repair response, not ordinary worry-content
  /// selection. `null` for every other planner. See
  /// `CounselingMessage.interactionRepairReason`'s doc for why this is
  /// carried forward.
  final InteractionRepairReason? interactionRepairReason;

  /// Phase 11.3: set only by `TurnPlanMaterializer.reflect()`'s recovery
  /// branch, when `CounselorDecision.goalExhaustionRecovery` was non-null
  /// (every `ReflectQuestionGoal` already asked this reflect phase). `null`
  /// for every other turn. See `CounselingMessage.goalExhaustionRecovery`'s
  /// doc for why this is carried forward the same way
  /// [interactionRepairReason] is.
  final GoalExhaustionRecovery? goalExhaustionRecovery;

  /// Phase 13.3: this turn's contribution to finishing its stage, read by
  /// `CounselingStatePolicy`. `null` keeps the fixed-budget behavior.
  final StageProgress? stageProgress;

  /// Phase 13.3: see `CounselingMessage.interventionStep`.
  final InterventionStep? interventionStep;

  /// Phase 13.5: see `CounselingMessage.closingStep`.
  final ClosingStep? closingStep;

  /// Phase 13.8: see `CounselingMessage.earlyWrapUp`.
  final EarlyWrapUp? earlyWrapUp;

  /// Phase 13.9C: see `CounselingMessage.isClarify`.
  final bool isClarify;

  /// See `CounselingMessage.interventionCredited`.
  final bool? interventionCredited;

  const CounselingTurnPlan({
    required this.reflectionTarget,
    required this.questionGoal,
    required this.reflectionSentence,
    required this.questionSentence,
    required this.forbidden,
    required this.constraints,
    required this.requiredAct,
    required this.userContextIds,
    required this.cbtContextIds,
    this.interventionPlan,
    this.planningStatus = TurnPlanningStatus.planned,
    this.allowedActsForTurn = const [],
    this.progressGoalId,
    this.realizationSpec,
    this.interactionRepairReason,
    this.goalExhaustionRecovery,
    this.stageProgress,
    this.interventionStep,
    this.closingStep,
    this.earlyWrapUp,
    this.isClarify = false,
    this.interventionCredited,
  });

  String get deterministicReply => [
    reflectionSentence.trim(),
    questionSentence.trim(),
  ].where((sentence) => sentence.isNotEmpty).join(' ');
}

enum TurnConstraint {
  requireReflection,
  requireExactlyOneQuestion,
  forbidAdvice,
  forbidNewUserFacts,
  forbidStageAdvance,
  forbidNewIntervention,
  requireNoQuestion,
}

enum TurnPlanningStatus { planned, unavailable }

/// Harness가 확정한 단일 CBT 개입과 construction provenance.
class InterventionPlan {
  final InterventionType type;
  final String target;

  /// 상담 문장. 사용자에게 하는 질문이다.
  final String promptSentence;

  final String selectedCbtId;
  final List<String> forbidden;

  /// 이 개입에 딸린 교육 문구와 앱 활동.
  ///
  /// 상담 문장과 분리해 둔다. 한 문장에 질문과 화면 이동을 섞으면 사용자가
  /// 무엇을 해야 할지 흐려진다.
  final ActivityRecommendation recommendation;

  const InterventionPlan({
    required this.type,
    required this.target,
    required this.promptSentence,
    required this.selectedCbtId,
    required this.forbidden,
    this.recommendation = ActivityRecommendation.none,
  });
}

class TurnPlanningContext {
  final CounselingState state;
  final int currentWeek;
  final String userMessage;
  final List<CbtKnowledgeItem> knowledge;
  final MindriumCounselingContext? userContext;
  final List<CounselingMessage> recentMessages;

  /// 검색 결과를 상담 맥락으로 압축한 중간 표현.
  ///
  /// 기존 planner 는 [userContext] 에서 직접 항목을 꺼내 쓴다. 두 경로를 함께 두고
  /// planner 를 하나씩 옮긴다. 한 번에 갈아치우면 문장이 이상해졌을 때 원인이
  /// retrieval 인지 planner 인지 갈리지 않는다.
  final RetrievalSummary retrievalSummary;

  const TurnPlanningContext({
    required this.state,
    this.currentWeek = 0,
    required this.userMessage,
    required this.knowledge,
    this.userContext,
    this.recentMessages = const [],
    this.retrievalSummary = RetrievalSummary.empty,
  });

  /// [userContext] 만 주어진 경우에도 요약을 갖춘 컨텍스트를 만든다.
  ///
  /// 테스트와 기존 호출부가 요약을 따로 만들지 않아도 되게 한다.
  TurnPlanningContext withDerivedSummary({
    RetrievalSummaryBuilder builder = const RetrievalSummaryBuilder(),
  }) {
    return TurnPlanningContext(
      state: state,
      currentWeek: currentWeek,
      userMessage: userMessage,
      knowledge: knowledge,
      userContext: userContext,
      recentMessages: recentMessages,
      retrievalSummary: builder.build(
        userMessage: userMessage,
        context: userContext,
        recentMessages: recentMessages,
      ),
    );
  }
}

abstract class CounselingTurnPlanner {
  CounselingTurnPlan? plan(TurnPlanningContext context);
}
