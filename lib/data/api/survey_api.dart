import 'package:dio/dio.dart';

import 'api_client.dart';

class SurveyApi {
  final ApiClient _client;
  SurveyApi(this._client);

  /// 설문 제출: POST /users/me/surveys
  Future<Map<String, dynamic>> submitSurvey({
    required String type,
    Map<String, dynamic>? answers,
    String? description,
    DateTime? completedAt,
  }) async {
    final payload = <String, dynamic>{
      'type': type,
      if (description != null) 'description': description,
      if (answers != null) 'answers': answers,
      'completed_at':
      (completedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final res = await _client.dio.post('/users/me/surveys', data: payload);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /users/me/surveys response',
    );
  }

  /// 설문 전체 목록: GET /users/me/surveys
  Future<List<Map<String, dynamic>>> getSurveys() async {
    final res = await _client.dio.get('/users/me/surveys');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (raw) => raw.map(
              (key, value) => MapEntry(key.toString(), value),
        ),
      )
          .toList()
          .cast<Map<String, dynamic>>();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /users/me/surveys response',
    );
  }

  /// 최신 설문 1개: GET /users/me/surveys/latest
  Future<Map<String, dynamic>> getLatestSurvey() async {
    final res = await _client.dio.get('/users/me/surveys/latest');
    final data = res.data;

    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /users/me/surveys/latest response',
    );
  }
}
