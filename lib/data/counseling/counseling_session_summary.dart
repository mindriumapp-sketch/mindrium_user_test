import 'counseling_models.dart';
import 'user_thought_extractor.dart';

/// 한 상담 세션에서 확인된 사실들.
///
/// **LLM 요약이 아니다.** 상담 중 harness 가 각 턴에서 이미 알고 있던 값을
/// 그대로 누적한 것이다. 모델에게 "지난 상담을 요약해줘"라고 물으면 없는 내용을
/// 지어낼 수 있고, 다음 세션의 개인화가 그 위에 쌓인다.
///
/// 확인되지 않은 항목은 null 로 남긴다.
class CounselingSessionSummary {
  final String sessionId;

  /// 이번 세션의 주제.
  final String? concern;

  /// 상황(A).
  final String? activatingEvent;

  /// 자동적 사고(B).
  final String? automaticThought;

  /// 감정(C).
  final String? emotion;

  /// 행동(C).
  final String? behavior;

  /// 근거 탐색 질문에 사용자가 답한 내용.
  final String? exploredEvidence;

  /// 사용자가 이번 세션에서 찾은 대안적 생각.
  final String? alternativeThought;

  /// 사용한 승인 개입의 CBT id.
  final String? interventionUsed;

  /// 제안한 앱 활동.
  final String? activityRecommended;

  /// 개입 뒤 사용자의 반응.
  final String? userResponse;

  /// 세션 종료 시점의 SUD.
  final int? endingSud;

  /// 다루지 못하고 남은 주제.
  final String? unfinishedTopic;

  /// 위 항목을 채우는 데 사용한 사용자 기록 id.
  final List<String> provenanceIds;

  /// 세션에서 진행한 사용자 턴 수.
  final int turnCount;

  const CounselingSessionSummary({
    required this.sessionId,
    this.concern,
    this.activatingEvent,
    this.automaticThought,
    this.emotion,
    this.behavior,
    this.exploredEvidence,
    this.alternativeThought,
    this.interventionUsed,
    this.activityRecommended,
    this.userResponse,
    this.endingSud,
    this.unfinishedTopic,
    this.provenanceIds = const [],
    this.turnCount = 0,
  });

  /// 다음 세션 개인화에 쓸 만한 내용이 있는지.
  bool get hasContent =>
      concern != null ||
      automaticThought != null ||
      alternativeThought != null ||
      interventionUsed != null;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'concern': concern,
    'activating_event': activatingEvent,
    'automatic_thought': automaticThought,
    'emotion': emotion,
    'behavior': behavior,
    'explored_evidence': exploredEvidence,
    'alternative_thought': alternativeThought,
    'intervention_used': interventionUsed,
    'activity_recommended': activityRecommended,
    'user_response': userResponse,
    'ending_sud': endingSud,
    'unfinished_topic': unfinishedTopic,
    'provenance_ids': provenanceIds,
    'turn_count': turnCount,
  };
}

/// 턴마다 확인된 사실을 누적한다.
///
/// 한 번에 요약을 만들지 않고 턴 단위로 쌓는 이유는, 상담이 끝난 뒤에는
/// "그때 사용자가 무엇에 답했는지"를 다시 판단해야 하지만 진행 중에는
/// harness 가 이미 알고 있기 때문이다.
class CounselingSessionMemory {
  final String sessionId;

  String? _concern;
  String? _activatingEvent;
  String? _automaticThought;
  String? _emotion;
  String? _behavior;
  String? _exploredEvidence;
  String? _alternativeThought;
  String? _interventionUsed;
  String? _activityRecommended;
  String? _userResponse;
  int? _endingSud;
  String? _unfinishedTopic;
  int _turnCount = 0;

  final Set<String> _provenance = {};

  /// 직전 턴에 어떤 질문을 했는지. 다음 사용자 발화를 무엇으로 볼지 정한다.
  _PendingAnswer _pending = _PendingAnswer.none;

  CounselingSessionMemory({required this.sessionId});

