import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'affect_signal.dart';
import 'response_move.dart';

/// 신호를 상담사의 태도로 옮긴다.
///
/// 핵심 규칙: 사용자의 감정을 그대로 되비추지 않는다.
/// distressed 사용자에게 상담사가 distressed 표정을 보이면 안 된다. concerned 다.
class AffectiveAdapter {
  final AffectivePolicy policy;

  const AffectiveAdapter({this.policy = AffectivePolicy.defaults});

  AvatarExpression adapt({
    required AffectSignal signal,
    required CounselingState state,
    SafetyLevel safetyLevel = SafetyLevel.normal,
  }) {
    // 위기 상황에서는 표정을 극적으로 쓰지 않는다. 연출은 안전을 돕지 않는다.
    if (safetyLevel != SafetyLevel.normal) return AvatarExpression.attentive;

    // 라벨이 계속 anxious 여도 불안이 내려가는 중이면 격려가 맞다.
    // 궤적을 보지 않으면 세 턴 내내 같은 표정에 머문다.
    if (signal.trajectory == AffectTrajectory.improving &&
        signal.label != AffectLabel.distressed) {
      return AvatarExpression.encouraging;
    }

    final base = _baseFor(state);

    // 신호가 충분히 뚜렷하면 단계 기본값 대신 신호를 따른다.
    if (signal.confidence >= policy.spikeThreshold || signal.spike) {
      final fromSignal = _fromSignal(signal.label);
      if (fromSignal != null) return fromSignal;
    }

    // 같은 표정이 오래 이어지면 한 번 바꿔 준다. 굳은 표정이 계속되면 부자연스럽다.
    if (signal.streak >= policy.streakThreshold) {
      final relief = _reliefFor(base);
      if (relief != null) return relief;
    }

    return base;
  }

  /// 두 박자 표정의 첫 박자: 사용자가 보낸 직후, 답을 기다리는 동안 듣는 얼굴.
  AvatarExpression listening() => AvatarExpression.attentive;

  /// 두 박자 표정의 두 번째 박자: 최종 응답이 확정되는 순간, 사용자 정서 단서 ×
  /// 실제로 나간 응답의 행동으로 정한다. 단서 하나만으로 표정을 바꾸지 않는다.
  /// 같은 상황이 이어지면 같은 표정을 유지한다(다양성을 위해 의미를 바꾸지 않는다).
  AvatarExpression respond({
    required AffectSignal signal,
    required ResponseMove move,
    required CounselingState state,
    SafetyLevel safetyLevel = SafetyLevel.normal,
  }) {
    if (safetyLevel != SafetyLevel.normal) return AvatarExpression.attentive;
    if (move == ResponseMove.repair) return AvatarExpression.concerned;
    if (signal.label == AffectLabel.distressed) return AvatarExpression.concerned;
    if (signal.label == AffectLabel.anxious && move == ResponseMove.empathize) {
      return AvatarExpression.warm;
    }
    if (signal.label == AffectLabel.positive || move == ResponseMove.integrate) {
      return AvatarExpression.encouraging;
    }
    if (move == ResponseMove.appGuide || move == ResponseMove.closing) return AvatarExpression.warm;
    return _baseFor(state);
  }

  /// 상담 단계가 정하는 기본 태도.
  AvatarExpression _baseFor(CounselingState state) {
    switch (state) {
      case CounselingState.checkIn:
        return AvatarExpression.warm;
      case CounselingState.explore:
        return AvatarExpression.attentive;
      case CounselingState.reflect:
        return AvatarExpression.attentive;
      case CounselingState.intervention:
        return AvatarExpression.encouraging;
      case CounselingState.closing:
        return AvatarExpression.warm;
    }
  }

  /// 사용자 신호 → 상담사 태도. 미러링이 아니라 대응이다.
  AvatarExpression? _fromSignal(AffectLabel label) {
    switch (label) {
      case AffectLabel.distressed:
        return AvatarExpression.concerned;
      case AffectLabel.anxious:
        return AvatarExpression.attentive;
      case AffectLabel.positive:
        return AvatarExpression.encouraging;
      case AffectLabel.neutral:
        return AvatarExpression.warm;
      case AffectLabel.uncertain:
        return null;
    }
  }

  /// 연속 유지를 끊을 때 쓰는 대체 표정. 의미가 크게 달라지지 않는 쪽으로 옮긴다.
  AvatarExpression? _reliefFor(AvatarExpression current) {
    switch (current) {
      case AvatarExpression.warm:
        return AvatarExpression.neutral;
      case AvatarExpression.attentive:
        return AvatarExpression.warm;
      case AvatarExpression.encouraging:
        return AvatarExpression.warm;
      case AvatarExpression.concerned:
        // 걱정하는 표정은 유지되는 편이 자연스럽다. 억지로 바꾸지 않는다.
        return null;
      case AvatarExpression.neutral:
        return AvatarExpression.warm;
    }
  }
}
