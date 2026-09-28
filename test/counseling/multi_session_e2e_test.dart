import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

/// 서버를 흉내 내는 저장소. upsert 규칙과 정렬까지 재현한다.
class _InMemorySessionsApi implements CounselingSessionsApi {
  final Map<String, Map<String, dynamic>> _rows = {};

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
    final existing = _rows[sessionId];
    // 완료된 세션은 이탈 스냅샷으로 덮어쓰지 않는다.
    if (existing != null &&
        existing['completion_status'] == 'completed' &&
        completionStatus != 'completed') {
      return existing;
    }

    _rows[sessionId] = {
      'session_id': sessionId,
      'week': week,
      'completion_status': completionStatus,
      'final_state': finalState,
      'main_concern': mainConcern,
      'core_thought': coreThought,
      'core_thought_source': coreThoughtSource,
      'alternative_thought': alternativeThought,
      'sud_end': sudEnd,
      'intervention_used': interventionUsed,
      'activity_recommended': activityRecommended,
      'unfinished_issue': unfinishedIssue,
      'provenance_ids': provenanceIds,
      'turn_count': turnCount,
      'ended_at': endedAt.toIso8601String(),
    };
    return _rows[sessionId]!;
  }

  @override
  Future<List<Map<String, dynamic>>> listSessions({
    int limit = 5,
    String? completionStatus,
  }) async {
    final rows = _rows.values
        .where(
          (r) =>
              completionStatus == null ||
              r['completion_status'] == completionStatus,
        )
        .toList()
      ..sort(
        (a, b) => (b['ended_at'] as String).compareTo(a['ended_at'] as String),
      );
    return rows.take(limit).toList();
  }
}

class _EmptyDataSource implements MindriumDataSource {
  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() async => const [];
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

  CounselingProvider newSession(_InMemorySessionsApi api) => CounselingProvider(
    knowledgeRepository: repository,
    currentWeek: 4,
    sessionsApi: api,
    instantEmpathy: true,
    contextBuilder: MindriumContextBuilder(dataSource: _EmptyDataSource()),
    harness: CounselingHarness(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      turnPlanner: const DeterministicCounselingTurnPlanner(),
    ),
  );

  /// 발표 불안 시나리오를 closing 까지 진행한다.
  Future<CounselingProvider> runFullSession(_InMemorySessionsApi api) async {
    final provider = newSession(api);
    await provider.initialize();

    const script = [
      '내일 발표가 있어서 불안해요.',
      '질문에 답을 못할까 봐 걱정돼요.',
      '사람들이 저를 무능하게 볼 것 같아요.',
      '한 번 막히면 준비를 안 했다고 생각할 것 같아요.',
      '완벽하게 답하지 못해도 준비한 내용은 설명할 수 있어요.',
    ];

    for (final message in script) {
      await provider.sendMessage(message);
      if (provider.state == CounselingState.closing) break;
    }
    // Phase 13.5: answer the closing proposal so the session is finalized
    // (and saved as completed), and keep answering any pending question.
    for (var i = 0; i < 4 && !provider.isSessionFinalized; i++) {
      await provider.sendMessage(
        provider.state == CounselingState.closing ? '네' : '준비한 만큼은 설명할 수 있을 것 같아요.',
      );
    }
    return provider;
  }

  test('G 세션1 종료 → 저장 → 세션2 개인화가 이어진다', () async {
    final api = _InMemorySessionsApi();

    // ── 세션 1 ──
    final first = await runFullSession(api);
    await first.finalizeIfIncomplete();

    final saved = await api.listSessions();
    expect(saved, hasLength(1), reason: '세션 하나만 저장되어야 한다');
    expect(saved.single['core_thought'], isNotNull);

    // ── 세션 2 ──
    final second = newSession(api);
    await second.initialize();

    expect(second.previousSession, isNotNull, reason: '지난 세션을 읽어야 한다');
    expect(second.previousSession!.isCompleted, isTrue);

    // 같은 주제로 다시 이야기하면 지난 상담을 이어받는다.
    await second.sendMessage('또 발표가 있는데 걱정돼요.');

    final empathy = second.lastEmpathy!;
    expect(empathy.referencedPast, isTrue);
    expect(empathy.sentence, contains('지난 상담'));
    expect(
      empathy.provenanceIds.any((id) => id.startsWith('session:')),
      isTrue,
      reason: '근거로 세션 id 를 남겨야 한다',
    );
  });

  test('G 다른 주제면 지난 상담을 꺼내지 않는다', () async {
    final api = _InMemorySessionsApi();
    final first = await runFullSession(api);
    await first.finalizeIfIncomplete();

    final second = newSession(api);
    await second.initialize();

    await second.sendMessage('요즘 친구랑 사이가 어색해요.');

    final empathy = second.lastEmpathy!;
    // 지난 세션은 발표였다. 인간관계 이야기에 꺼내면 안 된다.
    expect(empathy.sentence, isNot(contains('지난 상담')));
    expect(
      empathy.provenanceIds.any((id) => id.startsWith('session:')),
      isFalse,
    );
  });

  test('G 공감과 질문이 한 턴에 겹치지 않는다', () async {
    final api = _InMemorySessionsApi();
    final first = await runFullSession(api);
    await first.finalizeIfIncomplete();

    final second = newSession(api);
    await second.initialize();
    await second.sendMessage('또 발표가 있는데 걱정돼요.');

    final empathy = second.lastEmpathy!.sentence;
    final reply = second.messages.last.text;

    // 공감에는 질문이 없고, 상담 응답에만 질문이 하나 있다.
    expect(empathy.contains('?'), isFalse);
    expect('?'.allMatches(reply).length, lessThanOrEqualTo(1));
  });

  test('G 중단된 세션은 주 참고 대상이 되지 않는다', () async {
    final api = _InMemorySessionsApi();

    final interrupted = newSession(api);
    await interrupted.initialize();
    await interrupted.sendMessage('사람들이 저를 무능하게 볼 것 같아요.');
    await interrupted.finalizeIfIncomplete();

    expect(
      (await api.listSessions()).single['completion_status'],
      'interrupted',
    );

    final next = newSession(api);
    await next.initialize();

    // 완료 세션이 없으므로 참고 대상도 없다.
    expect(next.previousSession, isNull);
  });

  test('G 세션 저장이 실패해도 다음 상담이 시작된다', () async {
    final next = newSession(_InMemorySessionsApi());
    await next.initialize();

    await next.sendMessage('발표가 걱정돼요.');

    expect(next.previousSession, isNull);
    expect(next.messages.length, greaterThan(1));
  });
}
