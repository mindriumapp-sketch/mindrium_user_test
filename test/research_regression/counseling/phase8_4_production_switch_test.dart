// Phase 8.4: production switch integration equivalence.
//
// Compares `CounselingHarness.handleTurn()` results between:
//   - a harness wired with the legacy composite planner
//     (`DeterministicCounselingTurnPlanner`), and
//   - the actual production harness (`CounselingHarness.deterministic()`),
//     which now defaults to `PolicyPipelineTurnPlanner`
//     (PolicyBoundaryBuilder -> DeterministicCounselorAgent -> TurnPlanAdapter).
//
// Both harnesses must produce equivalent results across representative
// states, since Phase 8.4 is a behavior-preserving migration.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';
import 'package:gad_app_team/features/counseling/turn_plan_prompt_builder.dart';

Future<String> loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  CounselingHarness legacyHarness() => CounselingHarness(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
        turnPlanner: const DeterministicCounselingTurnPlanner(),
        // Match every other assembly choice `CounselingHarness.deterministic()`
        // makes so the only variable under test is the planner pipeline.
        promptBuilder: const TurnPlanPromptBuilder(),
      );

  CounselingHarness productionHarness() => CounselingHarness.deterministic(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      );

  CounselingSessionState session({
    CounselingState state = CounselingState.explore,
    int week = 4,
    MindriumCounselingContext? userContext,
    List<CounselingMessage>? messages,
  }) {
    return CounselingSessionState(
      sessionId: 'phase8_4',
      currentWeek: week,
      state: state,
      userContext: userContext,
      messages: messages,
    );
  }

  MindriumCounselingContext contextWithDiary() {
    return MindriumCounselingContext(
      currentWeek: 4,
      relevantItems: [
        UserContextItem(
          id: 'diary:abc123',
          type: UserContextType.diary,
          text: '상황: 연구 발표 / 생각: 질문에 답을 못하면 무능해 보일 것이다',
          occurredAt: DateTime(2026, 8, 30),
          sud: 7,
        ),
      ],
      recentSud: const SudContext(
        latest: 7,
        weeklyAverage: 6.3,
        trend: 'increasing',
      ),
    );
  }

  Future<void> expectEquivalent({
    required CounselingSessionState Function() buildSession,
    required String userMessage,
  }) async {
    final legacyResult = await legacyHarness().handleTurn(
      session: buildSession(),
      userMessage: userMessage,
    );
    final productionResult = await productionHarness().handleTurn(
      session: buildSession(),
      userMessage: userMessage,
    );

    expect(
      productionResult.assistantMessage.text,
      legacyResult.assistantMessage.text,
      reason: 'reply text differs',
    );
    expect(
      productionResult.assistantMessage.dialogueAct,
      legacyResult.assistantMessage.dialogueAct,
      reason: 'dialogueAct differs',
    );
    expect(
      productionResult.assistantMessage.dialogueGoalId,
      legacyResult.assistantMessage.dialogueGoalId,
      reason: 'dialogueGoalId differs',
    );
    expect(
      productionResult.assistantMessage.referencedCbtIds,
      legacyResult.assistantMessage.referencedCbtIds,
    );
    expect(
      productionResult.assistantMessage.referencedUserContextIds,
      legacyResult.assistantMessage.referencedUserContextIds,
    );
    expect(productionResult.uiAction, legacyResult.uiAction);
    expect(
      productionResult.turnPlan?.allowedActsForTurn,
      legacyResult.turnPlan?.allowedActsForTurn,
    );
    expect(
      productionResult.retrievalProvenanceIds,
      legacyResult.retrievalProvenanceIds,
    );
    expect(productionResult.state, legacyResult.state);
    expect(productionResult.stateBefore, legacyResult.stateBefore);
  }

  group('Phase 8.4 production switch equivalence', () {
    test('CheckIn', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.checkIn),
        userMessage: '요즘 발표 준비 때문에 계속 긴장돼요.',
      );
    });

    test('Explore 일반', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.explore),
        userMessage: '내일 발표인데 너무 불안해요.',
      );
    });

    test('Explore SUD 특수 경로', () async {
      await expectEquivalent(
        buildSession: () => session(
          state: CounselingState.explore,
          messages: [
            CounselingMessage(
              id: 'm1',
              role: 'user',
              text: '발표 생각만 하면 심장이 빨리 뛰어요.',
              createdAt: DateTime(2026, 9, 1),
            ),
            CounselingMessage(
              id: 'm2',
              role: 'assistant',
              text: '지금 불안이 몇 점 정도 되나요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.explore,
            ),
          ],
        ),
        userMessage: '6점이요',
      );
    });

    test('Reflect evidence goal', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.reflect, week: 3),
        userMessage: '사람들이 나를 무능하게 볼 것 같다는 생각이 들어요.',
      );
    });

    test('Reflect alternative goal', () async {
      await expectEquivalent(
        buildSession: () => session(
          state: CounselingState.reflect,
          week: 3,
          messages: [
            CounselingMessage(
              id: 'm1',
              role: 'user',
              text: '사람들이 나를 무능하게 볼 것 같아요.',
              createdAt: DateTime(2026, 9, 1),
            ),
            CounselingMessage(
              id: 'm2',
              role: 'assistant',
              text: '그렇게 생각하시는 근거가 있을까요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.socraticQuestion,
              dialogueGoalId: ReflectQuestionGoal.evidence.name,
            ),
          ],
        ),
        userMessage: '딱히 근거는 없는 것 같아요.',
      );
    });

    test('Reflect probability goal', () async {
      await expectEquivalent(
        buildSession: () => session(
          state: CounselingState.reflect,
          week: 3,
          messages: [
            CounselingMessage(
              id: 'm1',
              role: 'user',
              text: '사람들이 나를 무능하게 볼 것 같아요.',
              createdAt: DateTime(2026, 9, 1),
            ),
            CounselingMessage(
              id: 'm2',
              role: 'assistant',
              text: '근거가 있을까요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.socraticQuestion,
              dialogueGoalId: ReflectQuestionGoal.evidence.name,
            ),
            CounselingMessage(
              id: 'm3',
              role: 'user',
              text: '딱히 없어요.',
              createdAt: DateTime(2026, 9, 1),
            ),
            CounselingMessage(
              id: 'm4',
              role: 'assistant',
              text: '다르게 볼 방법이 있을까요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.socraticQuestion,
              dialogueGoalId: ReflectQuestionGoal.alternative.name,
            ),
          ],
        ),
        userMessage: '음 그럴 수도 있겠네요.',
      );
    });

    test('Reflect goal exhausted (반복)', () async {
      await expectEquivalent(
        buildSession: () => session(
          state: CounselingState.reflect,
          week: 3,
          messages: [
            CounselingMessage(
              id: 'm1',
              role: 'user',
              text: '사람들이 나를 무능하게 볼 것 같아요.',
              createdAt: DateTime(2026, 9, 1),
            ),
            CounselingMessage(
              id: 'm2',
              role: 'assistant',
              text: '근거가 있을까요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.socraticQuestion,
              dialogueGoalId: ReflectQuestionGoal.evidence.name,
            ),
            CounselingMessage(
              id: 'm3',
              role: 'assistant',
              text: '다르게 볼 방법이 있을까요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.socraticQuestion,
              dialogueGoalId: ReflectQuestionGoal.alternative.name,
            ),
            CounselingMessage(
              id: 'm4',
              role: 'assistant',
              text: '실제로 그럴 확률이 얼마나 될까요?',
              createdAt: DateTime(2026, 9, 1),
              dialogueAct: DialogueAct.socraticQuestion,
              dialogueGoalId: ReflectQuestionGoal.probability.name,
            ),
          ],
        ),
        userMessage: '잘 모르겠어요.',
      );
    });

    test('Reflect clarify (실제 thought 없음)', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.reflect, week: 3),
        userMessage: '그냥 좀 그래요.',
      );
    });

    test('Intervention balancedThought', () async {
      await expectEquivalent(
        buildSession: () => session(
          state: CounselingState.intervention,
          week: 4,
          userContext: contextWithDiary(),
        ),
        userMessage: '생각을 바꾸는 게 잘 안 돼요.',
      );
    });

    test('Intervention avoidance (gainLossReview)', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.intervention, week: 7),
        userMessage: '발표 때 질문을 피하려고 원고만 계속 봐요.',
      );
    });

    test('Intervention maintenance', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.intervention, week: 8),
        userMessage: '발표 전에 천천히 호흡하는 방법이 도움이 됐어요.',
      );
    });

    test('Intervention unavailable', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.intervention, week: 1),
        userMessage: '오늘은 뭘 이야기해야 할까요?',
      );
    });

    test('Closing with summary target', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.closing),
        userMessage: '발표 걱정 이야기를 나눴어요.',
      );
    });

    test('Closing without summary target', () async {
      await expectEquivalent(
        buildSession: () => session(state: CounselingState.closing),
        userMessage: '네, 감사합니다.',
      );
    });
  });

  // The "CounselingHarness.deterministic() no longer wires the legacy
  // composite planner" live-wiring guard moved to
  // test/counseling/counseling_harness_wiring_test.dart (Phase 10.7B) —
  // that's a standing production invariant, not a historical equivalence
  // proof, so it stays in the main suite while this file (a one-time
  // migration comparison) moved to test/research_regression/.
}
