import 'package:flutter/widgets.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:gad_app_team/widgets/abc_chips_design.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String todayTaskDiaryRoute = 'today_task';
const String todayTaskHomeDiaryArgKey = 'isHomeTodayDiary';
const String todayTaskAutoNavigateAbcArgKey = 'autoNavigateToTodayTaskAbc';

class TodayTaskDraftProgress {
  static const int none = 0;
  static const int anxietyEvaluated = 20;
  static const int diaryWritten = 40;
  static const int locTimeRecorded = 60;
  static const int groupCompleted = 80;

  static const Map<int, int> _normalizedValues = {
    none: none,
    anxietyEvaluated: anxietyEvaluated,
    diaryWritten: diaryWritten,
    locTimeRecorded: locTimeRecorded,
    groupCompleted: groupCompleted,
    25: anxietyEvaluated,
    50: diaryWritten,
    75: locTimeRecorded,
    100: groupCompleted,
  };

  static int normalize(dynamic raw, {int fallback = none}) {
    int? value;
    if (raw is int) {
      value = raw;
    } else if (raw is num) {
      value = raw.toInt();
    } else if (raw is String) {
      value = int.tryParse(raw.trim());
    }

    if (value == null) {
      return fallback;
    }
    return _normalizedValues[value] ?? fallback;
  }

  static bool isCompleted(dynamic raw) {
    return normalize(raw) >= groupCompleted;
  }
}

void prepareTodayTaskDiaryFlow(ApplyOrSolveFlow flow) {
  flow.clear();
  flow.setOrigin('daily');
  flow.setDiaryRoute(todayTaskDiaryRoute);
}

Map<String, dynamic> buildTodayTaskDiaryArgs(
  ApplyOrSolveFlow flow, {
  String? diaryId,
  int? beforeSud,
  String? sudId,
  bool autoNavigateToAbc = false,
}) {
  return {
    ...flow.toArgs(),
    'origin': 'daily',
    if (diaryId != null && diaryId.isNotEmpty) 'abcId': diaryId,
    if (beforeSud != null) 'beforeSud': beforeSud,
    if (sudId != null && sudId.isNotEmpty) 'sudId': sudId,
    todayTaskHomeDiaryArgKey: true,
    if (autoNavigateToAbc) todayTaskAutoNavigateAbcArgKey: true,
  };
}

class TodayTaskDraftSnapshot {
  const TodayTaskDraftSnapshot({
    required this.diaryId,
    required this.progress,
    required this.beforeSud,
    required this.sudId,
    required this.activatingChips,
    required this.beliefChips,
    required this.physicalChips,
    required this.emotionChips,
    required this.behaviorChips,
  });

  final String? diaryId;
  final int progress;
  final int? beforeSud;
  final String? sudId;
  final List<AbcChip> activatingChips;
  final List<AbcChip> beliefChips;
  final List<AbcChip> physicalChips;
  final List<AbcChip> emotionChips;
  final List<AbcChip> behaviorChips;

  factory TodayTaskDraftSnapshot.fromMap(Map<String, dynamic> raw) {
    final rawDiaryId = raw['diary_id']?.toString().trim();
    return TodayTaskDraftSnapshot(
      diaryId: (rawDiaryId == null || rawDiaryId.isEmpty) ? null : rawDiaryId,
      progress: TodayTaskDraftProgress.normalize(raw['draft_progress']),
      beforeSud: _draftBeforeSud(raw['sud_scores']),
      sudId: _draftSudId(raw['sud_scores']),
      activatingChips: [
        if (_activationChip(raw['activation']) case final activation?)
          activation,
      ],
      beliefChips: _chipList(raw['belief'], 'B'),
      physicalChips: _chipList(raw['consequence_physical'], 'CP'),
      emotionChips: _chipList(raw['consequence_emotion'], 'CE'),
      behaviorChips: _chipList(raw['consequence_action'], 'CA'),
    );
  }

  String get stageDescription {
    switch (progress) {
      case TodayTaskDraftProgress.locTimeRecorded:
        return '위치/시간 기록까지 저장되어 있어요.';
      case TodayTaskDraftProgress.diaryWritten:
        return 'ABC 일기 작성까지 저장되어 있어요.';
      case TodayTaskDraftProgress.anxietyEvaluated:
        return '불안 평가까지 저장되어 있어요.';
      default:
        return '작성 중인 오늘의 일기가 있어요.';
    }
  }

