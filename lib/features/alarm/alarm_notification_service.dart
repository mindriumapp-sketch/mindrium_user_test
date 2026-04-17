import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geofence_service/geofence_service.dart'
    show
        GeofenceService,
        GeofenceRadiusSortType,
        Geofence,
        GeofenceRadius,
        Location;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final String? location;
  final String? locationAddress;
  final int locationRadiusMeters;

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
    this.location,
    this.locationAddress,
    this.locationRadiusMeters = 100,
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
    String? location,
    String? locationAddress,
    int? locationRadiusMeters,
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
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      locationRadiusMeters: locationRadiusMeters ?? this.locationRadiusMeters,
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
        if (location != null && location!.trim().isNotEmpty)
          'location': location!.trim(),
        if (locationAddress != null && locationAddress!.trim().isNotEmpty)
          'address': locationAddress!.trim(),
        'radius_meters': locationRadiusMeters,
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
    final legacyLocationValue =
        locationRaw is String ? locationRaw.toString() : null;
    final locationEnabled =
        (hasLocationObject ||
            _readBool(json['location_enabled'], fallback: false)) &&
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
      enabled: _readBool(json['enabled'], fallback: false),
      weekdays:
          parsedWeekdays.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : parsedWeekdays,
      vibration: _readBool(json['vibration'], fallback: true),
      locationEnabled: locationEnabled,
      latitude: latitude,
      longitude: longitude,
      location:
          location['location']?.toString() ??
          location['label']?.toString() ??
          legacyLocationValue ??
          ((json['location'] is String)
              ? json['location']?.toString()
              : null) ??
          json['location_label']?.toString(),
      locationAddress:
          location['address']?.toString() ??
          json['location_address']?.toString(),
      locationRadiusMeters: _readInt(
        location['radius_meters'] ?? json['location_radius_meters'],
        fallback: 100,
      ).clamp(30, 1000),
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

  static bool _readBool(dynamic raw, {required bool fallback}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;

    final normalized = raw?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;

    if (const {'true', '1', 'yes', 'y', 'on'}.contains(normalized)) {
      return true;
    }
    if (const {'false', '0', 'no', 'n', 'off'}.contains(normalized)) {
      return false;
    }

    return fallback;
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
  static const String todayTaskReminderPreferenceKey =
      'settings_notifications_today_task_enabled';
  static const String _channelId = 'mindrium_alarm_channel';
  static const String _educationChannelId = 'mindrium_education_channel';
  static const String _todayTaskChannelId = 'mindrium_today_task_channel';
  static const String _todayTaskLastActiveDateKeyPrefix =
      'today_task_last_active_date_v1';
  static const DarwinInitializationSettings _darwinInitializationSettings =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );
  static const DarwinNotificationDetails _darwinNotificationDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      );
  static const DarwinNotificationDetails _darwinTimeSensitiveDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
  static const DarwinNotificationDetails _darwinMacNotificationDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
  static const MethodChannel _notificationLaunchChannel = MethodChannel(
    'mindrium/notification_launch',
  );
  static const EventChannel _notificationLaunchEventChannel = EventChannel(
    'mindrium/notification_launch_events',
  );
  static const int _todayTaskReminderHour = 19;
  static const int _todayTaskReminderMinute = 30;
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
  bool _locationListenerBound = false;
  bool? _canScheduleExactAlarms;
  StreamSubscription<dynamic>? _notificationLaunchSubscription;
  final Map<String, AlarmSetting> _locationAlarmMap = {};
  final Map<String, String> _lastLocationNotificationSlotByAlarm = {};
  Map<String, dynamic>? _pendingTapPayload;
  String? _lastHandledPayloadRaw;
  DateTime? _lastHandledPayloadAt;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    _setBestEffortLocalLocation();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: _darwinInitializationSettings,
      macOS: _darwinInitializationSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    await _initializeNativeNotificationLaunchBridge();

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

    const todayTaskChannel = AndroidNotificationChannel(
      _todayTaskChannelId,
      'Mindrium Today Task',
      description: '오늘의 할 일을 오래 비웠을 때 보내는 리마인더',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(todayTaskChannel);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handleNotificationTapPayload(
        launchDetails?.notificationResponse?.payload,
      );
    }

    _initialized = true;
  }

  Future<void> requestPermissions({bool requestExactAlarms = false}) async {
    await initialize();

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.requestNotificationsPermission();

    _canScheduleExactAlarms = await _queryCanScheduleExactAlarms(
      androidPlugin: androidPlugin,
    );
    if (requestExactAlarms && _canScheduleExactAlarms == false) {
      final requestResult = await androidPlugin?.requestExactAlarmsPermission();
      if (requestResult != null) {
        _canScheduleExactAlarms = requestResult;
      }
      _canScheduleExactAlarms = await _queryCanScheduleExactAlarms(
        androidPlugin: androidPlugin,
      );
      if (_canScheduleExactAlarms == false) {
        debugPrint(
          'exact alarm permission unavailable; falling back to inexact scheduling.',
        );
      }
    }

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

    if (kDebugMode) {
      try {
        final notificationStatus = await Permission.notification.status;
        debugPrint(
          '[requestPermissions] notificationStatus=$notificationStatus',
        );
      } catch (e) {
        debugPrint('[requestPermissions] notification status check failed: $e');
      }
    }
  }

  Future<bool> canScheduleExactAlarms({bool refresh = false}) async {
    await initialize();

    if (!refresh && _canScheduleExactAlarms != null) {
      return _canScheduleExactAlarms!;
    }

    _canScheduleExactAlarms = await _queryCanScheduleExactAlarms();
    return _canScheduleExactAlarms!;
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
    if (_isDuplicateNotificationPayload(payloadRaw)) {
      if (kDebugMode) {
        debugPrint('[notificationTap] duplicate payload ignored: $payloadRaw');
      }
      return;
    }

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
    if (action == 'open_home' || action == 'open_today_task') {
      return _tryNavigateHome();
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

  Future<void> _initializeNativeNotificationLaunchBridge() async {
    _notificationLaunchSubscription ??= _notificationLaunchEventChannel
        .receiveBroadcastStream()
        .listen(
          (dynamic event) {
            final payload = event?.toString();
            if (kDebugMode) {
              debugPrint('[notificationTap][nativeEvent] payload=$payload');
            }
            _handleNotificationTapPayload(payload);
          },
          onError: (Object error) {
            if (kDebugMode) {
              debugPrint('[notificationTap][nativeEvent] stream error: $error');
            }
          },
        );

    try {
      final payload = await _notificationLaunchChannel.invokeMethod<String>(
        'getInitialNotificationPayload',
      );
      if (payload != null && payload.trim().isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[notificationTap][nativeInitial] payload=$payload');
        }
        _handleNotificationTapPayload(payload);
      }
    } on MissingPluginException {
      // Android and older iOS builds won't provide this fallback channel.
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[notificationTap][nativeInitial] failed: ${e.code} ${e.message}',
        );
      }
    }
  }

  bool _isDuplicateNotificationPayload(String? payloadRaw) {
    final normalized = payloadRaw?.trim();
    final now = DateTime.now();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    final isDuplicate =
        _lastHandledPayloadRaw == normalized &&
        _lastHandledPayloadAt != null &&
        now.difference(_lastHandledPayloadAt!) < const Duration(seconds: 2);

    _lastHandledPayloadRaw = normalized;
    _lastHandledPayloadAt = now;
    return isDuplicate;
  }

  bool _tryNavigateToApplyFlow(Map<String, dynamic> payload) {
    final context = appNavigatorKey.currentContext;
    final navigator = appNavigatorKey.currentState;
    if (context == null || navigator == null) {
      if (kDebugMode) {
        debugPrint('[notificationTap] navigator not ready yet');
      }
      return false;
    }

    if (!_isReadyForNotificationNavigation(navigator)) {
      if (kDebugMode) {
        debugPrint(
          '[notificationTap] route not ready yet: route=${currentAppRouteName()} canPop=${navigator.canPop()}',
        );
      }
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

    if (kDebugMode) {
      debugPrint(
        '[notificationTap] navigating to /before_sud route=${currentAppRouteName()} args=$args',
      );
    }
    navigator.pushNamed('/before_sud', arguments: args);
    return true;
  }

  bool _isReadyForNotificationNavigation(NavigatorState navigator) {
    return isReadyForExternalNavigation(navigator);
  }

  bool _tryNavigateToEducationHome() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return false;
    navigator.pushNamedAndRemoveUntil('/home_edu', (route) => false);
    return true;
  }

  bool _tryNavigateHome() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return false;
    navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    return true;
  }

  String _buildTapPayload(String alarmId) {
    return jsonEncode({'action': 'start_apply', 'alarm_id': alarmId});
  }

  String _buildEducationTapPayload() {
    return jsonEncode({'action': 'open_education'});
  }

  String _buildTodayTaskTapPayload() {
    return jsonEncode({'action': 'open_home'});
  }

  Future<bool> requestLocationPermission({bool requireAlways = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.always) {
      return true;
    }

    final alwaysStatus = await Permission.locationAlways.status;
    if (alwaysStatus.isGranted) {
      return true;
    }

    final requestedAlwaysStatus = await Permission.locationAlways.request();
    if (requestedAlwaysStatus.isGranted) {
      return true;
    }

    if (requireAlways) {
      return false;
    }

    return permission == LocationPermission.whileInUse;
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

  Future<bool> isTodayTaskReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(todayTaskReminderPreferenceKey) ?? true;
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

  Future<void> setTodayTaskReminderEnabled(
    bool enabled, {
    required DateTime? todayDate,
    required bool diaryDone,
    required bool relaxationDone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(todayTaskReminderPreferenceKey, enabled);

    if (!enabled) {
      await cancelTodayTaskInactivityReminder();
      return;
    }

    await syncTodayTaskInactivityReminder(
      todayDate: todayDate,
      diaryDone: diaryDone,
      relaxationDone: relaxationDone,
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
          iOS: _darwinNotificationDetails,
          macOS: _darwinMacNotificationDetails,
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

  Future<void> syncTodayTaskInactivityReminder({
    required DateTime? todayDate,
    required bool diaryDone,
    required bool relaxationDone,
  }) async {
    await initialize();
    await _cancelTodayTaskInactivitySchedule();

    if (!await isTodayTaskReminderEnabled()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storageKey = _todayTaskLastActiveDateKey(prefs);
    final referenceDate = _normalizeKstDate(todayDate ?? _currentKstDate());
    final performedToday = diaryDone || relaxationDone;

    final storedLastActive = _decodeStoredDate(prefs.getString(storageKey));
    final lastActiveDate =
        performedToday ? referenceDate : (storedLastActive ?? referenceDate);

    await prefs.setString(storageKey, _encodeStoredDate(lastActiveDate));

    final scheduled = _nextTodayTaskReminderInstance(
      lastActiveDate: lastActiveDate,
    );

    await _plugin.zonedSchedule(
      _todayTaskNotificationId,
      '오늘의 할 일 리마인더',
      '오늘의 할 일을 2일 넘게 쉬고 있어요. 가볍게 다시 시작해볼까요?',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _todayTaskChannelId,
          'Mindrium Today Task',
          channelDescription: '오늘의 할 일을 오래 비웠을 때 보내는 리마인더',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          enableVibration: true,
          playSound: true,
        ),
        iOS: _darwinNotificationDetails,
        macOS: _darwinMacNotificationDetails,
      ),
      payload: _buildTodayTaskTapPayload(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelTodayTaskInactivityReminder() async {
    await initialize();
    await _cancelTodayTaskInactivitySchedule();
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

    await _logPendingNotificationState(
      source: 'syncAlarms',
      totalAlarms: alarms.length,
      enabledAlarms: alarms.where((alarm) => alarm.enabled).length,
      locationAlarms: locationEnabled.length,
    );
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
    final preferredScheduleMode = await _resolveTimeAlarmScheduleMode();

    for (final weekday in weekdays) {
      final scheduled = _nextInstanceForWeekday(
        weekday: weekday,
        hour: alarm.hour,
        minute: alarm.minute,
      );

      try {
        await _scheduleWeeklyAlarmOccurrence(
          alarm: alarm,
          weekday: weekday,
          scheduled: scheduled,
          scheduleMode: preferredScheduleMode,
        );
      } catch (e) {
        if (preferredScheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
          debugPrint(
            'exact alarm schedule failed for ${alarm.id} on weekday $weekday; retrying inexact: $e',
          );
          _canScheduleExactAlarms = false;
          try {
            await _scheduleWeeklyAlarmOccurrence(
              alarm: alarm,
              weekday: weekday,
              scheduled: scheduled,
              scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          } catch (fallbackError) {
            debugPrint(
              'inexact alarm schedule failed for ${alarm.id} on weekday $weekday: $fallbackError',
            );
          }
          continue;
        }

        debugPrint(
          'alarm schedule failed for ${alarm.id} on weekday $weekday: $e',
        );
      }
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

  Future<void> _cancelTodayTaskInactivitySchedule() async {
    await _plugin.cancel(_todayTaskNotificationId);
  }

  Future<void> _syncLocationGeofences(List<AlarmSetting> alarms) async {
    _locationAlarmMap
      ..clear()
      ..addEntries(alarms.map((a) => MapEntry(a.id, a)));
    _lastLocationNotificationSlotByAlarm.removeWhere(
      (alarmId, _) => !_locationAlarmMap.containsKey(alarmId),
    );

    if (!_locationListenerBound) {
      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addStreamErrorListener(_onGeofenceError);
      _locationListenerBound = true;
    }

    if (alarms.isEmpty) {
      try {
        if (_geofenceService.isRunningService) {
          await _geofenceService.stop();
        } else {
          _geofenceService.clearGeofenceList();
        }
        _lastLocationNotificationSlotByAlarm.clear();
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

  void _onLocationChanged(Location location) {
    unawaited(_notifyForLocationPresence(location));
  }

  Future<void> _notifyForLocationPresence(Location location) async {
    final now = DateTime.now();

    for (final alarm in _locationAlarmMap.values) {
      if (!alarm.enabled) continue;
      if (!_isWithinScheduledWindow(alarm, now)) continue;
      if (!_isWithinLocationRadius(alarm, location)) continue;

      final slotKey = _locationNotificationSlotKey(alarm, now);
      if (_lastLocationNotificationSlotByAlarm[alarm.id] == slotKey) {
        continue;
      }
      _lastLocationNotificationSlotByAlarm[alarm.id] = slotKey;

      final locationText =
          (alarm.location?.trim().isNotEmpty ?? false)
              ? alarm.location!.trim()
              : '설정한 위치';

      await _plugin.show(
        _instantNotificationId(alarm.id),
        alarm.label,
        '$locationText에 계시네요. 지금 시작해볼까요?',
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
          iOS: _darwinNotificationDetails,
          macOS: _darwinMacNotificationDetails,
        ),
        payload: _buildTapPayload(alarm.id),
      );
    }
  }

  void _onGeofenceError(dynamic error) {
    debugPrint('geofence stream error: $error');
  }

  Future<bool> _queryCanScheduleExactAlarms({
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  }) async {
    final plugin =
        androidPlugin ??
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final canSchedule = await plugin?.canScheduleExactNotifications();
    return canSchedule ?? true;
  }

  Future<AndroidScheduleMode> _resolveTimeAlarmScheduleMode() async {
    final canUseExact = await canScheduleExactAlarms();
    return canUseExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _scheduleWeeklyAlarmOccurrence({
    required AlarmSetting alarm,
    required int weekday,
    required tz.TZDateTime scheduled,
    required AndroidScheduleMode scheduleMode,
  }) async {
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
        iOS: _darwinTimeSensitiveDetails,
        macOS: _darwinMacNotificationDetails,
      ),
      payload: _buildTapPayload(alarm.id),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    if (kDebugMode) {
      debugPrint(
        '[scheduleAlarm] id=${alarm.id} label=${alarm.label} weekday=$weekday scheduled=$scheduled tz=${tz.local.name}',
      );
    }
  }

  Future<void> _logPendingNotificationState({
    required String source,
    required int totalAlarms,
    required int enabledAlarms,
    required int locationAlarms,
  }) async {
    if (!kDebugMode) return;

    try {
      final pending = await _plugin.pendingNotificationRequests();
      final canExact = await canScheduleExactAlarms();
      debugPrint(
        '[$source] total=$totalAlarms enabled=$enabledAlarms pending=${pending.length} location=$locationAlarms exact=$canExact',
      );
    } catch (e) {
      debugPrint('[$source] pending notification introspection failed: $e');
    }
  }

  bool _isWithinScheduledWindow(AlarmSetting alarm, DateTime now) {
    final weekdays =
        alarm.weekdays.toSet().where((d) => d >= 1 && d <= 7).toSet();
    if (!weekdays.contains(now.weekday)) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final alarmMinutes = alarm.hour * 60 + alarm.minute;
    return nowMinutes == alarmMinutes;
  }

  bool _isWithinLocationRadius(AlarmSetting alarm, Location location) {
    final latitude = alarm.latitude;
    final longitude = alarm.longitude;
    if (latitude == null || longitude == null) return false;

    final distance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      latitude,
      longitude,
    );
    return distance <= alarm.locationRadiusMeters;
  }

  String _locationNotificationSlotKey(AlarmSetting alarm, DateTime now) {
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = alarm.hour.toString().padLeft(2, '0');
    final minute = alarm.minute.toString().padLeft(2, '0');
    return '$year-$month-$day-$hour:$minute';
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

  tz.TZDateTime _nextTodayTaskReminderInstance({
    required DateTime lastActiveDate,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    final thresholdDate = _normalizeKstDate(
      lastActiveDate.add(const Duration(days: 3)),
    );
    var scheduled = tz.TZDateTime(
      tz.local,
      thresholdDate.year,
      thresholdDate.month,
      thresholdDate.day,
      _todayTaskReminderHour,
      _todayTaskReminderMinute,
    );

    if (scheduled.isAfter(now)) {
      return scheduled;
    }

    scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _todayTaskReminderHour,
      _todayTaskReminderMinute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  DateTime _currentKstDate() {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(nowKst.year, nowKst.month, nowKst.day);
  }

  DateTime _normalizeKstDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _todayTaskLastActiveDateKey(SharedPreferences prefs) {
    final uid = prefs.getString('uid')?.trim();
    if (uid == null || uid.isEmpty) {
      return _todayTaskLastActiveDateKeyPrefix;
    }
    return '${_todayTaskLastActiveDateKeyPrefix}_$uid';
  }

  String _encodeStoredDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _decodeStoredDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
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

  int _instantNotificationId(String alarmId) {
    int hash = 17;
    for (final code in alarmId.codeUnits) {
      hash = (hash * 31 + code) & 0x3fffffff;
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch % 1000;
    return (hash % 1000000) * 1000 + timestamp;
  }

  int _educationNotificationId(int weekday) => 7000000 + weekday;
  static const int _todayTaskNotificationId = 7100001;

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
