import 'package:dio/dio.dart';

import 'api_client.dart';

/// `POST /counseling/respond` (Phase 14.X Bounded LLM-led 시제품).
/// docs/counseling/phase14x_bounded_llm_led.md.
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
    final res = await _client.dio.post(
      '/counseling/respond',
      data: body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /counseling/respond response',
    );
  }
}
