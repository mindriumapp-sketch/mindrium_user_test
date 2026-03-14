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
    required int totalStages,
    required int lastStageIndex,
    required bool completed,
    required DateTime startTime,
    DateTime? endTime,
  }) async {
    final payload = <String, dynamic>{
      'week_number': weekNumber,
      if (diaryId != null) 'diary_id': diaryId,
      'total_stages': totalStages,
      'last_stage_idx': lastStageIndex,
      'completed': completed,
      'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
    };

    final res = await _client.dio.post('/edu-sessions', data: payload);

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
    required int totalStages,
    required int lastStageIndex,
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
      'total_stages': totalStages,
      'last_stage_idx': lastStageIndex,
      'completed': completed,
      'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
      if (negativeItems != null) 'negative_items': negativeItems,
      if (positiveItems != null) 'positive_items': positiveItems,
      if (classificationQuiz != null) 'classification_quiz': classificationQuiz,
    };

    final res = await _client.dio.post('/edu-sessions/week3-5', data: payload);

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
  ///     lastStageIndex: 10,
  ///     effectivenessEvaluations: [...],
  ///   );
  Future<Map<String, dynamic>> updateEduSession({
    required String sessionId,
    int? totalStages,
    int? lastStageIndex,
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
      if (totalStages != null) 'total_stages': totalStages,
      if (lastStageIndex != null) 'last_stage_idx': lastStageIndex,
      if (completed != null) 'completed': completed,
      if (startTime != null) 'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),

      // 3,5주차
      if (negativeItems != null) 'negative_items': negativeItems,
      if (positiveItems != null) 'positive_items': positiveItems,
      if (classificationQuiz != null) 'classification_quiz': classificationQuiz,

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

  Future<void> completeWeekSession({
    required int weekNumber,
    required int totalStages,
    String? sessionId,
  }) async {
    final now = DateTime.now();
    String? targetSessionId = sessionId?.trim();

    if (targetSessionId == null || targetSessionId.isEmpty) {
      final sessions = await listEduSessions(weekNumber: weekNumber);
      if (sessions.isNotEmpty) {
        final latestId = sessions.first['session_id']?.toString();
        if (latestId != null && latestId.isNotEmpty) {
          targetSessionId = latestId;
        }
      }
    }

    if (targetSessionId != null && targetSessionId.isNotEmpty) {
      await updateEduSession(
        sessionId: targetSessionId,
        completed: true,
        lastStageIndex: totalStages,
        totalStages: totalStages,
        endTime: now,
      );
      return;
    }

    if (weekNumber == 3 || weekNumber == 5) {
      await createWeek3or5Session(
        weekNumber: weekNumber,
        totalStages: totalStages,
        lastStageIndex: totalStages,
        completed: true,
        startTime: now,
        endTime: now,
      );
      return;
    }

    if (weekNumber == 1 ||
        weekNumber == 2 ||
        weekNumber == 4 ||
        weekNumber == 6) {
      await createCommonSession(
        weekNumber: weekNumber,
        totalStages: totalStages,
        lastStageIndex: totalStages,
        completed: true,
        startTime: now,
        endTime: now,
      );
    }
  }

  Future<bool> isWeekSessionCompleted(int weekNumber) async {
    final sessions = await listEduSessions(weekNumber: weekNumber);
    for (final s in sessions) {
      final completed = s['completed'] == true;
      final totalStagesRaw = s['total_stages'];
      final lastIdxRaw = s['last_stage_idx'];
      final totalStages = totalStagesRaw is num ? totalStagesRaw.toInt() : 0;
      final lastIdx = lastIdxRaw is num ? lastIdxRaw.toInt() : 0;
      if (completed && totalStages > 0 && lastIdx >= totalStages) {
        return true;
      }
    }
    return false;
  }
}
