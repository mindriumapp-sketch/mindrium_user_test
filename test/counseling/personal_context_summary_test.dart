import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';

/// Phase 5 — PersonalContextSummary는 실제 DB/세션 근거에서만 값을
/// 만들어야 한다. 추론(예: "회피 성향이 강하다")은 절대 만들지 않는다.
void main() {
  group('PersonalContextSummary.fromRetrievalSummary', () {
    test('근거가 전혀 없으면 모든 필드가 비어 있다', () {
      final summary = PersonalContextSummary.fromRetrievalSummary(
        RetrievalSummary.empty,
      );

      expect(summary.currentRelatedIssue, isNull);
      expect(summary.previousSimilarIssue, isNull);
      expect(summary.previousAlternativeThought, isNull);
      expect(summary.previousHelpfulActivity, isNull);
      expect(summary.unfinishedIssue, isNull);
      expect(summary.previousIntervention, isNull);
      expect(summary.previousSessionSummary, isNull);
      expect(summary.evidenceIds, isEmpty);

      expect(summary.hasRelevantPastIssue, isFalse);
      expect(summary.hasPreviousAlternativeThought, isFalse);
      expect(summary.hasHelpfulActivity, isFalse);
      expect(summary.hasUnfinishedIssue, isFalse);
      expect(summary.sudTrendAvailable, isFalse);
    });

    test('DB 근거가 있는 필드만 그대로 옮긴다 — 지어내지 않는다', () {
      final retrieval = RetrievalSummary(
        currentThought: '발표에서 질문에 답 못할까 봐 걱정된다',
        similarPastThought: '예전에도 비슷한 걱정을 했다',
        recentSud: 7,
        sudTrend: 'increasing',
        unfinishedIssue: '발표 질문 상황',
        provenanceIds: const ['diary:abc123'],
      );

      final summary = PersonalContextSummary.fromRetrievalSummary(retrieval);

      expect(summary.currentRelatedIssue, retrieval.currentThought);
      expect(summary.previousSimilarIssue, retrieval.similarPastThought);
      expect(summary.recentSud, 7);
      expect(summary.sudTrend, 'increasing');
      expect(summary.unfinishedIssue, '발표 질문 상황');
      expect(summary.evidenceIds, ['diary:abc123']);
      expect(summary.hasUnfinishedIssue, isTrue);
      expect(summary.sudTrendAvailable, isTrue);

      // 지난 세션 관련성이 없으므로(hasPreviousSessionReference == false)
      // previousIntervention/previousSessionSummary는 여전히 비어 있어야
      // 한다. 다만 similarPastThought 자체는 있으므로
      // hasRelevantPastIssue는 참이다 — 이건 "지난 세션 참조"가 아니라
      // "비슷한 과거 생각이 있다"는 별개의 신호다.
      expect(summary.previousIntervention, isNull);
      expect(summary.previousSessionSummary, isNull);
      expect(summary.hasRelevantPastIssue, isTrue);
    });

    test('지난 세션이 이번 주제와 관련될 때만 세션 필드를 채운다', () {
      final previousSession = PreviousSession(
        sessionId: 's1',
        week: 3,
        completionStatus: 'completed',
        mainConcern: '발표 전 긴장',
        coreThought: '질문에 답하지 못하면 무능해 보일 것이다',
        interventionUsed: 'week3_balanced_thought_01',
        provenanceIds: const ['session:s1'],
      );
      final retrieval = RetrievalSummary(
        previousSessionThought: previousSession.coreThought,
      );

      final relevant = PersonalContextSummary.fromRetrievalSummary(
        retrieval,
        previousSession: previousSession,
      );

      expect(relevant.previousIntervention, 'week3_balanced_thought_01');
      expect(relevant.previousSessionSummary, previousSession);
      expect(relevant.hasRelevantPastIssue, isTrue);

      // hasPreviousSessionReference가 false인 요약(관련 없음)에는 같은
      // previousSession을 넘겨도 세션 필드가 비어 있어야 한다 — 무관한
      // 과거 세션이 새 대화에 섞이지 않는 기존 안전장치를 그대로 물려받음.
      final unrelated = PersonalContextSummary.fromRetrievalSummary(
        RetrievalSummary.empty,
        previousSession: previousSession,
      );

      expect(unrelated.previousIntervention, isNull);
      expect(unrelated.previousSessionSummary, isNull);
    });

    test('degraded 플래그를 그대로 옮긴다', () {
      final summary = PersonalContextSummary.fromRetrievalSummary(
        RetrievalSummary.empty,
        degraded: true,
      );

      expect(summary.degraded, isTrue);
    });
  });
}
