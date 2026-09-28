import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';

/// [UserContextRetriever]가 만드는 개인화 근거 묶음.
///
/// **DB/세션 근거가 없는 필드는 항상 null이다.** "이 사용자는 회피 성향이
/// 강하다" 같은 장기 성향 추론은 이 클래스가 존재하는 한 만들지 않는다 —
/// 모든 필드는 실제 기록(현재 발화/일기/지난 세션)에서 그대로 옮긴 값이거나,
/// 그 값이 있는지를 나타내는 boolean이다.
///
/// 지난 세션 관련 필드(`unfinishedIssue`/`previousIntervention`/
/// `previousSessionSummary`)는 [RetrievalSummary.hasPreviousSessionReference]
/// (이번 주제와 관련될 때만 참) 가드를 통과했을 때만 채워진다 — 무관한
/// 과거 세션이 새 대화에 섞여 들어가지 않도록 하는 기존 안전장치를
/// 그대로 물려받는다.
class PersonalContextSummary {
  /// 이번 발화에 드러난 핵심 생각. [RetrievalSummary.currentThought].
  final String? currentRelatedIssue;

  /// 과거 기록에 있는 비슷한 생각. [RetrievalSummary.similarPastThought].
  final String? previousSimilarIssue;

  /// 사용자가 전에 스스로 찾은 대안적 생각(현재 세션 내 또는 관련 지난
  /// 세션에서). [RetrievalSummary.previousAlternativeThought]를 우선하고,
  /// 없으면 관련된 지난 세션의 것을 쓴다.
  final String? previousAlternativeThought;

  /// 전후 SUD가 실제로 낮아진 것이 확인된 활동.
  /// [RetrievalSummary.previouslyHelpfulActivity].
  final EffectiveIntervention? previousHelpfulActivity;

  final int? recentSud;

  /// 'increasing' | 'decreasing' | 'stable'
  final String? sudTrend;

  /// 불안이 높았는데 대안적 생각이 남지 않은 미해결 기록.
  final String? unfinishedIssue;

  /// 관련된 지난 세션에서 사용한 승인 개입의 CBT id.
  final String? previousIntervention;

  /// 관련된 지난 세션의 구조화 기록 그 자체(추론이 아니라 서버에 저장된
  /// 사실). 관련 없으면 null이다.
  final PreviousSession? previousSessionSummary;

  /// 위 필드를 만드는 데 실제로 쓴 기록 id — validator가 "이 문장이 실제
  /// DB에 근거하는가"를 확인할 근거.
  final List<String> evidenceIds;

  final bool degraded;

  const PersonalContextSummary({
    this.currentRelatedIssue,
    this.previousSimilarIssue,
    this.previousAlternativeThought,
    this.previousHelpfulActivity,
    this.recentSud,
    this.sudTrend,
    this.unfinishedIssue,
    this.previousIntervention,
    this.previousSessionSummary,
    this.evidenceIds = const [],
    this.degraded = false,
  });

  static const empty = PersonalContextSummary();

  /// 관련 있는 과거 걱정이 있는지. 향후 Agent가 "처음부터 다시 탐색하지
  /// 않고 이어갈지"를 정할 때 쓸 신호다 — 지금은 아무도 읽지 않는다.
  bool get hasRelevantPastIssue =>
      previousSimilarIssue != null || previousSessionSummary != null;

  bool get hasPreviousAlternativeThought => previousAlternativeThought != null;

  bool get hasHelpfulActivity => previousHelpfulActivity != null;

  bool get hasUnfinishedIssue => unfinishedIssue != null;

  bool get sudTrendAvailable => sudTrend != null;

  /// 기존 [RetrievalSummary] + 지난 세션 원본 기록으로부터 만든다. 새 판단
  /// 기준을 추가하지 않고, [RetrievalSummary]가 이미 적용한 관련성
  /// 가드([RetrievalSummary.hasPreviousSessionReference])만 따른다.
  factory PersonalContextSummary.fromRetrievalSummary(
    RetrievalSummary summary, {
    PreviousSession? previousSession,
    bool degraded = false,
  }) {
    final sessionIsRelevant = summary.hasPreviousSessionReference;

    return PersonalContextSummary(
      currentRelatedIssue: summary.currentThought,
      previousSimilarIssue: summary.similarPastThought,
      previousAlternativeThought:
          summary.previousAlternativeThought ??
          (sessionIsRelevant ? summary.previousSessionAlternativeThought : null),
      previousHelpfulActivity: summary.previouslyHelpfulActivity,
      recentSud: summary.recentSud,
      sudTrend: summary.sudTrend,
      unfinishedIssue: summary.unfinishedIssue,
      previousIntervention:
          sessionIsRelevant ? previousSession?.interventionUsed : null,
      previousSessionSummary: sessionIsRelevant ? previousSession : null,
      evidenceIds: summary.provenanceIds,
      degraded: degraded,
    );
  }
}
