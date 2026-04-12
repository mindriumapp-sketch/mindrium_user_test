import 'package:gad_app_team/utils/server_datetime.dart';

class ScreenTimeSummary {
  final double totalMinutes;
  final double todayMinutes;
  final double weekMinutes;
  final int sessions;
  final DateTime? lastEntryAt;

  const ScreenTimeSummary({
    required this.totalMinutes,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.sessions,
    required this.lastEntryAt,
  });

  factory ScreenTimeSummary.fromJson(Map<String, dynamic> json) {
    return ScreenTimeSummary(
      totalMinutes: (json['totalMinutes'] as num?)?.toDouble() ?? 0,
      todayMinutes: (json['todayMinutes'] as num?)?.toDouble() ?? 0,
      weekMinutes: (json['weekMinutes'] as num?)?.toDouble() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      lastEntryAt: _parseDate(json['lastEntryAt']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    return parseServerDateTime(raw);
  }
}

class ScreenTimeEntry {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final DateTime createdAt;
  final String? platform;

  const ScreenTimeEntry({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.createdAt,
    this.platform,
  });

  factory ScreenTimeEntry.fromJson(Map<String, dynamic> json) {
    return ScreenTimeEntry(
      id: json['screen_id']?.toString() ?? '',
      startTime:
          parseServerDateTime(json['start_time'], fallback: DateTime.now()) ??
          DateTime.now(),
      endTime:
          parseServerDateTime(json['end_time'], fallback: DateTime.now()) ??
          DateTime.now(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      platform: json['platform'] as String?,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    return parseServerDateTime(raw);
  }
}
