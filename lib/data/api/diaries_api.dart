import 'package:dio/dio.dart';

import 'api_client.dart';

class DiariesApi {
  final ApiClient _client;
  DiariesApi(this._client);

  /// 공통: body에 client_timestamp 붙이는 헬퍼
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
    required Map<String, dynamic> activation,            // DiaryChip 구조
    List<Map<String, dynamic>> belief = const [],        // List<DiaryChip>
    List<Map<String, dynamic>> consequenceP = const [],  // List<DiaryChip>
    List<Map<String, dynamic>> consequenceE = const [],  // List<DiaryChip>
    List<Map<String, dynamic>> consequenceB = const [],  // List<DiaryChip>
    List<String> alternativeThoughts = const [],
    Map<String, dynamic>? locTime,
    @Deprecated('Use locTime instead.')
    List<Map<String, dynamic>> alarms = const [],
    double? latitude,
    double? longitude,
    String? addressName,
    DateTime? clientTimestamp,
  }) async {
    final base = <String, dynamic>{
      if (groupId != null) 'group_id': groupId,
      'activation': activation,
      'belief': belief,
      'consequence_physical': consequenceP,
      'consequence_emotion': consequenceE,
      'consequence_action': consequenceB,
      'alternative_thoughts': alternativeThoughts,
      'loc_time': locTime ?? (alarms.isNotEmpty ? alarms.last : null),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (addressName != null) 'address_name': addressName,
    };

    final payload = _withClientTimestamp(
      base,
      clientTimestamp: clientTimestamp,
    );

    final res = await _client.dio.post('/diaries', data: payload);
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
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
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
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
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
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/latest response',
    );
  }

  /// updateDiary는 body를 그대로 넘기되, client_timestamp만 자동으로 붙여줌.
  /// body는 백엔드 DiaryUpdate(schema)에 맞는 형태여야 함.
  Future<Map<String, dynamic>> updateDiary(
      String diaryId,
      Map<String, dynamic> body, {
        DateTime? clientTimestamp,
      }) async {
    final payload = _withClientTimestamp(
      body,
      clientTimestamp: clientTimestamp,
    );

    final res = await _client.dio.put('/diaries/$diaryId', data: payload);
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
      final mapped = data
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
      Map<String, dynamic> body, {
        DateTime? clientTimestamp,
      }) async {
    final payload = _withClientTimestamp(
      body,
      clientTimestamp: clientTimestamp,
    );

    final res = await _client.dio.put('/diaries/$diaryId/loc_time', data: payload);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /diaries/{id}/loc_time upsert response',
    );
  }

  Future<void> deleteLocTime(
      String diaryId, {
        DateTime? clientTimestamp,
      }) async {
    final payload = _withClientTimestamp(
      <String, dynamic>{},
      clientTimestamp: clientTimestamp,
    );

    await _client.dio.delete(
      '/diaries/$diaryId/loc_time',
      data: payload,
    );
  }

  // ---- Backward compatibility wrappers ----
  Future<List<Map<String, dynamic>>> listLocTime(String diaryId) async {
    final single = await getLocTime(diaryId);
    if (single == null) return const [];
    return [single];
  }

  Future<Map<String, dynamic>> createLocTime(
    String diaryId,
    Map<String, dynamic> body, {
    DateTime? clientTimestamp,
  }) => upsertLocTime(
    diaryId,
    body,
    clientTimestamp: clientTimestamp,
  );

  Future<Map<String, dynamic>> updateLocTime(
    String diaryId,
    String locTimeId,
    Map<String, dynamic> body, {
    DateTime? clientTimestamp,
  }) => upsertLocTime(
    diaryId,
    body,
    clientTimestamp: clientTimestamp,
  );

  Future<void> deleteAllLocTime(
    String diaryId, {
    DateTime? clientTimestamp,
  }) => deleteLocTime(diaryId, clientTimestamp: clientTimestamp);

  Future<List<Map<String, dynamic>>> listAlarms(String diaryId) =>
      listLocTime(diaryId);

  Future<Map<String, dynamic>> createAlarm(
    String diaryId,
    Map<String, dynamic> body, {
    DateTime? clientTimestamp,
  }) => createLocTime(diaryId, body, clientTimestamp: clientTimestamp);

  Future<Map<String, dynamic>> updateAlarm(
    String diaryId,
    String alarmId,
    Map<String, dynamic> body, {
    DateTime? clientTimestamp,
  }) => updateLocTime(
    diaryId,
    alarmId,
    body,
    clientTimestamp: clientTimestamp,
  );

  Future<void> deleteAlarm(
    String diaryId,
    String alarmId, {
    DateTime? clientTimestamp,
  }) => deleteLocTime(diaryId, clientTimestamp: clientTimestamp);

  Future<void> deleteAllAlarms(
    String diaryId, {
    DateTime? clientTimestamp,
  }) => deleteLocTime(diaryId, clientTimestamp: clientTimestamp);
}
