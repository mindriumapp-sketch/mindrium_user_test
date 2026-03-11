import 'package:dio/dio.dart';

import 'api_client.dart';

/// 이완(점진적 이완 등) 관련 로그 전용 API 래퍼.
/// FastAPI의 /relaxation_tasks 계열 엔드포인트를 감싼다.
class RelaxationApi {
  final ApiClient _client;
  RelaxationApi(this._client);

  String _encodeDateTime(DateTime dt) => dt.toUtc().toIso8601String();

  /// 이완 세션 로그 저장
  ///
  /// - relaxId가 없으면: POST /relaxation_tasks → 새 도큐먼트 생성
  /// - relaxId가 있으면: PUT  /relaxation_tasks/{relax_id} → 같은 세션 도큐먼트 덮어쓰기
  /// - [startTime], [endTime] 은 ISO8601(UTC) 문자열로 전송.
  /// - [logs] 는 `{ action, timestamp, elapsed_seconds }` 형태 리스트.
  Future<Map<String, dynamic>> saveRelaxationTask({
    String? relaxId,        // 🔥 추가: 서버 relax_id (없으면 create, 있으면 update)
    required String taskId,
    int? weekNumber,
    required DateTime startTime,
    DateTime? endTime,
    required List<Map<String, dynamic>> logs,
    double? latitude,
    double? longitude,
    String? addressName,
  }) async {
    final payload = <String, dynamic>{
      'task_id': taskId,
      'week_number': weekNumber,
      'start_time': _encodeDateTime(startTime),
      if (endTime != null) 'end_time': _encodeDateTime(endTime),
      'logs': logs,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (addressName != null) 'address_name': addressName,
    };

    final Response res;
    if (relaxId == null) {
      // 최초 저장 → create
      res = await _client.dio.post(
        '/relaxation_tasks',
        data: payload,
      );
    } else {
      // 이후 저장 → update
      res = await _client.dio.put(
        '/relaxation_tasks/$relaxId',
        data: payload,
      );
    }

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid relaxation_tasks response',
    );
  }

  /// 조건에 해당하는 이완 세션 로그 목록 조회
  Future<List<Map<String, dynamic>>> listRelaxationTasks({
    int? weekNumber,
    String? taskId,
    DateTime? dateKst,
  }) async {
    final query = <String, dynamic>{};
    if (weekNumber != null) {
      query['week_number'] = weekNumber;
    }
    if (taskId != null) {
      query['task_id'] = taskId;
    }
    if (dateKst != null) {
      final y = dateKst.year.toString().padLeft(4, '0');
      final m = dateKst.month.toString().padLeft(2, '0');
      final d = dateKst.day.toString().padLeft(2, '0');
      query['date_kst'] = '$y-$m-$d'; // FastAPI date 파싱용
    }

    final res = await _client.dio.get(
      '/relaxation_tasks',
      queryParameters: query.isEmpty ? null : query,
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
      message: 'Invalid /relaxation_tasks list response',
    );
  }

  /// 특정 조건에 해당하는 가장 최근 이완 세션 로그 1개 조회
  ///
  /// - 백엔드: GET /relaxation_tasks/latest
  ///   + week_number, task_id만 사용
  Future<Map<String, dynamic>?> getLatestRelaxationTask({
    int? weekNumber,
    String? taskId,
  }) async {
    final query = <String, dynamic>{};
    if (weekNumber != null) {
      query['week_number'] = weekNumber;
    }
    if (taskId != null) {
      query['task_id'] = taskId;
    }

    final res = await _client.dio.get(
      '/relaxation_tasks/latest',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;

    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /relaxation_tasks/latest response',
    );
  }

  /// 이완 점수(relaxation_score)만 업데이트
  ///
  /// - 서버 라우터: PATCH /relaxation_tasks/{relax_id}/score
  Future<Map<String, dynamic>> updateRelaxationScore({
    required String relaxId,
    required double relaxationScore,
  }) async {
    // 1) 소수로 들어와도 정수로 변환
    // 2) 1~10 범위 밖이면 클램핑
    final intScore =
    relaxationScore.round().clamp(1, 10).toInt();

    final res = await _client.dio.patch(
      '/relaxation_tasks/$relaxId/score',
      data: {
        'relaxation_score': intScore,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message:
      'Invalid /relaxation_tasks/{relaxId}/score response',
    );
  }

  /// 전체 이완 시간 요약
  /// - 백엔드: GET /relaxation_tasks/summary
  /// - 응답 키:
  ///   totalMinutes, todayMinutes, weekMinutes,
  ///   weekSessions, completedSessions, completedMinutes, lastEntryAt
  Future<Map<String, dynamic>> getRelaxationSummary() async {
    final res = await _client.dio.get('/relaxation_tasks/summary');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /relaxation_tasks/summary response',
    );
  }


  /// 특정 조건(week/task/date)에 해당하는 이완 시간 요약
  /// - 백엔드: GET /relaxation_tasks/task-summary
  /// - 쿼리:
  ///   week_number, task_id, date_kst(YYYY-MM-DD, KST 기준)
  /// - 응답 키:
  ///   taskId, weekNumber, queryDate,
  ///   totalMinutes, totalSessions, completedSessions, completedMinutes, lastEntryAt
  Future<Map<String, dynamic>> getRelaxationTaskSummary({
    int? weekNumber,
    String? taskId,
    DateTime? dateKst,
  }) async {
    final query = <String, dynamic>{};

    if (weekNumber != null) {
      query['week_number'] = weekNumber;
    }
    if (taskId != null) {
      query['task_id'] = taskId;
    }
    if (dateKst != null) {
      final y = dateKst.year.toString().padLeft(4, '0');
      final m = dateKst.month.toString().padLeft(2, '0');
      final d = dateKst.day.toString().padLeft(2, '0');
      query['date_kst'] = '$y-$m-$d';
    }

    final res = await _client.dio.get(
      '/relaxation_tasks/task-summary',
      queryParameters: query.isEmpty ? null : query,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /relaxation_tasks/task-summary response',
    );
  }

  Future<bool> isWeekEducationTaskCompleted(int weekNumber) async {
    final summary = await getRelaxationTaskSummary(
      taskId: 'week${weekNumber}_education',
    );
    final completedRaw = summary['completedSessions'];
    final completedSessions = completedRaw is num ? completedRaw.toInt() : 0;
    return completedSessions > 0;
  }
}
