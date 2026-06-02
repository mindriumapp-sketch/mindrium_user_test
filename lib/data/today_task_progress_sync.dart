import 'package:flutter/widgets.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/today_task_draft_progress.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:provider/provider.dart';

Future<int> syncTodayTaskDraftState(
  BuildContext context, {
  required int progress,
  DiariesApi? diariesApi,
  String? diaryId,
  bool allowLower = false,
  bool? diaryDone,
  bool syncHomeTodayTaskState = true,
}) async {
  final effective = await syncTodayTaskDraftProgress(
    context,
    progress: progress,
    diariesApi: diariesApi,
    diaryId: diaryId,
    allowLower: allowLower,
  );

  if (!context.mounted) {
    return effective;
  }

  final resolvedDiaryDone =
      diaryDone ?? TodayTaskDraftProgress.isCompleted(effective);
  final todayTaskProvider =
      syncHomeTodayTaskState ? context.read<TodayTaskProvider>() : null;
  if (resolvedDiaryDone) {
    await context.read<UserProvider>().refreshProgress();
  }

  if (todayTaskProvider != null) {
    todayTaskProvider.setTodayTaskLocally(
      diaryDone: resolvedDiaryDone,
      diaryDraftProgress: effective,
    );
  }
  return effective;
}
