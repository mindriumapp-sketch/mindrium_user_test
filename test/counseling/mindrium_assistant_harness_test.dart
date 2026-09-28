import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/mindrium_assistant_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

/// 독립적으로 mock 가능함을 보이기 위한 최소 fake. 실제 조회 없이 고정된
/// 결과만 돌려준다.
class _FakeUserContextRetriever implements UserContextRetriever {
  int callCount = 0;

  @override
  Future<UserContextResult> retrieve(UserContextRequest request) async {
    callCount++;
    return const UserContextResult(
      retrievalSummary: RetrievalSummary.empty,
      provenanceIds: ['fake:diary1'],
    );
  }
}

class _FakeCounselingKnowledgeRetriever
    implements CounselingKnowledgeRetriever {
  int callCount = 0;

  @override
  Future<CounselingKnowledgeResult> retrieve(
    CounselingKnowledgeRequest request,
  ) async {
    callCount++;
    return const CounselingKnowledgeResult(ids: ['fake:week4_01']);
  }
}

class _FakeAppGuideKnowledgeRetriever implements AppGuideKnowledgeRetriever {
  int callCount = 0;

  @override
  Future<AppGuideKnowledgeResult> retrieve(
    AppGuideKnowledgeRequest request,
  ) async {
    callCount++;
    return const AppGuideKnowledgeResult(sourceRefs: ['fake:worry_archive']);
  }
}

Future<String> _loadFromDisk(String path) => File(path).readAsString();