  static int? _draftBeforeSud(dynamic rawScores) {
    if (rawScores is! List || rawScores.isEmpty) return null;
    final latest = rawScores.last;
    if (latest is! Map) return null;

    final raw = latest['before_sud'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static String? _draftSudId(dynamic rawScores) {
    if (rawScores is! List || rawScores.isEmpty) return null;
    final latest = rawScores.last;
    if (latest is! Map) return null;

    final sudId = latest['sud_id']?.toString().trim();
    if (sudId == null || sudId.isEmpty) return null;
    return sudId;
  }

  static AbcChip? _activationChip(dynamic rawActivation) {
    if (rawActivation is! Map) return null;

    final label = rawActivation['label']?.toString().trim() ?? '';
    if (label.isEmpty) return null;

    final chipId = rawActivation['chip_id']?.toString().trim();
    return AbcChip(
      chipId: (chipId != null && chipId.isNotEmpty) ? chipId : 'draft_A_$label',
      label: label,
      type: 'A',
    );
  }

  static List<AbcChip> _chipList(dynamic rawList, String type) {
    if (rawList is! List) return const [];

    return rawList
        .whereType<Map>()
        .map((entry) {
          final label = entry['label']?.toString().trim() ?? '';
          final rawChipId = entry['chip_id']?.toString().trim();
          return AbcChip(
            chipId:
                (rawChipId != null && rawChipId.isNotEmpty)
                    ? rawChipId
                    : 'draft_${type}_$label',
            label: label,
            type: type,
          );
        })
        .where((chip) => chip.label.isNotEmpty)
        .toList();
  }
}

class TodayTaskDraftProgressStore {
  static const String _nsPrefix = 'today_task.diary_draft';

  static Future<String> _prefix() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid')?.trim();
    if (uid == null || uid.isEmpty) {
      return '$_nsPrefix.default';
    }
    return '$_nsPrefix.$uid';
  }

  static Future<void> save({required int progress, String? diaryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    final normalized = TodayTaskDraftProgress.normalize(progress);

    await prefs.setInt('$prefix.progress', normalized);

    final trimmedDiaryId = diaryId?.trim();
    if (trimmedDiaryId != null && trimmedDiaryId.isNotEmpty) {
      await prefs.setString('$prefix.diary_id', trimmedDiaryId);
    } else {
      await prefs.remove('$prefix.diary_id');
    }
  }

  static Future<int> readProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    return TodayTaskDraftProgress.normalize(prefs.getInt('$prefix.progress'));
  }

  static Future<String?> readDiaryId() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    final diaryId = prefs.getString('$prefix.diary_id')?.trim();
    if (diaryId == null || diaryId.isEmpty) return null;
    return diaryId;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _prefix();
    await prefs.remove('$prefix.progress');
    await prefs.remove('$prefix.diary_id');
  }
}

Future<int> syncTodayTaskDraftProgress(
  BuildContext context, {
  required int progress,
  DiariesApi? diariesApi,
  String? diaryId,
  bool allowLower = false,
}) async {
  final flow = context.read<ApplyOrSolveFlow>();
  final normalized = TodayTaskDraftProgress.normalize(progress);
  final current = TodayTaskDraftProgress.normalize(flow.draftProgress);
  final effective = allowLower || normalized >= current ? normalized : current;

  final trimmedDiaryId = diaryId?.trim();
  if (trimmedDiaryId != null && trimmedDiaryId.isNotEmpty) {
    flow.setDiaryId(trimmedDiaryId);
  }
  flow.setDraftProgress(effective);

  final resolvedDiaryId =
      trimmedDiaryId != null && trimmedDiaryId.isNotEmpty
          ? trimmedDiaryId
          : flow.diaryId;

  await TodayTaskDraftProgressStore.save(
    progress: effective,
    diaryId: resolvedDiaryId,
  );

  if (diariesApi != null &&
      flow.diaryRoute?.trim() == todayTaskDiaryRoute &&
      resolvedDiaryId != null &&
      resolvedDiaryId.isNotEmpty) {
    try {
      await diariesApi.updateDiary(resolvedDiaryId, {
        'draft_progress': effective,
      });
    } catch (e) {
      debugPrint('today_task draft_progress 동기화 실패: $e');
    }
  }

  return effective;
}
