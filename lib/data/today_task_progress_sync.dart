import 'package:flutter/widgets.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/today_task_draft_progress.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:provider/provider.dart';

Future<int> syncTodayTaskDraftState(
  BuildContext context, {
  required int progress,
  DiariesApi? diariesApi,
  String? diaryId,
  bool allowLower = false,
  bool? diaryDone,
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

  context.read<TodayTaskProvider>().setTodayTaskLocally(
    diaryDone: diaryDone ?? TodayTaskDraftProgress.isCompleted(effective),
    diaryDraftProgress: effective,
  );
  return effective;
}
