import '../../data/api/alarm_settings_api.dart';
import 'alarm_notification_service.dart';

class AlarmSettingsSyncHelper {
  const AlarmSettingsSyncHelper._();

  static List<AlarmSetting> _parseRows(List<Map<String, dynamic>> rows) {
    return rows.map(AlarmSetting.fromJson).toList();
  }

  static Future<List<AlarmSetting>> fetchAndSync({
    required AlarmSettingsApi api,
    AlarmNotificationService? service,
  }) async {
    final rows = await api.listAlarmSettings();
    final alarms = _parseRows(rows);
    await (service ?? AlarmNotificationService.instance).saveAlarms(alarms);
    return alarms;
  }

  static Future<List<AlarmSetting>> replaceAndSync({
    required AlarmSettingsApi api,
    required List<AlarmSetting> alarms,
    AlarmNotificationService? service,
  }) async {
    final savedRows = await api.replaceAlarmSettings(
      alarms.map((alarm) => alarm.toJson()).toList(),
    );
    final savedAlarms = _parseRows(savedRows);
    await (service ?? AlarmNotificationService.instance).saveAlarms(savedAlarms);
    return savedAlarms;
  }

  static Future<List<AlarmSetting>> upsertAndSync({
    required AlarmSettingsApi api,
    required AlarmSetting alarm,
    AlarmNotificationService? service,
  }) async {
    final rows = await api.listAlarmSettings();
    final alarms = _parseRows(rows);

    final existingIndex = alarms.indexWhere((item) => item.id == alarm.id);
    if (existingIndex >= 0) {
      alarms[existingIndex] = alarm;
    } else {
      alarms.add(alarm);
    }

    return replaceAndSync(api: api, alarms: alarms, service: service);
  }
}
