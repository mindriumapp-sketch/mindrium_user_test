import 'package:flutter/foundation.dart';
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/counseling/counseling_session_summary.dart';
import 'package:gad_app_team/data/counseling/episode_history.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/assistant/app_guide/app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/mindrium_assistant_harness.dart';

import 'counseling_benchmark.dart';
import 'empathy_planner.dart';
import 'counseling_harness.dart';
import 'counseling_state.dart';
import 'safety_gate.dart';
import 'turn_plan.dart';

/// 채팅 화면의 상태를 들고 있는다.
///
/// Step 1 은 메모리에만 저장한다. MongoDB 로 남기는 것은 Step 4 다.
class CounselingProvider extends ChangeNotifier {
  final CounselingHarness harness;
  final CbtKnowledgeRepository knowledgeRepository;

  /// MindRium 앱 사용법 지식(Phase 6). `knowledgeRepository`와 같은 패턴 —
  /// [initialize]에서 한 번만 로드한다. 상담 응답에는 아직 반영되지 않는다
  /// ([AssistantIntent]가 항상 `counselingOnly`이기 때문).
  final AppGuideRepository appGuideRepository;

  /// `harness` 위에 놓인 최상위 진입점. Phase 7A 현재: intent는 실제로
  /// 계산되어 [AssistantContext]에 실리지만(shadow routing), 모든 턴은
  /// 여전히 그대로 [CounselingHarness]로 넘어가 동작을 바꾸지 않는다 —
  /// appGuide/mixed 전용 응답 경로는 Phase 7B 이후의 일이다.
  /// docs/counseling/chatbot_system.md 참고.
  late final MindRiumAssistantHarness _assistantHarness =
      MindRiumAssistantHarness(
        counselingHarness: harness,
        appGuideKnowledgeRetriever: LocalAppGuideKnowledgeRetriever(
          repository: appGuideRepository,
        ),
        intentRouter: DeterministicAssistantIntentRouter(
          repository: appGuideRepository,
        ),
      );

  /// 없으면 개인화 없이 동작한다. 서버에 접근할 수 없는 환경도 있으므로 선택으로 둔다.
  final MindriumContextBuilder? contextBuilder;

  /// 실제 모델이 답을 만드는 동안 현재 발화에 근거한 짧은 공감을 먼저 보여준다.
  final bool instantEmpathy;

  /// 공감 문장을 만든다. 근거 없는 과거 언급을 막는 정책이 여기 있다.
  final EmpathyPlanner empathyPlanner;

  /// 세션 요약을 서버에 남긴다. 없으면 저장하지 않고 상담만 진행한다.
  final CounselingSessionsApi? sessionsApi;

  /// 지난 세션 중 어느 것을 참고할지 정한다.
  final PreviousSessionSelector previousSessionSelector;

  CounselingSessionState _session;
  final List<CounselingMessage> _messages = [];
  bool _isGenerating = false;
  bool _isReady = false;
  CounselingUiAction? _pendingUiAction;

  /// CTA 가 붙어 있는 상담자 메시지. 그 말풍선 아래에만 버튼을 보인다.
  String? _pendingUiActionMessageId;
  SafetyLevel _lastSafetyLevel = SafetyLevel.normal;

  /// 직전 턴에 관찰한 SUD. 턴 사이 정서 변화를 보는 데 쓴다.
  int? _previousSud;
  EmpathyPlan? _lastEmpathy;

  /// 직전 턴에 만든 검색 요약. 세션 기억을 채우는 데 쓴다.
  RetrievalSummary? _lastRetrievalSummary;

  /// 세션 동안 확인된 사실을 턴 단위로 쌓는다. LLM 요약이 아니다.
  late CounselingSessionMemory _memory = CounselingSessionMemory(
    sessionId: _session.sessionId,
  );

  DateTime _startedAt = DateTime.now();

  /// 정상 종료로 이미 저장했는지. 화면 이탈 스냅샷이 덮어쓰지 않게 한다.
  bool _savedAsCompleted = false;

  /// 세션 시작 시점의 SUD.
  int? _sudStart;

