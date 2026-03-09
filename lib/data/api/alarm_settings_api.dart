import 'package:dio/dio.dart';

import 'api_client.dart';

class AlarmSettingsApi {
  final ApiClient _client;
  AlarmSettingsApi(this._client);

  Map<String, dynamic> _withClientTimestamp(
    Map<String, dynamic> body, {
    DateTime? clientTimestamp,
  }) {
    return {
      ...body,
      'client_timestamp':
          (clientTimestamp ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> listAlarmSettings() async {
    final res = await _client.dio.get('/alarm-settings');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
          .cast<Map<String, dynamic>>();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /alarm-settings response',
    );
  }

  Future<List<Map<String, dynamic>>> replaceAlarmSettings(
    List<Map<String, dynamic>> alarms, {
    DateTime? clientTimestamp,
  }) async {
    final payload = _withClientTimestamp(
      {'notifications': alarms},
      clientTimestamp: clientTimestamp,
    );

    final res = await _client.dio.put('/alarm-settings', data: payload);
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
          .cast<Map<String, dynamic>>();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /alarm-settings replace response',
    );
  }
}
