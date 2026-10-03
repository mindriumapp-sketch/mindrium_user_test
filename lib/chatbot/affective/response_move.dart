import 'package:gad_app_team/data/counseling/counseling_models.dart';

/// 최종적으로 사용자에게 나간 응답의 행동 (표정 두 번째 박자의 근거).
///
/// B가 검증에서 거절되어 A가 답했으면 A 응답에서 읽는다. 버려진 B의 행동은
/// 표정에 쓰지 않는다.
enum ResponseMove {
  /// 대화에 대한 불만을 받아 주고 방식을 바꿈
  repair,

  /// 기법 질문에 대한 답을 받아 줌
  integrate,

  /// 감정·걱정을 인정하거나 되짚음
  empathize,

  /// 앱 사용법 안내
  appGuide,

  /// 마무리
  closing,

  /// 그 외(질문, 설명 등)
  other;

  /// B 경로에서 채택된 응답(검증 통과)의 행동.
  static ResponseMove fromLlmLed({
    required String domain,
    required List<String> moves,
    String? interventionStep,
    required String sessionAction,
  }) {
    if (moves.contains('repair')) return ResponseMove.repair;
    if (sessionAction == 'finalize' || moves.contains('finalize')) return ResponseMove.closing;
    if (interventionStep == 'integration' || moves.contains('integrate')) return ResponseMove.integrate;
    final empathic = moves.any((m) => m == 'acknowledge' || m == 'reflect_emotion' || m == 'restate');
    if (domain == 'app_guide' || (domain == 'mixed' && !empathic)) return ResponseMove.appGuide;
    if (empathic) return ResponseMove.empathize;
    return ResponseMove.other;
  }

  /// A 경로 응답의 턴 메타데이터에서 읽는다.
  static ResponseMove fromMessage(CounselingMessage m, {bool appGuide = false}) {
    if (m.interactionRepairReason != null) return ResponseMove.repair;
    if (m.closingStep == ClosingStep.finalized || m.dialogueAct == DialogueAct.closing) {
      return ResponseMove.closing;
    }
    if (m.interventionStep == InterventionStep.integration) return ResponseMove.integrate;
    if (appGuide) return ResponseMove.appGuide;
    if (m.dialogueAct == DialogueAct.reflect) return ResponseMove.empathize;
    return ResponseMove.other;
  }
}
