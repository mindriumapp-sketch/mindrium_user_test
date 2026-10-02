import 'package:dio/dio.dart';

import 'api_client.dart';

/// `POST /counseling/classify` (Phase 14.2A, 인식 전용).
///
/// 응답은 세 라벨과 확신도뿐이다. 이 API의 결과는 상담 결정에 쓰지 않는다
/// (그림자 관찰 전용). docs/counseling/phase14_dialogue_moves.md 5.1절.
abstract interface class CounselingClassifyApi {
  Future<Map<String, dynamic>> classify({
    required String requestId,
    required String userText,
    String? assistantPrev,
    Duration timeout,
  });
}

class DioCounselingClassifyApi implements CounselingClassifyApi {
  final ApiClient _client;

  DioCounselingClassifyApi(this._client);

  @override
  Future<Map<String, dynamic>> classify({
    required String requestId,
    required String userText,
    String? assistantPrev,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final res = await _client.dio.post(
      '/counseling/classify',
      data: {
        'request_id': requestId,
        'user_text': userText,
        if (assistantPrev != null) 'assistant_prev': assistantPrev,
      },
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /counseling/classify response',
    );
  }
}
