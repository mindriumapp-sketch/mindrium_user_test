import 'package:flutter/foundation.dart';

/// 개발용 계측. 프로덕션 로깅과 분리되어 있고 기본으로 꺼져 있다.
///
/// shell 스크립트로는 Activity cold start 와 PSS 스냅샷까지만 잴 수 있다.
/// ChatPage 가 실제로 준비된 시각이나 한 턴에 걸린 시간은 앱 안에서만 알 수 있다.
///
/// 켜는 법:
///   flutter run --profile --dart-define=COUNSELING_BENCH=true
///
/// 출력은 한 줄에 하나씩, 파싱하기 쉬운 형식으로 남긴다.
///   [COUNSELING_BENCH] chat_page_ready_ms=412
///   [COUNSELING_BENCH] turn_ms=38 safety=normal parse=strict cbt_ids=1
class CounselingBenchmark {
  /// dart-define 으로만 켠다. 릴리스 빌드에서 실수로 남지 않게 한다.
  static const bool enabled = bool.fromEnvironment(
    'COUNSELING_BENCH',
    defaultValue: false,
  );

  static const String _tag = '[COUNSELING_BENCH]';

  const CounselingBenchmark._();

  /// 이름과 값 쌍을 한 줄로 남긴다. 꺼져 있으면 아무 일도 하지 않는다.
  static void emit(String event, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;

    final buffer = StringBuffer('$_tag $event');
    fields.forEach((key, value) {
      if (value != null) buffer.write(' $key=$value');
    });
    debugPrint(buffer.toString());
  }

  /// 구간을 재고 결과를 남긴다.
  static Future<T> measure<T>(
    String event,
    Future<T> Function() body, {
    Map<String, Object?> Function(T result)? fields,
  }) async {
    if (!enabled) return body();

    final stopwatch = Stopwatch()..start();
    final result = await body();
    stopwatch.stop();

    emit(event, {
      'ms': stopwatch.elapsedMilliseconds,
      ...?fields?.call(result),
    });
    return result;
  }
}