/// Phase 3 (MindRiumAssistantHarness 스켈레톤) 검증.
///
/// 목표는 "새 계층을 넣었지만 사용자에게 보이는 동작은 100% 기존과 동일"함을
/// 증명하는 것이다. 아직 [AssistantIntent] 라우팅이 없으므로 모든 턴은
/// 그대로 [CounselingHarness]로 전달되어야 한다.
void main() {
  late LocalCbtKnowledgeRepository repository;
  late LocalAppGuideRepository appGuideRepository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _loadFromDisk);
    await repository.initialize();
    appGuideRepository = LocalAppGuideRepository(loadAsset: _loadFromDisk);
    await appGuideRepository.initialize();
  });

  CounselingHarness newHarness() => CounselingHarness.deterministic(
    llm: MockLlmService(),
    safetyGate: const KeywordSafetyGate(),
    knowledgeRepository: repository,
  );

  CounselingSessionState newSession() =>
      CounselingSessionState(sessionId: 'test', currentWeek: 4);

  test('순수 상담 발화는 상담 intent만 잡힌다', () {
    final assistantHarness = MindRiumAssistantHarness(
      counselingHarness: newHarness(),
    );

    final intent = assistantHarness.detectIntent('발표가 걱정돼요.');

    expect(intent.needsCounseling, isTrue);
    expect(intent.needsAppGuidance, isFalse);
  });

  test('handleTurn은 결과를 그대로 CounselingHarness에 위임한다', () async {
    final counselingHarness = newHarness();
    final assistantHarness = MindRiumAssistantHarness(
      counselingHarness: counselingHarness,
    );

    final directSession = newSession();
    final viaAssistantSession = newSession();

    final direct = await counselingHarness.handleTurn(
      session: directSession,
      userMessage: '발표가 걱정돼요.',
    );
    final viaAssistant = await assistantHarness.handleTurn(
      session: viaAssistantSession,
      userMessage: '발표가 걱정돼요.',
    );

    // 같은 입력이면 문장·상태·행위가 완전히 동일해야 한다 — 새 계층이
    // 상담 내용에 아무 영향도 주지 않는다는 뜻이다.
    expect(viaAssistant.assistantMessage.text, direct.assistantMessage.text);
    expect(viaAssistant.state, direct.state);
    expect(
      viaAssistant.assistantMessage.dialogueAct,
      direct.assistantMessage.dialogueAct,
    );
  });

  group('Phase 4 — retrieval 경계', () {
    test('세 retriever는 독립적으로 mock 가능하고 실제로 호출된다', () async {
      final fakeUserContext = _FakeUserContextRetriever();
      final fakeCounselingKnowledge = _FakeCounselingKnowledgeRetriever();
      final fakeAppGuide = _FakeAppGuideKnowledgeRetriever();

      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
        userContextRetriever: fakeUserContext,
        counselingKnowledgeRetriever: fakeCounselingKnowledge,
        appGuideKnowledgeRetriever: fakeAppGuide,
      );

      final context = await assistantHarness.buildContext(
        session: newSession(),
        userMessage: '발표가 걱정돼요.',
      );

      expect(fakeUserContext.callCount, 1);
      expect(fakeCounselingKnowledge.callCount, 1);
      expect(fakeAppGuide.callCount, 1);
      expect(context.userContext?.provenanceIds, ['fake:diary1']);
      expect(context.counselingKnowledge?.ids, ['fake:week4_01']);
      expect(context.appGuideKnowledge?.sourceRefs, ['fake:worry_archive']);
    });

    test('NoOpAppGuideKnowledgeRetriever는 항상 빈 결과다', () async {
      const retriever = NoOpAppGuideKnowledgeRetriever();

      final result = await retriever.retrieve(
        const AppGuideKnowledgeRequest(query: '걱정 기록은 어디서 봐?'),
      );

      expect(result.hasMatch, isFalse);
      expect(result.degraded, isFalse);
    });

    test('mock retriever를 넣어도 최종 상담 응답은 CounselingHarness 결과와 동일하다', () async {
      final counselingHarness = newHarness();
      final baseline = await counselingHarness.handleTurn(
        session: newSession(),
        userMessage: '발표가 걱정돼요.',
      );

      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: counselingHarness,
        userContextRetriever: _FakeUserContextRetriever(),
        counselingKnowledgeRetriever: _FakeCounselingKnowledgeRetriever(),
        appGuideKnowledgeRetriever: _FakeAppGuideKnowledgeRetriever(),
      );
      final withFakes = await assistantHarness.handleTurn(
        session: newSession(),
        userMessage: '발표가 걱정돼요.',
      );

      // check_in 상태의 deterministic planner는 CBT knowledge를 전혀
      // 읽지 않으므로, retriever가 가짜 값을 돌려줘도(Phase 5부터는
      // precomputedContext로 실제 harness에 전달됨) 이 턴의 응답은 바뀌지
      // 않는다. knowledge가 실제로 쓰이는 상태(intervention)에서의
      // 동등성은 아래 "Phase 5" 그룹에서 별도로 검증한다.
      expect(withFakes.assistantMessage.text, baseline.assistantMessage.text);
    });
  });

  group('Phase 5 — precomputed context bridge', () {
    test(
      'previousSessionContext를 채워도 상담 응답 내용은 harness 직접 호출과 동일하다',
      () async {
        // EmpathyPlanner만 읽는 previousSessionThought/
        // previousSessionAlternativeThought/unfinishedIssue가 precomputed
        // RetrievalSummary에 추가로 실려도, DeterministicCounselingTurnPlanner
        // 계열 중 어떤 sub-planner도 이 필드들을 읽지 않으므로 최종 상담
        // 응답은 harness가 직접(previousSession 없이) 계산한 것과 완전히
        // 같아야 한다 — mindrium_assistant_harness.dart의 핵심 전제.
        final previousSession = PreviousSession(
          sessionId: 's1',
          week: 3,
          completionStatus: 'completed',
          mainConcern: '발표 전 긴장',
          coreThought: '질문에 답하지 못하면 무능해 보일 것이다',
          alternativeThought: '완벽하지 않아도 준비한 내용은 설명할 수 있다',
          interventionUsed: 'week3_balanced_thought_01',
          provenanceIds: const ['session:s1'],
        );

        final directHarness = newHarness();
        final direct = await directHarness.handleTurn(
          session: newSession(),
          userMessage: '발표가 걱정돼요.',
        );

        final assistantHarness = MindRiumAssistantHarness(
          counselingHarness: newHarness(),
        );
        final viaAssistant = await assistantHarness.handleTurn(
          session: newSession(),
          userMessage: '발표가 걱정돼요.',
          previousSessionContext: PreviousSessionContext(
            latestRelevantSession: previousSession,
            carriedUnfinishedIssue: '발표 질문 상황',
          ),
        );

        expect(
          viaAssistant.assistantMessage.text,
          direct.assistantMessage.text,
        );
        expect(viaAssistant.state, direct.state);
      },
    );

    test('buildContext는 precomputedContext로 넘길 CBT knowledge/요약을 실제로 만든다', () async {
      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
      );

      final context = await assistantHarness.buildContext(
        session: newSession(),
        userMessage: '발표가 걱정돼요.',
      );

      // PersonalContextSummary는 채워지지만(향후 Agent가 쓸 자리), 아직
      // 상담 응답에는 반영되지 않는다 — 이 둘은 서로 다른 검증이다.
      expect(context.userContext, isNotNull);
      expect(context.counselingKnowledge, isNotNull);
    });
  });

  group('Phase 7A — intent shadow routing', () {
    test('buildContext는 실제 intent를 계산해 AssistantContext에 싣는다', () async {
      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
      );

      final counselingOnly = await assistantHarness.buildContext(
        session: newSession(),
        userMessage: '발표가 걱정돼요.',
      );
      final appGuideOnly = await assistantHarness.buildContext(
        session: newSession(),
        userMessage: '알림 설정은 어떻게 바꿔?',
      );

      expect(counselingOnly.intent.needsCounseling, isTrue);
      expect(counselingOnly.intent.needsAppGuidance, isFalse);
      expect(appGuideOnly.intent.needsCounseling, isFalse);
      expect(appGuideOnly.intent.needsAppGuidance, isTrue);
    });
  });

  group('Phase 7B — appGuideOnly routing activated', () {
    test('counselingOnly 발화는 여전히 CounselingHarness로 간다', () async {
      final counselingHarness = newHarness();
      final session = newSession();
      final direct = await counselingHarness.handleTurn(
        session: session,
        userMessage: '발표가 너무 불안해요.',
      );

      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
      );
      final viaAssistant = await assistantHarness.handleTurn(
        session: newSession(),
        userMessage: '발표가 너무 불안해요.',
      );

      expect(viaAssistant.assistantMessage.text, direct.assistantMessage.text);
      expect(viaAssistant.assistantMessage.dialogueAct, isNotNull);
    });

    test('appGuideOnly 발화는 AppGuide 경로로 간다', () async {
      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
        appGuideKnowledgeRetriever: LocalAppGuideKnowledgeRetriever(
          repository: appGuideRepository,
        ),
      );

      final result = await assistantHarness.handleTurn(
        session: newSession(),
        userMessage: '알림 설정은 어떻게 바꿔?',
      );

      expect(result.assistantMessage.text, contains('알림'));
      expect(result.promptVersion, 'app_guide_v1');
    });
  });

  group('Phase 7C — mixed response composition', () {
    test('mixed 발화는 상담 + 앱 가이드를 합친다', () async {
      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
        appGuideKnowledgeRetriever: LocalAppGuideKnowledgeRetriever(
          repository: appGuideRepository,
        ),
      );

      final result = await assistantHarness.handleTurn(
        session: newSession(),
        userMessage: '걱정이 심한데 이완 활동은 어디서 할 수 있어?',
      );

      // 상담 응답(걱정)과 앱 가이드(이완 활동 경로)가 모두 있어야 한다.
      expect(result.assistantMessage.text, contains('걱정'));
      expect(result.assistantMessage.text, contains('이완'));
      expect(result.promptVersion, 'mixed_v1');
    });

    test('mixed인데 앱 가이드 정보가 없으면 상담만 반환한다', () async {
      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
        appGuideKnowledgeRetriever: LocalAppGuideKnowledgeRetriever(
          repository: appGuideRepository,
        ),
      );

      final result = await assistantHarness.handleTurn(
        session: newSession(),
        userMessage: '불안한데 영상 통화 상담은 어디서 해?',
      );

      // 상담 응답은 정상이고, 앱 가이드는 없다고 하지만 전체 응답이 실패하지는 않는다.
      expect(result.assistantMessage.text, isNotEmpty);
      // promptVersion은 기존 상담 응답이어야 한다 (mixed_v1 아님).
      expect(result.promptVersion, isNot('mixed_v1'));
    });

    test('위기 신호가 있으면 Safety가 먼저 작동한다 (mixed routing과 무관)', () async {
      final assistantHarness = MindRiumAssistantHarness(
        counselingHarness: newHarness(),
        appGuideKnowledgeRetriever: LocalAppGuideKnowledgeRetriever(
          repository: appGuideRepository,
        ),
      );

      final result = await assistantHarness.handleTurn(
        session: newSession(),
        userMessage: '죽고 싶어요',
      );

      // Safety가 작동하면 109가 나온다.
      expect(result.assistantMessage.text, contains('109'));
      expect(result.handledBySafety, isTrue);
    });
  });
}
