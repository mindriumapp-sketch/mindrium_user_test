import 'package:dio/dio.dart';

import 'api_client.dart';

class UserDataApi {
  final ApiClient _client;
  UserDataApi(this._client);

  /// 핵심 가치 조회: GET /users/me/value-goal
  Future<Map<String, dynamic>?> getValueGoal() async {
    final res = await _client.dio.get('/users/me/value-goal');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /users/me/value-goal response',
    );
  }

  /// 핵심 가치 업데이트: PUT /users/me/value-goal
  Future<Map<String, dynamic>> updateValueGoal(String valueGoal) async {
    final res = await _client.dio.put(
      '/users/me/value-goal',
      data: {'value_goal': valueGoal},
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /users/me/value-goal (PUT) response',
    );
  }

  /// 사용자 진행도 조회: GET /users/me/progress
  Future<Map<String, dynamic>> getProgress() async {
    final res = await _client.dio.get('/users/me/progress');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /users/me/progress response',
    );
  }
}
