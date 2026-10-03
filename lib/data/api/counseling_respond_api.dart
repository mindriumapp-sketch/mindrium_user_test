import 'package:dio/dio.dart';

import 'api_client.dart';

/// `POST /counseling/respond` (Phase 14.X Bounded LLM-led 시제품).
/// docs/counseling/phase14x_bounded_llm_led.md.
/// A failed `/counseling/respond` call, classified (no prompt, no key).
/// [requestStatus]: http_429 | http_4xx_other | http_5xx | network_error |
/// timeout | schema_reject | unknown. [httpStatus] is the upstream status
/// when the backend reports one, else the backend's own status.
class CounselingRespondFailure implements Exception {
  final String requestStatus;
  final int? httpStatus;
  final bool retryAfter;
  final String? providerRequestId;

  const CounselingRespondFailure(this.requestStatus,
      {this.httpStatus, this.retryAfter = false, this.providerRequestId});

  static const _reasons = {
    'http_429', 'http_4xx_other', 'http_5xx', 'network_error', 'timeout', 'schema_reject',
  };

  /// From a backend error response (status code + JSON body).
  factory CounselingRespondFailure.fromResponse(int status, Object? body) {
    final detail = body is Map ? body['detail'] : null;
    if (detail is Map && _reasons.contains(detail['reason'])) {
      return CounselingRespondFailure(
        detail['reason'] as String,
        httpStatus: (detail['upstream_status'] as num?)?.toInt() ?? status,
        retryAfter: detail['retry_after'] == true,
        providerRequestId: detail['provider_request_id'] as String?,
      );
    }
    return CounselingRespondFailure(
      status == 429 ? 'http_429' : status >= 500 ? 'http_5xx' : 'http_4xx_other',
      httpStatus: status,
    );
  }

  @override
  String toString() => 'CounselingRespondFailure($requestStatus, $httpStatus)';
}

abstract interface class CounselingRespondApi {
  Future<Map<String, dynamic>> respond(Map<String, dynamic> body, {Duration timeout});
}

class DioCounselingRespondApi implements CounselingRespondApi {
  final ApiClient _client;

  DioCounselingRespondApi(this._client);

  @override
  Future<Map<String, dynamic>> respond(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final Response<dynamic> res;
    try {
      res = await _client.dio.post(
        '/counseling/respond',
        data: body,
        options: Options(sendTimeout: timeout, receiveTimeout: timeout),
      );
    } on DioException catch (e) {
      final r = e.response;
      if (r != null) throw CounselingRespondFailure.fromResponse(r.statusCode ?? 0, r.data);
      throw CounselingRespondFailure(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => 'timeout',
        DioExceptionType.connectionError => 'network_error',
        _ => 'unknown',
      });
    }
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const CounselingRespondFailure('schema_reject');
  }
}
