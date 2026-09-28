// Phase 12.3 follow-up (N4): mid-session, a counseling message with no
// worry/anxiety word was routed to the app guide because a single word
// ("작성") overlapped an app feature name. Real device (dogfood session 4).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/intent/assistant_intent_router.dart';
import 'package:gad_app_team/features/assistant/response/app_guide_response_builder.dart';
import 'package:gad_app_team/features/assistant/retrieval/app_guide_knowledge_retriever.dart';

Future<String> _load(String path) => File(path).readAsString();

void main() {
  late DeterministicAssistantIntentRouter router;

  setUpAll(() async {
    final repository = LocalAppGuideRepository(loadAsset: _load);
    await repository.initialize();
    router = DeterministicAssistantIntentRouter(repository: repository);
  });

  const counselingContent = [
    '수업 과제도 해야하고 공모전 준비, 논문 작성, 융합연구 미팅준비 등 할게 진짜 많아', // dogfood s4
    '다른 관점에서 어떻게 봐야할지 모르겠어', // dogfood s5: usage pattern "어떻게 … 봐" without an app term
    '이 상황을 어떻게 해야 할지 모르겠어',
    '어디서부터 해야 할지 모르겠어요',
    '내일 미팅인데 준비를 하나도 못했어',
    '오늘 할 일을 하나도 못 끝냈어',
  ];

  test('reproduces: without session context the dogfood message goes to app guide', () {
    expect(router.detect(counselingContent.first).needsAppGuidance, isTrue);
  });

  group('in an ongoing counseling session, content stays counseling', () {
    for (final m in counselingContent) {
      test(m, () {
        final intent = router.detect(m, counselingInProgress: true);
        expect(intent.isCounselingOnly, isTrue, reason: '$intent');
      });
    }
  });

  group('explicit app-usage questions still reach the app guide mid-session', () {
    for (final m in [
      '지난 걱정 기록은 어디서 봐?',
      '알림 설정은 어떻게 바꿔?',
      '위젯은 어떻게 추가해?',
    ]) {
      test(m, () {
        expect(router.detect(m, counselingInProgress: true).needsAppGuidance, isTrue);
      });
    }
  });

  group('app-guide answer uses the right topic particle', () {
    late LocalAppGuideRepository repository;
    setUpAll(() async {
      repository = LocalAppGuideRepository(loadAsset: _load);
      await repository.initialize();
    });

    test('"걱정 기록는" no longer appears (dogfood session 4)', () async {
      final knowledge = await LocalAppGuideKnowledgeRetriever(repository: repository)
          .retrieve(const AppGuideKnowledgeRequest(query: '걱정 기록은 어디서 봐?'));
      final text = const DeterministicAppGuideResponseBuilder().build('걱정 기록은 어디서 봐?', knowledge).text;
      expect(text.contains('기록는'), isFalse, reason: text);
    });
  });
}
