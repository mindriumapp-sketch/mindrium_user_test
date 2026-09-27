import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';

/// Phase 9.1: what `RemoteCounselorAgent` actually sends over the wire for
/// `POST /counseling/decide`.
///
/// This is a deliberately separate DTO from [PolicyBoundary] /
/// [PolicyBoundaryRequest] — it never serializes those objects directly.
/// Only the already-minimized fields below cross the network boundary:
/// - action/goal/intervention/constraint *ids* (never raw user records)
/// - a small window of recent conversation (never the full transcript)
/// - [relevantPersonalContext], built exclusively from a pre-minimized
///   [PersonalContextSummary] — never from `MindriumCounselingContext`
///   (the raw diary/session object) or a full diary list.
class RemoteCounselorRequest {
  final String userMessage;
  final String currentState;
  final List<String> allowedActions;
  final List<String> candidateGoalIds;
  final List<String> eligibleInterventionIds;
  final List<String> forbiddenConstraints;
  final bool goalsExhausted;
  final String goalExhaustionPolicy;
  final bool hasClosingSummaryTarget;
  final RemotePersonalContext relevantPersonalContext;
  final List<RemoteCbtKnowledgeRef> allowedCbtKnowledge;
  final List<RemoteConversationTurn> recentConversation;
  final RemoteDialogueProgress dialogueProgress;

  const RemoteCounselorRequest({
    required this.userMessage,
    required this.currentState,
    required this.allowedActions,
    required this.candidateGoalIds,
    required this.eligibleInterventionIds,
    required this.forbiddenConstraints,
    required this.goalsExhausted,
    required this.goalExhaustionPolicy,
    required this.hasClosingSummaryTarget,
    required this.relevantPersonalContext,
    required this.allowedCbtKnowledge,
    required this.recentConversation,
    required this.dialogueProgress,
  });

  Map<String, dynamic> toJson() => {
    'user_message': userMessage,
    'current_state': currentState,
    'allowed_actions': allowedActions,
    'candidate_goal_ids': candidateGoalIds,
    'eligible_intervention_ids': eligibleInterventionIds,
    'forbidden_constraints': forbiddenConstraints,
    'goals_exhausted': goalsExhausted,
    'goal_exhaustion_policy': goalExhaustionPolicy,
    'has_closing_summary_target': hasClosingSummaryTarget,
    'relevant_personal_context': relevantPersonalContext.toJson(),
    'allowed_cbt_knowledge':
        allowedCbtKnowledge.map((item) => item.toJson()).toList(),
    'recent_conversation':
        recentConversation.map((turn) => turn.toJson()).toList(),
    'dialogue_progress': dialogueProgress.toJson(),
  };
}

/// Minimal personalization facts extracted from [PersonalContextSummary].
///
/// Deliberately mirrors only the boolean/id-shaped signals a remote model
/// needs to decide *which allowed action/goal to pick* — never full diary
/// text, never a raw session transcript.
class RemotePersonalContext {
  final bool hasRelevantPastIssue;
  final bool hasPreviousAlternativeThought;
  final bool hasHelpfulActivity;
  final bool hasUnfinishedIssue;
  final String? sudTrend;

  const RemotePersonalContext({
    required this.hasRelevantPastIssue,
    required this.hasPreviousAlternativeThought,
    required this.hasHelpfulActivity,
    required this.hasUnfinishedIssue,
    required this.sudTrend,
  });

  factory RemotePersonalContext.fromSummary(PersonalContextSummary summary) {
    return RemotePersonalContext(
      hasRelevantPastIssue: summary.hasRelevantPastIssue,
      hasPreviousAlternativeThought: summary.hasPreviousAlternativeThought,
      hasHelpfulActivity: summary.hasHelpfulActivity,
      hasUnfinishedIssue: summary.hasUnfinishedIssue,
      sudTrend: summary.sudTrend,
    );
  }

  Map<String, dynamic> toJson() => {
    'has_relevant_past_issue': hasRelevantPastIssue,
    'has_previous_alternative_thought': hasPreviousAlternativeThought,
    'has_helpful_activity': hasHelpfulActivity,
    'has_unfinished_issue': hasUnfinishedIssue,
    'sud_trend': sudTrend,
  };
}

