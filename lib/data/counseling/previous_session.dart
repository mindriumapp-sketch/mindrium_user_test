/// 서버에 저장된 지난 상담 세션 요약.
///
/// 전체 대화가 아니라 구조화된 사실만 담는다.
class PreviousSession {
  final String sessionId;
  final int week;

  /// 'completed' | 'interrupted'
  final String completionStatus;

  final String? mainConcern;
  final String? coreThought;

  /// coreThought 가 어디서 나왔는지. 'current_utterance' | 'recent_message' | 'diary'
  final String? coreThoughtSource;

  final String? alternativeThought;
  final String? interventionUsed;
  final String? activityRecommended;
  final String? unfinishedIssue;

  /// 기법 답이 어떻게 받아들여졌는지. 'credited'(기법 성과로 인정) |
  /// 'acknowledged'(저정보·중립 답으로만 받아 줌) | null(기법 없음 또는 이전 기록).
  final String? interventionOutcome;
  final int? sudEnd;
  final List<String> provenanceIds;
  final DateTime? endedAt;

  const PreviousSession({
    required this.sessionId,
    required this.week,
    required this.completionStatus,
    this.mainConcern,
    this.coreThought,
    this.coreThoughtSource,
    this.alternativeThought,
    this.interventionUsed,
    this.activityRecommended,
    this.unfinishedIssue,
    this.interventionOutcome,
    this.sudEnd,
    this.provenanceIds = const [],
    this.endedAt,
  });

  bool get isCompleted => completionStatus == 'completed';

  factory PreviousSession.fromJson(Map<String, dynamic> json) {
    return PreviousSession(
      sessionId: (json['session_id'] ?? '').toString(),
      week: (json['week'] as num?)?.toInt() ?? 0,
      completionStatus: (json['completion_status'] ?? '').toString(),
      mainConcern: json['main_concern'] as String?,
      coreThought: json['core_thought'] as String?,
      coreThoughtSource: json['core_thought_source'] as String?,
      alternativeThought: json['alternative_thought'] as String?,
      interventionUsed: json['intervention_used'] as String?,
      activityRecommended: json['activity_recommended'] as String?,
      unfinishedIssue: json['unfinished_issue'] as String?,
      interventionOutcome: json['intervention_outcome'] as String?,
      sudEnd: (json['sud_end'] as num?)?.toInt(),
      provenanceIds:
          (json['provenance_ids'] as List?)?.whereType<String>().toList() ??
          const [],
      endedAt: DateTime.tryParse((json['ended_at'] ?? '').toString()),
    );
  }
}

/// 이번 상담에서 참고할 지난 세션 한 건을 고른다.
///
/// **완료된 세션을 우선한다.** 중단된 세션은 상담이 끝까지 가지 못한 기록이라
/// 결론이 불완전하고, 그걸 "지난번에 이렇게 정리했었죠"처럼 쓰면 사용자가 하지
/// 않은 마무리를 상담자가 지어내게 된다.
///
/// 중단 세션은 **미해결 주제만** 보조로 쓴다.
class PreviousSessionSelector {
  const PreviousSessionSelector();

  /// 참고할 완료 세션. 없으면 null.
  PreviousSession? selectPrimary(List<PreviousSession> sessions) {
    PreviousSession? best;
    for (final session in sessions) {
      if (!session.isCompleted) continue;
      if (best == null || _isNewer(session, best)) best = session;
    }
    return best;
  }

  /// 중단 세션에서 이어받을 미해결 주제.
  ///
  /// 완료 세션이 이미 같은 주제를 다뤘다면 꺼내지 않는다.
  String? selectUnfinishedIssue(
    List<PreviousSession> sessions, {
    PreviousSession? primary,
  }) {
    // 완료 세션의 미해결 주제가 있으면 그것이 우선이다.
    final fromPrimary = primary?.unfinishedIssue;
    if (fromPrimary != null && fromPrimary.trim().isNotEmpty) {
      return fromPrimary;
    }

    PreviousSession? candidate;
    for (final session in sessions) {
      if (session.isCompleted) continue;
      final issue = session.unfinishedIssue;
      if (issue == null || issue.trim().isEmpty) continue;
      // 완료 세션보다 오래된 중단 기록은 이미 지난 이야기로 본다.
      if (primary != null && !_isNewer(session, primary)) continue;
      if (candidate == null || _isNewer(session, candidate)) {
        candidate = session;
      }
    }
    return candidate?.unfinishedIssue;
  }

  bool _isNewer(PreviousSession a, PreviousSession b) {
    final at = a.endedAt;
    final bt = b.endedAt;
    if (at == null) return false;
    if (bt == null) return true;
    return at.isAfter(bt);
  }
}
