import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

class _CountingDataSource implements MindriumDataSource {
  int diaryCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() async {
    diaryCalls++;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> listWorryGroups() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listRelaxationTasks() async => const [];
}

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _load);
    await repository.initialize();
  });

  CounselingProvider buildProvider(_CountingDataSource source) {
    return CounselingProvider(
      knowledgeRepository: repository,
      currentWeek: 4,
      contextBuilder: MindriumContextBuilder(dataSource: source),
      harness: CounselingHarness(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
        turnPlanner: const DeterministicCounselingTurnPlanner(),
      ),
    );
  }

  Future<CounselingProvider> runToIntervention() async {
    final provider = buildProvider(_CountingDataSource());
    await provider.initialize();
    for (final message in [
      '사람들이 저를 무능하게 볼 것 같아요.',
      '그 생각을 바꾸기 어려워요.',
      '한 번 막히면 다 안다고 생각할 것 같아요.',
    ]) {
      await provider.sendMessage(message);
    }
    return provider;
  }

  group('추천은 화면 이동이 아니다', () {
    test('활동에는 사용자에게 보여줄 이름이 있다', () {
      for (final activity in CounselingActivity.values) {
        expect(activity.label, isNotEmpty, reason: activity.name);
      }
    });

    test('추천 문구는 강제하지 않고 여지를 남긴다', () {
      const recommendation = ActivityRecommendation(
        activity: CounselingActivity.alternativeThought,
      );

      final sentence = recommendation.suggestionSentence!;
      expect(sentence, contains('원하시면'));
      expect(sentence, contains('대안적 생각 작성 활동'));
      // 화면을 열라고 지시하지 않는다.
      expect(sentence, isNot(contains('눌러')));
      expect(sentence, isNot(contains('이동')));
    });

    test('활동이 없으면 추천 문구도 없다', () {
      expect(
        const ActivityRecommendation().suggestionSentence,
        isNull,
      );
    });

    test('추천 근거를 provenance 로 남긴다', () {
      final rec = const ActivityRecommendationPolicy().recommend(
        type: InterventionType.balancedThought,
        source: repository.getById('week4_alternative_thought_01'),
      );

      expect(rec.activity, CounselingActivity.alternativeThought);
      expect(rec.provenanceIds, ['week4_alternative_thought_01']);
      expect(rec.rationale, contains('balancedThought'));
    });
  });

  group('불변식', () {
    test('한 턴에 추천은 최대 하나이고 그 메시지에만 붙는다', () async {
      final provider = await runToIntervention();

      final withSuggestion = provider.messages
          .where((m) => provider.uiActionForMessage(m.id) != null)
          .toList();

      expect(withSuggestion.length, lessThanOrEqualTo(1));
    });

    test('새 턴이 오면 이전 추천은 사라진다', () async {
      final provider = await runToIntervention();
      final beforeId = provider.messages.last.id;

      await provider.sendMessage('네 알겠어요.');

      expect(provider.uiActionForMessage(beforeId), isNull);
    });

    test('위기 턴에는 추천이 없다', () async {
      final provider = buildProvider(_CountingDataSource());
      await provider.initialize();

      await provider.sendMessage('죽고 싶어요');

      expect(provider.pendingUiAction, isNull);
      expect(
        provider.uiActionForMessage(provider.messages.last.id),
        isNull,
      );
    });

    test('수행하지 않아도 상담은 계속된다', () async {
      final provider = await runToIntervention();
      final before = provider.messages.length;

      await provider.sendMessage('다른 이야기를 해도 될까요?');

      expect(provider.messages.length, greaterThan(before));
    });

    test('추천을 수행으로 간주하지 않는다', () async {
      final provider = await runToIntervention();

      // 추천이 있어도 세션 기억에 대안적 생각이 저절로 생기지 않는다.
      // 수행 여부는 서버 기록에 남았을 때만 인정한다.
      expect(provider.sessionSummary.alternativeThought, isNull);
    });

    test('추천이 화면 이동을 유발하는 경로가 없다', () {
      final chatPage = File('lib/chatbot/chatbot_main.dart').readAsStringSync();

      // 추천 때문에 라우트를 여는 코드가 남아 있으면 안 된다.
      expect(chatPage.contains('CounselingActivityRoute'), isFalse);
      expect(chatPage.contains('completeActivity'), isFalse);
      expect(
        File('lib/features/counseling/counseling_activity_route.dart').existsSync(),
        isFalse,
      );
    });
  });
}
