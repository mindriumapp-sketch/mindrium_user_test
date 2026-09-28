import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/llm_service.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/hybrid_turn_router.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

CounselingTurnPlan _plan({
  InterventionPlan? intervention,
  TurnPlanningStatus status = TurnPlanningStatus.planned,
}) => CounselingTurnPlan(
  reflectionTarget: '무능해 보일 것이다',
  questionGoal: '근거 탐색',
  reflectionSentence: '그 생각이 걱정되는군요.',
  questionSentence: '근거가 무엇인지 떠올려볼까요?',
  forbidden: const [],
  constraints: const [],
  requiredAct: DialogueAct.socraticQuestion,
  userContextIds: const [],
  cbtContextIds: const [],
  interventionPlan: intervention,
  planningStatus: status,
);

const _intervention = InterventionPlan(
  type: InterventionType.balancedThought,
  target: '무능해 보일 것이다',
  promptSentence: '조금 더 균형 잡힌 문장은 무엇일까요?',
  selectedCbtId: 'week4_alternative_thought_01',
  forbidden: [],
);

void main() {
  const disabled = HybridTurnRouter();
  const enabled = HybridTurnRouter(llmEnabled: true);

  group('HIGH — 모델 사용 금지', () {
    test('안전 수준이 정상이 아니면 어떤 상태에서도 막는다', () {
      for (final level in [SafetyLevel.elevated, SafetyLevel.crisis]) {
        for (final state in CounselingState.values) {
          final decision = enabled.route(
            state: state,
            safetyLevel: level,
            plan: _plan(),
          );
          expect(decision.allowLlm, isFalse, reason: '$level/$state');
          expect(decision.complexity, TurnComplexity.high);
          expect(decision.reason, 'safety');
        }
      }
    });

    test('계획이 없으면 막는다', () {
      final decision = enabled.route(
        state: CounselingState.reflect,
        safetyLevel: SafetyLevel.normal,
      );

      // 승인된 행동이 정해지지 않은 상태에서 모델에 맡기면
      // 승인되지 않은 개입을 만들어낼 수 있다.
      expect(decision.allowLlm, isFalse);
      expect(decision.reason, 'no_plan');
    });

    test('승인된 개입이 없는 주차는 막는다', () {
      final decision = enabled.route(
        state: CounselingState.intervention,
        safetyLevel: SafetyLevel.normal,
        plan: _plan(status: TurnPlanningStatus.unavailable),
      );

      expect(decision.allowLlm, isFalse);
      expect(decision.reason, 'no_approved_intervention');
    });

    test('개입 상태인데 개입 계획이 없으면 막는다', () {
      final decision = enabled.route(
        state: CounselingState.intervention,
        safetyLevel: SafetyLevel.normal,
        plan: _plan(),
      );

      expect(decision.allowLlm, isFalse);
      expect(decision.complexity, TurnComplexity.high);
    });
  });

  group('LOW — 문장이 이미 정해진 구간', () {
    test('승인된 개입 실행 턴은 모델을 쓰지 않는다', () {
      final decision = enabled.route(
        state: CounselingState.intervention,
        safetyLevel: SafetyLevel.normal,
        plan: _plan(intervention: _intervention),
      );

      expect(decision.complexity, TurnComplexity.low);
      expect(decision.allowLlm, isFalse);
      expect(decision.reason, 'approved_intervention');
    });

    test('체크인은 고정 질문으로 충분하다', () {
      final decision = enabled.route(
        state: CounselingState.checkIn,
        safetyLevel: SafetyLevel.normal,
        plan: _plan(),
      );

      expect(decision.complexity, TurnComplexity.low);
      expect(decision.allowLlm, isFalse);
    });
  });

  group('MEDIUM — 표현 다양성 구간', () {
    test('탐색·되짚기만 모델을 열어둘 수 있다', () {
      for (final state in [CounselingState.explore, CounselingState.reflect]) {
        final decision = enabled.route(
          state: state,
          safetyLevel: SafetyLevel.normal,
          plan: _plan(),
        );
        expect(decision.complexity, TurnComplexity.medium, reason: state.name);
        expect(decision.allowLlm, isTrue, reason: state.name);
      }
    });

    test('기본 구성은 모델을 쓰지 않는다', () {
      for (final state in [CounselingState.explore, CounselingState.reflect]) {
        final decision = disabled.route(
          state: state,
          safetyLevel: SafetyLevel.normal,
          plan: _plan(),
        );
        // 제품 기본값은 결정론이다.
        expect(decision.allowLlm, isFalse, reason: state.name);
        expect(decision.reason, 'llm_disabled');
      }
    });

    test('마무리는 모델을 켜도 결정론 경로를 유지한다', () {
      final decision = enabled.route(
        state: CounselingState.closing,
        safetyLevel: SafetyLevel.normal,
        plan: _plan(),
      );

      expect(decision.complexity, TurnComplexity.low);
      expect(decision.allowLlm, isFalse);
      expect(decision.reason, 'fixed_closing');
    });
  });

  group('harness 통합', _harnessTests);

  group('불변식', () {
    test('모델을 켜도 HIGH 는 절대 열리지 않는다', () {
      final decisions = [
        enabled.route(
          state: CounselingState.reflect,
          safetyLevel: SafetyLevel.crisis,
          plan: _plan(),
        ),
        enabled.route(
          state: CounselingState.reflect,
          safetyLevel: SafetyLevel.normal,
        ),
        enabled.route(
          state: CounselingState.intervention,
          safetyLevel: SafetyLevel.normal,
          plan: _plan(status: TurnPlanningStatus.unavailable),
        ),
      ];

      for (final decision in decisions) {
        expect(decision.complexity, TurnComplexity.high);
        expect(decision.allowLlm, isFalse, reason: decision.reason);
      }
    });

    test('모든 상태를 빠짐없이 다룬다', () {
      for (final state in CounselingState.values) {
        expect(
          () => enabled.route(
            state: state,
            safetyLevel: SafetyLevel.normal,
            plan: _plan(),
          ),
          returnsNormally,
          reason: state.name,
        );
      }
    });
  });
}

