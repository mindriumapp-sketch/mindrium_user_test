import 'package:flutter/foundation.dart';
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';

import 'counseling_harness.dart';
import 'counseling_state.dart';
import 'safety_gate.dart';

/// 채팅 화면의 상태를 들고 있는다.
///
/// Step 1 은 메모리에만 저장한다. MongoDB 로 남기는 것은 Step 4 다.
class CounselingProvider extends ChangeNotifier {
  final CounselingHarness harness;
  final CbtKnowledgeRepository knowledgeRepository;

  /// 없으면 개인화 없이 동작한다. 서버에 접근할 수 없는 환경도 있으므로 선택으로 둔다.
  final MindriumContextBuilder? contextBuilder;

  CounselingSessionState _session;
  final List<CounselingMessage> _messages = [];
  bool _isGenerating = false;
  bool _isReady = false;
  CounselingUiAction? _pendingUiAction;
  SafetyLevel _lastSafetyLevel = SafetyLevel.normal;

  CounselingProvider({
    required this.harness,
    required this.knowledgeRepository,
    required int currentWeek,
    this.contextBuilder,
    String? sessionId,
  }) : _session = CounselingSessionState(
         sessionId:
             sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
         currentWeek: currentWeek,
       );

  List<CounselingMessage> get messages => List.unmodifiable(_messages);
  CounselingState get state => _session.state;
  bool get isGenerating => _isGenerating;
  bool get isReady => _isReady;
  CounselingUiAction? get pendingUiAction => _pendingUiAction;

  /// 직전 턴의 안전 수준. 표시 계층이 위기 상황에서 연출을 줄이는 데 쓴다.
  SafetyLevel get lastSafetyLevel => _lastSafetyLevel;

  /// 이번 세션에 쓰는 사용자 컨텍스트. 서버 조회에 실패하면 null 이거나 degraded 다.
  MindriumCounselingContext? get userContext => _session.userContext;

  /// 코퍼스를 올리고 첫 인사를 띄운다.
  Future<void> initialize() async {
    if (_isReady) return;

    await knowledgeRepository.initialize();

    // 사용자 컨텍스트는 세션 시작 시 한 번만 읽는다. 턴마다 다시 조회하지 않는다.
    _session.userContext = await _buildContext();

    _messages.add(
      CounselingMessage(
        id: '${_session.sessionId}_greeting',
        role: 'assistant',
        // 첫 인사는 모델이 아니라 앱이 정한다.
        text: '안녕하세요. 오늘 어떤 이야기를 나누고 싶으신가요?\n'
            '지금 마음에 걸리는 일이 있다면 편하게 적어 주세요.',
        createdAt: DateTime.now(),
      ),
    );

    _isReady = true;
    notifyListeners();
  }

  /// 상담 중 새 기록이 생긴 경우처럼, 명시적으로 컨텍스트를 다시 읽어야 할 때 호출한다.
  Future<void> refreshContext() async {
    _session.userContext = await _buildContext();
    notifyListeners();
  }

  /// 컨텍스트 조회는 실패해도 상담을 막지 않는다.
  Future<MindriumCounselingContext?> _buildContext() async {
    final builder = contextBuilder;
    if (builder == null) return null;

    try {
      return await builder.build(currentWeek: _session.currentWeek);
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
    _isGenerating = true;
    _pendingUiAction = null;
    notifyListeners();

    try {
      final result = await harness.handleTurn(
        session: _session,
        userMessage: trimmed,
      );

      _messages.add(result.assistantMessage);
      _pendingUiAction = result.uiAction;
      _lastSafetyLevel = result.safety.level;

      // harness 가 프롬프트에 넣을 최근 대화를 세션에서 읽으므로 함께 갱신한다.
      _session.messages
        ..clear()
        ..addAll(_messages);
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 대화를 처음부터 다시 시작한다.
  Future<void> reset() async {
    _session = CounselingSessionState(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      currentWeek: _session.currentWeek,
    );
    _messages.clear();
    _pendingUiAction = null;
    _lastSafetyLevel = SafetyLevel.normal;
    _isReady = false;
    await initialize();
  }
}
