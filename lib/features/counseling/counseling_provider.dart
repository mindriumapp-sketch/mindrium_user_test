import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gad_app_team/chatbot/affective/response_move.dart';
import 'package:gad_app_team/chatbot/affective/affect_signal.dart';
import 'package:gad_app_team/chatbot/affective/affect_signal_detector.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gad_app_team/data/api/counseling_respond_api.dart';
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/counseling_patterns.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/counseling/counseling_session_summary.dart';
import 'package:gad_app_team/data/counseling/counseling_session_record.dart';
import 'package:gad_app_team/data/counseling/episode_history.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/assistant/app_guide/app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/features/assistant/mindrium_assistant_harness.dart';

import 'counseling_harness.dart';
import 'counseling_state.dart';
import 'llm_led/term_glossary.dart';
import 'policy/selectors/closing_decision_selector.dart';
import 'llm_led/pseudonym.dart';
import 'safety_gate.dart';
import 'turn_plan.dart';

/// 채팅 화면, 상담 세션과 저장 상태를 관리한다.
class CounselingProvider extends ChangeNotifier {
  final CounselingHarness harness;
  final CbtKnowledgeRepository knowledgeRepository;

  /// 앱 안내 질문에 사용할 지식. [initialize]에서 로드한다.
  final AppGuideRepository appGuideRepository;

  /// 규칙 상담과 앱 안내를 사용자 의도에 따라 연결한다.
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

  /// 세션 요약을 서버에 남긴다. 없으면 저장하지 않고 상담만 진행한다.
  final CounselingSessionsApi? sessionsApi;

  /// Phase 14.X: the Bounded LLM-led path. When set, each non-crisis turn
  /// goes to it first; a timeout, error or validator rejection falls back to
  /// the deterministic path for that turn. Null = off (default).
  final CounselingRespondApi? llmLedApi;
  final CounselingPatternIntentApi? patternIntentApi;

  TermGlossary _glossary = TermGlossary.empty;
  bool get _llmLedThisSession => llmLedApi != null;

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

  /// 직전 턴에 만든 검색 요약. 세션 기억을 채우는 데 쓴다.
  RetrievalSummary? _lastRetrievalSummary;

  /// 세션 동안 확인된 사실을 턴 단위로 쌓는다. LLM 요약이 아니다.
  late CounselingSessionMemory _memory = CounselingSessionMemory(
    sessionId: _session.sessionId,
  );

  DateTime _startedAt = DateTime.now();

  /// 정상 종료로 이미 저장했는지. 화면 이탈 스냅샷이 덮어쓰지 않게 한다.
  bool _savedAsCompleted = false;

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
    this.sessionsApi,
    this.llmLedApi,
    this.patternIntentApi,
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
  bool get isSessionFinalized =>
      _messages.any((m) => !m.isUser && m.closingStep == ClosingStep.finalized);
  CounselingUiAction? get pendingUiAction => _pendingUiAction;

  /// [messageId] 말풍선 아래에 보여줄 추천 활동. 없으면 null.
  ///
  /// 한 턴에 최대 하나다. **추천일 뿐이며 수행을 뜻하지 않는다.**
  /// 실제 수행 여부는 서버 기록에 남았을 때만 인정한다.
  CounselingUiAction? uiActionForMessage(String messageId) =>
      _pendingUiActionMessageId == messageId ? _pendingUiAction : null;

  /// 직전 턴의 안전 수준. 표시 계층이 위기 상황에서 연출을 줄이는 데 쓴다.
  SafetyLevel get lastSafetyLevel => _lastSafetyLevel;

  /// 마지막으로 사용자에게 나간 응답의 행동(표정 두 번째 박자). B가 거절되어
  /// A가 답했으면 A 응답 기준이다.
  ResponseMove _lastResponseMove = ResponseMove.other;
  ResponseMove get lastResponseMove => _lastResponseMove;

  /// 지금까지 누적된 세션 요약.
  CounselingSessionSummary get sessionSummary => _memory.summary;

  /// 이번 상담에서 참고하는 지난 완료 세션. 없으면 null.
  PreviousSession? get previousSession => _previousSession;

  @visibleForTesting
  CounselingSessionState get debugSession => _session;

  /// 지난 세션에서 이어받은 미해결 주제. 없으면 null.
  String? get carriedUnfinishedIssue => _carriedUnfinishedIssue;

