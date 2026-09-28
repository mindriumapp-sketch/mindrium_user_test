import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

/// 저장 호출을 기록하는 가짜 API. 서버 upsert 규칙도 흉내 낸다.
class _FakeSessionsApi implements CounselingSessionsApi {
  final List<Map<String, dynamic>> saved = [];
  bool fail = false;

  @override
  Future<Map<String, dynamic>> upsertSession({
    required String sessionId,
    required int week,
    required String completionStatus,
    required DateTime startedAt,
    required DateTime endedAt,
    String? finalState,
    String? safetyLevel,
    String? mainConcern,
    String? coreThought,
    String? coreThoughtSource,
    String? alternativeThought,
    String? affect,
    int? sudStart,
    int? sudEnd,
    String? interventionUsed,
    String? activityRecommended,
    String? unfinishedIssue,
    List<String> provenanceIds = const [],
    int turnCount = 0,
  }) async {
    if (fail) throw StateError('network');
    saved.add({
      'session_id': sessionId,
      'completion_status': completionStatus,
      'week': week,
      'final_state': finalState,
      'main_concern': mainConcern,
      'core_thought': coreThought,
      'core_thought_source': coreThoughtSource,
      'alternative_thought': alternativeThought,
      'unfinished_issue': unfinishedIssue,
      'provenance_ids': provenanceIds,
      'turn_count': turnCount,
    });
    return saved.last;
  }

