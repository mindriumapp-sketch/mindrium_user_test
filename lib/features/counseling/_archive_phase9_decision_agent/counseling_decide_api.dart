import 'package:dio/dio.dart';
import 'package:gad_app_team/data/api/api_client.dart';

/// `POST /counseling/decide` 호출 계약.
///
/// Phase 9.1: `RemoteCounselorAgent`가 사용할 계약/backend 경계만 만든다 —
/// 이 클라이언트는 어떤 production/shadow 경로에서도 아직 호출되지 않는다.
/// `CounselingRealizeApi`(counseling_realize_api.dart)와 동일한 패턴을
/// 따른다: 원시 응답 Map을 반환하고, 파싱/검증은 호출부
/// (`RemoteCounselorAgent`/`RemoteCounselorResponse.fromJson`)에서 한다.
abstract interface class CounselingDecideApi {
  Future<Map<String, dynamic>> decide({
    required Map<String, dynamic> requestBody,
    Duration timeout,
  });
}

class DioCounselingDecideApi implements CounselingDecideApi {
  final ApiClient _client;

  DioCounselingDecideApi(this._client);

  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, dynamic> requestBody,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final res = await _client.dio.post(
      '/counseling/decide',
      data: requestBody,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /counseling/decide response',
    );
  }
}