  CounselingSessionSummary get summary => CounselingSessionSummary(
    sessionId: sessionId,
    concern: _concern,
    activatingEvent: _activatingEvent,
    automaticThought: _automaticThought,
    emotion: _emotion,
    behavior: _behavior,
    exploredEvidence: _exploredEvidence,
    alternativeThought: _alternativeThought,
    interventionUsed: _interventionUsed,
    activityRecommended: _activityRecommended,
    userResponse: _userResponse,
    endingSud: _endingSud,
    unfinishedTopic: _unfinishedTopic,
    provenanceIds: _provenance.toList()..sort(),
    turnCount: _turnCount,
  );

  /// 한 턴을 기록한다.
  ///
  /// [record] 는 harness 결과에 의존하지 않도록 필요한 값만 받는다.
  /// 그래야 provider 든 테스트든 같은 방식으로 쌓을 수 있다.
  void record(SessionTurnRecord turn) {
    _turnCount++;

    // 직전 턴에 무엇을 물었는지에 따라 이번 발화의 의미가 정해진다.
    switch (_pending) {
      case _PendingAnswer.evidence:
        _exploredEvidence ??= turn.userMessage;
      case _PendingAnswer.alternativeThought:
        _alternativeThought ??= turn.userMessage;
        _userResponse = turn.userMessage;
      case _PendingAnswer.none:
        break;
    }
    _pending = _PendingAnswer.none;

    _concern ??= turn.theme;
    _automaticThought ??= turn.automaticThought;
    _activatingEvent ??= turn.activatingEvent;
    _emotion ??= turn.emotion;
    _behavior ??= turn.behavior;
    if (turn.sud != null) _endingSud = turn.sud;
    _unfinishedTopic = turn.unfinishedIssue ?? _unfinishedTopic;

    if (turn.interventionCbtId != null) {
      _interventionUsed = turn.interventionCbtId;
      _activityRecommended = turn.activity ?? _activityRecommended;
      _pending = _PendingAnswer.alternativeThought;
    } else if (turn.askedEvidence) {
      _pending = _PendingAnswer.evidence;
    }

    _provenance.addAll(turn.provenanceIds);
  }

  /// 개입까지 가지 못한 채 끝났다면 지금 다루던 생각을 미해결로 남긴다.
  void close() {
    if (_interventionUsed == null && _alternativeThought == null) {
      _unfinishedTopic ??= _automaticThought;
    }
  }
}

enum _PendingAnswer { none, evidence, alternativeThought }

/// 한 턴에서 확인된 값. harness 가 이미 아는 것만 담는다.
class SessionTurnRecord {
  final String userMessage;
  final String? theme;
  final String? automaticThought;
  final String? activatingEvent;
  final String? emotion;
  final String? behavior;
  final int? sud;
  final String? unfinishedIssue;

  /// 이번 턴에 근거 탐색 질문을 했는지.
  final bool askedEvidence;

  /// 이번 턴에 사용한 승인 개입의 CBT id.
  final String? interventionCbtId;

  /// 이번 턴에 제안한 앱 활동.
  final String? activity;

  final List<String> provenanceIds;

  const SessionTurnRecord({
    required this.userMessage,
    this.theme,
    this.automaticThought,
    this.activatingEvent,
    this.emotion,
    this.behavior,
    this.sud,
    this.unfinishedIssue,
    this.askedEvidence = false,
    this.interventionCbtId,
    this.activity,
    this.provenanceIds = const [],
  });

  /// 사용자 컨텍스트의 일기에서 A/B/C 항목을 꺼내 채운다.
  factory SessionTurnRecord.fromDiary({
    required String userMessage,
    required UserContextItem? diary,
    String? theme,
    String? automaticThought,
    int? sud,
    String? unfinishedIssue,
    bool askedEvidence = false,
    String? interventionCbtId,
    String? activity,
    List<String> provenanceIds = const [],
  }) {
    return SessionTurnRecord(
      userMessage: userMessage,
      theme: theme,
      automaticThought: automaticThought,
      activatingEvent: UserThoughtExtractor.situationFromDiary(diary?.text),
      emotion: UserThoughtExtractor.emotionFromDiary(diary?.text),
      behavior: UserThoughtExtractor.behaviorFromDiary(diary?.text),
      sud: sud,
      unfinishedIssue: unfinishedIssue,
      askedEvidence: askedEvidence,
      interventionCbtId: interventionCbtId,
      activity: activity,
      provenanceIds: provenanceIds,
    );
  }
}
