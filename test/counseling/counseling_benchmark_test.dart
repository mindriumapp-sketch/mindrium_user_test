import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/counseling_benchmark.dart';

void main() {
  test('T52 계측은 dart-define 없이는 꺼져 있다', () {
    // 릴리스 빌드에 개발용 로그가 실수로 남지 않아야 한다.
    expect(CounselingBenchmark.enabled, isFalse);
  });

  test('T52 꺼져 있으면 아무것도 출력하지 않는다', () {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };

    try {
      CounselingBenchmark.emit('turn', {'ms': 42});
    } finally {
      debugPrint = original;
    }

    expect(printed, isEmpty);
  });

  test('T52 꺼져 있어도 measure 는 값을 그대로 돌려준다', () async {
    final result = await CounselingBenchmark.measure(
      'noop',
      () async => 7,
    );

    expect(result, 7);
  });
}
