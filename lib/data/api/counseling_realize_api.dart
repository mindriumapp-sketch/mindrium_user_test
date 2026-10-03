import 'package:dio/dio.dart';

import 'api_client.dart';

/// `POST /counseling/realize`(GPT) 호출 계약.
///
/// 이 API는 상담 전략을 정하지 않는다. Harness가 이미 확정한 초안을 더
/// 자연스러운 한국어로 다듬는 선택적 표현 계층이다. 자세한 책임 경계는
/// docs/counseling/chatbot_system.md (tag counseling-handover-v1) 9절 참고.
///
/// 인터페이스로 분리해 `RemoteLlmRealizer` 테스트에서 실제 네트워크 없이
/// fake 구현을 주입할 수 있게 한다.
abstract interface class CounselingRealizeApi {
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs,
    String? affect,
    String tone,
    List<Map<String, String>> recentConversation,
    List<String> allowedCbtFacts,
    List<String> forbiddenBehaviors,
    String promptVersion,
    Duration timeout,
    int? sudRatingValue,
  });
}

class DioCounselingRealizeApi implements CounselingRealizeApi {
  final ApiClient _client;

  DioCounselingRealizeApi(this._client);

  @override
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs = const [],
    String? affect,
    String tone = 'warm, calm, concise',
    List<Map<String, String>> recentConversation = const [],
    List<String> allowedCbtFacts = const [],
    List<String> forbiddenBehaviors = const [],
    String promptVersion = 'remote-realizer-v1',
    Duration timeout = const Duration(seconds: 8),
    int? sudRatingValue,
  }) async {
    final body = <String, dynamic>{
      'request_id': requestId,
      'prompt_version': promptVersion,
      'deterministic_draft': deterministicDraft,
      'reflection_target': reflectionTarget,
      'question_goal': questionGoal,
      'required_act': requiredAct,
      'allowed_acts': allowedActs,
      'affect': affect,
      'tone': tone,
      'recent_conversation': recentConversation,
      'allowed_cbt_facts': allowedCbtFacts,
      'forbidden_behaviors': forbiddenBehaviors,
      'sud_rating_value': sudRatingValue,
    };

    final res = await _client.dio.post(
      '/counseling/realize',
      data: body,
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw DioException(
      requestOptions: res.requestOptions,
      message: 'Invalid /counseling/realize response',
    );
  }
}
