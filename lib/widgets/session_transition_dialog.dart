import 'package:flutter/material.dart';
import 'package:gad_app_team/data/education_week_contents.dart';
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
  required int weekNumber,
  required VoidCallback onMoveNow,
  VoidCallback? onFinish,
}) {
  final nav = Navigator.of(context);
  final week = educationWeekContents[weekNumber - 1];
  final cbtName = week['session1Name'] ?? '학습';
  final relaxName = week['session2Name'] ?? '이완';
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => CustomPopupDesign(
          title: '이완으로 마무리할까요?',
          message: '$cbtName을(를) 마쳤어요.\n$relaxName으로 마무리해볼까요?',
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

Future<void> showCbtReviewToRelaxationDialog({
  required BuildContext context,
  required int weekNumber,
  required VoidCallback onMoveNow,
  VoidCallback? onFinish,
}) {
  final nav = Navigator.of(context);
  final week = educationWeekContents[weekNumber - 1];
  final cbtName = week['session1Name'] ?? '학습';
  final relaxName = week['session2Name'] ?? '이완';
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => CustomPopupDesign(
          title: '이완도 복습하시겠어요?',
          message: '$cbtName 복습을 마쳤어요.\n이어서 $relaxName도 다시 해볼까요?',
          positiveText: '지금 이동',
          negativeText: '끝내기',
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
  required int weekNumber,
  required VoidCallback onMoveNow,
  VoidCallback? onFinish,
}) {
  final nav = Navigator.of(context);
  final week = educationWeekContents[weekNumber - 1];
  final cbtName = week['session1Name'] ?? '학습';
  final relaxName = week['session2Name'] ?? '이완';
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => CustomPopupDesign(
          title: '학습을 이어서 할까요?',
          message: '$relaxName을(를) 마쳤어요.\n$cbtName을(를) 이어서 진행할까요?',
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