/// Minimal reference to a CBT knowledge item — id/title/tags only, never the
/// full paragraph text (mirrors how `/counseling/realize` limits itself to
/// `allowed_cbt_facts`, but even tighter since this agent only *selects*
/// among `eligibleInterventionIds`, it does not draft text).
class RemoteCbtKnowledgeRef {
  final String id;
  final String title;
  final List<String> tags;

  const RemoteCbtKnowledgeRef({
    required this.id,
    required this.title,
    required this.tags,
  });

  factory RemoteCbtKnowledgeRef.fromKnowledgeItem(CbtKnowledgeItem item) {
    return RemoteCbtKnowledgeRef(id: item.id, title: item.title, tags: item.tags);
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'tags': tags};
}

class RemoteConversationTurn {
  final String role;
  final String text;

  const RemoteConversationTurn({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class RemoteDialogueProgress {
  final List<String> askedGoalIds;
  final List<String> usedInterventionIds;
  final bool isFirstReflectTurn;

  const RemoteDialogueProgress({
    required this.askedGoalIds,
    required this.usedInterventionIds,
    required this.isFirstReflectTurn,
  });

  Map<String, dynamic> toJson() => {
    'asked_goal_ids': askedGoalIds,
    'used_intervention_ids': usedInterventionIds,
    'is_first_reflect_turn': isFirstReflectTurn,
  };
}

/// Builds [RemoteCounselorRequest] from the already-computed policy boundary
/// plus a pre-minimized [PersonalContextSummary].
///
/// **Privacy-by-signature**: this function intentionally does NOT accept
/// `MindriumCounselingContext` (the raw diary/session object available at
/// `context.userContext`) or any full transcript/diary list. The only
/// personalization channel is [personalContext], which the caller must
/// already have built via `PersonalContextSummary.fromRetrievalSummary` —
/// a type that is itself constrained to DB/session-backed facts. This
/// function only ever reads `context.userMessage`, `context.recentMessages`
/// (windowed), `context.knowledge` (id/title/tags only) and `context.currentWeek`
/// is not even forwarded — it never touches `context.userContext`.
RemoteCounselorRequest buildRemoteCounselorRequest({
  required PolicyBoundaryRequest context,
  required PolicyBoundary policy,
  required PersonalContextSummary personalContext,
  int recentConversationWindow = 2,
  int maxKnowledgeItems = 5,
}) {
  final recent = context.recentMessages;
  final window =
      recent.length > recentConversationWindow
          ? recent.sublist(recent.length - recentConversationWindow)
          : recent;

  final eligibleIds = policy.eligibleInterventionIds.toSet();
  final knowledgeRefs =
      context.knowledge
          .where((item) => eligibleIds.contains(item.id))
          .take(maxKnowledgeItems)
          .map(RemoteCbtKnowledgeRef.fromKnowledgeItem)
          .toList();

  return RemoteCounselorRequest(
    userMessage: context.userMessage,
    currentState: policy.currentState.name,
    allowedActions: policy.allowedActions.map((act) => act.wireName).toList(),
    candidateGoalIds: List<String>.from(policy.candidateGoalIds),
    eligibleInterventionIds: List<String>.from(policy.eligibleInterventionIds),
    forbiddenConstraints:
        policy.forbiddenConstraints.map((c) => c.name).toList(),
    goalsExhausted: policy.goalsExhausted,
    goalExhaustionPolicy: policy.exhaustionPolicy.name,
    hasClosingSummaryTarget: policy.hasClosingSummaryTarget,
    relevantPersonalContext: RemotePersonalContext.fromSummary(
      personalContext,
    ),
    allowedCbtKnowledge: knowledgeRefs,
    recentConversation:
        window
            .map(
              (message) => RemoteConversationTurn(
                role: message.isUser ? 'user' : 'assistant',
                text: message.text,
              ),
            )
            .toList(),
    dialogueProgress: RemoteDialogueProgress(
      askedGoalIds: policy.progressInfo.askedGoalIds.toList(),
      usedInterventionIds: policy.progressInfo.usedInterventionIds.toList(),
      isFirstReflectTurn: policy.progressInfo.isFirstReflectTurn,
    ),
  );
}
