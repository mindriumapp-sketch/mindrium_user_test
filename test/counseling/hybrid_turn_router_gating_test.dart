// Real bug fix, found while preparing to evaluate a real LLM ResponseRealizer
// (RemoteLlmRealizer / /counseling/realize): `CounselingHarness.handleTurn`
// computed `HybridTurnRouter.route(...)` into `routing` but never checked
// `routing.allowLlm` before calling `responseRealizer.realize(...)`. Harmless
// while the only realizer ever configured was `DeterministicResponseRealizer`
// (which makes no network/model call regardless), but the moment a real
// LLM-backed realizer is wired in via `CounselingHarness.remoteGpt(...)`, an
// approved-intervention turn's wording — which `HybridTurnRouter` explicitly
// marks `allowLlm: false` for, precisely so a model can never push an
// approved CBT turn outside its approved scope — would have been sent to the
// model anyway. This test locks in the fix: `responseRealizer.realize` must
// never be invoked when the router says no, regardless of state.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan_prompt_builder.dart';

class _SpyRealizer implements ResponseRealizer {
  int callCount = 0;

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    callCount++;
    return RealizationResult(
      reply: '이 문장이 최종 응답에 나타나면 라우터 게이트가 깨진 것이다.',
      source: RealizationSource.remoteLlm,
      latency: const Duration(milliseconds: 1),
      validationResult: RealizationValidationResult.valid,
      chosenAct: request.requiredAct,
    );
  }
}

Future<String> _loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _loadFromDisk);
    await repository.initialize();
  });

  CounselingHarness remoteGptHarness(ResponseRealizer realizer) {
    return CounselingHarness.remoteGpt(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      responseRealizer: realizer,
    );
  }

  CounselingSessionState session({
    required CounselingState state,
    int week = 4,
    MindriumCounselingContext? userContext,
  }) {
    return CounselingSessionState(
      sessionId: 'hybrid_turn_router_gating',
      currentWeek: week,
      state: state,
      userContext: userContext,
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

  test(
    'CounselingHarness.remoteGpt: intervention turn never calls the injected realizer',
    () async {
      final spy = _SpyRealizer();
      final result = await remoteGptHarness(spy).handleTurn(
        session: session(
          state: CounselingState.intervention,
          week: 4,
          userContext: contextWithDiary(),
        ),
        userMessage: '생각을 바꾸는 게 잘 안 돼요.',
      );

      expect(
        spy.callCount,
        0,
        reason:
            'HybridTurnRouter marks intervention turns allowLlm:false so an '
            'approved CBT turn can never be pushed outside its approved '
            'scope by a model — the realizer must not even be called.',
      );
      expect(result.realizationSource, RealizationSource.deterministic);
      expect(
        result.assistantMessage.text.contains('라우터 게이트가 깨진 것이다'),
        isFalse,
      );
    },
  );

  test(
    'CounselingHarness.remoteGpt: checkIn turn never calls the injected realizer',
    () async {
      final spy = _SpyRealizer();
      final result = await remoteGptHarness(spy).handleTurn(
        session: session(state: CounselingState.checkIn),
        userMessage: '오늘은 좀 힘들었어요.',
      );

      expect(spy.callCount, 0);
      expect(result.realizationSource, RealizationSource.deterministic);
    },
  );

  test(
    'CounselingHarness.remoteGpt: explore turn DOES call the injected realizer (llmEnabled:true)',
    () async {
      final spy = _SpyRealizer();
      await remoteGptHarness(spy).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );

      expect(
        spy.callCount,
        1,
        reason:
            'explore/reflect are the states HybridTurnRouter allows a real '
            'realizer to run for when llmEnabled:true — this must still '
            'work after the gating fix, not just the negative cases above.',
      );
    },
  );

  test(
    'CounselingHarness.deterministic: explore turn never calls a realizer either (llmEnabled defaults false)',
    () async {
      final spy = _SpyRealizer();
      final harness = CounselingHarness(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
        turnPlanner: const PolicyPipelineTurnPlanner(),
        promptBuilder: const TurnPlanPromptBuilder(),
        responseRealizer: spy,
      );

      await harness.handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );

      expect(
        spy.callCount,
        0,
        reason:
            'a harness assembled without remoteGpt()\'s explicit '
            'HybridTurnRouter(llmEnabled: true) must keep the router\'s '
            'default (llmEnabled: false) — an injected realizer must not '
            'be reachable just by supplying one.',
      );
    },
  );
}
