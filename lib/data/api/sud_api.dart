import 'package:dio/dio.dart';

import 'api_client.dart';

class SudApi {
  final ApiClient _client;
  SudApi(this._client);

  Future<Map<String, dynamic>> createSudScore({
    required String diaryId,
    required int beforeScore,
    int? afterScore,
  }) async {
    final base = <String, dynamic>{
      'before_sud': beforeScore,
      if (afterScore != null) 'after_sud': afterScore,
    };

    final res = await _client.dio.post(
      '/sud-scores',
      queryParameters: {'diary_id': diaryId},
      data: base,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /sud-scores response',
    );
  }

  Future<List<Map<String, dynamic>>> listSudScores(String diaryId) async {
    final res = await _client.dio.get('/sud-scores/$diaryId');
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /sud-scores/{id} response',
    );
  }

  Future<Map<String, dynamic>> updateSudScore({
    required String diaryId,
    required String sudId,
    int? beforeScore,
    int? afterScore,
  }) async {
    final base = <String, dynamic>{
      if (beforeScore != null) 'before_sud': beforeScore,
      if (afterScore != null) 'after_sud': afterScore,
    };

    final res = await _client.dio.put(
      '/sud-scores/$diaryId/$sudId',
      data: base,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /sud-scores update response',
    );
  }

  Future<void> deleteSudScore({
    required String diaryId,
    required String sudId,
  }) async {
    final res = await _client.dio.delete('/sud-scores/$diaryId/$sudId');

    // 백엔드가 204 No Content 돌려줄 예정
    if (res.statusCode == 204 || res.statusCode == 200) {
      return;
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message:
          'Invalid /sud-scores delete response (status: ${res.statusCode})',
    );
  }
  // ---------------------------------------------------------------------------
  // (추후 사용용) SUD 주차별 / 일별 통계 API
  // 주석만 풀면 바로 사용 가능
  // ---------------------------------------------------------------------------

  /*
  /// 주차별 평균 SUD 통계 조회
  ///
  /// GET /sud-scores/stats/weekly
  ///
  /// 백엔드 쿼리 파라미터:
  /// - start: DateTime? (ISO8601, UTC)
  /// - end: DateTime? (ISO8601, UTC)
  /// - target_user_id: String? (없으면 전체)
  ///
  /// 응답 예시 (List):
  /// [
  ///   {
  ///     "weekStart": "2025-01-06T00:00:00Z",
  ///     "avgBefore": 5.3,
  ///     "avgAfter": 3.1,
  ///     "count": 12
  ///   },
  ///   ...
  /// ]
  Future<List<Map<String, dynamic>>> getWeeklySudStats({
    DateTime? start,
    DateTime? end,
    String? targetUserId,
  }) async {
    final query = <String, dynamic>{
      if (start != null) 'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end.toUtc().toIso8601String(),
      if (targetUserId != null) 'target_user_id': targetUserId,
    };

    final res = await _client.dio.get(
      '/sud-scores/stats/weekly',
      queryParameters: query,
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(
                raw.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /sud-scores/stats/weekly response',
    );
  }

  /// 특정 주차의 일자별 평균 SUD 통계 조회
  ///
  /// GET /sud-scores/stats/daily
  ///
  /// 백엔드 쿼리 파라미터:
  /// - week_start_date: "yyyy-MM-dd" (KST 기준 주 시작 날짜)
  /// - target_user_id: String? (옵션)
  ///
  /// 응답 예시 (List):
  /// [
  ///   {
  ///     "date": "2025-01-06T00:00:00Z",
  ///     "avgBefore": 5.0,
  ///     "avgAfter": 3.0,
  ///     "count": 4
  ///   },
  ///   ...
  /// ]
  Future<List<Map<String, dynamic>>> getDailySudStats({
    required DateTime weekStartDate,
    String? targetUserId,
  }) async {
    final query = <String, dynamic>{
      'week_start_date': _formatDate(weekStartDate),
      if (targetUserId != null) 'target_user_id': targetUserId,
    };

    final res = await _client.dio.get(
      '/sud-scores/stats/daily',
      queryParameters: query,
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(
                raw.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /sud-scores/stats/daily response',
    );
  }
  */
}
