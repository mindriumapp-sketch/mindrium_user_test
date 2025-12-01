import 'package:dio/dio.dart';

import 'api_client.dart';

class Week8Api {
  final ApiClient _client;
  Week8Api(this._client);

  String _encodeDateTime(DateTime dt) => dt.toUtc().toIso8601String();

  /// 8주차 세션 생성
  ///
  /// - POST /edu-sessions/week8
  /// - week_number는 항상 8로 고정
  /// - effectivenessEvaluations / userJourneyResponses는 선택
  ///
  /// effectivenessEvaluations 예:
  /// {
  ///   "behavior": "...",
  ///   "chip_id": "chip_xxx" or null,
  ///   "was_effective": true,
  ///   "will_continue": false
  /// }
  ///
  /// userJourneyResponses 예:
  /// {
  ///   "question": "...",
  ///   "answer": "..."
  /// }
  Future<Map<String, dynamic>> createWeek8Session({
    String? diaryId,
    required int totalScreens,
    required int lastScreenIndex,
    required DateTime startTime,
    bool completed = false,
    DateTime? endTime,
    List<Map<String, dynamic>>? effectivenessEvaluations,
    List<Map<String, dynamic>>? userJourneyResponses,
  }) async {
    final payload = <String, dynamic>{
      'week_number': 8,
      'total_screens': totalScreens,
      'last_screen_idx': lastScreenIndex,
      'start_time': _encodeDateTime(startTime),
      'completed': completed,
      if (diaryId != null && diaryId.isNotEmpty) 'diary_id': diaryId,
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
      if (effectivenessEvaluations != null &&
          effectivenessEvaluations.isNotEmpty)
        'effectiveness_evaluations': effectivenessEvaluations,
      if (userJourneyResponses != null && userJourneyResponses.isNotEmpty)
        'user_journey_responses': userJourneyResponses,
    };

    final res = await _client.dio.post(
      '/edu-sessions/week8',
      data: payload,
    );
    final data = res.data;

    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week8 session create response',
    );
  }

  /// 최신 8주차 edu 세션 하나 가져오기 (없으면 null)
  ///
  /// - GET /edu-sessions?week_number=8
  /// - 백엔드에서 start_time 기준 내림차순이므로, 첫 번째 요소가 최신
  Future<Map<String, dynamic>?> fetchWeek8Session() async {
    final res = await _client.dio.get(
      '/edu-sessions',
      queryParameters: {'week_number': 8},
    );
    final data = res.data;

    if (data is List) {
      if (data.isEmpty) return null;
      final first = data.first;
      if (first is Map) {
        return Map<String, dynamic>.from(
          first.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions (week8) response',
    );
  }

  /// 단일 8주차 세션 조회 (session_id 기준)
  ///
  /// - GET /edu-sessions/{session_id}
  Future<Map<String, dynamic>> getWeek8Session(String sessionId) async {
    final res = await _client.dio.get('/edu-sessions/$sessionId');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions/{session_id} response',
    );
  }

  /// 8주차 효과성 평가 업데이트 (전체 교체)
  ///
  /// effectivenessEvaluations 각 원소 예시:
  /// {
  ///   "behavior": "...",
  ///   "chip_id": "chip_xxx" or null,
  ///   "was_effective": true,
  ///   "will_continue": false
  /// }
  ///
  /// - PUT /edu-sessions/{session_id}/week8/effectiveness
  /// - body: { "evaluations": [...] }
  Future<Map<String, dynamic>> updateEffectiveness({
    required String sessionId,
    required List<Map<String, dynamic>> effectivenessEvaluations,
  }) async {
    final payload = <String, dynamic>{
      'evaluations': effectivenessEvaluations,
    };

    final res = await _client.dio.put(
      '/edu-sessions/$sessionId/week8/effectiveness',
      data: payload,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week8 effectiveness update response',
    );
  }

  /// 8주차 사용자 여정 답변 업데이트 (전체 교체)
  ///
  /// userJourneyResponses 각 원소 예시:
  /// {
  ///   "question": "...",
  ///   "answer": "..."
  /// }
  ///
  /// - PUT /edu-sessions/{session_id}/week8/user-journey
  /// - body: { "responses": [...] }
  Future<Map<String, dynamic>> updateUserJourney({
    required String sessionId,
    required List<Map<String, dynamic>> userJourneyResponses,
  }) async {
    final payload = <String, dynamic>{
      'responses': userJourneyResponses,
    };

    final res = await _client.dio.put(
      '/edu-sessions/$sessionId/week8/user-journey',
      data: payload,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week8 user journey update response',
    );
  }

  /// 8주차 세션 완료/진행 상태 업데이트
  ///
  /// - PUT /edu-sessions/{session_id}
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
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid week8 completion update response',
    );
  }
}
