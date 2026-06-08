import 'package:gad_app_team/data/storage/auth_session_storage.dart';
import 'package:gad_app_team/data/today_task_draft_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodayTaskLocalStateStore {
  static const String _nsPrefix = 'today_task.local_state';

  static Future<String> _prefix() async {
    final uid = (await AuthSessionStorage().userId)?.trim();
    if (uid == null || uid.isEmpty) {
      return '$_nsPrefix.default';
    }
    return '$_nsPrefix.$uid';
  }

  static Future<void> saveDiaryProgress({
    required String? dateKey,
    required int progress,
  }) async {
    if (dateKey == null || dateKey.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    await prefs.setString('$prefix.date', dateKey.trim());
    await prefs.setInt(
      '$prefix.diary_progress',
      TodayTaskDraftProgress.normalize(progress),
    );
  }

  static Future<int> readDiaryProgress({required String? dateKey}) async {
    if (dateKey == null || dateKey.trim().isEmpty) {
      return TodayTaskDraftProgress.none;
    }

    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    if (prefs.getString('$prefix.date') != dateKey.trim()) {
      return TodayTaskDraftProgress.none;
    }
    return TodayTaskDraftProgress.normalize(
      prefs.getInt('$prefix.diary_progress'),
    );
  }

  static Future<void> saveRelaxationDone({
    required String? dateKey,
    required bool done,
  }) async {
    if (dateKey == null || dateKey.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    await prefs.setString('$prefix.date', dateKey.trim());
    await prefs.setBool('$prefix.relaxation_done', done);
  }

  static Future<bool> readRelaxationDone({required String? dateKey}) async {
    if (dateKey == null || dateKey.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    if (prefs.getString('$prefix.date') != dateKey.trim()) return false;
    return prefs.getBool('$prefix.relaxation_done') ?? false;
  }
}
