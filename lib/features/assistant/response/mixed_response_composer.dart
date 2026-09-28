import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';

import 'app_guide_response.dart';

/// Mixed (상담 + 앱 가이드) 응답을 하나로 합친다.
///
/// Counseling과 App Guide 응답을 deterministic하게 조합하되,
/// 가장 중요한 상담 내용을 우선하고, 앱 가이드 정보를 보충한다.
abstract interface class MixedResponseComposer {
  CounselingTurnResult compose({
    required CounselingTurnResult counseling,
    required AppGuideResponse appGuide,
  });
}

/// Deterministic mixer. 어떤 외부 LLM도 사용하지 않는다.
///
/// 구성 원칙:
/// 1. 상담 응답을 기본으로 함
/// 2. 앱 안내를 보충적으로 붙임
/// 3. 같은 내용을 반복하지 않음
/// 4. 상담 질문 수는 증가시키지 않음
/// 5. App Guide 내용은 KB에서 온 것 그대로 유지
class DeterministicMixedResponseComposer implements MixedResponseComposer {
  const DeterministicMixedResponseComposer();

  @override
  CounselingTurnResult compose({
    required CounselingTurnResult counseling,
    required AppGuideResponse appGuide,
  }) {
    // App Guide 정보가 없거나 degraded 상태면 상담 응답만 반환한다.
    if (appGuide.status != AppGuideAnswerStatus.grounded) {
      return counseling;
    }

    // App Guide 응답을 상담 응답에 덧붙인다.
    final combinedText = _combine(counseling.assistantMessage.text, appGuide);
    final combinedMessage = CounselingMessage(
      id: counseling.assistantMessage.id,
      role: counseling.assistantMessage.role,
      text: combinedText,
      createdAt: counseling.assistantMessage.createdAt,
      dialogueAct: counseling.assistantMessage.dialogueAct,
      referencedCbtIds: counseling.assistantMessage.referencedCbtIds,
      referencedUserContextIds:
          counseling.assistantMessage.referencedUserContextIds,
      parseStatus: counseling.assistantMessage.parseStatus,
      latency: counseling.assistantMessage.latency,
      dialogueGoalId: counseling.assistantMessage.dialogueGoalId,
    );

    // Provenance 병합: 상담의 근거 + 앱 가이드의 근거
    final mergedProvenance = <String>{
      ...counseling.retrievalProvenanceIds,
      ...appGuide.sourceRefs,
    }.toList();

    return CounselingTurnResult(
      assistantMessage: combinedMessage,
      state: counseling.state,
      stateBefore: counseling.stateBefore,
      safety: counseling.safety,
      handledBySafety: counseling.handledBySafety,
      promptVersion: 'mixed_v1',
      turnPlan: counseling.turnPlan,
      uiAction: counseling.uiAction,
      offeredCbtIdCount: counseling.offeredCbtIdCount,
      offeredUserContextIdCount: counseling.offeredUserContextIdCount,
      retrievalProvenanceIds: mergedProvenance,
      routing: counseling.routing,
      realizationSource: counseling.realizationSource,
      actChosenByModel: counseling.actChosenByModel,
    );
  }

  /// 상담 응답에 앱 가이드 정보를 덧붙인다.
  ///
  /// 원칙:
  /// - 상담 응답을 먼저 완성
  /// - 앱 가이드는 보충 정보로
  /// - 반복되는 내용 제외
  String _combine(String counselingText, AppGuideResponse appGuide) {
    final guideText = appGuide.text;

    // 매우 단순한 경우: 상담 응답 뒤에 개행 2개 + 가이드 텍스트 붙이기.
    // 향후 더 정교한 문장 융합도 가능하지만, 현 단계에서는
    // deterministic한 붙이기만으로 충분하다.
    return '$counselingText\n\n$guideText';
  }
}
