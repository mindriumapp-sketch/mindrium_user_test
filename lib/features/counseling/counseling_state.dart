import 'package:gad_app_team/data/counseling/counseling_models.dart';

/// 상담 진행 단계. LLM 출력이 아니라 harness 의 정책 코드가 결정한다.
///
/// Step 1 은 5단계만 둔다. 필요해지면 reflect 를 identifyThought /
/// examineEvidence / alternativeThought 로 쪼갠다.
enum CounselingState {
  checkIn,
  explore,
  reflect,
  intervention,
  closing;

  String get wireName {
    switch (this) {
      case CounselingState.checkIn:
        return 'check_in';
      case CounselingState.explore:
        return 'explore';
      case CounselingState.reflect:
        return 'reflect';
      case CounselingState.intervention:
        return 'intervention';
      case CounselingState.closing:
        return 'closing';
    }
  }

  /// 이 단계에서 모델이 해도 되는 발화 행위.
  List<DialogueAct> get allowedActs {
    switch (this) {
      case CounselingState.checkIn:
        return const [DialogueAct.explore, DialogueAct.reflect];
      case CounselingState.explore:
        return const [DialogueAct.explore, DialogueAct.reflect];
      case CounselingState.reflect:
        return const [
          DialogueAct.reflect,
          DialogueAct.summarize,
          DialogueAct.socraticQuestion,
        ];
      case CounselingState.intervention:
        return const [
          DialogueAct.socraticQuestion,
          DialogueAct.psychoeducation,
          DialogueAct.reflect,
        ];
      case CounselingState.closing:
        return const [DialogueAct.closing, DialogueAct.summarize];
    }
  }

  /// 이 단계에서 검색할 CBT 지식의 태그 힌트.
  Set<String> get retrievalTags {
    switch (this) {
      case CounselingState.checkIn:
        return const {'sud', 'self_monitoring'};
      case CounselingState.explore:
        return const {'abc_model', 'diary', 'thought', 'behavior'};
      case CounselingState.reflect:
        return const {'thought', 'cognitive_restructuring', 'behavior'};
      case CounselingState.intervention:
        return const {
          'alternative_thought',
          'cognitive_restructuring',
          'relaxation',
          'confrontation',
        };
      case CounselingState.closing:
        return const {'maintenance', 'habit'};
    }
  }

  /// 이 단계에서 모델이 해야 할 일. 프롬프트에 그대로 들어간다.
  String get goal {
    switch (this) {
      case CounselingState.checkIn:
        return '사용자가 오늘 어떤 상태인지, 지금 불안이 어느 정도인지 확인한다.';
      case CounselingState.explore:
        return '사용자가 걱정하는 상황을 구체적으로 떠올릴 수 있게 돕는다.';
      case CounselingState.reflect:
        return '사용자의 말에서 반복되는 생각이나 행동을 되비추어 함께 확인한다.';
      case CounselingState.intervention:
        return 'Mindrium 에서 배운 기법 중 하나를 사용자가 직접 적용해보도록 질문한다.';
      case CounselingState.closing:
        return '오늘 나눈 내용을 짧게 정리하고 대화를 마무리한다.';
    }
  }
}

/// 상태 전이 정책.
///
/// 모델은 다음 상태를 제안하지 않는다. 턴 수와 직전 발화 행위만 보고 코드가 정한다.
class CounselingStatePolicy {
  /// 한 상태에 머무를 수 있는 최대 턴 수. 대화가 한 단계에 갇히지 않게 한다.
  static const int maxTurnsPerState = 3;

  /// 세션 전체 최대 턴 수. 넘으면 마무리로 보낸다.
  static const int maxSessionTurns = 20;

  const CounselingStatePolicy();

  CounselingState next({
    required CounselingState current,
    required int turnsInCurrentState,
    required int totalTurns,
    required DialogueAct lastAct,
  }) {
    if (totalTurns >= maxSessionTurns) return CounselingState.closing;

    // 아직 이 단계에서 할 일이 남았으면 머문다.
    if (turnsInCurrentState < maxTurnsPerState) {
      // 파싱 실패로 무엇을 했는지 모르는 턴은 진행으로 세지 않고 제자리에 둔다.
      if (lastAct == DialogueAct.unknown) return current;

      switch (current) {
        case CounselingState.checkIn:
          // 체크인은 한 번 주고받으면 충분하다.
          return CounselingState.explore;
        case CounselingState.explore:
          // 되비추기가 나왔다는 건 살펴볼 재료가 모였다는 뜻이다.
          return lastAct == DialogueAct.reflect
              ? CounselingState.reflect
              : current;
        case CounselingState.reflect:
          return lastAct == DialogueAct.summarize
              ? CounselingState.intervention
              : current;
        case CounselingState.intervention:
        case CounselingState.closing:
          return current;
      }
    }

    // 한 단계에 너무 오래 머물렀으면 다음 단계로 넘긴다.
    switch (current) {
      case CounselingState.checkIn:
        return CounselingState.explore;
      case CounselingState.explore:
        return CounselingState.reflect;
      case CounselingState.reflect:
        return CounselingState.intervention;
      case CounselingState.intervention:
        return CounselingState.closing;
      case CounselingState.closing:
        return CounselingState.closing;
    }
  }
}