  /// core thought 가 어디서 나왔는지. 다음 세션에서 근거를 추적하는 데 쓴다.
  String? _coreThoughtSource;

  /// 마지막으로 관찰한 정서 라벨.
  String? _lastSignalLabel;

  /// pause/dispose/closing 저장이 겹쳐도 서버에는 순서대로 보낸다.
  Future<void> _persistQueue = Future<void>.value();
  int _lastPersistedTurnCount = -1;
  String? _lastPersistedStatus;

  /// 이번 상담에서 참고할 지난 완료 세션.
  PreviousSession? _previousSession;
  EpisodeHistory _episodeHistory = EpisodeHistory.empty;

  MindriumCounselingContext? _withEpisodes(MindriumCounselingContext? ctx) {
    if (_episodeHistory.isEmpty) return ctx;
    return (ctx ?? MindriumCounselingContext(currentWeek: _session.currentWeek))
        .withEpisodes(_episodeHistory);
  }

  /// 지난 세션에서 이어받은 미해결 주제.
  String? _carriedUnfinishedIssue;

  CounselingProvider({
    required this.harness,
    required this.knowledgeRepository,
    required int currentWeek,
    AppGuideRepository? appGuideRepository,
    this.contextBuilder,
    this.instantEmpathy = false,
    this.empathyPlanner = const EmpathyPlanner(),
    this.sessionsApi,
    this.previousSessionSelector = const PreviousSessionSelector(),
    String? sessionId,
  }) : appGuideRepository = appGuideRepository ?? LocalAppGuideRepository(),
       _session = CounselingSessionState(
         sessionId:
             sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
         currentWeek: currentWeek,
       );

  List<CounselingMessage> get messages => List.unmodifiable(_messages);
  CounselingState get state => _session.state;
  bool get isGenerating => _isGenerating;
  bool get isReady => _isReady;

  /// Phase 13.5: the session is over only once the closing handshake is
  /// finalized (the user agreed, or the session had to end), not merely
  /// when the state reaches closing. The UI end-notice and `completed`
  /// persistence key off this.
  bool get isSessionFinalized => _messages.any(
    (m) => !m.isUser && m.closingStep == ClosingStep.finalized,
  );
  CounselingUiAction? get pendingUiAction => _pendingUiAction;

  /// [messageId] 말풍선 아래에 보여줄 추천 활동. 없으면 null.
  ///
  /// 한 턴에 최대 하나다. **추천일 뿐이며 수행을 뜻하지 않는다.**
  /// 실제 수행 여부는 서버 기록에 남았을 때만 인정한다.
  CounselingUiAction? uiActionForMessage(String messageId) =>
      _pendingUiActionMessageId == messageId ? _pendingUiAction : null;

  /// 직전 턴의 안전 수준. 표시 계층이 위기 상황에서 연출을 줄이는 데 쓴다.
  SafetyLevel get lastSafetyLevel => _lastSafetyLevel;

  /// 직전 턴에 만든 공감과 그 근거.
  EmpathyPlan? get lastEmpathy => _lastEmpathy;

  /// 지금까지 누적된 세션 요약.
  CounselingSessionSummary get sessionSummary => _memory.summary;

  /// 이번 상담에서 참고하는 지난 완료 세션. 없으면 null.
  PreviousSession? get previousSession => _previousSession;

  @visibleForTesting
  CounselingSessionState get debugSession => _session;

  /// 지난 세션에서 이어받은 미해결 주제. 없으면 null.
  String? get carriedUnfinishedIssue => _carriedUnfinishedIssue;

  /// 직전 턴 대비 정서 변화를 SUD 로 판단한다.
  ///
  /// 서버가 주는 [RetrievalSummary.sudTrend] 는 주 단위 추이라 한 세션 안의
  /// 변화를 보여주지 못한다. 세션 안에서는 턴 사이 SUD 를 직접 비교한다.
  AffectChange _affectChange(RetrievalSummary summary) {
    final current = summary.recentSud;
    final previous = _previousSud;
    _previousSud = current ?? previous;

    if (current == null || previous == null) return AffectChange.unknown;
    if (current < previous) return AffectChange.improved;
    if (current > previous) return AffectChange.worsened;
    return AffectChange.steady;
  }

