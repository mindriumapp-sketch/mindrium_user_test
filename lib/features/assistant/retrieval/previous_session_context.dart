import 'package:gad_app_team/data/counseling/previous_session.dart';

/// 장기 기억(지난 세션) 입력. [CounselingSessionState]는 "이번 턴의 상태
/// 머신"만 책임지므로, 여러 세션에 걸친 기억은 여기 분리해 둔다.
///
/// `latestRelevantSession`은 기존 `PreviousSessionSelector.selectPrimary()`가
/// 이미 고른 결과를 그대로 받는다 — 새 선택 로직을 만들지 않는다.
class PreviousSessionContext {
  final PreviousSession? latestRelevantSession;
  final String? carriedUnfinishedIssue;

  const PreviousSessionContext({
    this.latestRelevantSession,
    this.carriedUnfinishedIssue,
  });

  static const none = PreviousSessionContext();
}
