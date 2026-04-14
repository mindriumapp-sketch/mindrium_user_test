import 'package:dio/dio.dart';

import 'api_client.dart';

class DiariesApi {
  final ApiClient _client;
  DiariesApi(this._client);

  /// DiaryChip JSON 헬퍼
  /// label 은 필수, chipId / category 는 선택
  Map<String, dynamic> makeDiaryChip({
    required String label,
    String? chipId,
    String? category, // "anxious" / "healthy" or null
  }) {
    return {
      'label': label,
      if (chipId != null) 'chip_id': chipId,
      if (category != null) 'category': category,
    };
  }

  Future<Map<String, dynamic>> createDiary({
    Object? groupId, // int든 String이든 허용
    required Map<String, dynamic> activation, // DiaryChip 구조
    int? draftProgress,
    List<Map<String, dynamic>> belief = const [], // List<DiaryChip>
    List<Map<String, dynamic>> consequenceP = const [], // List<DiaryChip>
    List<Map<String, dynamic>> consequenceE = const [], // List<DiaryChip>
    List<Map<String, dynamic>> consequenceB = const [], // List<DiaryChip>
    List<String> alternativeThoughts = const [],
    Map<String, dynamic>? locTime,
    String? route,
    bool locAutoFilled = false,
  }) async {
    final base = <String, dynamic>{
      if (groupId != null) 'group_id': groupId,
      'activation': activation,
      if (draftProgress != null) 'draft_progress': draftProgress,
      'belief': belief,
      'consequence_physical': consequenceP,
      'consequence_emotion': consequenceE,
      'consequence_action': consequenceB,
      'alternative_thoughts': alternativeThoughts,
      'loc_time': locTime,
      if (route != null) 'route': route,
      'loc_auto_filled': locAutoFilled,
    };

    final res = await _client.dio.post('/diaries', data: base);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries response',
    );
  }

  Future<List<Map<String, dynamic>>> listDiaries({Object? groupId}) async {
    final res = await _client.dio.get(
      '/diaries',
      queryParameters: {if (groupId != null) 'group_id': groupId},
    );
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries list response',
    );
  }

  /// 요약 리스트 (/diaries/summaries)
  Future<List<Map<String, dynamic>>> listDiarySummaries({
    Object? groupId,
  }) async {
    final res = await _client.dio.get(
      '/diaries/summaries',
      queryParameters: {if (groupId != null) 'group_id': groupId},
    );
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/summaries response',
    );
  }

  Future<Map<String, dynamic>> getDiary(String diaryId) async {
    final res = await _client.dio.get('/diaries/$diaryId');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/{id} response',
    );
  }

  Future<Map<String, dynamic>> getLatestDiary({Object? groupId}) async {
    final res = await _client.dio.get(
      '/diaries/latest',
      queryParameters: {if (groupId != null) 'group_id': groupId},
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/latest response',
    );
  }

  Future<Map<String, dynamic>?> getLatestTodayTaskDraft() async {
    try {
      final res = await _client.dio.get('/diaries/today-task/latest-draft');
      final data = res.data;
      if (data == null) return null;
      if (data is Map<String, dynamic>) return data;
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Invalid /diaries/today-task/latest-draft response',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> deleteTodayTaskDraft(String diaryId) async {
    await _client.dio.delete('/diaries/$diaryId/draft');
  }

  /// body는 백엔드 DiaryUpdate(schema)에 맞는 형태여야 함.
  Future<Map<String, dynamic>> updateDiary(
    String diaryId,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.dio.put('/diaries/$diaryId', data: body);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/{id} update response',
    );
  }

  Future<Map<String, dynamic>?> getLocTime(String diaryId) async {
    final res = await _client.dio.get('/diaries/$diaryId/loc_time');
    final data = res.data;
    if (data == null) return null;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    if (data is List) {
      final mapped =
          data
              .whereType<Map>()
              .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
      return mapped.isEmpty ? null : mapped.last.cast<String, dynamic>();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/{id}/loc_time response',
    );
  }

  Future<Map<String, dynamic>> upsertLocTime(
    String diaryId,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.dio.put('/diaries/$diaryId/loc_time', data: body);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/{id}/loc_time upsert response',
    );
  }

  Future<void> deleteLocTime(String diaryId) async {
    await _client.dio.delete('/diaries/$diaryId/loc_time');
  }

  // ---- Backward compatibility wrappers ----
  Future<List<Map<String, dynamic>>> listLocTime(String diaryId) async {
    final single = await getLocTime(diaryId);
    if (single == null) return const [];
    return [single];
  }

  Future<Map<String, dynamic>> createLocTime(
    String diaryId,
    Map<String, dynamic> body,
  ) => upsertLocTime(diaryId, body);

  Future<Map<String, dynamic>> updateLocTime(
    String diaryId,
    String locTimeId,
    Map<String, dynamic> body,
  ) => upsertLocTime(diaryId, body);

  Future<void> deleteAllLocTime(String diaryId) => deleteLocTime(diaryId);
}
