import 'package:flutter/material.dart';
import 'package:gad_app_team/features/menu/education/education_page.dart';
import 'package:gad_app_team/features/menu/relaxation/relaxation_education.dart';
import 'package:gad_app_team/features/session_start.dart';

const Map<int, String> kRelaxationWeekDescriptions = {
  1: '점진적 이완으로 몸의 긴장을 천천히 풀어보겠습니다.',
  2: '점진적 이완을 복습하며 이완 감각을 안정적으로 익혀보겠습니다.',
  3: '긴장 유도 없이 이완만 하는 연습을 해보겠습니다.',
  4: '신호를 통해 이완 전환하는 법을 익혀보겠습니다.',
  5: '차등 이완으로 움직임 속에서도 이완을 유지해보겠습니다.',
  6: '차등 이완을 복습하며 일상 속 이완을 연습해보겠습니다.',
  7: '신속 이완으로 짧은 시간 안에 몸과 호흡을 안정시켜보겠습니다.',
  8: '신속 이완을 복습하며 전체 이완 루틴을 정리해보겠습니다.',
};

String relaxationDescriptionForWeek(int weekNumber) {
  return kRelaxationWeekDescriptions[weekNumber] ?? '이번 주차 이완 훈련을 시작해요.';
}

bool _isRelaxationReviewTask(String taskId) {
  return taskId == 'daily_review' || taskId.endsWith('_review');
}

String _relaxationStartTitle({
  required int weekNumber,
  required String taskId,
  required bool isReviewMode,
}) {
  final baseTitle = relaxationTitleForWeek(weekNumber);
  // baseTitle에서 ' - '를 기준으로 나누고 마지막 요소를 가져옵니다.
  final contentTitle = baseTitle.split(' - ').last;

  if (isReviewMode) {
    return '$contentTitle을 복습해보겠습니다.';
  }
  return '$contentTitle을 배워보겠습니다.';
}

String _relaxationStartDescription({
  required int weekNumber,
  required String taskId,
  required bool isReviewMode,
}) {
  if (!isReviewMode) {
    return relaxationDescriptionForWeek(weekNumber);
  }

  switch (weekNumber) {
    case 1:
      return '1주차에서는 점진적 이완으로 몸의 긴장을 천천히 푸는 연습을 했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 2:
      return '2주차에서는 점진적 이완을 반복하며 이완 감각을 안정적으로 익히는 연습을 했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 3:
      return '3주차에서는 긴장 유도 없이 이완만 하는 연습을 했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 4:
      return '4주차에서는 신호를 통해 이완 전환하는 법을 익혔어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 5:
      return '5주차에서는 차등 이완으로 움직임 속에서도 이완을 유지하는 연습을 했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 6:
      return '6주차에서는 차등 이완을 반복하며 일상 속 이완을 연습했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 7:
      return '7주차에서는 신속 이완으로 짧은 시간 안에 몸과 호흡을 안정시키는 연습을 했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    case 8:
      return '8주차에서는 신속 이완을 반복하며 전체 이완 루틴을 정리했어요.\n이번에는 그 내용을 복습해보겠습니다.';
    default:
      return '이전에 진행한 이완 훈련을 복습해보겠습니다.';
  }
}

class RelaxationStartScreen extends StatelessWidget {
  final String? sessionId;
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;
  final bool? isReviewMode;

  const RelaxationStartScreen({
    super.key,
    this.sessionId,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
    this.isReviewMode,
  });

  @override
  Widget build(BuildContext context) {
    final useEducationBridge = weekNumber == 1 || weekNumber == 2;
    final jsonPrefix = 'week${weekNumber}_relaxation_';
    final resolvedIsReviewMode =
        isReviewMode ?? _isRelaxationReviewTask(taskId);

    return SessionStartScreen(
      weekNumber: weekNumber,
      isReviewMode: resolvedIsReviewMode,
      weekTitle: _relaxationStartTitle(
        weekNumber: weekNumber,
        taskId: taskId,
        isReviewMode: resolvedIsReviewMode,
      ),
      weekDescription: _relaxationStartDescription(
        weekNumber: weekNumber,
        taskId: taskId,
        isReviewMode: resolvedIsReviewMode,
      ),
      onPrevious: () {
        Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
      },
      nextPageBuilder:
          () =>
              useEducationBridge
                  ? _RelaxationEducationBridge(
                    sessionId: sessionId,
                    taskId: taskId,
                    weekNumber: weekNumber,
                    mp3Asset: mp3Asset,
                    riveAsset: riveAsset,
                    jsonPrefix: jsonPrefix,
                  )
                  : PracticePlayer(
                    sessionId: sessionId,
                    taskId: taskId,
                    weekNumber: weekNumber,
                    mp3Asset: mp3Asset,
                    riveAsset: riveAsset,
                  ),
    );
  }
}

class _RelaxationEducationBridge extends StatelessWidget {
  final String? sessionId;
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;
  final String jsonPrefix;

  const _RelaxationEducationBridge({
    required this.sessionId,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
    required this.jsonPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return EducationPage(
      title: '점진적 이완',
      jsonPrefixes: [jsonPrefix],
      isRelax: true,
      sessionId: sessionId,
      nextPageBuilder:
          () => PracticePlayer(
            sessionId: sessionId,
            taskId: taskId,
            weekNumber: weekNumber,
            mp3Asset: mp3Asset,
            riveAsset: riveAsset,
          ),
    );
  }
}
