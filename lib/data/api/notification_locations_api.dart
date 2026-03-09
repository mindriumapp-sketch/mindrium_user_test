import 'package:dio/dio.dart';

import 'api_client.dart';

class NotificationLocationsApi {
  final ApiClient _client;
  NotificationLocationsApi(this._client);

  Future<List<Map<String, dynamic>>> listLocationLabels({
    int limit = 20,
  }) async {
    final res = await _client.dio.get(
      '/notification-locations/labels',
      queryParameters: {
        'limit': limit,
      },
    );
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
      message: 'Invalid /notification-locations/labels response',
    );
  }

  Future<Map<String, dynamic>> upsertLocationLabel({
    required String label,
    DateTime? clientTimestamp,
  }) async {
    final payload = <String, dynamic>{
      'label': label,
      'client_timestamp':
          (clientTimestamp ?? DateTime.now().toUtc()).toIso8601String(),
    };
    final res = await _client.dio.post(
      '/notification-locations/labels',
      data: payload,
    );
    final data = res.data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /notification-locations/labels create response',
    );
  }
}
