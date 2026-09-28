import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/intent/assistant_intent_router.dart';

Future<String> _loadFromDisk(String path) => File(path).readAsString();

/// Phase 7 — AssistantIntentRouter 검증.
///
/// 핵심 원칙: intent(무엇을 원하는가)와 knowledge match(답할 근거가
/// 있는가)는 서로 다른 축이다. "영상 통화 상담 어디서 해?"는 KB에 없는
/// 기능이라도 앱 사용법 질문이므로 needsAppGuidance=true여야 한다
/// (마지막 그룹 참고).
void main() {
  late LocalAppGuideRepository repository;
  late DeterministicAssistantIntentRouter router;

  setUpAll(() async {
    repository = LocalAppGuideRepository(loadAsset: _loadFromDisk);
    await repository.initialize();
    router = DeterministicAssistantIntentRouter(repository: repository);
  });

  group('counseling only', () {
    test('"내일 발표가 너무 불안해"', () {
      final intent = router.detect('내일 발표가 너무 불안해');
      expect(intent.needsCounseling, isTrue);
      expect(intent.needsAppGuidance, isFalse);
    });

    test('"사람들이 나를 이상하게 볼까 걱정돼"', () {
      final intent = router.detect('사람들이 나를 이상하게 볼까 걱정돼');
      expect(intent.needsCounseling, isTrue);
      expect(intent.needsAppGuidance, isFalse);
    });
  });

  group('app guide only', () {
    test('"지난 걱정 기록은 어디서 봐?" — "걱정"은 감정이 아니라 기능 이름의 일부다', () {
      final intent = router.detect('지난 걱정 기록은 어디서 봐?');
      expect(intent.needsCounseling, isFalse);
      expect(intent.needsAppGuidance, isTrue);
    });

    test('"알림 설정은 어떻게 바꿔?"', () {
      final intent = router.detect('알림 설정은 어떻게 바꿔?');
      expect(intent.needsCounseling, isFalse);
      expect(intent.needsAppGuidance, isTrue);
    });

    test('"위젯은 어떻게 추가해?"', () {
      final intent = router.detect('위젯은 어떻게 추가해?');
      expect(intent.needsCounseling, isFalse);
      expect(intent.needsAppGuidance, isTrue);
    });
  });

  group('mixed', () {
    test('"요즘 다시 불안한데 예전에 적은 기록은 어디서 확인해?"', () {
      final intent = router.detect('요즘 다시 불안한데 예전에 적은 기록은 어디서 확인해?');
      expect(intent.needsCounseling, isTrue);
      expect(intent.needsAppGuidance, isTrue);
    });

    test('"걱정이 심한데 이완 활동은 어디서 할 수 있어?"', () {
      final intent = router.detect('걱정이 심한데 이완 활동은 어디서 할 수 있어?');
      expect(intent.needsCounseling, isTrue);
      expect(intent.needsAppGuidance, isTrue);
    });
  });

  group('unknown app feature (핵심)', () {
    test('"영상 통화 상담 어디서 해?" → appGuide intent는 true, KB에는 없는 기능', () {
      final intent = router.detect('영상 통화 상담 어디서 해?');

      expect(intent.needsCounseling, isFalse);
      expect(
        intent.needsAppGuidance,
        isTrue,
        reason: 'KB에 없는 기능이라도 사용법을 묻는 질문이면 appGuide 의도로 잡아야 한다',
      );
    });
  });

  group('unrelated / fallback 정책', () {
    test('상담도 앱 안내도 아닌 애매한 문장은 상담으로 fallback한다', () {
      final intent = router.detect('오늘 날씨가 좋네요.');

      expect(intent.needsCounseling, isTrue);
      expect(intent.needsAppGuidance, isFalse);
    });
  });

  group('repository 없이도 동작한다', () {
    test('entity 매칭 없이 usage 패턴만으로도 unknown feature를 잡는다', () {
      const routerWithoutRepo = DeterministicAssistantIntentRouter();

      final intent = routerWithoutRepo.detect('영상 통화 상담 어디서 해?');

      expect(intent.needsAppGuidance, isTrue);
    });
  });
}
