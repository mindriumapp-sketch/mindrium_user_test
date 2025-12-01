import 'package:dio/dio.dart';

import 'api_client.dart';

class ScheduleEventsApi {
  final ApiClient _client;
  ScheduleEventsApi(this._client);

  // DateTime → 'YYYY-MM-DD'
  String _formatDate(DateTime date) =>
      date.toIso8601String().split('T').first;

  // DateTime → ISO8601(UTC) (client_timestamp용)
  String _encodeDateTime(DateTime dt) =>
      dt.toUtc().toIso8601String();

  /// 캘린더 이벤트 생성
  ///
  /// - POST /schedule-events
  /// - startDate, endDate: 날짜만 사용 (시분초 버림)
  /// - actions 예:
  ///   [
  ///     { "label": "산책하기", "chip_id": "chip_walk" },
  ///     { "label": "명상", "chip_id": null },
  ///   ]
  ///
  /// rejectOnConflict:
  ///   - true → 기간 겹치면 409 + conflicts 반환
  ///   - false → 그냥 생성
  Future<Map<String, dynamic>> createScheduleEvent({
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> actions,
    bool rejectOnConflict = false,
    DateTime? clientTimestamp,
  }) async {
    final payload = <String, dynamic>{
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'actions': actions,
      'client_timestamp':
      _encodeDateTime(clientTimestamp ?? DateTime.now()),
    };

    final res = await _client.dio.post(
      '/schedule-events',
      data: payload,
      queryParameters: {
        'reject_on_conflict': rejectOnConflict,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid schedule event create response',
    );
  }

  /// 캘린더 이벤트 목록 조회
  ///
  /// - GET /schedule-events
  /// - startDate / endDate: start_date 필터 (>=, <=)에만 사용
  Future<List<Map<String, dynamic>>> listScheduleEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);

    final res = await _client.dio.get(
      '/schedule-events',
      queryParameters: query.isEmpty ? null : query,
    );
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) =>
          raw.map((key, value) => MapEntry(key.toString(), value)))
          .toList()
          .cast<Map<String, dynamic>>();
    }
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid schedule events response',
    );
  }

  /// 캘린더 이벤트 수정 (부분 수정)
  ///
  /// - PUT /schedule-events/{event_id}
  /// - startDate / endDate / actions 중 수정할 것만 넘기면 됨
  /// - 최소 1개는 있어야 함 (아무것도 없으면 에러)
  ///
  /// actions 예:
  ///   [
  ///     { "label": "산책하기", "chip_id": "chip_walk" },
  ///   ]
  Future<Map<String, dynamic>> updateScheduleEvent({
    required String eventId,
    DateTime? startDate,
    DateTime? endDate,
    List<Map<String, dynamic>>? actions,
    bool rejectOnConflict = false,
    DateTime? clientTimestamp,
  }) async {
    final payload = <String, dynamic>{};

    if (startDate != null) {
      payload['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      payload['end_date'] = _formatDate(endDate);
    }
    if (actions != null) {
      payload['actions'] = actions;
    }

    if (payload.isEmpty) {
      throw ArgumentError(
        '수정할 필드가 없습니다 (startDate, endDate, actions 중 최소 1개 필요)',
      );
    }

    payload['client_timestamp'] =
        _encodeDateTime(clientTimestamp ?? DateTime.now());

    final res = await _client.dio.put(
      '/schedule-events/$eventId',
      data: payload,
      queryParameters: {
        'reject_on_conflict': rejectOnConflict,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid schedule event update response',
    );
  }

  /// 캘린더 이벤트 삭제 (소프트 삭제)
  ///
  /// - DELETE /schedule-events/{event_id}
  /// - body: { "client_timestamp": ... }
  Future<void> deleteScheduleEvent({
    required String eventId,
    DateTime? clientTimestamp,
  }) async {
    await _client.dio.delete(
      '/schedule-events/$eventId',
      data: {
        'client_timestamp':
        _encodeDateTime(clientTimestamp ?? DateTime.now()),
      },
    );
  }
}
