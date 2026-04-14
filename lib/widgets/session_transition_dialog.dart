import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';

const Duration kSessionTransitionAutoAdvance = Duration(seconds: 10);

bool shouldShowCbtToRelaxationTransition({
  required int currentWeek,
  required bool mainRelaxCompleted,
  required int weekNumber,
}) {
  return weekNumber == currentWeek && !mainRelaxCompleted;
}

bool shouldShowRelaxationToCbtTransition({
  required int currentWeek,
  required bool mainCbtCompleted,
  required int weekNumber,
  required String taskId,
}) {
  return taskId == 'week${weekNumber}_education' &&
      weekNumber == currentWeek &&
      !mainCbtCompleted;
}

Future<void> showCbtToRelaxationDialog({
  required BuildContext context,
  required VoidCallback onMoveNow,
  VoidCallback? onFinish,
}) {
  final nav = Navigator.of(context);
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => CustomPopupDesign(
          title: '이완으로 마무리할까요?',
          message: '학습을 마쳤어요.\n이완 연습으로 마무리해볼까요?',
          positiveText: '지금 이동',
          negativeText: '끝내기',
          autoPositiveAfter: kSessionTransitionAutoAdvance,
          backgroundAsset: null,
          iconAsset: null,
          onPositivePressed: onMoveNow,
          onNegativePressed:
              onFinish ??
              () {
                nav.pop();
                nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
              },
        ),
  );
}

Future<void> showRelaxationToCbtDialog({
  required BuildContext context,
  required VoidCallback onMoveNow,
  VoidCallback? onFinish,
}) {
  final nav = Navigator.of(context);
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => CustomPopupDesign(
          title: 'CBT를 이어서 할까요?',
          message: '이완을 마쳤어요.\nCBT 세션을 이어서 진행할까요?',
          positiveText: '지금 이동',
          negativeText: '끝내기',
          autoPositiveAfter: kSessionTransitionAutoAdvance,
          backgroundAsset: null,
          iconAsset: null,
          onPositivePressed: onMoveNow,
          onNegativePressed:
              onFinish ??
              () {
                nav.pop();
                nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
              },
        ),
  );
}
