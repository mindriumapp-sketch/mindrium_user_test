/// 사용자의 상태에 대한 신호. **상담사의 표정이 아니다.**
///
/// 이 둘을 같은 enum 으로 두면 "사용자가 괴로우면 상담사도 괴로운 표정"이라는
/// 과도한 미러링이 자연스럽게 코드로 굳는다. 신호와 태도는 끝까지 분리한다.
library;

/// 직전 턴 대비 정서 궤적.
enum AffectTrajectory {
  unknown,

  /// 불안이 낮아지는 중.
  improving,

  /// 큰 변화 없음.
  steady,

  /// 불안이 높아지는 중.
  worsening,
}

enum AffectLabel {
  neutral,
  anxious,
  distressed,
  positive,

  /// 판단할 근거가 부족함.
  uncertain,
}

class AffectSignal {
  final AffectLabel label;

  /// 0.0~1.0. 어휘 규칙의 강도이며 보정된 확률이 아니다.
  final double confidence;

  /// 직전 신호 대비 급격한 변화인지.
  final bool spike;

  /// 같은 표정이 연속으로 몇 번 나왔는지.
  final int streak;

  /// 최근 SUD. 없을 수 있다.
  final int? sud;

  /// 직전 턴 대비 변화. 한 턴의 라벨만 보면 "불안 → 불안 → 불안"처럼 보이지만,
  /// SUD 가 8 → 7 → 5 로 내려가고 있다면 상담자의 태도는 달라져야 한다.
  final AffectTrajectory trajectory;

  const AffectSignal({
    required this.label,
    required this.confidence,
    this.spike = false,
    this.streak = 0,
    this.sud,
    this.trajectory = AffectTrajectory.unknown,
  });

  static const AffectSignal unknown = AffectSignal(
    label: AffectLabel.uncertain,
    confidence: 0,
  );

  AffectSignal copyWith({bool? spike, int? streak}) {
    return AffectSignal(
      label: label,
      confidence: confidence,
      spike: spike ?? this.spike,
      streak: streak ?? this.streak,
      sud: sud,
    );
  }
}

/// 상담사가 보일 태도. 사용자의 감정을 그대로 되비추지 않는다.
enum AvatarExpression {
  neutral,
  warm,
  attentive,
  concerned,
  encouraging,
}

/// 표정 전환 정책. 실험에서 값을 바꿀 가능성이 높아 상수 대신 객체로 둔다.
class AffectivePolicy {
  /// 이 이상이면 단계 기본값을 무시하고 신호를 따른다.
  final double spikeThreshold;

  /// 같은 표정이 이만큼 이어지면 한 번 바꿔 준다.
  final int streakThreshold;

  /// 이 이상의 SUD 는 높은 불안으로 본다.
  final int highSudThreshold;

  const AffectivePolicy({
    this.spikeThreshold = 0.92,
    this.streakThreshold = 3,
    this.highSudThreshold = 7,
  });

  static const AffectivePolicy defaults = AffectivePolicy();
}
