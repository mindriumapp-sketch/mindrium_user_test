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

  /// harness 가 이번 단계에서 모델에게 요구하는 발화 행위.
  ///
  /// 상담 흐름은 harness 가 정한다는 원칙을 발화 행위까지 밀어붙인 것이다.
  /// 모델은 이 행위에 해당하는 문장을 쓰기만 하면 되고, 분류는 하지 않는다.
  DialogueAct get requiredAct {
    switch (this) {
      case CounselingState.checkIn:
        return DialogueAct.explore;
      case CounselingState.explore:
        return DialogueAct.explore;
      case CounselingState.reflect:
        return DialogueAct.reflect;
      case CounselingState.intervention:
        return DialogueAct.socraticQuestion;
      case CounselingState.closing:
        return DialogueAct.closing;
    }
  }

  /// 이번 턴에 모델이 해야 할 일. 상태 머신 전체를 설명하는 대신 이것만 준다.
  String get currentTask {
    switch (this) {
      case CounselingState.checkIn:
        return '사용자가 오늘 어떤 상태인지 묻는다.';
      case CounselingState.explore:
        return '사용자의 걱정을 한 가지 더 구체적으로 묻는다.';
      case CounselingState.reflect:
        return '사용자가 말한 핵심 생각을 짧게 되비추고 함께 살펴본다.';
      case CounselingState.intervention:
        return '그 생각을 다른 각도에서 볼 수 있는 질문을 하나 한다.';
      case CounselingState.closing:
        return '오늘 이야기를 한 문장으로 정리하고 마무리한다.';
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
          'behavior',
          'avoidance',
          'self_monitoring',
          'habit',
          'planning',
          'maintenance',
          'relapse_prevention',
          'values',
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
/// 모델은 다음 상태를 제안하지 않는다. 단계별 턴 예산을 harness 가 갖고 있고,
/// 모델의 발화 행위는 그 진행을 **앞당기기만** 한다.
///
/// 예산을 단계마다 다르게 두는 이유: 모든 단계에 같은 상한을 쓰면 탐색에서만
/// 서너 턴을 소모해 대화가 진도를 못 나간다. 실제로 "발표가 걱정돼요 →
/// 질문에 답을 못할까 봐요" 두 턴이면 되짚기로 넘어가는 것이 자연스럽다.
class CounselingStatePolicy {
  /// 세션 전체 최대 턴 수. 넘으면 마무리로 보낸다.
  static const int maxSessionTurns = 20;

  const CounselingStatePolicy();

  /// 단계별로 머무를 최대 턴 수.
  ///
  /// checkIn 과 탐색은 한 번이면 충분하다. Phase 13.3부터 reflect/intervention
  /// 은 턴 수가 아니라 **완료 조건**([StageProgress.complete])으로 넘어가고,
  /// 이 값은 완료 신호가 오지 않을 때의 안전 상한이다.
  int budgetFor(CounselingState state) {
    switch (state) {
      case CounselingState.checkIn:
        return 1;
      case CounselingState.explore:
        return 1;
      case CounselingState.reflect:
        // Phase 13.4: up to 4 turns, so clarify turns no longer crowd out
        // the reflective goals (the old budget of 2 < 3 goals).
        return 4;
      case CounselingState.intervention:
        // Phase 13.3: ask → answer → integrate, plus one slack turn for a
        // repair in between.
        return 3;
      case CounselingState.closing:
        // 마무리는 사용자가 끝낼 때까지 머문다.
        return maxSessionTurns;
    }
  }

  /// Phase 13.3/13.4: the fewest turns a completion-driven stage stays,
  /// even if it reports [StageProgress.complete] earlier.
  int minTurnsFor(CounselingState state) {
    switch (state) {
      case CounselingState.reflect:
        return 2;
      case CounselingState.checkIn:
      case CounselingState.intervention:
        // Intervention needs no minimum: the prompt turn reports
        // `inProgress`, so it can't advance early, and a noEligible wrap-up
        // must advance right away (otherwise the user's reply to the closing
        // proposal is swallowed by a second wrap-up).
      case CounselingState.explore:
      case CounselingState.closing:
        return 1;
    }
  }

  /// Stages that advance on completion rather than on a fixed count.
  bool _completionDriven(CounselingState state) =>
      state == CounselingState.reflect ||
      state == CounselingState.intervention;

  CounselingState next({
    required CounselingState current,
    required int turnsInCurrentState,
    required int totalTurns,
    required DialogueAct lastAct,
    StageProgress? progress,
  }) {
    if (totalTurns >= maxSessionTurns) return CounselingState.closing;

    // 무엇을 했는지 모르는 턴(파싱 실패 등)은 진행으로 세지 않는다.
    if (lastAct == DialogueAct.unknown) return current;

    // Phase 13.5: closing → one controlled return when the user wants to
    // keep talking. The closing selector enforces "at most once".
    if (current == CounselingState.closing) {
      return progress == StageProgress.reopen ? CounselingState.reflect : current;
    }

    // 모델이 다음 단계에 해당하는 행위를 이미 했으면 앞당긴다.
    if (_acceleratesFrom(current, lastAct)) return _advance(current);

    final turnsAfterThis = turnsInCurrentState + 1;
    if (_completionDriven(current)) {
      // Phase 13.3/13.4: advance on completion (after the minimum), else only
      // at the cap. A turn with no stage signal (e.g. an interaction-repair
      // turn) never counts as completion.
      if (progress == StageProgress.complete &&
          turnsAfterThis >= minTurnsFor(current)) {
        return _advance(current);
      }
      if (turnsAfterThis >= budgetFor(current)) return _advance(current);
      return current;
    }

    // 아니면 이 단계의 턴 예산을 다 쓴 뒤 넘어간다.
    // turnsInCurrentState 는 '이미 끝낸 턴 수'이므로 이번 턴을 더해 비교한다.
    if (turnsAfterThis >= budgetFor(current)) return _advance(current);

    return current;
  }

  /// 모델의 발화 행위가 다음 단계로 넘어갈 근거가 되는지.
  bool _acceleratesFrom(CounselingState current, DialogueAct act) {
    switch (current) {
      case CounselingState.explore:
        // 되비추기가 나왔다는 건 살펴볼 재료가 모였다는 뜻이다.
        return act == DialogueAct.reflect;
      case CounselingState.reflect:
        // 정리했다는 건 개입으로 넘어갈 준비가 됐다는 뜻이다.
        return act == DialogueAct.summarize;
      case CounselingState.checkIn:
      case CounselingState.intervention:
      case CounselingState.closing:
        return false;
    }
  }

  CounselingState _advance(CounselingState current) {
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
