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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:gad_app_team/navigation/app_navigator_key.dart';

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
  final String? locationAddress;
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
    this.locationAddress,
    this.locationRadiusMeters = 100,
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
    String? locationAddress,
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
      locationAddress: locationAddress ?? this.locationAddress,
      locationRadiusMeters: locationRadiusMeters ?? this.locationRadiusMeters,
      notifyOnEnter: notifyOnEnter ?? this.notifyOnEnter,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
    );
  }

  Map<String, dynamic> toJson() {
    final sortedDays =
        weekdays.toSet().where((d) => d >= 1 && d <= 7).toList()..sort();
    final payload = <String, dynamic>{
      'alarm_id': id,
      'label': label,
      'enabled': enabled,
      'vibration': vibration,
      'schedule': {
        'hour': hour,
        'minute': minute,
        'weekdays': sortedDays,
        'timezone': 'Asia/Seoul',
      },
    };

    if (locationEnabled && latitude != null && longitude != null) {
      payload['location'] = {
        'latitude': latitude,
        'longitude': longitude,
        if (locationLabel != null && locationLabel!.trim().isNotEmpty)
          'label': locationLabel!.trim(),
        if (locationAddress != null && locationAddress!.trim().isNotEmpty)
          'address': locationAddress!.trim(),
        'radius_meters': locationRadiusMeters,
        'notify_on_enter': notifyOnEnter,
        'notify_on_exit': notifyOnExit,
      };
    }

    return payload;
  }

  factory AlarmSetting.fromJson(Map<String, dynamic> json) {
    final scheduleRaw = json['schedule'];
    final schedule =
        scheduleRaw is Map
            ? scheduleRaw.map((k, v) => MapEntry(k.toString(), v))
            : const <String, dynamic>{};

    final rawWeekdays =
        (schedule['weekdays'] as List?) ??
        (json['weekdays'] as List?) ??
        const [];
    final parsedWeekdays =
        rawWeekdays
            .map((e) => e is int ? e : int.tryParse(e.toString()))
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet()
            .toList()
          ..sort();

    final locationRaw = json['location'];
    final location =
        locationRaw is Map
            ? locationRaw.map((k, v) => MapEntry(k.toString(), v))
            : const <String, dynamic>{};

    final hasLocationObject = locationRaw is Map;
    final latitude = _readDouble(location['latitude'] ?? json['latitude']);
    final longitude = _readDouble(location['longitude'] ?? json['longitude']);
    final locationEnabled =
        (hasLocationObject || json['location_enabled'] == true) &&
        latitude != null &&
        longitude != null;

    return AlarmSetting(
      id:
          json['alarm_id']?.toString() ??
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      hour: _readInt(
        schedule['hour'] ?? json['hour'],
        fallback: 9,
      ).clamp(0, 23),
      minute: _readInt(
        schedule['minute'] ?? json['minute'],
        fallback: 0,
      ).clamp(0, 59),
      label:
          (json['label']?.toString().trim().isNotEmpty ?? false)
              ? json['label'].toString().trim()
              : 'Mindrium 알림',
      enabled: json['enabled'] == true,
      weekdays:
          parsedWeekdays.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : parsedWeekdays,
      vibration: json['vibration'] != false,
      locationEnabled: locationEnabled,
      latitude: latitude,
      longitude: longitude,
      locationLabel:
          location['label']?.toString() ?? json['location_label']?.toString(),
      locationAddress:
          location['address']?.toString() ??
          json['location_address']?.toString(),
      locationRadiusMeters: _readInt(
        location['radius_meters'] ?? json['location_radius_meters'],
        fallback: 100,
      ).clamp(30, 1000),
      notifyOnEnter:
          hasLocationObject
              ? location['notify_on_enter'] != false
              : json['notify_on_enter'] != false,
      notifyOnExit:
          hasLocationObject
              ? location['notify_on_exit'] == true
              : json['notify_on_exit'] == true,
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

class _EducationReminderSlot {
  const _EducationReminderSlot({
    required this.weekday,
    required this.hour,
    required this.minute,
  });

  final int weekday;
  final int hour;
  final int minute;
}

class AlarmNotificationService {
  AlarmNotificationService._();

  static final AlarmNotificationService instance = AlarmNotificationService._();

  static const String storageKey = 'mindrium_alarm_settings_v1';
  static const String educationPreferenceKey =
      'settings_notifications_education_enabled';
  static const String _channelId = 'mindrium_alarm_channel';
  static const String _educationChannelId = 'mindrium_education_channel';
  static const List<_EducationReminderSlot> _educationReminderSlots = [
    _EducationReminderSlot(weekday: DateTime.tuesday, hour: 19, minute: 30),
    _EducationReminderSlot(weekday: DateTime.thursday, hour: 19, minute: 30),
    _EducationReminderSlot(weekday: DateTime.sunday, hour: 17, minute: 0),
  ];

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
  Map<String, dynamic>? _pendingTapPayload;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    _setBestEffortLocalLocation();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

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

    const educationChannel = AndroidNotificationChannel(
      _educationChannelId,
      'Mindrium Education',
      description: 'Mindrium의 주차별 교육 리마인드',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(educationChannel);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleNotificationTapPayload(
        launchDetails?.notificationResponse?.payload,
      );
    }

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
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void handlePendingNotificationTap() {
    final pending = _pendingTapPayload;
    if (pending == null) return;
    if (_tryHandleNotificationAction(pending)) {
      _pendingTapPayload = null;
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _handleNotificationTapPayload(response.payload);
  }

  void _handleNotificationTapPayload(String? payloadRaw) {
    final payload = _decodeNotificationPayload(payloadRaw);
    if (_tryHandleNotificationAction(payload)) {
      _pendingTapPayload = null;
    } else {
      _pendingTapPayload = payload;
    }
  }

  bool _tryHandleNotificationAction(Map<String, dynamic> payload) {
    final action = payload['action']?.toString() ?? 'start_apply';
    if (action == 'open_education') {
      return _tryNavigateToEducationHome();
    }
    if (action == 'start_apply' || action == 'apply') {
      return _tryNavigateToApplyFlow(payload);
    }
    return false;
  }

  Map<String, dynamic> _decodeNotificationPayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const {'action': 'start_apply'};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      // ignore
    }
    return const {'action': 'start_apply'};
  }

  bool _tryNavigateToApplyFlow(Map<String, dynamic> payload) {
    final context = appNavigatorKey.currentContext;
    final navigator = appNavigatorKey.currentState;
    if (context == null || navigator == null) {
      return false;
    }

    final flow = Provider.of<ApplyOrSolveFlow>(context, listen: false);
    flow.clear();
    flow.setOrigin('apply');
    flow.setDiaryRoute('notification');

    final args = <String, dynamic>{...flow.toArgs(), 'origin': 'apply'};
    final alarmId = payload['alarm_id']?.toString();
    if (alarmId != null && alarmId.isNotEmpty) {
      args['alarmId'] = alarmId;
    }

    navigator.pushNamed('/before_sud', arguments: args);
    return true;
  }

  bool _tryNavigateToEducationHome() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return false;
    navigator.pushNamedAndRemoveUntil('/home_edu', (route) => false);
    return true;
  }

  String _buildTapPayload(String alarmId) {
    return jsonEncode({'action': 'start_apply', 'alarm_id': alarmId});
  }

  String _buildEducationTapPayload() {
    return jsonEncode({'action': 'open_education'});
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
    final previousAlarms = await loadAlarms();
    final previousIds = previousAlarms.map((a) => a.id).toSet();
    final currentIds = alarms.map((a) => a.id).toSet();
    final removedIds = previousIds.difference(currentIds);

    final prefs = await SharedPreferences.getInstance();
    final encoded = alarms.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(storageKey, encoded);
    await syncAlarms(alarms, extraCancelIds: removedIds);
  }

  Future<void> syncFromStorage() async {
    final alarms = await loadAlarms();
    await syncAlarms(alarms);
  }

  Future<bool> isEducationReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(educationPreferenceKey) ?? true;
  }

  Future<void> setEducationReminderEnabled(
    bool enabled, {
    required int currentWeek,
    required int lastCompletedWeek,
    DateTime? lastCompletedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(educationPreferenceKey, enabled);

    if (!enabled) {
      await cancelEducationReminders();
      return;
    }

    await syncEducationReminders(
      currentWeek: currentWeek,
      lastCompletedWeek: lastCompletedWeek,
      lastCompletedAt: lastCompletedAt,
    );
  }

  Future<void> syncEducationReminders({
    required int currentWeek,
    required int lastCompletedWeek,
    DateTime? lastCompletedAt,
  }) async {
    await initialize();
    await _cancelEducationReminderSchedules();

    if (!await isEducationReminderEnabled()) {
      return;
    }

    if (!_shouldScheduleEducationReminders(
      currentWeek: currentWeek,
      lastCompletedWeek: lastCompletedWeek,
      lastCompletedAt: lastCompletedAt,
    )) {
      return;
    }

    for (final slot in _educationReminderSlots) {
      final scheduled = _nextInstanceForWeekday(
        weekday: slot.weekday,
        hour: slot.hour,
        minute: slot.minute,
      );

      await _plugin.zonedSchedule(
        _educationNotificationId(slot.weekday),
        '교육 알림',
        '이번 주 교육 프로그램을 이어가 볼까요?',
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _educationChannelId,
            'Mindrium Education',
            channelDescription: 'Mindrium의 주차별 교육 리마인드',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            enableVibration: true,
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
        payload: _buildEducationTapPayload(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelEducationReminders() async {
    await initialize();
    await _cancelEducationReminderSchedules();
  }

  Future<void> syncAlarms(
    List<AlarmSetting> alarms, {
    Iterable<String> extraCancelIds = const [],
  }) async {
    await initialize();

    final cancelIds = <String>{
      ...alarms.map((alarm) => alarm.id),
      ...extraCancelIds,
    };
    for (final alarmId in cancelIds) {
      await _cancelAlarmSchedules(alarmId);
    }
    for (final alarm in alarms.where((a) => a.enabled)) {
      final hasValidLocation =
          alarm.locationEnabled &&
          alarm.latitude != null &&
          alarm.longitude != null;

      // 위치 기반 알림은 지오펜스 콜백에서 시간 조건까지 함께 체크(AND)한다.
      if (hasValidLocation) continue;
      await _scheduleAlarm(alarm);
    }

    final locationEnabled =
        alarms
            .where(
              (a) =>
                  a.enabled &&
                  a.locationEnabled &&
                  a.latitude != null &&
                  a.longitude != null,
            )
            .toList();
    await _syncLocationGeofences(locationEnabled);
  }

  bool _shouldScheduleEducationReminders({
    required int currentWeek,
    required int lastCompletedWeek,
    DateTime? lastCompletedAt,
  }) {
    if (currentWeek < 1 || currentWeek > 8) return false;
    if (currentWeek <= lastCompletedWeek) return false;
    if (_isInCurrentKstWeek(lastCompletedAt)) return false;
    return true;
  }

  bool _isInCurrentKstWeek(DateTime? timestamp) {
    if (timestamp == null) return false;

    final targetUtc = timestamp.toUtc();
    final nowUtc = DateTime.now().toUtc();
    final nowKst = nowUtc.add(const Duration(hours: 9));
    final todayStartKstUtc = DateTime.utc(
      nowKst.year,
      nowKst.month,
      nowKst.day,
    ).subtract(const Duration(hours: 9));
    final weekStartUtc = todayStartKstUtc.subtract(
      Duration(days: nowKst.weekday - 1),
    );
    final weekEndUtc = weekStartUtc.add(const Duration(days: 7));

    return !targetUtc.isBefore(weekStartUtc) && targetUtc.isBefore(weekEndUtc);
  }

  Future<void> _scheduleAlarm(AlarmSetting alarm) async {
    final weekdays =
        alarm.weekdays.toSet().where((d) => d >= 1 && d <= 7).toList()..sort();

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
        payload: _buildTapPayload(alarm.id),
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

  Future<void> _cancelEducationReminderSchedules() async {
    for (final slot in _educationReminderSlots) {
      await _plugin.cancel(_educationNotificationId(slot.weekday));
    }
  }

  Future<void> _syncLocationGeofences(List<AlarmSetting> alarms) async {
    _locationAlarmMap
      ..clear()
      ..addEntries(alarms.map((a) => MapEntry(a.id, a)));

    if (!_geofenceListenerBound) {
      _geofenceService.addGeofenceStatusChangeListener(
        _onGeofenceStatusChanged,
      );
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

    final geofenceList =
        alarms
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

    // AND 조건: 위치 이벤트 + 설정한 요일/시간 윈도우를 동시에 만족해야 알림.
    if (!_isWithinScheduledWindow(alarm, DateTime.now())) {
      return;
    }

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
    final locationText =
        (alarm.locationLabel?.trim().isNotEmpty ?? false)
            ? alarm.locationLabel!.trim()
            : '설정한 위치';
    final body =
        isEnter ? '$locationText 근처에 도착했어요.' : '$locationText 영역을 벗어났어요.';

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
      payload: _buildTapPayload(alarm.id),
    );
  }

  void _onGeofenceError(dynamic error) {
    debugPrint('geofence stream error: $error');
  }

  bool _isWithinScheduledWindow(AlarmSetting alarm, DateTime now) {
    final weekdays =
        alarm.weekdays.toSet().where((d) => d >= 1 && d <= 7).toSet();
    if (!weekdays.contains(now.weekday)) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final alarmMinutes = alarm.hour * 60 + alarm.minute;
    final difference = (nowMinutes - alarmMinutes).abs();
    return difference <= 5; // ±5분 윈도우
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

  int _educationNotificationId(int weekday) => 7000000 + weekday;

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
