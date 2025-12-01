import 'package:dio/dio.dart';

import 'api_client.dart';

/// Custom Tag + Real Oddness / Category 로그 API
class CustomTagsApi {
  final ApiClient _client;

  CustomTagsApi(this._client);

  /// 커스텀 태그 목록 조회
  ///
  /// GET /custom-tags?chip_type=...&include_deleted=...
  ///
  /// - [chipType]: "A" | "B" | "CP" | "CE" | "CA" 중 하나 또는 null
  /// - [includeDeleted]: soft-delete된 태그까지 포함할지 여부
  Future<List<Map<String, dynamic>>> listCustomTags({
    String? chipType,
    bool includeDeleted = false,
  }) async {
    final res = await _client.dio.get(
      '/custom-tags',
      queryParameters: {
        if (chipType != null) 'chip_type': chipType,
        'include_deleted': includeDeleted,
      },
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (raw) => raw.map(
              (key, value) => MapEntry(key.toString(), value),
        ),
      )
          .toList()
          .cast<Map<String, dynamic>>();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags response',
    );
  }

  /// 단일 커스텀 태그 조회
  ///
  /// GET /custom-tags/{chip_id}?include_deleted=true|false
  Future<Map<String, dynamic>> getCustomTag({
    required String chipId,
    bool includeDeleted = false,
  }) async {
    final res = await _client.dio.get(
      '/custom-tags/$chipId',
      queryParameters: {
        'include_deleted': includeDeleted,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/{chip_id} response',
    );
  }

  /// 커스텀 태그 생성
  ///
  /// POST /custom-tags
  ///
  /// 백엔드 스키마:
  /// - chip_id: String (클라에서 생성해서 보내야 함)
  /// - label: String
  /// - type: "A" | "B" | "CP" | "CE" | "CA"
  /// - is_preset: bool (optional, default=false)
  /// - client_timestamp: DateTime (필수)
  Future<Map<String, dynamic>> createCustomTag({
    required String chipId,
    required String label,
    required String type,
    bool isPreset = false,
    DateTime? clientTimestamp,
  }) async {
    final payload = <String, dynamic>{
      'chip_id': chipId,
      'label': label,
      'type': type,
      'is_preset': isPreset,
      'client_timestamp':
      (clientTimestamp ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final res = await _client.dio.post(
      '/custom-tags',
      data: payload,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags (POST) response',
    );
  }

  /// 커스텀 태그 수정
  ///
  /// PUT /custom-tags/{chip_id}
  ///
  /// - 최소 한 개 이상의 필드(label / type / isPreset)를 수정해야 하며,
  ///   아무것도 안 보내면 백엔드에서 400("업데이트할 필드가 없습니다") 발생.
  Future<Map<String, dynamic>> updateCustomTag({
    required String chipId,
    String? label,
    String? type,
    bool? isPreset,
    DateTime? clientTimestamp,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label,
      if (type != null) 'type': type,
      if (isPreset != null) 'is_preset': isPreset,
      'client_timestamp':
      (clientTimestamp ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final res = await _client.dio.put(
      '/custom-tags/$chipId',
      data: body,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/{chip_id} (PUT) response',
    );
  }

  /// 커스텀 태그 삭제(soft delete)
  ///
  /// DELETE /custom-tags/{chip_id}
  ///
  /// body: { "client_timestamp": ... }
  Future<Map<String, dynamic>> deleteCustomTag({
    required String chipId,
    DateTime? clientTimestamp,
  }) async {
    final body = <String, dynamic>{
      'client_timestamp':
      (clientTimestamp ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final res = await _client.dio.delete(
      '/custom-tags/$chipId',
      data: body,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/{chip_id} (DELETE) response',
    );
  }

  /// Category 로그 조회 (short_term: confront/avoid 포함)
  Future<List<Map<String, dynamic>>> listCategoryLogs({
    String? chipId,
    String? diaryId,
    DateTime? startCompletedAt,
    DateTime? endCompletedAt,
  }) async {
    final res = await _client.dio.get(
      '/custom-tags/logs/category',
      queryParameters: {
        if (chipId != null) 'chip_id': chipId,
        if (diaryId != null) 'diary_id': diaryId,
        if (startCompletedAt != null)
          'start_completed_at': startCompletedAt.toUtc().toIso8601String(),
        if (endCompletedAt != null)
          'end_completed_at': endCompletedAt.toUtc().toIso8601String(),
      },
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
          .cast<Map<String, dynamic>>();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/logs/category response',
    );
  }

  // ---------------------------------------------------------------------------
  // Real Oddness Logs
  // ---------------------------------------------------------------------------

  /// Real Oddness 로그 생성
  ///
  /// POST /custom-tags/{chip_id}/real-oddness-logs
  ///
  /// 백엔드 스키마:
  /// - diary_id: String
  /// - chip_id: String (path의 chip_id와 동일해야 함)
  /// - before_odd: int (0~10)
  /// - after_odd: int? (0~10, optional)
  /// - alternative_thought: String
  /// - completed_at: DateTime
  Future<Map<String, dynamic>> createRealOddnessLog({
    required String chipId,
    required String diaryId,
    required int beforeOdd,
    int? afterOdd,
    required String alternativeThought,
    DateTime? completedAt,
  }) async {
    final payload = <String, dynamic>{
      'diary_id': diaryId,
      'chip_id': chipId,
      'before_odd': beforeOdd,
      if (afterOdd != null) 'after_odd': afterOdd,
      'alternative_thought': alternativeThought,
      'completed_at':
      (completedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final res = await _client.dio.post(
      '/custom-tags/$chipId/real-oddness-logs',
      data: payload,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/{chip_id}/real-oddness-logs response',
    );
  }

  /// Real Oddness 로그 조회
  ///
  /// GET /custom-tags/logs/real-oddness
  ///
  /// Query params:
  /// - chip_id: String?
  /// - diary_id: String?
  /// - start_completed_at: DateTime?
  /// - end_completed_at: DateTime?
  Future<List<Map<String, dynamic>>> listRealOddnessLogs({
    String? chipId,
    String? diaryId,
    DateTime? startCompletedAt,
    DateTime? endCompletedAt,
  }) async {
    final query = <String, dynamic>{
      if (chipId != null) 'chip_id': chipId,
      if (diaryId != null) 'diary_id': diaryId,
      if (startCompletedAt != null)
        'start_completed_at': startCompletedAt.toUtc().toIso8601String(),
      if (endCompletedAt != null)
        'end_completed_at': endCompletedAt.toUtc().toIso8601String(),
    };

    final res = await _client.dio.get(
      '/custom-tags/logs/real-oddness',
      queryParameters: query,
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (raw) => raw.map(
              (key, value) => MapEntry(key.toString(), value),
        ),
      )
          .toList()
          .cast<Map<String, dynamic>>();
    }

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/logs/real-oddness response',
    );
  }

  // ---------------------------------------------------------------------------
  // Category Logs
  // ---------------------------------------------------------------------------

  /// Category 로그 생성
  ///
  /// POST /custom-tags/{chip_id}/category-logs
  ///
  /// 백엔드 스키마:
  /// - diary_id: String
  /// - chip_id: String (path chip_id와 동일)
  /// - category: "anxious" | "healthy"
  /// - short_term: "confront" | "avoid" | null
  /// - long_term: "confront" | "avoid" | null
  /// - is_changed: bool
  /// - completed_at: DateTime
  Future<Map<String, dynamic>> createCategoryLog({
    required String chipId,
    required String diaryId,
    required String category,
    String? shortTerm,
    String? longTerm,
    bool isChanged = false,
    DateTime? completedAt,
  }) async {
    final payload = <String, dynamic>{
      'diary_id': diaryId,
      'chip_id': chipId,
      'category': category,
      if (shortTerm != null) 'short_term': shortTerm,
      if (longTerm != null) 'long_term': longTerm,
      'is_changed': isChanged,
      'completed_at':
      (completedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final res = await _client.dio.post(
      '/custom-tags/$chipId/category-logs',
      data: payload,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;

    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /custom-tags/{chip_id}/category-logs response',
    );
  }

}