// ───────────── harness 통합 ─────────────

class _CountingLlm implements LlmService {
  int calls = 0;

  @override
  Future<LlmResponse> generate(LlmRequest request) async {
    calls++;
    return const LlmResponse(
      text: '그 생각이 걱정되는군요. 근거가 무엇인지 떠올려볼까요?',
      latency: Duration.zero,
    );
  }
}

Future<String> _load(String path) => File(path).readAsString();

void _harnessTests() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _load);
    await repository.initialize();
  });

  Future<({CounselingTurnResult result, _CountingLlm llm})> run({
    required CounselingState state,
    required bool llmEnabled,
    String userMessage = '사람들이 저를 무능하게 볼 것 같아요.',
    int week = 4,
  }) async {
    final llm = _CountingLlm();
    final harness = CounselingHarness(
      llm: llm,
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      turnPlanner: const DeterministicCounselingTurnPlanner(),
      turnRouter: HybridTurnRouter(llmEnabled: llmEnabled),
    );

    final result = await harness.handleTurn(
      session: CounselingSessionState(
        sessionId: 'test',
        currentWeek: week,
        state: state,
      ),
      userMessage: userMessage,
    );
    return (result: result, llm: llm);
  }

  test('개입 턴은 모델을 켜도 호출하지 않는다', () async {
    final run1 = await run(
      state: CounselingState.intervention,
      llmEnabled: true,
    );

    expect(run1.llm.calls, 0);
    expect(run1.result.routing!.reason, 'approved_intervention');
  });

  test('되짚기 턴은 모델을 켜면 medium 복잡도로 라우팅된다', () async {
    // Phase 8.5: turnPlan이 있는 턴은 harness가 raw LlmService를 직접
    // 부르지 않고 항상 responseRealizer를 거친다(P2-L 원시 LLM 경로 제거).
    // 여기서 검증할 라우팅 가치는 "medium 복잡도로 모델 사용이 허용된다"는
    // 것이고, 실제 모델 호출 여부는 ResponseRealizer 구현체(예:
    // RemoteLlmRealizer)의 책임이다 — remote_llm_realizer_test.dart 참고.
    final run1 = await run(state: CounselingState.reflect, llmEnabled: true);

    expect(run1.llm.calls, 0);
    expect(run1.result.routing!.complexity, TurnComplexity.medium);
    expect(run1.result.routing!.allowLlm, isTrue);
  });

  test('기본 구성은 되짚기에서도 호출하지 않는다', () async {
    final run1 = await run(state: CounselingState.reflect, llmEnabled: false);

    expect(run1.llm.calls, 0);
    expect(run1.result.routing!.reason, 'llm_disabled');
  });

  test('위기 입력은 planner 도 모델도 거치지 않는다', () async {
    final run1 = await run(
      state: CounselingState.reflect,
      llmEnabled: true,
      userMessage: '죽고 싶어요',
    );

    expect(run1.llm.calls, 0);
    expect(run1.result.handledBySafety, isTrue);
  });
}