  /// 이번 세션에 쓰는 사용자 컨텍스트. 서버 조회에 실패하면 null 이거나 degraded 다.
  MindriumCounselingContext? get userContext => _session.userContext;

  /// 코퍼스를 올리고 첫 인사를 띄운다.
  Future<void> initialize() async {
    if (_isReady) return;

    final stopwatch = Stopwatch()..start();
    await knowledgeRepository.initialize();
    // App Guide 지식은 아직 상담 응답에 쓰이지 않는다(Phase 6). 그래서
    // 로드에 실패해도(자산 누락, 테스트 환경 등) 상담 자체를 막아서는 안
    // 된다 — knowledgeRepository와 달리 실패를 삼키고 그냥 빈 상태로
    // 둔다. 이후 App Guide 응답 생성이 실제로 붙을 때는 그 경로에서
    // degraded를 봐야 한다.
    try {
      await appGuideRepository.initialize();
    } on Object catch (e) {
      debugPrint('[CounselingProvider] App Guide 지식 로드 실패: $e');
    }
    CounselingBenchmark.emit('corpus_loaded', {
      'ms': stopwatch.elapsedMilliseconds,
      'items': knowledgeRepository.allIds.length,
    });

    // 사용자 컨텍스트는 세션 시작 시 한 번만 읽는다. 턴마다 다시 조회하지 않는다.
    _session.userContext = await _buildContext();
    await _loadPreviousSession();

    _messages.add(
      CounselingMessage(
        id: '${_session.sessionId}_greeting',
        role: 'assistant',
        // 첫 인사는 모델이 아니라 앱이 정한다.
        text:
            '안녕하세요. 오늘 어떤 이야기를 나누고 싶으신가요?\n'
            '지금 마음에 걸리는 일이 있다면 편하게 적어 주세요.',
        createdAt: DateTime.now(),
      ),
    );

    _isReady = true;
    stopwatch.stop();
    CounselingBenchmark.emit('provider_ready', {
      'ms': stopwatch.elapsedMilliseconds,
      'context':
          _session.userContext == null
              ? 'none'
              : (_session.userContext!.degraded ? 'degraded' : 'ok'),
    });
    notifyListeners();
  }

  /// 상담 중 새 기록이 생긴 경우처럼, 명시적으로 컨텍스트를 다시 읽어야 할 때 호출한다.
  Future<void> refreshContext() async {
    contextBuilder?.invalidateSnapshot();
    _session.userContext = await _buildContext();
    notifyListeners();
  }

