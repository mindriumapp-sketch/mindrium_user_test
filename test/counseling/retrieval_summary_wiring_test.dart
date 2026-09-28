import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

/// planner 가 실제로 받은 컨텍스트를 붙잡아 둔다.
class _SpyPlanner implements CounselingTurnPlanner {
  final CounselingTurnPlanner inner;
  TurnPlanningContext? received;

  _SpyPlanner(this.inner);

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    received = context;
    return inner.plan(context);
  }
}

MindriumCounselingContext _context() => MindriumCounselingContext(
  currentWeek: 4,
  relevantItems: [
    UserContextItem(
      id: 'diary:abc123',
      type: UserContextType.diary,
      text: '[발표 전 긴장] 상황: 연구 발표 / 생각: 실수하면 준비를 안 한 사람처럼 보일 것이다',
      occurredAt: DateTime(2026, 9, 1),
      sud: 8,
    ),
    UserContextItem(
      id: 'alt:zzz999',
      type: UserContextType.alternativeThought,
      text: '이전에 찾은 도움이 되는 생각: 준비한 내용은 설명할 수 있다',
      occurredAt: DateTime(2026, 9, 1),
    ),
  ],
  recentSud: const SudContext(
    latest: 8,
    weeklyAverage: 7.1,
    trend: 'increasing',
  ),
);

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _load);
    await repository.initialize();
  });

  Future<({CounselingTurnResult result, _SpyPlanner spy})> runTurn({
    MindriumCounselingContext? userContext,
    String userMessage = '질문에 답하지 못하면 사람들이 저를 무능하게 볼 것 같아요.',
  }) async {
    final spy = _SpyPlanner(const DeterministicCounselingTurnPlanner());
    final harness = CounselingHarness(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      turnPlanner: spy,
    );

    final result = await harness.handleTurn(
      session: CounselingSessionState(
        sessionId: 'test',
        currentWeek: 4,
        state: CounselingState.reflect,
        userContext: userContext,
      ),
      userMessage: userMessage,
    );

    return (result: result, spy: spy);
  }

  test('harness 가 planner 에 요약을 채워 넘긴다', () async {
    final run = await runTurn(userContext: _context());
    final summary = run.spy.received!.retrievalSummary;

    expect(summary.currentTheme, '발표 전 긴장');
    expect(summary.currentThought, '질문에 답하지 못하면 사람들이 저를 무능하게 볼 것 같아요.');
    expect(summary.similarPastThought, '실수하면 준비를 안 한 사람처럼 보일 것이다');
    expect(summary.previousAlternativeThought, '준비한 내용은 설명할 수 있다');
    expect(summary.recentSud, 8);
    expect(summary.sudTrend, 'increasing');
    expect(summary.hasPastReference, isTrue);
  });

  test('기존 userContext 경로도 그대로 남아 있다', () async {
    final run = await runTurn(userContext: _context());

    // 점진 전환 중이므로 두 경로가 함께 존재해야 한다.
    expect(run.spy.received!.userContext, isNotNull);
    expect(run.spy.received!.retrievalSummary.isEmpty, isFalse);
  });

  test('구성 근거가 턴 결과에 남는다', () async {
    final run = await runTurn(userContext: _context());

    expect(
      run.result.retrievalProvenanceIds,
      containsAll(['alt:zzz999', 'diary:abc123']),
    );
  });

  test('사용자 기록이 없으면 요약이 비고 근거도 없다', () async {
    final run = await runTurn();

    expect(run.spy.received!.retrievalSummary.hasPastReference, isFalse);
    expect(run.result.retrievalProvenanceIds, isEmpty);
  });

  test('안전 턴은 planner 도 요약도 거치지 않는다', () async {
    final spy = _SpyPlanner(const DeterministicCounselingTurnPlanner());
    final harness = CounselingHarness(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      turnPlanner: spy,
    );

    final result = await harness.handleTurn(
      session: CounselingSessionState(
        sessionId: 'test',
        currentWeek: 4,
        state: CounselingState.reflect,
        userContext: _context(),
      ),
      userMessage: '죽고 싶어요',
    );

    expect(result.handledBySafety, isTrue);
    expect(spy.received, isNull);
    expect(result.retrievalProvenanceIds, isEmpty);
  });

  test('withDerivedSummary 는 userContext 만으로 요약을 만든다', () {
    final context = TurnPlanningContext(
      state: CounselingState.reflect,
      currentWeek: 4,
      userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
      knowledge: const [],
      userContext: _context(),
    );

    expect(context.retrievalSummary.isEmpty, isTrue);
    expect(context.withDerivedSummary().retrievalSummary.isEmpty, isFalse);
  });
}
