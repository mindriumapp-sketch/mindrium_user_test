/// LLM 런타임 추상화.
///
/// 여기에는 GGUF 경로, context size, grammar 같은 런타임 세부사항을 넣지 않는다.
/// 그건 LlamaCppLlmService 등 구현체 내부 사정이며, 여기에 새면 Step 3 에서
/// 런타임을 갈아끼울 때 harness 까지 고쳐야 한다.
library;

class LlmRequest {
  final String systemPrompt;
  final String userPrompt;
  final double temperature;
  final int maxTokens;

  const LlmRequest({
    required this.systemPrompt,
    required this.userPrompt,
    this.temperature = 0.3,
    this.maxTokens = 256,
  });
}

class LlmResponse {
  final String text;
  final Duration latency;

  const LlmResponse({required this.text, required this.latency});
}

/// 모델 호출이 실패했을 때 던진다. harness 가 잡아서 안전한 응답으로 바꾼다.
class LlmException implements Exception {
  final String message;
  final Object? cause;

  const LlmException(this.message, {this.cause});

  @override
  String toString() => 'LlmException: $message';
}

abstract class LlmService {
  Future<LlmResponse> generate(LlmRequest request);
}
