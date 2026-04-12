import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/server_datetime.dart';

enum RepeatOption { none, daily, weekly }

class LocTimeSetting {
  final RepeatOption repeatOption;
  final List<int> weekdays;
  final TimeOfDay? time;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? reminderMinutes;
  final String? description;
  final String? id;
  final String? diaryId;
  final DateTime savedAt;
  final String? cause;
  final bool notifyEnter;
  final bool notifyExit;

  LocTimeSetting({
    this.cause,
    this.time,
    this.repeatOption = RepeatOption.none,
    this.weekdays = const [],
    this.location,
    this.latitude,
    this.longitude,
    this.description,
    this.reminderMinutes,
    this.id,
    this.diaryId,
    DateTime? savedAt,
    required this.notifyEnter,
    required this.notifyExit,
  }) : savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toJson({bool includeSavedAt = true}) {
    final map = <String, dynamic>{
      'description': description,
      'cause': cause,
      'notify_enter': notifyEnter,
      'notify_exit': notifyExit,
    };

    if (diaryId != null) {
      map['diary_id'] = diaryId;
    }

    if (includeSavedAt) {
      map['saved_at'] = savedAt.toIso8601String();
    }

    if (time != null) {
      final hh = time!.hour.toString().padLeft(2, '0');
      final mm = time!.minute.toString().padLeft(2, '0');
      final repForKey =
          (repeatOption == RepeatOption.none)
              ? RepeatOption.daily
              : repeatOption;
      final normalizedWeekdays =
          (repForKey == RepeatOption.weekly && weekdays.isNotEmpty)
              ? (weekdays.toSet().toList()..sort())
              : <int>[];
      final wdCsv = normalizedWeekdays.join(',');

      map['time'] = '$hh:$mm';
      map['repeat_option'] = repeatOption.name;
      if (normalizedWeekdays.isNotEmpty) {
        map['weekdays'] = normalizedWeekdays;
      }
      map['time_key'] = 't=$hh:$mm|rep=${repForKey.name}|wd=$wdCsv';
    }

    if (latitude != null && longitude != null) {
      map['latitude'] = latitude;
      map['longitude'] = longitude;
    }

    if (location != null && location!.isNotEmpty) {
      map['location'] = location;
    }

    if (description != null && description!.isNotEmpty) {
      map['location_desc'] = description;
    }

    if (description == null || description!.isEmpty) {
      map.remove('description');
    }

    map.removeWhere((key, value) => value == null);
    return map;
  }

  Map<String, dynamic> toMap({bool includeSavedAt = true}) =>
      toJson(includeSavedAt: includeSavedAt);

  factory LocTimeSetting.fromJson(Map<String, dynamic> json, {String? id}) {
    final repeatName = json['repeat_option'] ?? json['repeatOption'];
    final savedAtRaw = json['saved_at'] ?? json['savedAt'];

    return LocTimeSetting(
      id:
          id ??
          json['id']?.toString() ??
          json['_id']?.toString() ??
          json['settingId']?.toString(),
      diaryId: json['diary_id']?.toString(),
      time: _timeOfDayFrom(json['time']),
      repeatOption: _repeatOptionFrom(repeatName),
      weekdays: _weekdaysFrom(json['weekdays']),
      latitude: _doubleFrom(json['latitude']),
      longitude: _doubleFrom(json['longitude']),
      location:
          json['location']?.toString() ?? json['location_label']?.toString(),
      cause: json['cause']?.toString(),
      description:
          json['location_desc']?.toString() ??
          json['description']?.toString() ??
          json['location']?.toString(),
      // reminderMinutes: _intFrom(json['reminder_minutes'] ?? json['reminderMinutes']),
      savedAt: _dateFrom(savedAtRaw),
      notifyEnter: _boolFrom(json['notify_enter'] ?? json['notifyEnter']),
      notifyExit: _boolFrom(json['notify_exit'] ?? json['notifyExit']),
    );
  }
}

TimeOfDay? _timeOfDayFrom(dynamic raw) {
  if (raw == null) return null;
  if (raw is TimeOfDay) return raw;
  final text = raw.toString();
  if (!text.contains(':')) return null;
  final parts = text.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return TimeOfDay(hour: hour, minute: minute);
}

RepeatOption _repeatOptionFrom(dynamic raw) {
  if (raw == null) return RepeatOption.none;
  final text = raw.toString();
  return RepeatOption.values.firstWhere(
    (e) => e.name == text,
    orElse: () => RepeatOption.none,
  );
}

List<int> _weekdaysFrom(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()) ?? 0)
        .where((e) => e > 0)
        .toSet()
        .toList()
      ..sort();
  }
  return const [];
}

double? _doubleFrom(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

// int? _intFrom(dynamic raw) {
//   if (raw is num) return raw.toInt();
//   if (raw is String) return int.tryParse(raw);
//   return null;
// }

DateTime? _dateFrom(dynamic raw) {
  if (raw is DateTime || raw is String) return parseServerDateTime(raw);
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
  return null;
}

bool _boolFrom(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final lower = raw.toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }
  return false;
}

extension LocTimeSettingCopyExt on LocTimeSetting {
  LocTimeSetting copyWith({
    String? id,
    String? diaryId,
    TimeOfDay? time,
    RepeatOption? repeatOption,
    List<int>? weekdays,
    double? latitude,
    double? longitude,
    String? location,
    int? reminderMinutes,
    String? description,
    String? cause,
    DateTime? savedAt,
    bool? notifyEnter,
    bool? notifyExit,
  }) {
    return LocTimeSetting(
      id: id ?? this.id,
      diaryId: diaryId ?? this.diaryId,
      time: time ?? this.time,
      repeatOption: repeatOption ?? this.repeatOption,
      weekdays: weekdays ?? this.weekdays,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      description: description ?? this.description,
      cause: cause ?? this.cause,
      savedAt: savedAt ?? this.savedAt,
      notifyEnter: notifyEnter ?? this.notifyEnter,
      notifyExit: notifyExit ?? this.notifyExit,
    );
  }
}
