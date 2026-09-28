import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';

import 'personal_context_summary.dart';
import 'previous_session_context.dart';

export 'personal_context_summary.dart';
export 'previous_session_context.dart';

/// [UserContextRetriever]에 넘기는 입력.
///
/// `context`는 이미 서버에서 조회해 둔 [MindriumCounselingContext]다 — 이
/// retriever는 네트워크를 새로 호출하지 않는다(중복 조회 방지). 실제 조회는
/// 여전히 `MindriumContextBuilder`(및 `CounselingProvider`)가 담당한다. 이
/// 경계가 감싸는 것은 그 결과를 상담에 쓸 요약으로 압축하는 단계다.
///
/// `previousSessionContext`는 세션 상태 머신([CounselingSessionState])이
/// 아니라 [CounselingProvider]가 세션 시작 시 한 번 조회해 둔 지난 세션
/// 기억이다. [PreviousSessionContext.none]이면 이번 발화와 관련 있는 지난
/// 세션을 참조하지 않는다.
class UserContextRequest {
  final String userMessage;
  final MindriumCounselingContext? context;
  final List<CounselingMessage> recentMessages;
  final PreviousSessionContext previousSessionContext;

  const UserContextRequest({
    required this.userMessage,
    this.context,
    this.recentMessages = const [],
    this.previousSessionContext = PreviousSessionContext.none,
  });
}

/// [UserContextRetriever]의 결과.
///
/// [retrievalSummary]는 기존 [RetrievalSummary] 그 자체다(호환성 유지 —
/// `CounselingHarness`에 그대로 다시 넘길 수 있다). [personalContext]는
/// Phase 5에서 추가된, 향후 Agent가 쓰기 쉬운 구조화 묶음이다. 둘은 같은
/// 근거에서 나온 동일한 정보를 다른 모양으로 노출할 뿐 — 새 판단 기준을
/// 추가하지 않는다.
class UserContextResult {
  final RetrievalSummary retrievalSummary;
  final PersonalContextSummary personalContext;
  final List<String> provenanceIds;
  final bool degraded;

  const UserContextResult({
    required this.retrievalSummary,
    this.personalContext = PersonalContextSummary.empty,
    this.provenanceIds = const [],
    this.degraded = false,
  });

  static const empty = UserContextResult(
    retrievalSummary: RetrievalSummary.empty,
  );
}

/// "이 사용자에 대해 무엇을 알고 있는가?"를 답하는 경계.
///
/// 실제 사용자 DB 조회(일기/걱정그룹/이완활동)는 이 인터페이스 뒤에 있지
/// 않다 — 그건 `MindriumContextBuilder`가 세션 시작/발화마다 이미 하고
/// 있고, 이 retriever는 그 결과를 상담에 쓸 요약(`RetrievalSummary`/
/// `PersonalContextSummary`)으로 압축하는 기존 로직만 감싼다. 새 검색
/// 알고리즘을 여기서 만들지 않는다.
abstract interface class UserContextRetriever {
  Future<UserContextResult> retrieve(UserContextRequest request);
}

/// 현재 production이 쓰는 유일한 구현. `RetrievalSummaryBuilder`(기존
/// 코드, 변경 없음) 앞에 이 인터페이스를 씌운 adapter다.
class MindriumUserContextRetriever implements UserContextRetriever {
  final RetrievalSummaryBuilder summaryBuilder;

  const MindriumUserContextRetriever({
    this.summaryBuilder = const RetrievalSummaryBuilder(),
  });

  @override
  Future<UserContextResult> retrieve(UserContextRequest request) async {
    final previousSessionContext = request.previousSessionContext;
    final summary = summaryBuilder.build(
      userMessage: request.userMessage,
      context: request.context,
      recentMessages: request.recentMessages,
      previousSession: previousSessionContext.latestRelevantSession,
      carriedUnfinishedIssue: previousSessionContext.carriedUnfinishedIssue,
    );
    final degraded = request.context?.degraded ?? false;

    return UserContextResult(
      retrievalSummary: summary,
      personalContext: PersonalContextSummary.fromRetrievalSummary(
        summary,
        previousSession: previousSessionContext.latestRelevantSession,
        degraded: degraded,
      ),
      provenanceIds: summary.provenanceIds,
      degraded: degraded,
    );
  }
}
