import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/retrieval/app_guide_knowledge_retriever.dart';

Future<String> _loadFromDisk(String path) => File(path).readAsString();

/// Phase 6 — App Guide Knowledge Base 검증.
///
/// 가장 중요한 것은 "검색이 잘 되는가"보다 **"없는 기능을 만들지 않는가"**다
/// (마지막 그룹 참고).
void main() {
  late LocalAppGuideRepository repository;
  late LocalAppGuideKnowledgeRetriever retriever;

  setUpAll(() async {
    repository = LocalAppGuideRepository(loadAsset: _loadFromDisk);
    await repository.initialize();
    retriever = LocalAppGuideKnowledgeRetriever(repository: repository);
  });

  group('feature/alias lookup', () {
    test('정식 이름으로 기능을 찾는다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '이완 활동은 어떻게 해?'),
      );

      expect(result.hasMatch, isTrue);
      expect(
        result.matchedFeatures.map((f) => f.featureId),
        contains('relaxation'),
      );
      expect(result.confidence, greaterThan(0));
    });

    test('alias로도 같은 기능을 찾는다', () async {
      final byAlias = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '점진적 이완 하고 싶어요'),
      );
      final byName = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '이완 활동 하고 싶어요'),
      );

      expect(
        byAlias.matchedFeatures.map((f) => f.featureId),
        byName.matchedFeatures.map((f) => f.featureId),
      );
    });
  });

  group('screen/navigation lookup', () {
    test('"지난 걱정 어디서 봐?" → 보관함 관련 화면/내비게이션을 반환한다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '지난 걱정 어디서 봐?'),
      );

      expect(result.hasMatch, isTrue);
      expect(
        result.matchedFeatures.map((f) => f.featureId),
        contains('worry_archive'),
      );
      expect(result.navigationSteps, isNotEmpty);
      // 실제 코드에서 확인된 경로만 나와야 한다 — steps는 비어 있으면 안 됨.
      for (final path in result.navigationSteps) {
        expect(path.steps, isNotEmpty);
      }
    });

    test('AI 마음상담 화면을 찾으면 실제 내비게이션 경로가 함께 나온다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: 'AI 마음상담 어디서 해?'),
      );

      expect(
        result.matchedFeatures.map((f) => f.featureId),
        contains('ai_counseling'),
      );
      expect(
        result.navigationSteps.any((p) => p.to == 'ai_counseling'),
        isTrue,
      );
    });
  });

  group('manual/FAQ lookup', () {
    test('위젯 추가 방법은 실제 앱 튜토리얼 문구에서 그대로 온다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '위젯 어떻게 추가해요?'),
      );

      expect(result.manualKnowledge, isNotEmpty);
      expect(
        result.manualKnowledge.first.content,
        contains('Mindrium을 찾아 선택'),
      );
    });
  });

  group('provenance', () {
    test('매칭된 항목마다 source_refs가 있고 결과에 모인다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '리포트 확인하고 싶어요'),
      );

      expect(result.matchedFeatures, isNotEmpty);
      for (final feature in result.matchedFeatures) {
        expect(feature.sourceRefs, isNotEmpty);
      }
      expect(result.sourceRefs, isNotEmpty);
    });
  });

  group('hallucination-negative (핵심)', () {
    test('존재하지 않는 기능을 물으면 빈 결과다 — 가짜 화면/경로를 만들지 않는다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '영상 통화 상담은 어디서 해?'),
      );

      expect(result.hasMatch, isFalse);
      expect(result.matchedFeatures, isEmpty);
      expect(result.matchedScreens, isEmpty);
      expect(result.navigationSteps, isEmpty);
      expect(result.confidence, 0.0);
    });

    test('전혀 무관한 질문도 아무것도 만들어내지 않는다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '오늘 점심 메뉴 추천해줘'),
      );

      expect(result.hasMatch, isFalse);
    });

    test('일반적인 질문 어미만 있으면(구체적 대상 없음) 아무것도 매칭하지 않는다', () async {
      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '이거 어떻게 해?'),
      );

      expect(result.hasMatch, isFalse);
    });
  });

  group('degraded/empty', () {
    test('NoOpAppGuideKnowledgeRetriever는 항상 빈 결과다', () async {
      const noop = NoOpAppGuideKnowledgeRetriever();

      final result = await noop.retrieve(
        const AppGuideKnowledgeRequest(query: '이완 활동 어디서 해?'),
      );

      expect(result.hasMatch, isFalse);
      expect(result, same(AppGuideKnowledgeResult.empty));
    });
  });

  group('consistency (source_refs가 실제 코드를 가리키는지)', () {
    test('모든 feature/screen의 source_refs가 실제 존재하는 lib/ 파일을 가리킨다', () {
      // "flutter:경로#선택자" 형식에서 파일 경로만 뽑아 실제 존재 여부를
      // 확인한다. App Guide KB가 코드가 바뀐 뒤 방치되어 stale해지는 것을
      // 잡기 위한 최소한의 가드다.
      final allRefs = [
        for (final f in repository.features) ...f.sourceRefs,
        for (final s in repository.screens) ...s.sourceRefs,
        for (final n in repository.navigationPaths) ...n.sourceRefs,
        for (final m in repository.manualEntries) ...m.sourceRefs,
      ];

      expect(allRefs, isNotEmpty);

      for (final ref in allRefs) {
        if (!ref.startsWith('flutter:')) continue;
        final path = ref.substring('flutter:'.length).split('#').first;
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$ref 이 가리키는 파일이 더 이상 존재하지 않는다 — KB가 stale해졌다.',
        );
      }
    });
  });
}
