part of 'turn_plan.dart';

/// 지원하는 상태별 결정론적 planner를 한 Harness에 연결한다.
class DeterministicCounselingTurnPlanner implements CounselingTurnPlanner {
  final CounselingTurnPlanner inputGuardPlanner;
  final CounselingTurnPlanner processSignalPlanner;
  final CounselingTurnPlanner checkInPlanner;
  final CounselingTurnPlanner explorePlanner;
  final CounselingTurnPlanner reflectPlanner;
  final CounselingTurnPlanner interventionPlanner;
  final CounselingTurnPlanner closingPlanner;

  const DeterministicCounselingTurnPlanner({
    this.inputGuardPlanner = const DeterministicInputGuardTurnPlanner(),
    this.processSignalPlanner = const DeterministicProcessSignalTurnPlanner(),
    this.checkInPlanner = const DeterministicCheckInTurnPlanner(),
    this.explorePlanner = const DeterministicExploreTurnPlanner(),
    this.reflectPlanner = const DeterministicReflectTurnPlanner(),
    this.interventionPlanner = const DeterministicInterventionTurnPlanner(),
    this.closingPlanner = const DeterministicClosingTurnPlanner(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    // 의미 없는 입력·모욕·프롬프트 조작 시도는 상담 내용으로 다루지 않고
    // 가장 먼저 걸러 다시 답해 달라고 자연스럽게 청한다.
    // 그다음으로, 사용자가 "질문 그만하고 들어달라"거나 상담 과정 자체에
    // 회의적인 반응을 보이면 그 신호에 먼저 반응한다. 둘 다 상태별
    // planner보다 앞서 확인해 어느 상태에서도 같은 방식으로 잡는다.
    return inputGuardPlanner.plan(context) ??
        processSignalPlanner.plan(context) ??
        checkInPlanner.plan(context) ??
        explorePlanner.plan(context) ??
        reflectPlanner.plan(context) ??
        interventionPlanner.plan(context) ??
        closingPlanner.plan(context);
  }
}
