part of 'turn_plan.dart';

/// 첫 사용자 발화를 받아 주고 걱정을 더 이야기하도록 청한다(불안 점수는 묻지 않음).
class DeterministicCheckInTurnPlanner implements CounselingTurnPlanner {
  static const List<String> defaultForbidden = [
    '진단하거나 원인을 단정하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    'CBT 개입을 시작하지 않는다.',
    '질문을 여러 개 하지 않는다.',
  ];

  final CheckInDecisionSelector selector;
  final TurnPlanMaterializer materializer;

  const DeterministicCheckInTurnPlanner({
    this.selector = const CheckInDecisionSelector(),
    this.materializer = const TurnPlanMaterializer(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    if (context.state != CounselingState.checkIn) return null;
    final decision = selector.select(userMessage: context.userMessage);
    if (decision.isUnavailable) return null;
    return materializer.checkIn(decision);
  }
}

/// Step 3B-P6: 사용자 발화에 근거한 마무리만 생성한다.
class DeterministicClosingTurnPlanner implements CounselingTurnPlanner {
  static const List<String> defaultForbidden = [
    '새로운 CBT 개입을 시작하지 않는다.',
    '사용자가 말하지 않은 변화나 성과를 만들지 않는다.',
    '진단하거나 미래의 호전을 약속하지 않는다.',
    '새로운 질문이나 과제를 제시하지 않는다.',
  ];

  final ClosingDecisionSelector selector;
  final TurnPlanMaterializer materializer;

  const DeterministicClosingTurnPlanner({
    this.selector = const ClosingDecisionSelector(),
    this.materializer = const TurnPlanMaterializer(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    if (context.state != CounselingState.closing) return null;
    final decision = selector.select(
      userMessage: context.userMessage,
      recentMessages: context.recentMessages,
    );
    return materializer.closing(
      decision,
      recentMessages: context.recentMessages,
    );
  }
}

/// Step 3B-P4: Week 4의 balanced-thought 개입 하나만 지원한다.
class DeterministicInterventionTurnPlanner implements CounselingTurnPlanner {
  static const String balancedThoughtCbtId = 'week4_alternative_thought_01';
  static const List<String> defaultForbidden = [
    '새로운 CBT 기법을 제안하지 않는다.',
    '이완 기법으로 전환하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    '여러 개의 과제를 제시하지 않는다.',
  ];

  final ApprovedInterventionRegistry registry;

  /// 승인된 개입을 앱 활동·교육 문구와 잇는다.
  final ActivityRecommendationPolicy activityPolicy;

  final DeterministicSurfaceVariation surfaceVariation;

  final InterventionDecisionSelector selector;

  final TurnPlanMaterializer materializer;

  const DeterministicInterventionTurnPlanner({
    this.registry = const ApprovedInterventionRegistry(),
    this.activityPolicy = const ActivityRecommendationPolicy(),
    this.surfaceVariation = const DeterministicSurfaceVariation(),
    this.selector = const InterventionDecisionSelector(),
    this.materializer = const TurnPlanMaterializer(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    if (context.state != CounselingState.intervention) return null;

    final decision = selector.select(
      currentWeek: context.currentWeek,
      userMessage: context.userMessage,
      recentMessages: context.recentMessages,
      knowledge: context.knowledge,
      userContext: context.userContext,
      registry: registry,
    );

    if (decision.isUnavailable) {
      // Two distinct "nothing to do" outcomes, per
      // InterventionDecisionSelector's encoding note: `reflectionTarget ==
      // null` means legacy would build the full unavailable-plan; `== ''`
      // means legacy would return bare `null` (target computed but empty).
      if (decision.reflectionTarget == null) {
        return materializer.interventionUnavailable(
          context.userMessage,
          context.recentMessages,
        );
      }
      return null;
    }
    if (decision.selectedAction == DialogueAct.reflect) {
      return materializer.interventionIntegration(
        decision,
        currentWeek: context.currentWeek,
        knowledge: context.knowledge,
        recentMessages: context.recentMessages,
      );
    }
    if (decision.selectedAction == DialogueAct.summarize) {
      return materializer.interventionNoEligible(
        decision,
        recentMessages: context.recentMessages,
        userMessage: context.userMessage,
      );
    }

    return materializer.intervention(
      decision,
      currentWeek: context.currentWeek,
      knowledge: context.knowledge,
      recentMessages: context.recentMessages,
      userMessage: context.userMessage,
    );
  }
}

/// Step 3B-P3: explore 한 턴에서 상황을 구체화하는 결정론적 planner.
///
/// 현재 사용자 발화를 짧게 확인하고 질문을 하나만 한다. 일기나 CBT 항목을 문장
/// 생성에 사용하지 않으므로 construction provenance에도 포함하지 않는다.
class DeterministicExploreTurnPlanner implements CounselingTurnPlanner {
  final DeterministicSurfaceVariation surfaceVariation;
  static const List<String> defaultForbidden = [
    '행동 해결책을 제안하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    '직전 상담자의 질문을 반복하지 않는다.',
    '생각을 평가하거나 다음 CBT 단계로 넘어가지 않는다.',
  ];

  final ExploreDecisionSelector selector;
  final TurnPlanMaterializer materializer;

  const DeterministicExploreTurnPlanner({
    this.surfaceVariation = const DeterministicSurfaceVariation(),
    this.selector = const ExploreDecisionSelector(),
    this.materializer = const TurnPlanMaterializer(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    if (context.state != CounselingState.explore) return null;

    final current = context.userMessage.trim();
    if (current.isEmpty) return null;
    // check-in의 SUD 질문에 대한 "6점" 같은 답은 새 상담 주제가 아니다.
    // 숫자를 reflection target으로 넘기면 작은 모델이 빈 의미를 임의로 채우므로,
    // 직전의 실질적인 사용자 고민을 계속 탐색한다.
    final decision = selector.select(
      userMessage: context.userMessage,
      recentMessages: context.recentMessages,
    );
    return materializer.explore(
      decision,
      userMessage: context.userMessage,
      recentMessages: context.recentMessages,
      // explore 상태의 허용 행위(explore/reflect) 안에서 GPT가 이번 턴에
      // 질문 대신 반영만 할지 스스로 고를 수 있게 한다.
      allowedActsForTurn: context.state.allowedActs,
    );
  }
}

/// Step 3B-P2: reflect 상태 하나만 다루는 결정론적 planner.
///
/// 임상적 해석이나 요약을 생성하지 않는다. 현재 발화 또는 구조화된 기록에서
/// 근거가 있는 생각 문자열을 그대로 선택한다.
/// reflect 단계의 질문 목표. 어떤 목표를 쓸지는 **정책이 정하고 모델은 관여하지 않는다.**
enum ReflectQuestionGoal {
  /// 그 생각을 사실로 느끼게 하는 근거를 찾는다.
  evidence,

  /// 같은 상황을 다른 각도에서 본다.
  alternative,

  /// 실제로 일어날 가능성을 가늠한다.
  probability;

  String get question {
    switch (this) {
      case ReflectQuestionGoal.evidence:
        return '그 생각을 사실이라고 느끼게 하는 근거나 경험이 무엇인지 하나 떠올려볼까요?';
      case ReflectQuestionGoal.alternative:
        return '그 상황을 다른 관점에서 본다면 어떻게 볼 수 있을까요?';
      case ReflectQuestionGoal.probability:
        return '실제로 그렇게 될 가능성은 어느 정도라고 느끼시나요?';
    }
  }

  String get goal {
    switch (this) {
      case ReflectQuestionGoal.evidence:
        return '이 생각을 사실이라고 느끼게 하는 근거나 경험을 하나 탐색한다.';
      case ReflectQuestionGoal.alternative:
        return '같은 상황을 다른 관점에서 바라볼 여지를 하나 탐색한다.';
      case ReflectQuestionGoal.probability:
        return '그 일이 실제로 일어날 가능성을 어떻게 느끼는지 탐색한다.';
    }
  }
}

/// Step 3B-P5-D: reflect 문장과 질문을 harness가 직접 구성한다. LLM 호출 0회.
class DeterministicReflectTurnPlanner implements CounselingTurnPlanner {
  final DeterministicSurfaceVariation surfaceVariation;
  static const List<String> defaultForbidden = [
    '행동 해결책을 제안하지 않는다.',
    '새로운 사실을 만들지 않는다.',
    '이미 답이 주어진 질문을 반복하지 않는다.',
    '다음 CBT 단계로 넘어가지 않는다.',
  ];

  /// 질문 목표를 쓰는 순서. 정책이며 모델이 고르지 않는다.
  static const List<ReflectQuestionGoal> goalOrder = [
    ReflectQuestionGoal.evidence,
    ReflectQuestionGoal.alternative,
    ReflectQuestionGoal.probability,
  ];

  final ReflectDecisionSelector selector;
  final TurnPlanMaterializer materializer;

  const DeterministicReflectTurnPlanner({
    this.surfaceVariation = const DeterministicSurfaceVariation(),
    this.selector = const ReflectDecisionSelector(),
    this.materializer = const TurnPlanMaterializer(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    if (context.state != CounselingState.reflect) return null;

    final decision = selector.select(
      userMessage: context.userMessage,
      recentMessages: context.recentMessages,
      userContext: context.userContext,
    );
    return materializer.reflect(
      decision,
      recentMessages: context.recentMessages,
      // reflect 상태의 허용 행위(reflect/summarize/socraticQuestion) 안에서
      // GPT가 이번 턴에 질문 없이 반영만 하거나 정리로 넘어갈지 고를 수 있게
      // 한다. clarify 분기(requiredAct: explore)는 explore가 reflect의
      // allowedActs에 없어 여기 포함하지 않는다 — 기존처럼 고정한다.
      allowedActsForTurn: context.state.allowedActs,
    );
  }
}
