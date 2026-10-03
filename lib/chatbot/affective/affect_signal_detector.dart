import 'affect_signal.dart';

/// 사용자 발화에서 **정서적 단서(affective cue)** 를 찾는다.
///
/// 이것은 감정 인식(emotion recognition) 시스템이 아니다. 한국어 표층 표현을
/// 정규식으로 찾는 어휘 규칙이며, 정확도를 주장하지 않는다. 목적은 사용자의 감정을
/// 맞히는 것이 아니라, 상담사 아바타가 취할 태도를 정하기에 충분한 단서를 얻는 것이다.
/// 성능을 보고할 때도 "감정 인식 정확도"가 아니라 단서 탐지와 태도 적응으로 기술한다.
///
/// LLM 을 호출하지 않는다. 한 턴당 모델 추론은 상담 응답 생성 1회로 유지한다는 것이
/// 이 프로젝트의 제약이다. 분류를 위해 추론을 한 번 더 돌리면 지연·발열·배터리가
/// 모두 나빠진다. 나중에 정확도가 필요해지면 별도의 경량 분류기를 이 뒤에 넣는다.
class AffectSignalDetector {
  final AffectivePolicy policy;

  const AffectSignalDetector({this.policy = AffectivePolicy.defaults});

  /// 규칙별 확신도. 표현이 뚜렷할수록 높다.
  /// 확률이 아니라 규칙의 강도를 나타내는 값이며, 보정된 신뢰도가 아니다.
  static const double _strongConfidence = 0.95;
  static const double _mediumConfidence = 0.8;
  static const double _weakConfidence = 0.6;

  static final RegExp _distressed = RegExp(
    r'(힘들|괴로|버겁|못 견|못견|우울|슬프|눈물|속상|절망|무너|서운|후회|화나|화가|외로|지쳐|지친|지치|답답|막막|짜증)',
  );
  static final RegExp _anxious = RegExp(
    r'(불안|걱정|초조|두렵|두려워|두려운|무섭|무서워|긴장|떨리|조마조마|어떡하지|망칠)',
  );
  /// 대처에 성공했다는 명시적 보고. 표정을 바꿀 만큼 신호가 뚜렷하다.
  static final RegExp _positiveStrong = RegExp(
    r'(나아졌|좋아졌|괜찮아졌|해냈|잘 됐|잘됐|덜 불안|덜 힘들)',
  );

  /// 부드러운 긍정. 방향은 같지만 단계 기본 태도를 뒤집을 만큼은 아니다.
  static final RegExp _positiveSoft = RegExp(r'(다행|편안|안심|괜찮|고마)');
  static final RegExp _reflective = RegExp(r'(생각|고민|정리|되돌아|살펴)');

  /// 직전 턴과 SUD 를 비교해 궤적을 정한다.
  ///
  /// 한쪽이라도 값이 없으면 판단하지 않는다. 없는 변화를 추측하면
  /// "좋아지고 계시네요" 같은 근거 없는 말이 나온다.
  AffectTrajectory _trajectory(int? current, int? previous) {
    if (current == null || previous == null) return AffectTrajectory.unknown;
    if (current < previous) return AffectTrajectory.improving;
    if (current > previous) return AffectTrajectory.worsening;
    return AffectTrajectory.steady;
  }

  /// [userMessage] 는 사용자가 방금 한 말이다. 상담자의 답변이 아니다.
  ///
  /// 기존 구현은 상담자 응답 문장으로 표정을 골랐는데, 그러면 상담사가 자기 말에
  /// 반응하는 꼴이 된다. 신호는 사용자 쪽에서 읽는 것이 맞다.
  AffectSignal detect({
    required String userMessage,
    int? recentSud,
    AffectSignal? previous,
  }) {
    final text = userMessage.toLowerCase();

    var label = AffectLabel.neutral;
    var confidence = _weakConfidence;

    if (_distressed.hasMatch(text)) {
      label = AffectLabel.distressed;
      confidence = _strongConfidence;
    } else if (_anxious.hasMatch(text)) {
      label = AffectLabel.anxious;
      confidence = _mediumConfidence;
    } else if (_positiveStrong.hasMatch(text)) {
      label = AffectLabel.positive;
      confidence = _strongConfidence;
    } else if (_positiveSoft.hasMatch(text)) {
      label = AffectLabel.positive;
      confidence = _mediumConfidence;
    } else if (_reflective.hasMatch(text)) {
      label = AffectLabel.neutral;
      confidence = _mediumConfidence;
    } else if (text.trim().isEmpty) {
      return AffectSignal.unknown;
    }

    // 높은 SUD 는 표현이 담담해도 불안을 올려 잡는다.
    if (recentSud != null && recentSud >= policy.highSudThreshold) {
      if (label == AffectLabel.neutral) {
        label = AffectLabel.anxious;
        confidence = _mediumConfidence;
      }
      if (label == AffectLabel.anxious) confidence = _strongConfidence;
    }

    final streak = previous != null && previous.label == label
        ? previous.streak + 1
        : 1;

    // 직전과 라벨이 달라지면서 확신도가 높으면 급변으로 본다.
    final spike =
        previous != null &&
        previous.label != label &&
        confidence >= policy.spikeThreshold;

    return AffectSignal(
      label: label,
      confidence: confidence,
      spike: spike,
      streak: streak,
      sud: recentSud,
      trajectory: _trajectory(recentSud, previous?.sud),
    );
  }
}
