import 'package:dio/dio.dart';

import 'api_client.dart';

/// 상담 세션 요약 API.
///
/// **전체 대화 원문은 보내지 않는다.** 다음 세션 개인화에 실제로 쓰이는
/// 구조화 요약만 저장한다.
class CounselingSessionsApi {
  final ApiClient _client;

  CounselingSessionsApi(this._client);

  /// 세션 요약을 저장한다. 같은 `sessionId` 로 여러 번 불러도 한 문서만 남는다.
  ///
  /// 정상 종료(`completed`)와 화면 이탈(`interrupted`) 두 경로가 같은 세션을
  /// 저장하려 할 수 있어 upsert 로 둔다. 이미 completed 인 세션은 서버가
  /// interrupted 스냅샷으로 덮어쓰지 않는다.
  Future<Map<String, dynamic>> upsertSession({
    required String sessionId,
    required int week,
    required String completionStatus,
    required DateTime startedAt,
    required DateTime endedAt,
    String? finalState,
    String? safetyLevel,
    String? mainConcern,
    String? coreThought,
    String? coreThoughtSource,
    String? alternativeThought,
    String? affect,
    int? sudStart,
    int? sudEnd,
    String? interventionUsed,
    String? activityRecommended,
    String? unfinishedIssue,
    String? interventionOutcome,
    List<String> provenanceIds = const [],
    int turnCount = 0,
  }) async {
    final body = <String, dynamic>{
      'session_id': sessionId,
      'week': week,
      'completion_status': completionStatus,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      'final_state': finalState,
      'safety_level': safetyLevel,
      'main_concern': mainConcern,
      'core_thought': coreThought,
      'core_thought_source': coreThoughtSource,
      'alternative_thought': alternativeThought,
      'affect': affect,
      'sud_start': sudStart,
      'sud_end': sudEnd,
      'intervention_used': interventionUsed,
      'activity_recommended': activityRecommended,
      'unfinished_issue': unfinishedIssue,
      'intervention_outcome': interventionOutcome,
      'provenance_ids': provenanceIds,
      'turn_count': turnCount,
    };

    final res = await _client.dio.put(
      '/counseling-sessions/$sessionId',
      data: body,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /counseling-sessions/{id} response',
    );
  }

  /// 최근 세션 요약. 다음 세션 개인화에 쓴다.
  ///
  /// [completionStatus] 를 'completed' 로 주면 정상 종료된 세션만 받는다.
  Future<List<Map<String, dynamic>>> listSessions({
    int limit = 5,
    String? completionStatus,
  }) async {
    final res = await _client.dio.get(
      '/counseling-sessions',
      queryParameters: {
        'limit': limit,
        if (completionStatus != null) 'completion_status': completionStatus,
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
      message: 'Invalid /counseling-sessions response',
    );
  }
}
