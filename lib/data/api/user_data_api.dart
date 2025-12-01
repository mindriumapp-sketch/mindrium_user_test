import 'package:dio/dio.dart';

import 'api_client.dart';
import 'custom_tags_api.dart';

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

  // ----- Custom Tags (delegates to CustomTagsApi) -----
  CustomTagsApi get _customTags => CustomTagsApi(_client);

  Future<List<Map<String, dynamic>>> getCustomTags({
    String? chipType,
    bool includeDeleted = false,
  }) {
    return _customTags.listCustomTags(
      chipType: chipType,
      includeDeleted: includeDeleted,
    );
  }

  Future<Map<String, dynamic>> createCustomTag({
    required String text,
    required String type,
    bool isPreset = false,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final chipId = 'chip_$now';
    return _customTags.createCustomTag(
      chipId: chipId,
      label: text,
      type: type,
      isPreset: isPreset,
    );
  }
}
