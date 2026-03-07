import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geofence_service/geofence_service.dart'
    show
        GeofenceService,
        GeofenceRadiusSortType,
        Geofence,
        GeofenceRadius,
        GeofenceStatus,
        Location;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class AlarmSetting {
  final String id;
  final int hour;
  final int minute;
  final String label;
  final bool enabled;
  final List<int> weekdays; // 1(월) ~ 7(일)
  final bool vibration;
  final bool locationEnabled;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final int locationRadiusMeters;
  final bool notifyOnEnter;
  final bool notifyOnExit;

  const AlarmSetting({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    required this.enabled,
    required this.weekdays,
    required this.vibration,
    this.locationEnabled = false,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.locationRadiusMeters = 120,
    this.notifyOnEnter = true,
    this.notifyOnExit = false,
  });

  AlarmSetting copyWith({
    String? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    List<int>? weekdays,
    bool? vibration,
    bool? locationEnabled,
    double? latitude,
    double? longitude,
    String? locationLabel,
    int? locationRadiusMeters,
    bool? notifyOnEnter,
    bool? notifyOnExit,
  }) {
    return AlarmSetting(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      weekdays: weekdays ?? this.weekdays,
      vibration: vibration ?? this.vibration,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationLabel: locationLabel ?? this.locationLabel,
      locationRadiusMeters: locationRadiusMeters ?? this.locationRadiusMeters,
      notifyOnEnter: notifyOnEnter ?? this.notifyOnEnter,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
    );
  }

  Map<String, dynamic> toJson() {
    final sortedDays = weekdays.toSet().where((d) => d >= 1 && d <= 7).toList()
      ..sort();
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
      'enabled': enabled,
      'weekdays': sortedDays,
      'vibration': vibration,
      'location_enabled': locationEnabled,
      'latitude': latitude,
      'longitude': longitude,
      'location_label': locationLabel,
      'location_radius_meters': locationRadiusMeters,
      'notify_on_enter': notifyOnEnter,
      'notify_on_exit': notifyOnExit,
    };
  }

  factory AlarmSetting.fromJson(Map<String, dynamic> json) {
    final rawWeekdays = (json['weekdays'] as List?) ?? const [];
    final parsedWeekdays = rawWeekdays
        .map((e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
      ..sort();

    return AlarmSetting(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      hour: _readInt(json['hour'], fallback: 9).clamp(0, 23),
      minute: _readInt(json['minute'], fallback: 0).clamp(0, 59),
      label: (json['label']?.toString().trim().isNotEmpty ?? false)
          ? json['label'].toString().trim()
          : 'Mindrium 알림',
      enabled: json['enabled'] == true,
      weekdays: parsedWeekdays.isEmpty
          ? const [1, 2, 3, 4, 5, 6, 7]
          : parsedWeekdays,
      vibration: json['vibration'] != false,
      locationEnabled: json['location_enabled'] == true,
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      locationLabel: json['location_label']?.toString(),
      locationRadiusMeters:
          _readInt(json['location_radius_meters'], fallback: 120).clamp(30, 1000),
      notifyOnEnter: json['notify_on_enter'] != false,
      notifyOnExit: json['notify_on_exit'] == true,
    );
  }

  static int _readInt(dynamic raw, {required int fallback}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static double? _readDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }
}

class AlarmNotificationService {
  AlarmNotificationService._();

  static final AlarmNotificationService instance = AlarmNotificationService._();

  static const String storageKey = 'mindrium_alarm_settings_v1';
  static const String _channelId = 'mindrium_alarm_channel';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 15000,
    statusChangeDelayMs: 8000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: false,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
  );

  bool _initialized = false;
  bool _geofenceListenerBound = false;
  final Map<String, AlarmSetting> _locationAlarmMap = {};
  final Map<String, DateTime> _lastLocationNotifyAt = {};

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    _setBestEffortLocalLocation();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      _channelId,
      'Mindrium Alarm',
      description: 'Mindrium에서 설정한 일정 알림',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<bool> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<List<AlarmSetting>> loadAlarms() async {
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(storageKey) ?? const [];
    final alarms = <AlarmSetting>[];

    for (final raw in encoded) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        alarms.add(AlarmSetting.fromJson(decoded));
      } catch (_) {
        // 깨진 엔트리는 건너뜀
      }
    }

    alarms.sort(_compareAlarm);
    return alarms;
  }

  Future<void> saveAlarms(List<AlarmSetting> alarms) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final encoded = alarms.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(storageKey, encoded);
    await syncAlarms(alarms);
  }

  Future<void> syncFromStorage() async {
    final alarms = await loadAlarms();
    await syncAlarms(alarms);
  }

  Future<void> syncAlarms(List<AlarmSetting> alarms) async {
    await initialize();

    for (final alarm in alarms) {
      await _cancelAlarmSchedules(alarm.id);
    }
    for (final alarm in alarms.where((a) => a.enabled)) {
      await _scheduleAlarm(alarm);
    }

    final locationEnabled = alarms
        .where((a) => a.enabled && a.locationEnabled && a.latitude != null && a.longitude != null)
        .toList();
    await _syncLocationGeofences(locationEnabled);
  }

  Future<void> _scheduleAlarm(AlarmSetting alarm) async {
    final weekdays = alarm.weekdays.toSet().where((d) => d >= 1 && d <= 7).toList()
      ..sort();

    for (final weekday in weekdays) {
      final scheduled = _nextInstanceForWeekday(
        weekday: weekday,
        hour: alarm.hour,
        minute: alarm.minute,
      );

      await _plugin.zonedSchedule(
        _notificationId(alarm.id, weekday),
        alarm.label,
        '설정한 알림 시간입니다.',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Mindrium Alarm',
            channelDescription: 'Mindrium에서 설정한 일정 알림',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            enableVibration: alarm.vibration,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          macOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _cancelAlarmSchedules(String alarmId) async {
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_notificationId(alarmId, weekday));
    }
  }

  Future<void> _syncLocationGeofences(List<AlarmSetting> alarms) async {
    _locationAlarmMap
      ..clear()
      ..addEntries(alarms.map((a) => MapEntry(a.id, a)));

    if (!_geofenceListenerBound) {
      _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceService.addStreamErrorListener(_onGeofenceError);
      _geofenceListenerBound = true;
    }

    if (alarms.isEmpty) {
      try {
        if (_geofenceService.isRunningService) {
          await _geofenceService.stop();
        } else {
          _geofenceService.clearGeofenceList();
        }
      } catch (e) {
        debugPrint('geofence stop failed: $e');
      }
      return;
    }

    final geofenceList = alarms
        .map(
          (alarm) => Geofence(
            id: alarm.id,
            latitude: alarm.latitude!,
            longitude: alarm.longitude!,
            radius: [
              GeofenceRadius(
                id: 'r_${alarm.locationRadiusMeters}',
                length: alarm.locationRadiusMeters.toDouble(),
              ),
            ],
          ),
        )
        .toList();

    try {
      if (_geofenceService.isRunningService) {
        _geofenceService.clearGeofenceList();
        _geofenceService.addGeofenceList(geofenceList);
      } else {
        await _geofenceService.start(geofenceList);
      }
    } catch (e) {
      debugPrint('geofence start failed: $e');
    }
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    final alarm = _locationAlarmMap[geofence.id];
    if (alarm == null || !alarm.enabled) return;

    final isEnter = geofenceStatus == GeofenceStatus.ENTER;
    final isExit = geofenceStatus == GeofenceStatus.EXIT;
    if ((isEnter && !alarm.notifyOnEnter) || (isExit && !alarm.notifyOnExit)) {
      return;
    }
    if (!isEnter && !isExit) return;

    final eventKey = '${alarm.id}_${geofenceStatus.name}';
    final now = DateTime.now();
    final last = _lastLocationNotifyAt[eventKey];
    if (last != null && now.difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _lastLocationNotifyAt[eventKey] = now;

    final title = alarm.label;
    final locationText = (alarm.locationLabel?.trim().isNotEmpty ?? false)
        ? alarm.locationLabel!.trim()
        : '설정한 위치';
    final body = isEnter
        ? '$locationText 근처에 도착했어요.'
        : '$locationText 영역을 벗어났어요.';

    await _plugin.show(
      _instantNotificationId(alarm.id, geofenceStatus),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Mindrium Alarm',
          channelDescription: 'Mindrium에서 설정한 일정 알림',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          enableVibration: alarm.vibration,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void _onGeofenceError(dynamic error) {
    debugPrint('geofence stream error: $error');
  }

  tz.TZDateTime _nextInstanceForWeekday({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  void _setBestEffortLocalLocation() {
    final timezoneName = DateTime.now().timeZoneName;

    final candidates = <String>[
      _abbrToLocation[timezoneName] ?? '',
      ..._offsetToLocation(DateTime.now().timeZoneOffset),
      'Asia/Seoul',
      'Etc/UTC',
    ].where((e) => e.isNotEmpty);

    for (final locationName in candidates) {
      try {
        tz.setLocalLocation(tz.getLocation(locationName));
        return;
      } catch (_) {
        // 다음 후보로 진행
      }
    }
  }

  int _notificationId(String alarmId, int weekday) {
    int hash = 17;
    for (final code in alarmId.codeUnits) {
      hash = (hash * 37 + code) & 0x3fffffff;
    }
    final normalized = hash % 100000000; // 플랫폼 int 범위 안전하게 유지
    return normalized * 10 + weekday;
  }

  int _instantNotificationId(String alarmId, GeofenceStatus status) {
    int hash = 17;
    for (final code in alarmId.codeUnits) {
      hash = (hash * 31 + code) & 0x3fffffff;
    }
    final suffix = status == GeofenceStatus.ENTER ? 1 : 2;
    final timestamp = DateTime.now().millisecondsSinceEpoch % 1000;
    return (hash % 1000000) * 1000 + suffix * 100 + timestamp;
  }

  static int _compareAlarm(AlarmSetting a, AlarmSetting b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    if (aMinutes != bMinutes) return aMinutes.compareTo(bMinutes);
    return a.id.compareTo(b.id);
  }

  static const Map<String, String> _abbrToLocation = {
    'KST': 'Asia/Seoul',
    'JST': 'Asia/Tokyo',
    'EST': 'America/New_York',
    'EDT': 'America/New_York',
    'CST': 'America/Chicago',
    'CDT': 'America/Chicago',
    'MST': 'America/Denver',
    'MDT': 'America/Denver',
    'PST': 'America/Los_Angeles',
    'PDT': 'America/Los_Angeles',
    'UTC': 'Etc/UTC',
    'GMT': 'Etc/UTC',
  };

  static List<String> _offsetToLocation(Duration offset) {
    final hours = offset.inHours;
    if (hours == 9) return const ['Asia/Seoul', 'Asia/Tokyo'];
    if (hours == -4 || hours == -5) return const ['America/New_York'];
    if (hours == -6) return const ['America/Chicago'];
    if (hours == -7) return const ['America/Denver'];
    if (hours == -8) return const ['America/Los_Angeles'];
    if (hours == 0) return const ['Etc/UTC'];
    return const ['Etc/UTC'];
  }
}