  /// 컨텍스트 조회는 실패해도 상담을 막지 않는다.
  Future<MindriumCounselingContext?> _buildContext({
    String? userMessage,
  }) async {
    final builder = contextBuilder;
    if (builder == null) return null;

    try {
      return _withEpisodes(await builder.build(
        currentWeek: _session.currentWeek,
        userMessage: userMessage,
      ));
    } on Object catch (e) {
      debugPrint('[CounselingProvider] 사용자 컨텍스트 생성 실패: $e');
      return null;
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    _messages.add(
      CounselingMessage(
        id: '${_session.sessionId}_${_messages.length}_user',
        role: 'user',
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    );

    // 세션 진입 시점 컨텍스트는 아직 이번 발화의 주제를 모른다. 즉시 공감이
    // 그 상태 그대로 지난 세션을 참조하면(RetrievalSummary의 provenance 겹침
    // 판정), 오늘과 무관한 과거 세션이 잘못 끌려온다 — 두 시나리오를 실기기로
    // 테스트하다 발견한 문제. 요약을 만들기 전에 먼저 이번 발화로 컨텍스트를
    // 다시 선택한다. 내부 데이터는 캐시되어 있어(T24) 네트워크 재조회가
    // 생기지 않는다.
    if (contextBuilder != null) {
      _session.userContext = await _buildContext(userMessage: trimmed);
    }

    // 요약은 즉시 공감과 세션 기억이 함께 쓴다. harness 도 같은 요약을 만들지만
    // 그건 모델 응답 경로라 더 늦게 도착하고, 공감은 기다릴 수 없다.
    final summary = harness.retrievalSummaryBuilder.build(
      userMessage: trimmed,
      context: _session.userContext,
      recentMessages: _messages,
      previousSession: _previousSession,
      carriedUnfinishedIssue: _carriedUnfinishedIssue,
    );
    _lastRetrievalSummary = summary;
    _sudStart ??= summary.recentSud;
    if (summary.currentThought != null) {
      _coreThoughtSource ??=
          UserThoughtExtractor.evaluativeThought(trimmed) != null
              ? 'current_utterance'
              : 'recent_message';
    }

    // 무의미한 입력·욕설·부적절한 요청에는 "말씀하신 일이 계속 걸리시는군요"
    // 같은 즉시 공감을 붙이면 안 된다 — 실제로 걸릴 만한 내용이 없는데 있는
    // 것처럼 반응하게 된다. 이런 입력은 뒤이어 오는 input guard 응답이
    // 유일한 답이어야 한다.
    final skipEmpathy = DeterministicInputGuardTurnPlanner
        .looksInvalidOrInappropriate(trimmed);
    if (instantEmpathy && !skipEmpathy) {
      final empathy = empathyPlanner.plan(
        userMessage: trimmed,
        summary: summary,
        change: _affectChange(summary),
        recentMessages: _messages,
      );
      _lastEmpathy = empathy;

      _messages.add(
        CounselingMessage(
          id: '${_session.sessionId}_${_messages.length}_empathy',
          role: 'assistant',
          text: empathy.sentence,
          createdAt: DateTime.now(),
          dialogueAct: DialogueAct.reflect,
          referencedUserContextIds: empathy.provenanceIds,
        ),
      );
      // 모델을 기다리지 않고 화면에 먼저 표시한다.
      _session.messages
        ..clear()
        ..addAll(_messages);
    }
    _isGenerating = true;
    _pendingUiAction = null;
    _pendingUiActionMessageId = null;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    try {
      // 컨텍스트는 위에서 이미 이번 발화 기준으로 다시 선택했다.
      final result = await _assistantHarness.handleTurn(
        session: _session,
        userMessage: trimmed,
        previousSessionContext: PreviousSessionContext(
          latestRelevantSession: _previousSession,
          carriedUnfinishedIssue: _carriedUnfinishedIssue,
        ),
      );
      stopwatch.stop();

      // 한 턴의 전체 비용. Step 3 에서는 여기에 모델 추론 시간이 더해진다.
      CounselingBenchmark.emit('turn', {
        'ms': stopwatch.elapsedMilliseconds,
        'llm_ms': result.assistantMessage.latency?.inMilliseconds,
        'state_before': result.stateBefore.wireName,
        'state_after': result.state.wireName,
        'act': result.assistantMessage.dialogueAct?.wireName,
        'safety': result.safety.level.name,
        'handled_by_safety': result.handledBySafety,
        'parse': result.assistantMessage.parseStatus?.name,
        // 제공한 수와 인용한 수를 함께 남긴다. 둘을 비교해야 retrieval 문제인지
        // 모델이 근거를 무시한 것인지 구분할 수 있다.
        'offered_cbt_ids': result.offeredCbtIdCount,
        'referenced_cbt_ids': result.assistantMessage.referencedCbtIds.length,
        'offered_user_ids': result.offeredUserContextIdCount,
        'referenced_user_ids':
            result.assistantMessage.referencedUserContextIds.length,
        // harness 가 문장을 구성할 때 실제로 사용한 기록.
        'construction_ids': result.retrievalProvenanceIds.length,
        // 이번 턴을 어떻게 실현했는지. LLM 호출률을 집계하는 근거다.
        'complexity': result.routing?.complexity.name,
        'llm_allowed': result.routing?.allowLlm,
        'routing_reason': result.routing?.reason,
        'realization_source': result.realizationSource.name,
        // Adaptive Dialogue Policy Phase 1: GPT가 requiredAct가 아닌 다른
        // 허용 행위를 실제로 선택했는지. 도입 전에는 항상 false다.
        'act_chosen_by_model': result.actChosenByModel,
      });

      // 정상 종료 판정은 **closing 으로 처음 넘어가는 순간**이다.
      // closing 상태는 여러 턴 유지될 수 있어 "closing 인 매 턴"으로 잡으면
      // 같은 세션을 반복 저장하게 된다.
      // Phase 13.5: "completed" means the closing handshake was finalized
      // on this turn (the first time), not the first entry into closing,
      // which used to happen right after the intervention question.
      final finalizedNow =
          result.assistantMessage.closingStep == ClosingStep.finalized &&
          !isSessionFinalized;

      _messages.add(result.assistantMessage);
      // CTA 는 이 메시지에 붙는다. 한 턴에 하나이며, 다음 턴에 새 제안이 오면
      // 이전 것은 사라진다.
      _pendingUiAction = result.uiAction;
      _pendingUiActionMessageId =
          result.uiAction == null ? null : result.assistantMessage.id;
      _lastSafetyLevel = result.safety.level;
      _recordTurn(trimmed, result);

      // harness 가 프롬프트에 넣을 최근 대화를 세션에서 읽으므로 함께 갱신한다.
      _session.messages
        ..clear()
        ..addAll(_messages);

      if (finalizedNow) await _persistSession('completed');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 지난 상담 기록을 읽어 참고 대상을 정한다.
  ///
  /// 완료 세션을 우선하고, 중단 세션은 미해결 주제만 보조로 받는다.
  /// 조회에 실패해도 상담을 막지 않는다.
  Future<void> _loadPreviousSession() async {
    final api = sessionsApi;
    if (api == null) return;

    try {
      final rows = await api.listSessions(limit: 10);
      final sessions = rows.map(PreviousSession.fromJson).toList();

      // 개인화: 지난 에피소드를 결정 근거로 둔다(기법 순서, 이전 대안 상기).
      _episodeHistory = EpisodeHistory.fromSessions(sessions);
      _session.userContext = _withEpisodes(_session.userContext);

      _previousSession = previousSessionSelector.selectPrimary(sessions);
      _carriedUnfinishedIssue = previousSessionSelector.selectUnfinishedIssue(
        sessions,
        primary: _previousSession,
      );
    } on Object catch (e) {
      debugPrint('[CounselingProvider] 지난 세션 조회 실패: $e');
    }
  }

  /// 세션 요약을 서버에 저장한다.
  ///
  /// 두 경로가 같은 세션을 저장하려 한다.
  ///   1. closing 최초 진입  → completed
  ///   2. 화면 이탈          → interrupted
  ///
  /// 같은 sessionId 로 upsert 하므로 문서는 하나만 남고, 이미 completed 인
  /// 세션은 서버가 interrupted 로 덮어쓰지 않는다. 클라이언트에서도
  /// [_savedAsCompleted] 로 한 번 더 막는다.
  ///
  /// 저장에 실패해도 상담을 막지 않는다.
  Future<void> _persistSession(String status) {
    final operation = _persistQueue.then((_) => _persistSnapshot(status));
    // 앞선 네트워크 실패가 뒤 저장을 막지 않도록 queue 자체는 정상 상태로 돌린다.
    _persistQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _persistSnapshot(String status) async {
    final api = sessionsApi;
    if (api == null) return;
    if (_savedAsCompleted) return;

    if (status == 'completed') {
      _memory.close();
    }
    final summary = _memory.summary;
    if (!summary.hasContent) return;
    // Episode facts come from turn metadata, not from the turn-order
    // recorder (which stored meta replies as alternative thoughts).
    final facts = EpisodeFacts.fromMessages(_session.messages);
    if (_lastPersistedTurnCount == summary.turnCount &&
        _lastPersistedStatus == status) {
      return;
    }

    try {
      await api.upsertSession(
        sessionId: _session.sessionId,
        week: _session.currentWeek,
        completionStatus: status,
        startedAt: _startedAt,
        endedAt: DateTime.now(),
        finalState: _session.state.wireName,
        safetyLevel: _lastSafetyLevel.name,
        mainConcern: summary.concern ?? facts.mainConcern,
        coreThought: facts.coreThought,
        coreThoughtSource: facts.coreThought == null ? null : _coreThoughtSource,
        alternativeThought: facts.alternativeThought,
        affect: _lastSignalLabel,
        sudStart: _sudStart ?? facts.sudStart,
        sudEnd: summary.endingSud,
        interventionUsed: summary.interventionUsed,
        activityRecommended: summary.activityRecommended,
        unfinishedIssue: facts.unfinishedIssue,
        interventionOutcome: _interventionOutcome,
        provenanceIds: summary.provenanceIds,
        turnCount: summary.turnCount,
      );
      _lastPersistedTurnCount = summary.turnCount;
      _lastPersistedStatus = status;
      if (status == 'completed') _savedAsCompleted = true;
    } on Object catch (e) {
      debugPrint('[CounselingProvider] 세션 요약 저장 실패: $e');
    }
  }

  /// 이번 세션 기법 답의 결과: 한 번이라도 성과로 인정됐으면 'credited',
  /// 받아 주기만 했으면 'acknowledged', 통합 턴이 없으면 null.
  String? get _interventionOutcome {
    final integrations = _session.messages.where(
      (m) => !m.isUser && m.interventionCredited != null,
    );
    if (integrations.isEmpty) return null;
    return integrations.any((m) => m.interventionCredited!) ? 'credited' : 'acknowledged';
  }

  /// 사용자가 화면을 벗어날 때 호출한다.
  ///
  /// 이미 정상 종료로 저장했으면 아무 일도 하지 않는다.
  Future<void> finalizeIfIncomplete() => _persistSession('interrupted');

  /// 이번 턴에서 확인된 사실을 세션 기억에 남긴다.
  ///
  /// 안전 턴은 상담 내용이 아니므로 기록하지 않는다.
  void _recordTurn(String userMessage, CounselingTurnResult result) {
    if (result.handledBySafety) return;

    final plan = result.turnPlan;
    final summary = _lastRetrievalSummary;
    final diary = UserThoughtExtractor.firstDiary(_session.userContext);

    _memory.record(
      SessionTurnRecord.fromDiary(
        userMessage: userMessage,
        diary: diary,
        theme: summary?.currentTheme,
        automaticThought: plan?.reflectionTarget ?? summary?.currentThought,
        sud: summary?.recentSud,
        unfinishedIssue: summary?.unfinishedIssue,
        // 근거 탐색 질문을 했으면 다음 발화가 그 답이다.
        askedEvidence:
            result.stateBefore == CounselingState.reflect &&
            (plan?.questionSentence.contains('근거나 경험') ?? false),
        interventionCbtId: plan?.interventionPlan?.selectedCbtId,
        activity: plan?.interventionPlan?.recommendation.activity?.name,
        provenanceIds: result.retrievalProvenanceIds,
      ),
    );
  }

  /// 대화를 처음부터 다시 시작한다.
  Future<void> reset() async {
    _session = CounselingSessionState(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      currentWeek: _session.currentWeek,
    );
    _messages.clear();
    _pendingUiAction = null;
    _pendingUiActionMessageId = null;
    _previousSud = null;
    _lastEmpathy = null;
    _savedAsCompleted = false;
    _startedAt = DateTime.now();
    _persistQueue = Future<void>.value();
    _lastPersistedTurnCount = -1;
    _lastPersistedStatus = null;
    _sudStart = null;
    _coreThoughtSource = null;
    _lastSignalLabel = null;
    _previousSession = null;
    _carriedUnfinishedIssue = null;
    _lastRetrievalSummary = null;
    _memory = CounselingSessionMemory(sessionId: _session.sessionId);
    _lastSafetyLevel = SafetyLevel.normal;
    _isReady = false;
    await initialize();
  }
}
