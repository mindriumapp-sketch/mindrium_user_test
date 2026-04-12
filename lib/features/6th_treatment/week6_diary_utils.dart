import 'package:gad_app_team/utils/server_datetime.dart';

class Week6ChipEntry {
  final String label;
  final String? chipId;

  const Week6ChipEntry({required this.label, this.chipId});
}

class Week6DiaryUtils {
  const Week6DiaryUtils._();

  static String? resolveDiaryId(Map<String, dynamic> raw) {
    return (raw['diary_id'] ?? raw['diaryId'] ?? raw['id'])?.toString();
  }

  static DateTime? parseCreatedAt(dynamic raw) {
    return parseServerDateTime(raw);
  }

  static String chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ??
              raw['chip_label'] ??
              raw['chipId'] ??
              raw['chip_id'] ??
              '')
          .toString();
    }
    return raw.toString();
  }

  static List<String> chipList(dynamic raw) {
    if (raw is List) {
      return raw
          .map(chipLabel)
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();
    }

    final label = chipLabel(raw);
    return label
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String chipText(dynamic raw) {
    return chipList(raw).join(', ');
  }

  static List<Week6ChipEntry> chipEntries(dynamic raw) {
    final entries = <Week6ChipEntry>[];

    void addEntry(String label, String? chipId) {
      final trimmed = label.trim();
      if (trimmed.isEmpty) return;
      entries.add(Week6ChipEntry(label: trimmed, chipId: chipId));
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          addEntry(
            chipLabel(item),
            item['chip_id']?.toString() ?? item['chipId']?.toString(),
          );
        } else {
          addEntry(chipLabel(item), null);
        }
      }
      return entries;
    }

    if (raw is Map) {
      addEntry(
        chipLabel(raw),
        raw['chip_id']?.toString() ?? raw['chipId']?.toString(),
      );
      return entries;
    }

    for (final label in chipList(raw)) {
      addEntry(label, null);
    }
    return entries;
  }

  static String safeText(String text) {
    try {
      return String.fromCharCodes(text.runes);
    } catch (_) {
      return '';
    }
  }

  static dynamic _activationRaw(Map<String, dynamic> diary) {
    return diary['activation'] ??
        diary['activating_events'] ??
        diary['activatingEvent'];
  }

  static dynamic _behaviorRaw(Map<String, dynamic> diary) {
    return diary['consequence_action'] ??
        diary['consequence_behavior'] ??
        diary['consequence_b'];
  }

  static String extractActivation(Map<String, dynamic> diary) {
    return safeText(chipText(_activationRaw(diary)));
  }

  static String extractBelief(Map<String, dynamic> diary) {
    return safeText(chipText(diary['belief']));
  }

  static String extractPhysical(Map<String, dynamic> diary) {
    return safeText(
      chipText(diary['consequence_physical'] ?? diary['consequence_p']),
    );
  }

  static String extractEmotion(Map<String, dynamic> diary) {
    return safeText(
      chipText(diary['consequence_emotion'] ?? diary['consequence_e']),
    );
  }

  static String extractBehaviorText(Map<String, dynamic> diary) {
    return safeText(chipText(_behaviorRaw(diary)));
  }

  static List<String> extractBehaviorList(Map<String, dynamic> diary) {
    return chipList(_behaviorRaw(diary));
  }

  static List<Week6ChipEntry> extractBehaviorEntries(
    Map<String, dynamic> diary,
  ) {
    return chipEntries(_behaviorRaw(diary));
  }

  static String firstBehavior(
    Map<String, dynamic> diary, {
    List<String> fallback = const [],
  }) {
    final behaviors = extractBehaviorList(diary);
    if (behaviors.isNotEmpty) {
      return behaviors.first;
    }
    if (fallback.isNotEmpty) {
      return fallback.first;
    }
    return '';
  }
}
