// Phase 9.1: RemoteCounselorRequest serialization + privacy minimization.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_request.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

CbtKnowledgeItem _cbt(String id) => CbtKnowledgeItem(
  id: id,
  week: 4,
  type: 'technique',
  title: 'title-$id',
  paragraphs: const ['이 문단은 절대 request JSON에 나타나면 안 된다'],
  tags: const ['alternative_thought'],
  source: 'test',
  conversationalGuidanceAvailable: true,
);

void main() {
  group('buildRemoteCounselorRequest', () {
    late PolicyBoundaryRequest context;
    late PolicyBoundary policy;

    setUp(() {
      final fullDiaryText =
          '이것은 원본 일기 전문이며 raw diary이므로 절대 request에 포함되면 안 된다';
      context = PolicyBoundaryRequest(
        currentState: CounselingState.reflect,
        userMessage: '오늘 발표가 걱정돼요',
        userContext: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            UserContextItem(
              id: 'diary:1',
              type: UserContextType.diary,
              text: fullDiaryText,
              occurredAt: DateTime(2026, 9, 1),
              sud: 7,
            ),
          ],
        ),
        recentMessages: [
          CounselingMessage(
            id: '1',
            role: 'user',
            text: '아주 오래된 메시지 - window 밖',
            createdAt: DateTime(2026, 9, 1),
          ),
          CounselingMessage(
            id: '2',
            role: 'assistant',
            text: '최근 메시지 1',
            createdAt: DateTime(2026, 9, 2),
          ),
          CounselingMessage(
            id: '3',
            role: 'user',
            text: '최근 메시지 2',
            createdAt: DateTime(2026, 9, 3),
          ),
        ],
        currentWeek: 4,
        interventionRegistry: const ApprovedInterventionRegistry(),
        knowledge: [_cbt('cbt-1'), _cbt('cbt-2')],
        retrievalSummary: RetrievalSummary.empty,
      );

      policy = PolicyBoundary(
        currentState: CounselingState.reflect,
        allowedActions: const [DialogueAct.socraticQuestion],
        candidateGoalIds: const ['evidence', 'alternative'],
        eligibleInterventionIds: const ['cbt-1'],
        allowedFactIds: const ['diary:1'],
        forbiddenConstraints: const [TurnConstraint.forbidAdvice],
        progressInfo: DialogueProgressInfo(
          askedGoalIds: const {'probability'},
          usedInterventionIds: const {'cbt-old'},
          recentUserThoughts: const ['최근 메시지 2'],
          conversationTopics: const {'발표'},
          isFirstReflectTurn: false,
        ),
      );
    });

    test('preserves allowedActions/candidateGoalIds/eligibleInterventionIds exactly', () {
      final request = buildRemoteCounselorRequest(
        context: context,
        policy: policy,
        personalContext: PersonalContextSummary.empty,
      );

      expect(request.allowedActions, ['socratic_question']);
      expect(request.candidateGoalIds, ['evidence', 'alternative']);
      expect(request.eligibleInterventionIds, ['cbt-1']);
    });

    test('windows recent conversation instead of sending full transcript', () {
      final request = buildRemoteCounselorRequest(
        context: context,
        policy: policy,
        personalContext: PersonalContextSummary.empty,
        recentConversationWindow: 2,
      );

      expect(request.recentConversation.length, 2);
      expect(
        request.recentConversation.map((t) => t.text),
        ['최근 메시지 1', '최근 메시지 2'],
      );
      final json = request.toJson();
      final texts = (json['recent_conversation'] as List)
          .map((t) => (t as Map)['text'])
          .toList();
      expect(texts, isNot(contains('아주 오래된 메시지 - window 밖')));
    });

    test('only forwards CBT knowledge items that are eligible this turn, id/title/tags only', () {
      final request = buildRemoteCounselorRequest(
        context: context,
        policy: policy,
        personalContext: PersonalContextSummary.empty,
      );

      expect(request.allowedCbtKnowledge.length, 1);
      expect(request.allowedCbtKnowledge.single.id, 'cbt-1');
      final json = request.toJson();
      final knowledgeJson = (json['allowed_cbt_knowledge'] as List).single as Map;
      expect(knowledgeJson.containsKey('paragraphs'), isFalse);
      expect(knowledgeJson.keys.toSet(), {'id', 'title', 'tags'});
    });

    test('never includes raw diary text or full session objects in the JSON', () {
      final personalContext = PersonalContextSummary.fromRetrievalSummary(
        const RetrievalSummary(
          currentThought: '이것은 raw context 텍스트이며 request에 포함되면 안 된다',
          provenanceIds: ['diary:1'],
        ),
      );
      final request = buildRemoteCounselorRequest(
        context: context,
        policy: policy,
        personalContext: personalContext,
      );

      final json = request.toJson();
      final encoded = json.toString();
      expect(encoded, isNot(contains('원본 일기 전문')));
      expect(encoded, isNot(contains('raw context 텍스트')));
      // relevant_personal_context only carries booleans/sudTrend — no raw text field.
      final personalJson = json['relevant_personal_context'] as Map;
      expect(
        personalJson.keys.toSet(),
        {
          'has_relevant_past_issue',
          'has_previous_alternative_thought',
          'has_helpful_activity',
          'has_unfinished_issue',
          'sud_trend',
        },
      );
    });

    test('dialogueProgress carries only ids, not full thought text', () {
      final request = buildRemoteCounselorRequest(
        context: context,
        policy: policy,
        personalContext: PersonalContextSummary.empty,
      );

      expect(request.dialogueProgress.askedGoalIds, ['probability']);
      expect(request.dialogueProgress.usedInterventionIds, ['cbt-old']);
      final json = request.toJson()['dialogue_progress'] as Map;
      expect(json.containsKey('recent_user_thoughts'), isFalse);
      expect(json.containsKey('conversation_topics'), isFalse);
    });
  });
}
