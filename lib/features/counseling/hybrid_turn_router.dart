import 'counseling_state.dart';
import 'safety_gate.dart';
import 'turn_plan.dart';

/// 이번 턴이 요구하는 판단의 성격.
///
/// **"어려울수록 LLM"이 아니다.** 오히려 반대다. 임상적으로 중요하거나 위험한
/// 판단일수록 모델에서 멀리 두고, 표현의 다양성만 필요한 저위험 구간에서만
/// 모델을 쓴다. 1.7B/4B 실측에서 상담 reasoning 은 실패했고 adherence 는
/// deterministic planner 가 훨씬 강했다.
enum TurnComplexity {
  /// 계획이 이미 문장까지 확정한 구간. 모델이 개선할 여지가 적다.
  low,

  /// 표현을 다듬으면 나아지는 구간. 모델 사용이 선택적으로 허용된다.
  medium,

  /// 임상 판단·안전·새 전략 선택. **모델 사용 금지.**
  high,
}

/// 이번 턴을 어떻게 실현할지.
class TurnRoutingDecision {
  final TurnComplexity complexity;

  /// 모델을 호출해도 되는지.
  final bool allowLlm;

  /// 판단 근거. 로그와 회귀 테스트에서 이유를 확인한다.
  final String reason;

  const TurnRoutingDecision({
    required this.complexity,
    required this.allowLlm,
    required this.reason,
  });
}

/// 턴 복잡도를 보고 결정론 경로와 모델 경로를 나눈다.
class HybridTurnRouter {
  /// 모델을 아예 쓰지 않는 구성. 제품 기본값.
  final bool llmEnabled;

  const HybridTurnRouter({this.llmEnabled = false});

  TurnRoutingDecision route({
    required CounselingState state,
    required SafetyLevel safetyLevel,
    CounselingTurnPlan? plan,
  }) {
    // 안전은 어떤 규칙보다 앞선다. 위기 응답은 임상 검수된 고정 문구다.
    if (safetyLevel != SafetyLevel.normal) {
      return const TurnRoutingDecision(
        complexity: TurnComplexity.high,
        allowLlm: false,
        reason: 'safety',
      );
    }

    // 계획을 세우지 못한 턴은 승인된 행동이 정해지지 않은 상태다.
    // 여기서 모델에게 맡기면 승인되지 않은 개입을 만들어낼 수 있다.
    if (plan == null) {
      return const TurnRoutingDecision(
        complexity: TurnComplexity.high,
        allowLlm: false,
        reason: 'no_plan',
      );
    }

    if (plan.planningStatus == TurnPlanningStatus.unavailable) {
      return const TurnRoutingDecision(
        complexity: TurnComplexity.high,
        allowLlm: false,
        reason: 'no_approved_intervention',
      );
    }

    // 승인된 개입을 실행하는 턴은 문장이 이미 정해져 있다.
    // 모델이 바꾸면 승인 범위를 벗어날 수 있다.
    if (plan.interventionPlan != null) {
      return const TurnRoutingDecision(
        complexity: TurnComplexity.low,
        allowLlm: false,
        reason: 'approved_intervention',
      );
    }

    switch (state) {
      // 체크인은 고정 질문 하나면 충분하다.
      case CounselingState.checkIn:
        return const TurnRoutingDecision(
          complexity: TurnComplexity.low,
          allowLlm: false,
          reason: 'fixed_opening',
        );

      // 탐색과 되짚기는 planner 가 대상과 질문을 이미 정했다.
      // 표현만 다듬는 여지가 있어 모델 사용을 허용할 수 있다.
      case CounselingState.explore:
      case CounselingState.reflect:
        // Phase 13.8 (P3): what the turn is decides remote eligibility, not
        // the state it happens in. Only an ordinary counseling turn (one
        // with a realization spec) may be rewritten. Interaction-repair and
        // goal-exhaustion recovery turns answer the conversation itself with
        // reviewed deterministic sentences; on device the remote realizer
        // turned a repair into "…의지를 보이셨습니다".
        if (!_isOrdinaryCounselingTurn(plan)) {
          return const TurnRoutingDecision(
            complexity: TurnComplexity.low,
            allowLlm: false,
            reason: 'repair_or_recovery',
          );
        }
        return TurnRoutingDecision(
          complexity: TurnComplexity.medium,
          allowLlm: llmEnabled,
          reason: llmEnabled ? 'expression_variety' : 'llm_disabled',
        );

      // 마무리는 새 질문이나 개입이 섞이지 않도록 검수된 결정론 문장을 쓴다.
      case CounselingState.closing:
        return const TurnRoutingDecision(
          complexity: TurnComplexity.low,
          allowLlm: false,
          reason: 'fixed_closing',
        );

      case CounselingState.intervention:
        // 개입 상태인데 interventionPlan 이 없으면 승인된 개입이 확정되지 않은
        // 것이다. 위에서 걸러지지만 방어적으로 막는다.
        return const TurnRoutingDecision(
          complexity: TurnComplexity.high,
          allowLlm: false,
          reason: 'intervention_without_plan',
        );
    }
  }

  static bool _isOrdinaryCounselingTurn(CounselingTurnPlan plan) =>
      plan.realizationSpec != null &&
      plan.interactionRepairReason == null &&
      plan.goalExhaustionRecovery == null;
}