  @override
  Future<List<Map<String, dynamic>>> listSessions({
    int limit = 5,
    String? completionStatus,
  }) async => saved;
}

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _load);
    await repository.initialize();
  });

  CounselingProvider build(_FakeSessionsApi api) => CounselingProvider(
    knowledgeRepository: repository,
    currentWeek: 4,
    sessionsApi: api,
    harness: CounselingHarness(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      turnPlanner: const DeterministicCounselingTurnPlanner(),
    ),
  );

  /// closing 까지 진행시킨다.
  Future<CounselingProvider> runToClosing(_FakeSessionsApi api) async {
    final provider = build(api);
    await provider.initialize();

    var guard = 0;
    while (provider.state != CounselingState.closing && guard < 12) {
      await provider.sendMessage('사람들이 저를 무능하게 볼 것 같아요. $guard');
      guard++;
    }
    return provider;
  }

  group('정상 종료 저장', () {
    test('closing 최초 진입에 completed 로 저장한다', () async {
      final api = _FakeSessionsApi();
      final provider = await runToClosing(api);

      expect(provider.state, CounselingState.closing);
      expect(api.saved, hasLength(1));
      expect(api.saved.single['completion_status'], 'completed');
      expect(api.saved.single['session_id'], isNotEmpty);
    });

    test('closing 이 여러 턴 유지돼도 다시 저장하지 않는다', () async {
      final api = _FakeSessionsApi();
      final provider = await runToClosing(api);

      await provider.sendMessage('네 알겠습니다.');
      await provider.sendMessage('고맙습니다.');

      // "closing 인 매 턴"이 아니라 "closing 으로 넘어가는 순간"이 기준이다.
      expect(api.saved, hasLength(1));
    });

    test('구조화 요약을 담아 보낸다', () async {
      final api = _FakeSessionsApi();
      await runToClosing(api);

      final sent = api.saved.single;
      expect(sent['week'], 4);
      expect(sent['final_state'], 'closing');
      expect(sent['turn_count'], greaterThan(0));
      expect(sent.containsKey('core_thought'), isTrue);
      expect(sent.containsKey('provenance_ids'), isTrue);
    });
  });

  group('이탈 저장', () {
    test('중간에 나가면 interrupted 로 저장한다', () async {
      final api = _FakeSessionsApi();
      final provider = build(api);
      await provider.initialize();
      await provider.sendMessage('사람들이 저를 무능하게 볼 것 같아요.');

      await provider.finalizeIfIncomplete();

      expect(api.saved, hasLength(1));
      expect(api.saved.single['completion_status'], 'interrupted');
    });

    test('이미 completed 면 이탈 저장이 덮어쓰지 않는다', () async {
      final api = _FakeSessionsApi();
      final provider = await runToClosing(api);

      await provider.finalizeIfIncomplete();

      // 두 경로가 같은 세션을 두고 경쟁하지 않아야 한다.
      expect(api.saved, hasLength(1));
      expect(api.saved.single['completion_status'], 'completed');
    });

    test('같은 턴의 pause와 dispose snapshot은 한 번만 저장한다', () async {
      final api = _FakeSessionsApi();
      final provider = build(api);
      await provider.initialize();
      await provider.sendMessage('사람들이 저를 무능하게 볼 것 같아요.');

      await Future.wait([
        provider.finalizeIfIncomplete(),
        provider.finalizeIfIncomplete(),
      ]);

      expect(api.saved, hasLength(1));
      expect(api.saved.single['completion_status'], 'interrupted');
    });

    test('중단 저장 뒤 대화가 진행되면 더 최신 snapshot을 저장한다', () async {
      final api = _FakeSessionsApi();
      final provider = build(api);
      await provider.initialize();
      await provider.sendMessage('발표가 걱정돼요.');
      await provider.finalizeIfIncomplete();

      await provider.sendMessage('질문에 답하지 못할까 봐 걱정돼요.');
      await provider.finalizeIfIncomplete();

      expect(api.saved, hasLength(2));
      expect(
        api.saved.last['turn_count'],
        greaterThan(api.saved.first['turn_count'] as int),
      );
    });

    test('내용이 없으면 저장하지 않는다', () async {
      final api = _FakeSessionsApi();
      final provider = build(api);
      await provider.initialize();

      await provider.finalizeIfIncomplete();

      // 인사만 하고 나간 세션은 남길 것이 없다.
      expect(api.saved, isEmpty);
    });
  });

  group('상담을 막지 않는다', () {
    test('저장에 실패해도 대화가 이어진다', () async {
      final api = _FakeSessionsApi()..fail = true;
      final provider = build(api);
      await provider.initialize();

      await provider.sendMessage('사람들이 저를 무능하게 볼 것 같아요.');
      await provider.finalizeIfIncomplete();
      await provider.sendMessage('계속 이야기할 수 있나요?');

      expect(provider.messages.length, greaterThan(2));
    });

    test('API 가 없으면 저장 없이 동작한다', () async {
      final provider = CounselingProvider(
        knowledgeRepository: repository,
        currentWeek: 4,
        harness: CounselingHarness(
          llm: MockLlmService(),
          safetyGate: const KeywordSafetyGate(),
          knowledgeRepository: repository,
          turnPlanner: const DeterministicCounselingTurnPlanner(),
        ),
      );
      await provider.initialize();

      await provider.sendMessage('사람들이 저를 무능하게 볼 것 같아요.');
      await provider.finalizeIfIncomplete();

      expect(provider.messages, isNotEmpty);
    });
  });

  group('저장 범위', () {
    test('대화 원문을 통째로 보내지 않는다', () async {
      final api = _FakeSessionsApi();
      await runToClosing(api);

      final sent = api.saved.single;
      // 전체 transcript, 프롬프트, 모델 출력은 저장 대상이 아니다.
      expect(sent.containsKey('messages'), isFalse);
      expect(sent.containsKey('transcript'), isFalse);
      expect(sent.containsKey('prompt'), isFalse);
    });

    test('API 계약에 원문 필드가 없다', () {
      final source =
          File('lib/data/api/counseling_sessions_api.dart').readAsStringSync();

      expect(source.contains("'messages'"), isFalse);
      expect(source.contains("'transcript'"), isFalse);
      expect(source.contains("'prompt'"), isFalse);
    });
  });
}
