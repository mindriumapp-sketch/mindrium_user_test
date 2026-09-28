import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/assistant/retrieval/counseling_knowledge_retriever.dart';
import 'package:gad_app_team/features/assistant/retrieval/user_context_retriever.dart';

Future<String> _loadFromDisk(String path) => File(path).readAsString();

/// Phase 4 production adapter 검증 — 새 알고리즘이 아니라 기존 구현을
/// 그대로 감싸는지를 본다.
void main() {
  group('MindriumUserContextRetriever', () {
    const retriever = MindriumUserContextRetriever();

    test('context가 없으면 빈 RetrievalSummary를 돌려준다', () async {
      final result = await retriever.retrieve(
        const UserContextRequest(userMessage: '발표가 걱정돼요.'),
      );

      expect(result.retrievalSummary.hasPreviousSessionReference, isFalse);
      expect(result.provenanceIds, isEmpty);
      expect(result.degraded, isFalse);
    });

    test('context.degraded를 결과에 그대로 반영한다', () async {
      final result = await retriever.retrieve(
        UserContextRequest(
          userMessage: '발표가 걱정돼요.',
          context: const MindriumCounselingContext(
            currentWeek: 4,
            relevantItems: [],
            degraded: true,
          ),
        ),
      );

      expect(result.degraded, isTrue);
    });

    test('일기 항목이 있으면 provenance id로 남는다', () async {
      final result = await retriever.retrieve(
        UserContextRequest(
          userMessage: '발표가 계속 걱정돼요.',
          context: MindriumCounselingContext(
            currentWeek: 4,
            relevantItems: [
              UserContextItem(
                id: 'diary:abc123',
                type: UserContextType.diary,
                text: '상황: 발표 / 생각: 무능해 보일 것 같다',
                occurredAt: DateTime(2026, 9, 1),
              ),
            ],
          ),
        ),
      );

      expect(result.provenanceIds, contains('diary:abc123'));
    });
  });

  group('LocalCbtKnowledgeAdapter', () {
    late LocalCbtKnowledgeRepository repository;

    setUpAll(() async {
      repository = LocalCbtKnowledgeRepository(loadAsset: _loadFromDisk);
      await repository.initialize();
    });

    test('기존 CbtKnowledgeRepository.search()를 그대로 감싼다', () async {
      final adapter = LocalCbtKnowledgeAdapter(repository: repository);

      final direct = repository.search(
        query: '발표가 걱정돼요.',
        week: 4,
        limit: 3,
      );
      final result = await adapter.retrieve(
        const CounselingKnowledgeRequest(
          query: '발표가 걱정돼요.',
          week: 4,
          limit: 3,
        ),
      );

      expect(result.ids, direct.map((item) => item.id).toList());
      expect(result.items.length, direct.length);
      expect(result.degraded, isFalse);
    });

    test('일치하는 항목이 없으면 빈 결과다', () async {
      final adapter = LocalCbtKnowledgeAdapter(repository: repository);

      final result = await adapter.retrieve(
        const CounselingKnowledgeRequest(
          query: 'asdkjfhalsdkjfh 완전히 무관한 문자열',
          week: 999,
          limit: 3,
        ),
      );

      expect(result.items, isEmpty);
      expect(result.ids, isEmpty);
    });
  });
}
