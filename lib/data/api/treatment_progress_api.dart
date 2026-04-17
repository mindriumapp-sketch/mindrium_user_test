import 'package:dio/dio.dart';

import 'api_client.dart';

class TreatmentProgressApi {
  final ApiClient _client;
  TreatmentProgressApi(this._client);

  Future<List<Map<String, dynamic>>> listTreatmentProgress({
    int? weekNumber,
  }) async {
    final res = await _client.dio.get(
      '/treatment-progress',
      queryParameters: {if (weekNumber != null) 'week_number': weekNumber},
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
      message: 'Invalid /treatment-progress response',
    );
  }

  Future<Map<String, dynamic>> getActiveTreatmentProgress() async {
    final res = await _client.dio.get('/treatment-progress/active');
    final data = res.data;

    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /treatment-progress/active response',
    );
  }

  Future<Map<String, dynamic>> getTreatmentProgress(int weekNumber) async {
    final res = await _client.dio.get('/treatment-progress/$weekNumber');
    final data = res.data;

    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /treatment-progress/{week_number} response',
    );
  }
}
