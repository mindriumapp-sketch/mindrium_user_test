// Phase 10.6B: orchestration-level tests for the canary rollout gate wired
// into CounselingHarness.handleTurn(). These do NOT test Remote quality —
// that was already validated in Phase 10.5 with real API calls. The only
// thing under test here is: does the rollout config correctly decide
// whether RemoteLlmRealizer.realize() is called at all, and does telemetry
// carry no raw content. A fake in-memory ResponseRealizer stands in for
// RemoteLlmRealizer so no network call is ever made.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/realization_telemetry.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

class _SpyRealizer implements ResponseRealizer {
  int callCount = 0;
  bool shouldFailValidation = false;
  String failureCategory = 'question_count_mismatch';

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    callCount++;
    return RealizationResult(
      reply: shouldFailValidation ? '' : '스파이 응답입니다. 무엇이 궁금하신가요?',
      source: RealizationSource.remoteLlm,
      latency: const Duration(milliseconds: 5),
      validationResult:
          shouldFailValidation
              ? RealizationValidationResult(
                isValid: false,
                violations: [failureCategory],
              )
              : RealizationValidationResult.valid,
      chosenAct: request.requiredAct,
      modelIdentifier: 'gpt-4o-mini',
      promptVersion: 'realize_v2',
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

  CounselingHarness harnessWith({
    required ResponseRealizer realizer,
    RolloutConfig? rolloutConfig,
    bool isInternalAccount = false,
    RealizationTelemetrySink? telemetrySink,
  }) {
    return CounselingHarness.remoteGpt(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
      responseRealizer: realizer,
      rolloutConfig: rolloutConfig,
      isInternalAccount: isInternalAccount,
      telemetrySink: telemetrySink,
    );
  }

  CounselingSessionState session({
    required CounselingState state,
    String sessionId = 'session-fixed-1',
    int week = 4,
    MindriumCounselingContext? userContext,
  }) {
    return CounselingSessionState(
      sessionId: sessionId,
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

  group('no rollout config (rolloutConfig: null) — unchanged legacy behavior', () {
    test('explore still calls the realizer exactly as before Phase 10.6B', () async {
      final spy = _SpyRealizer();
      await harnessWith(realizer: spy).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 1);
    });
  });

  group('flag OFF / kill switch / stage gating — API must be 0 calls', () {
    test('default RolloutConfig() (fully off) -> 0 calls even for explore', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(),
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 0);
    });

    test('kill switch ON -> 0 calls even with stage:pilot 100%', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
          killSwitch: true,
        ),
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 0);
    });

    test('internalOnly + non-internal account -> 0 calls', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.internalOnly,
        ),
        isInternalAccount: false,
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 0);
    });

    test('internalOnly + internal account -> explore/reflect ARE called', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.internalOnly,
        ),
        isInternalAccount: true,
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 1);
    });

    test('pilot cohort outside percentage -> 0 calls', () async {
      final spy = _SpyRealizer();
      // rolloutPercentage: 0 guarantees every session is outside the cohort.
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 0,
        ),
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 0);
    });

    test('pilot cohort at 100% -> explore/reflect ARE called', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 1);
    });
  });

  group('router-frozen states — 0 calls regardless of rollout config', () {
    final wideOpenConfig = const RolloutConfig(
      enabled: true,
      stage: RolloutStage.pilot,
      rolloutPercentage: 100,
    );

    test('checkIn always 0 calls', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: wideOpenConfig,
      ).handleTurn(
        session: session(state: CounselingState.checkIn),
        userMessage: '오늘은 좀 힘들었어요.',
      );
      expect(spy.callCount, 0);
    });

    test('intervention always 0 calls', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: wideOpenConfig,
      ).handleTurn(
        session: session(
          state: CounselingState.intervention,
          userContext: contextWithDiary(),
        ),
        userMessage: '생각을 바꾸는 게 잘 안 돼요.',
      );
      expect(spy.callCount, 0);
    });

    test('closing always 0 calls', () async {
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: wideOpenConfig,
      ).handleTurn(
        session: session(state: CounselingState.closing),
        userMessage: '오늘은 여기까지 할게요.',
      );
      expect(spy.callCount, 0);
    });
  });

  group('fallback to deterministic on Remote failure (rollout ON)', () {
    test('invalid Remote response (validation failure) falls back to deterministic', () async {
      final spy = _SpyRealizer()..shouldFailValidation = true;
      final result = await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 1, reason: 'Remote must still be attempted');
      expect(result.realizationSource, RealizationSource.deterministic);
      expect(
        result.assistantMessage.text.contains('스파이 응답입니다'),
        isFalse,
        reason: 'rejected Remote reply must never reach the user',
      );
    });

    test(
      'Phase 10.6C-DOGFOOD: on rejection, the user sees the non-quoting '
      'semantic-deterministic fallback, not the legacy verbatim-quote draft',
      () async {
        final spy = _SpyRealizer()..shouldFailValidation = true;
        final result = await harnessWith(
          realizer: spy,
          rolloutConfig: const RolloutConfig(
            enabled: true,
            stage: RolloutStage.pilot,
            rolloutPercentage: 100,
          ),
        ).handleTurn(
          session: session(state: CounselingState.explore),
          userMessage: '발표가 다가오니까 계속 초조해요.',
        );

        // Every legacy `TurnPlanMaterializer` reflection template wraps the
        // target in curly quotes (`"$target"라고...`); the semantic-
        // deterministic candidates never use that character, regardless of
        // target content — a content-independent signal that the fallback
        // text actually changed, not just that it's non-empty.
        expect(result.assistantMessage.text.contains('“'), isFalse);
        expect(result.assistantMessage.text.contains('”'), isFalse);
      },
    );
  });

  group('telemetry', () {
    test('emits one event per rollout-gated turn, with no raw text', () async {
      final events = <RealizationTelemetryEvent>[];
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
        telemetrySink: events.add,
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );

      expect(events, hasLength(1));
      final event = events.single;
      expect(event.remoteAttempted, isTrue);
      expect(event.remoteAccepted, isTrue);
      expect(event.rolloutStage, RolloutStage.pilot);
      expect(event.modelIdentifier, 'gpt-4o-mini');
      expect(event.promptVersion, 'realize_v2');

      final logEntry = event.toLogEntry();
      final serialized = logEntry.toString();
      expect(serialized.contains('발표'), isFalse);
      expect(serialized.contains('초조'), isFalse);
      expect(serialized.contains('스파이 응답'), isFalse);
      expect(logEntry.keys, isNot(contains('reply')));
      expect(logEntry.keys, isNot(contains('user_message')));
      expect(logEntry.keys, isNot(contains('reflection_target')));
    });

    test('question_count_mismatch fallback is flagged in telemetry', () async {
      final events = <RealizationTelemetryEvent>[];
      final spy =
          _SpyRealizer()
            ..shouldFailValidation = true
            ..failureCategory = 'question_count_mismatch';
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
        telemetrySink: events.add,
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );

      expect(events.single.remoteAccepted, isFalse);
      expect(events.single.questionCountMismatch, isTrue);
      expect(events.single.fallbackReason, 'question_count_mismatch');
    });

    test('no telemetry event when telemetrySink is null (default)', () async {
      // Just confirms no crash/no-op when nothing is listening — this is
      // the state of every call site as of this phase.
      final spy = _SpyRealizer();
      await harnessWith(
        realizer: spy,
        rolloutConfig: const RolloutConfig(
          enabled: true,
          stage: RolloutStage.pilot,
          rolloutPercentage: 100,
        ),
      ).handleTurn(
        session: session(state: CounselingState.explore),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );
      expect(spy.callCount, 1);
    });
  });

  group('cohort stability at the harness level', () {
    test('the same sessionId always gets the same rollout outcome at a fixed percentage', () async {
      const config = RolloutConfig(
        enabled: true,
        stage: RolloutStage.pilot,
        rolloutPercentage: 50,
      );
      const fixedSessionId = 'session-stability-check';

      final firstSpy = _SpyRealizer();
      await harnessWith(realizer: firstSpy, rolloutConfig: config).handleTurn(
        session: session(
          state: CounselingState.explore,
          sessionId: fixedSessionId,
        ),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );

      final secondSpy = _SpyRealizer();
      await harnessWith(realizer: secondSpy, rolloutConfig: config).handleTurn(
        session: session(
          state: CounselingState.explore,
          sessionId: fixedSessionId,
        ),
        userMessage: '발표가 다가오니까 계속 초조해요.',
      );

      expect(
        firstSpy.callCount,
        secondSpy.callCount,
        reason:
            'same sessionId at the same percentage must always produce '
            'the same in/out-of-cohort outcome',
      );
    });
  });
}
