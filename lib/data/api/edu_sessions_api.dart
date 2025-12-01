// edu_sessions_api.dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class EduSessionsApi {
  final ApiClient _client;
  EduSessionsApi(this._client);

  // 공통 DateTime → ISO8601(UTC) 인코딩
  String _encodeDateTime(DateTime dt) => dt.toUtc().toIso8601String();

  /// 교육 세션 목록 조회
  /// - weekNumber / diaryId로 필터 가능
  Future<List<Map<String, dynamic>>> listEduSessions({
    int? weekNumber,
    String? diaryId,
  }) async {
    final res = await _client.dio.get(
      '/edu-sessions',
      queryParameters: {
        if (weekNumber != null) 'week_number': weekNumber,
        if (diaryId != null) 'diary_id': diaryId,
      },
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => raw.cast<String, dynamic>())
          .toList();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions response',
    );
  }

  /// 단일 교육 세션 조회
  Future<Map<String, dynamic>> getEduSession(String sessionId) async {
    final res = await _client.dio.get('/edu-sessions/$sessionId');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions/{session_id} response',
    );
  }

  /// 1,2,4,6주차 공통 세션 생성
  Future<Map<String, dynamic>> createCommonSession({
    required int weekNumber, // 1,2,4,6만 사용
    String? diaryId,
    required int totalScreens,
    required int lastScreenIndex,
    required bool completed,
    required DateTime startTime,
    DateTime? endTime,
  }) async {
    final payload = <String, dynamic>{
      'week_number': weekNumber,
      if (diaryId != null) 'diary_id': diaryId,
      'total_screens': totalScreens,
      'last_screen_idx': lastScreenIndex,
      'completed': completed,
      'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
    };

    final res = await _client.dio.post(
      '/edu-sessions',
      data: payload,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions (POST) response',
    );
  }

  /// 3,5주차 세션 생성 (분류 퀴즈 / 부정/긍정 리스트)
  ///
  /// classificationQuiz 예시:
  /// {
  ///   "correct_count": 3,
  ///   "total_count": 4,
  ///   "results": [
  ///     {"text": "...", "correct_type": "anxious", "user_choice": "anxious", "is_correct": true},
  ///     ...
  ///   ]
  /// }
  Future<Map<String, dynamic>> createWeek3or5Session({
    required int weekNumber, // 3 또는 5
    String? diaryId,
    required int totalScreens,
    required int lastScreenIndex,
    required bool completed,
    required DateTime startTime,
    DateTime? endTime,
    List<String>? negativeItems,
    List<String>? positiveItems,
    Map<String, dynamic>? classificationQuiz,
  }) async {
    final payload = <String, dynamic>{
      'week_number': weekNumber,
      if (diaryId != null) 'diary_id': diaryId,
      'total_screens': totalScreens,
      'last_screen_idx': lastScreenIndex,
      'completed': completed,
      'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
      if (negativeItems != null) 'negative_items': negativeItems,
      if (positiveItems != null) 'positive_items': positiveItems,
      if (classificationQuiz != null)
        'classification_quiz': classificationQuiz,
    };

    final res = await _client.dio.post(
      '/edu-sessions/week3-5',
      data: payload,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /edu-sessions/week3-5 response',
    );
  }

  /// 교육 세션 공통 부분 수정 (3,5,7,8주차 특수 필드까지 한 번에 커버)
  ///
  /// - PUT /edu-sessions/{session_id}
  /// - 백엔드 EduSessionUpdate 스키마와 1:1 매칭
  ///
  /// 사용 예:
  ///   // 3주차에서 부정/긍정 리스트만 수정
  ///   updateEduSession(
  ///     sessionId: '...',
  ///     negativeItems: [...],
  ///     positiveItems: [...],
  ///   );
  ///
  ///   // 8주차에서 효과성 평가 + 완료 상태 같이 수정
  ///   updateEduSession(
  ///     sessionId: '...',
  ///     completed: true,
  ///     lastScreenIndex: 10,
  ///     effectivenessEvaluations: [...],
  ///   );
  Future<Map<String, dynamic>> updateEduSession({
    required String sessionId,
    int? totalScreens,
    int? lastScreenIndex,
    bool? completed,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? negativeItems,
    List<String>? positiveItems,
    Map<String, dynamic>? classificationQuiz,
    List<Map<String, dynamic>>? behaviorItems,
    List<Map<String, dynamic>>? effectivenessEvaluations,
    List<Map<String, dynamic>>? userJourneyResponses,
  }) async {
    final payload = <String, dynamic>{
      if (totalScreens != null) 'total_screens': totalScreens,
      if (lastScreenIndex != null) 'last_screen_idx': lastScreenIndex,
      if (completed != null) 'completed': completed,
      if (startTime != null) 'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),

      // 3,5주차
      if (negativeItems != null) 'negative_items': negativeItems,
      if (positiveItems != null) 'positive_items': positiveItems,
      if (classificationQuiz != null)
        'classification_quiz': classificationQuiz,

      // 7주차
      if (behaviorItems != null) 'behavior_items': behaviorItems,

      // 8주차
      if (effectivenessEvaluations != null)
        'effectiveness_evaluations': effectivenessEvaluations,
      if (userJourneyResponses != null)
        'user_journey_responses': userJourneyResponses,
    };

    if (payload.isEmpty) {
      throw ArgumentError('수정할 필드가 없습니다 (updateEduSession payload is empty)');
    }

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
      message: 'Invalid /edu-sessions (PUT) response',
    );
  }
}
