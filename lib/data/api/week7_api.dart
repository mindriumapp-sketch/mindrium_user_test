import 'package:dio/dio.dart';

import 'api_client.dart';

class Week7Api {
  final ApiClient _client;
  Week7Api(this._client);

  String _encodeDateTime(DateTime dt) => dt.toUtc().toIso8601String();

  /// 7주차 세션 생성
  ///
  /// - week_number는 항상 7로 고정
  /// - diaryId는 2,3,4,5,6주차에서만 주로 쓰지만, 스키마상 Optional이라 그대로 허용
  /// - behaviorItems 구조 예:
  ///   [
  ///     {
  ///       "chip_id": "sleep_early",
  ///       "category": "confront", // or "avoid"
  ///       "reason": "수면 리듬을 되돌리고 싶어서",
  ///       "analysis": {
  ///         "execution_short_gain": "당장은 피곤하지만 성취감 있음",
  ///         "execution_long_gain": true,
  ///         "non_execution_gain": "늦게까지 놀 수 있음",
  ///         "non_execution_short_loss": "다음날 더 피곤함",
  ///         "non_execution_long_loss": true,
  ///       }
  ///     },
  ///   ]
  Future<Map<String, dynamic>> createWeek7Session({
    String? diaryId,
    required int totalScreens,
    required int lastScreenIndex,
    required DateTime startTime,
    bool completed = false,
    DateTime? endTime,
    List<Map<String, dynamic>>? behaviorItems,
  }) async {
    final payload = <String, dynamic>{
      'week_number': 7,
      'total_screens': totalScreens,
      'last_screen_idx': lastScreenIndex,
      'start_time': _encodeDateTime(startTime),
      'completed': completed,
      if (diaryId != null && diaryId.isNotEmpty) 'diary_id': diaryId,
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
      if (behaviorItems != null && behaviorItems.isNotEmpty)
        'behavior_items': behaviorItems,
    };

    final res = await _client.dio.post(
      '/edu-sessions/week7',
      data: payload,
    );
    final data = res.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week7 session create response',
    );
  }

  /// 최신 7주차 edu 세션 하나 가져오기 (없으면 null)
  Future<Map<String, dynamic>?> fetchLatestWeek7Session() async {
    final res = await _client.dio.get(
      '/edu-sessions',
      queryParameters: {'week_number': 7},
    );
    final data = res.data;

    if (data is List) {
      if (data.isEmpty) return null;
      final first = data.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions (week7) response',
    );
  }

  /// 단일 7주차 세션 조회 (session_id 기준)
  Future<Map<String, dynamic>> getWeek7Session(String sessionId) async {
    final res = await _client.dio.get('/edu-sessions/$sessionId');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions/{session_id} response',
    );
  }

  /// 7주차 behavior_items 단일 추가/수정
  ///
  /// category: "confront" 또는 "avoid"
  /// analysis: 백엔드 BehaviorExecutionAnalysis 구조와 맞는 map
  Future<Map<String, dynamic>> upsertBehaviorItem({
    required String sessionId,
    required String chipId,
    required String category,
    String? reason,
    Map<String, dynamic>? analysis,
  }) async {
    final payload = <String, dynamic>{
      'chip_id': chipId,
      'category': category,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (analysis != null) 'analysis': analysis,
    };

    final res = await _client.dio.put(
      '/edu-sessions/$sessionId/week7/items',
      data: payload,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week7 item upsert response',
    );
  }

  /// 7주차 behavior_items 단일 삭제
  Future<void> deleteBehaviorItem({
    required String sessionId,
    required String chipId,
  }) async {
    await _client.dio.delete(
      '/edu-sessions/$sessionId/week7/items/$chipId',
    );
  }

  /// 7주차 세션 완료/진행 상태 업데이트
  ///
  /// - 일부 필드만 보내도 됨 (백엔드 EduSessionUpdate: 부분 수정)
  Future<Map<String, dynamic>> updateCompletion({
    required String sessionId,
    required bool completed,
    DateTime? endTime,
    int? lastScreenIndex,
    int? totalScreens,
  }) async {
    final payload = <String, dynamic>{
      'completed': completed,
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
      if (lastScreenIndex != null) 'last_screen_idx': lastScreenIndex,
      if (totalScreens != null) 'total_screens': totalScreens,
    };

    final res = await _client.dio.put(
      '/edu-sessions/$sessionId',
      data: payload,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week7 completion update response',
    );
  }
}