  /// 이번 세션에 쓰는 사용자 컨텍스트. 서버 조회에 실패하면 null 이거나 degraded 다.
  MindriumCounselingContext? get userContext => _session.userContext;

  /// 코퍼스를 올리고 첫 인사를 띄운다.
  Future<void> initialize() async {
    if (_isReady) return;

    await knowledgeRepository.initialize();
    // 앱 안내 자료가 없어도 상담 자체는 계속한다.
    try {
      await appGuideRepository.initialize();
    } on Object catch (e) {
      debugPrint('[CounselingProvider] App Guide 지식 로드 실패: $e');
    }
    // 사용자 컨텍스트는 세션 시작 시 한 번만 읽는다. 턴마다 다시 조회하지 않는다.
    _session.userContext = await _buildContext();
    await _loadPreviousSession();
    if (llmLedApi != null && _glossary.terms.isEmpty) {
      try {
        _glossary = await TermGlossary.load(rootBundle.loadString);
      } on Object catch (e) {
        debugPrint('[CounselingProvider] glossary load failed: $e');
      }
    }
    if (llmLedApi != null) {
      debugPrint(
        'LLM_LED_SESSION ${jsonEncode({'session': pseudonymize(_session.sessionId)})}',
      );
    }

    _messages.add(
      CounselingMessage(
        id: '${_session.sessionId}_greeting',
        role: 'assistant',
        // 첫 인사는 모델이 아니라 앱이 정한다.
        text:
            '안녕하세요.\n마음에 걸리는 걱정을 함께 살펴보거나 앱 사용법을 안내해 드릴 수 있어요.\n'
            '어떤 도움이 필요하신가요?',
        createdAt: DateTime.now(),
      ),
    );

    _isReady = true;
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
      return _withEpisodes(
        await builder.build(
          currentWeek: _session.currentWeek,
          userMessage: userMessage,
        ),
      );
    } on Object catch (e) {
      debugPrint('[CounselingProvider] 사용자 컨텍스트 생성 실패: $e');
      return null;
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    _isGenerating = true;
    _pendingUiAction = null;
    _pendingUiActionMessageId = null;

    try {
      _messages.add(
        CounselingMessage(
          id: '${_session.sessionId}_${_messages.length}_user',
          role: 'user',
          text: trimmed,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();

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
      if (summary.currentThought != null) {
        _coreThoughtSource ??=
            UserThoughtExtractor.evaluativeThought(trimmed) != null
                ? 'current_utterance'
                : 'recent_message';
      }

      // 컨텍스트는 위에서 이미 이번 발화 기준으로 다시 선택했다.
      final result = await _handleTurnLlmLedFirst(trimmed);

      await _applyTurnResult(trimmed, result);
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 상담 경로와 관계없이 화면·기억·저장에 같은 결과를 반영한다.
  Future<void> _applyTurnResult(
    String userText,
    CounselingTurnResult result,
  ) async {
    final finalizedNow =
        result.assistantMessage.closingStep == ClosingStep.finalized &&
        !isSessionFinalized;
    _messages.add(result.assistantMessage);
    _pendingUiAction = result.uiAction;
    _pendingUiActionMessageId =
        result.uiAction == null ? null : result.assistantMessage.id;
    _lastSafetyLevel = result.safety.level;
    if (!result.handledBySafety) {
      final cue = const AffectSignalDetector().detect(userMessage: userText);
      if (cue.label != AffectLabel.neutral &&
          cue.label != AffectLabel.uncertain) {
        _lastSignalLabel = cue.label.name;
      }
    }
    _recordTurn(userText, result);
    _session.messages
      ..clear()
      ..addAll(_messages);
    if (finalizedNow) await _persistSession('completed');
  }

  /// Phase 14.X: the LLM-led path first, the deterministic path when it
  /// does not produce an accepted turn. Logs one line per turn (no text).
  Future<CounselingTurnResult> _handleTurnLlmLedFirst(String userText) async {
    var isPatternRequest = CounselingPatterns.explicitlyRequested(userText);
    final api = llmLedApi;
    final optedOut = _messages
        .where((m) => m.isUser)
        .any((m) => CounselingPatterns.optedOut(m.text));
    if (!isPatternRequest &&
        api != null &&
        patternIntentApi != null &&
        !optedOut &&
        !CounselingPatterns.rejectsAnalysis(userText) &&
        !ClosingDecisionSelector.isExplicitEnd(userText)) {
      final safety = await harness.safetyGate.evaluate(userText);
      if (safety.isNormal) {
        try {
          isPatternRequest = await patternIntentApi!
              .isPatternRequest(userText)
              .timeout(const Duration(seconds: 4));
        } on Object {
          // 네트워크 오류나 시간 초과 시 기존 상담 경로를 사용한다.
        }
      }
    }
    if (isPatternRequest &&
        (api == null ||
            _session.userContext?.patterns == null ||
            _session.userContext!.patterns!
                .relevant(userText, explicit: true)
                .isEmpty)) {
      final patternReply = await _explicitPatternReply(userText);
      if (patternReply != null) return patternReply;
    }
    if (api == null || !_llmLedThisSession) {
      return _committedA(await _turn(userText));
    }
    final endToEnd = Stopwatch()..start();
    final b = await harness.handleLlmLedTurn(
      session: _session,
      userMessage: userText,
      patternAnalysisRequested: isPatternRequest,
      api: api,
      appGuide: appGuideRepository,
      glossary: _glossary,
    );
    if (b.result != null) {
      _logLlmLed(b, null, endToEnd.elapsedMilliseconds);
      final o = b.output;
      _lastResponseMove =
          o == null
              ? ResponseMove.fromMessage(b.result!.assistantMessage)
              : ResponseMove.fromLlmLed(
                domain: o.domain,
                moves: o.moves,
                interventionStep: o.interventionStep,
                sessionAction: o.sessionAction,
              );
      return b.result!;
    }
    final fallbackWatch = Stopwatch()..start();
    final a =
        (isPatternRequest
            ? await _explicitPatternReply(userText)
            : null) ??
        await _turn(userText);
    _logLlmLed(
      b,
      fallbackWatch.elapsedMilliseconds,
      endToEnd.elapsedMilliseconds,
    );
    // the discarded B output never reaches the avatar
    return _committedA(a);
  }

  Future<CounselingTurnResult?> _explicitPatternReply(String userText) async {
    final patterns = _session.userContext?.patterns;
    final optedOut = _messages
        .where((m) => m.isUser)
        .any((m) => CounselingPatterns.optedOut(m.text));
    if (optedOut ||
        CounselingPatterns.rejectsAnalysis(userText) ||
        ClosingDecisionSelector.isExplicitEnd(userText)) {
      return null;
    }
    final selected =
        patterns?.relevant(userText, explicit: true) ??
        const <CounselingPattern>[];
    final safety = await harness.safetyGate.evaluate(userText);
    if (!safety.isNormal) return null;
    if (patterns == null) {
      final before = _session.state;
      final id = '${_session.sessionId}_${_session.totalTurns}_pattern';
      _session.totalTurns += 1;
      return _committedA(
        CounselingTurnResult(
          assistantMessage: CounselingMessage(
            id: id,
            role: 'assistant',
            text: '지금은 기록을 불러오지 못해 패턴을 확인할 수 없어요. 잠시 후 다시 확인해 주세요.',
            createdAt: DateTime.now(),
            dialogueAct: DialogueAct.reflect,
          ),
          state: before,
          stateBefore: before,
          safety: safety,
          handledBySafety: false,
          promptVersion: 'pattern_unavailable_v1',
        ),
      );
    }
    final missing =
        RegExp(r'알림|알람').hasMatch(userText)
            ? (patterns.activeAlarmCount == 0
                ? '현재 켜진 알림이 없어요.'
                : '설정된 알림과 가까운 일기 기록이 반복됐다고 설명하기에는 자료가 충분하지 않아요.')
            : '반복된 시간이나 장소를 설명하기에는 기록이 아직 충분하지 않아요.';
    final text =
        selected.isEmpty
            ? '최근 ${patterns.windowDays}일의 일기 ${patterns.diaryCount}건을 확인했어요. $missing'
            : '${selected.map((p) => p.text).join(' ')} 이 기록이 지금 이야기와 관련이 있을까요?';
    final before = _session.state;
    final id = '${_session.sessionId}_${_session.totalTurns}_pattern';
    _session.totalTurns += 1;
    return _committedA(
      CounselingTurnResult(
        assistantMessage: CounselingMessage(
          id: id,
          role: 'assistant',
          text: text,
          createdAt: DateTime.now(),
          dialogueAct: DialogueAct.reflect,
          referencedUserContextIds:
              selected.map((p) => 'pattern:${p.id}').toList(),
        ),
        state: before,
        stateBefore: before,
        safety: safety,
        handledBySafety: false,
        promptVersion: 'pattern_summary_v1',
      ),
    );
  }

  CounselingTurnResult _committedA(CounselingTurnResult a) {
    _lastResponseMove = ResponseMove.fromMessage(
      a.assistantMessage,
      appGuide: a.promptVersion.startsWith('app_guide'),
    );
    return a;
  }

  /// One line per LLM-led turn (no text): status, rejection reasons and the
  /// latency breakdown, plus the fallback (path A) time when it was used.
  void _logLlmLed(LlmLedTurn b, int? fallbackMs, int endToEndMs) {
    final o = b.output;
    debugPrint(
      'LLM_LED ${jsonEncode({'session': pseudonymize(_session.sessionId), 'turn': _messages.where((m) => m.isUser).length, 'status': b.status, 'group': b.group, 'request_status': b.requestStatus, 'http_status': b.failure?.httpStatus, 'retry_after': b.failure?.retryAfter, 'provider_request_id': b.failure?.providerRequestId, 'reject_cause': b.failure?.cause, 'finish_reason': b.failure?.finishReason, 'fallback': b.result == null, 'latency_ms': b.latencyMs, 'domain': o?.domain, 'moves': o?.moves, 'session_action': o?.sessionAction, 'intervention_step': o?.interventionStep, 'primary_rejection': b.primaryRejection, 'violations': b.violations, ...b.timing, 'fallback_ms': fallbackMs, 'end_to_end_ms': endToEndMs})}',
    );
  }

  Future<CounselingTurnResult> _turn(String userText) =>
      _assistantHarness.handleTurn(
        session: _session,
        userMessage: userText,
        previousSessionContext: PreviousSessionContext(
          latestRelevantSession: _previousSession,
          carriedUnfinishedIssue: _carriedUnfinishedIssue,
        ),
      );

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
    final record = CounselingSessionRecord.build(
      summary: summary,
      messages: _session.messages,
      coreThoughtSource: _coreThoughtSource,
      affect: _lastSignalLabel,
    );
    final facts = record.facts;
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
        mainConcern: record.mainConcern,
        coreThought: facts.coreThought,
        coreThoughtSource: record.coreThoughtSource,
        alternativeThought: facts.alternativeThought,
        affect: record.affect,
        sudStart: facts.sudStart,
        sudEnd: facts.sudEnd,
        interventionUsed: summary.interventionUsed,
        activityRecommended: summary.activityRecommended,
        unfinishedIssue: facts.unfinishedIssue,
        interventionOutcome: record.interventionOutcome,
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
        interventionCbtId:
            plan?.interventionPlan?.selectedCbtId ??
            (result.assistantMessage.interventionStep == InterventionStep.prompt
                ? result.assistantMessage.referencedCbtIds.firstOrNull
                : null),
        activity: plan?.interventionPlan?.recommendation.activity?.name,
        provenanceIds:
            {
              ...result.retrievalProvenanceIds,
              ...result.assistantMessage.referencedUserContextIds,
            }.toList(),
      ),
    );
  }

  /// 대화를 처음부터 다시 시작한다.
  Future<void> reset() async {
    if (_isGenerating) return;
    _isGenerating = true;
    notifyListeners();
    try {
      await finalizeIfIncomplete();
      _session = CounselingSessionState(
        sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
        currentWeek: _session.currentWeek,
      );
      _messages.clear();
      _pendingUiAction = null;
      _pendingUiActionMessageId = null;
      _savedAsCompleted = false;
      _startedAt = DateTime.now();
      _persistQueue = Future<void>.value();
      _lastPersistedTurnCount = -1;
      _lastPersistedStatus = null;
      _coreThoughtSource = null;
      _lastSignalLabel = null;
      _previousSession = null;
      _carriedUnfinishedIssue = null;
      _lastRetrievalSummary = null;
      _memory = CounselingSessionMemory(sessionId: _session.sessionId);
      _lastSafetyLevel = SafetyLevel.normal;
      _isReady = false;
      await initialize();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}
