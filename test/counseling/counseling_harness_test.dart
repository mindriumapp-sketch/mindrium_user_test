// Phase 10.7B: this file used to test CounselingHarness's raw-LLM
// generation path (bare `CounselingHarness(...)` construction, no
// `turnPlanner` — which used to fall through to a direct `llm.generate()` +
// `CounselingOutputParser.parse()` branch inside `handleTurn()`). That
// branch was confirmed unreachable from both production factories
// (`.deterministic()`/`.remoteGpt()` always set a `turnPlanner`) and has
// been removed from `counseling_harness.dart`. Most of what this file used
// to assert (prompt content for a given profile, CBT/user-context id
// scrubbing, dialogue_act override, JSON-parse fallback) either no longer
// applies (deterministic output can't invent an id or an act to scrub —
// `parsed.referencedCbtIds`/`dialogueAct` come straight from `turnPlan`,
// not from free-text model output) or is covered elsewhere against the
// actually-reachable Remote-realization path (`remote_llm_realizer_test.dart`,
// `adaptive_dialogue_policy_test.dart`, `hybrid_turn_router_gating_test.dart`).
// What remains here is the handful of properties that don't depend on that
// removed branch at all: safety gating (short-circuits before any
// planner/realizer code runs) and `CounselingStatePolicy`'s pure logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/activity_recommendation.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'dart:io';

Future<String> loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  CounselingHarness harnessWith(MockLlmService llm) {
    return CounselingHarness(
      llm: llm,
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
    );
  }

  CounselingSessionState newSession({
    CounselingState state = CounselingState.explore,
    int week = 4,
  }) {
    return CounselingSessionState(
      sessionId: 'test',
      currentWeek: week,
      state: state,
    );
  }

  test('T6 위기 발화는 LLM 을 호출하지 않는다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);
    final session = newSession();

    final result = await harness.handleTurn(
      session: session,
      userMessage: '요즘 그냥 죽고 싶어요.',
    );

    expect(llm.receivedRequests, isEmpty);
    expect(result.handledBySafety, isTrue);
    expect(result.safety.level, SafetyLevel.crisis);
    expect(result.safety.reasonCode, 'keyword_crisis');
    expect(result.assistantMessage.text, contains('109'));
  });

  test('T6 주의 수준도 LLM 을 호출하지 않는다', () async {
    final llm = MockLlmService();
    final harness = harnessWith(llm);

    final result = await harness.handleTurn(
      session: newSession(),
      userMessage: '요즘 공황이 와서 견딜 수 없어요.',
    );

    expect(llm.receivedRequests, isEmpty);
    expect(result.handledBySafety, isTrue);
    expect(result.safety.level, SafetyLevel.elevated);
    expect(result.uiAction, CounselingActivity.relaxation);
  });

  test('T6 안전 대응 턴은 상담 단계를 진행시키지 않는다', () async {
    final harness = harnessWith(MockLlmService());
    final session = newSession(state: CounselingState.explore);

    final result = await harness.handleTurn(
      session: session,
      userMessage: '자해 생각이 들어요.',
    );

    expect(result.state, CounselingState.explore);
    expect(session.state, CounselingState.explore);
    expect(session.turnsInCurrentState, 0);
  });

  test('T7 상태마다 허용 행위가 달라진다', () {
    expect(
      CounselingState.explore.allowedActs,
      isNot(equals(CounselingState.closing.allowedActs)),
    );
    expect(CounselingState.closing.allowedActs, contains(DialogueAct.closing));
    expect(
      CounselingState.explore.allowedActs,
      isNot(contains(DialogueAct.closing)),
    );
  });

  test('T15 단계별 턴 예산을 다 쓰면 다음 단계로 넘어간다', () async {
    const policy = CounselingStatePolicy();

    // 되짚기는 예산이 2턴이다. 1턴을 끝낸 상태에서 이번 턴이 마지막이 된다.
    expect(policy.budgetFor(CounselingState.reflect), 2);
    expect(
      policy.next(
        current: CounselingState.reflect,
        turnsInCurrentState: 1,
        totalTurns: 5,
        lastAct: DialogueAct.reflect,
      ),
      CounselingState.intervention,
    );

    // 예산이 남아 있으면 머문다.
    expect(
      policy.next(
        current: CounselingState.reflect,
        turnsInCurrentState: 0,
        totalTurns: 5,
        lastAct: DialogueAct.reflect,
      ),
      CounselingState.reflect,
    );

    // 승인 개입은 한 턴에 하나만 수행하고 곧바로 마무리로 이동한다.
    expect(policy.budgetFor(CounselingState.intervention), 1);
    expect(
      policy.next(
        current: CounselingState.intervention,
        turnsInCurrentState: 0,
        totalTurns: 5,
        lastAct: DialogueAct.socraticQuestion,
      ),
      CounselingState.closing,
    );
  });

  test('T15 모델의 발화 행위는 진행을 앞당기기만 한다', () {
    const policy = CounselingStatePolicy();

    // 되비추기가 나오면 탐색 예산이 남아 있어도 되짚기로 넘어간다.
    expect(
      policy.next(
        current: CounselingState.explore,
        turnsInCurrentState: 0,
        totalTurns: 1,
        lastAct: DialogueAct.reflect,
      ),
      CounselingState.reflect,
    );

    // 반대로 단계를 되돌리거나 건너뛰지는 못한다.
    expect(
      policy.next(
        current: CounselingState.checkIn,
        turnsInCurrentState: 0,
        totalTurns: 0,
        lastAct: DialogueAct.closing,
      ),
      CounselingState.explore,
    );
  });

  test('T15 세션 최대 턴을 넘으면 마무리로 보낸다', () {
    const policy = CounselingStatePolicy();

    final state = policy.next(
      current: CounselingState.explore,
      turnsInCurrentState: 0,
      totalTurns: CounselingStatePolicy.maxSessionTurns,
      lastAct: DialogueAct.explore,
    );

    expect(state, CounselingState.closing);
  });
}
