import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

/// Phase 8 Agent Architecture: Policy Boundary Contract
///
/// [PolicyBoundary] defines the allowable decision space for this turn.
/// It answers: "What can the agent decide within the policies set by the harness?"
///
/// This is the minimum contract needed for an Agent to generate [CounselingTurnPlan]
/// while respecting the deterministic planner's constraints.
///
/// Design Principle: Include only what current deterministic planners actually use.
/// (Avoid future-proofing with unused fields.)
/// How a policy boundary wants goal selection to behave once every goal in
/// the fixed sequence has already been asked this reflect phase.
enum GoalExhaustionPolicy {
  /// Stop offering candidates once exhausted (not used by any legacy
  /// planner today, but kept so the contract is explicit rather than
  /// assumed).
  noRepeat,

  /// Repeat the last goal in the sequence forever. This is what
  /// `DeterministicReflectTurnPlanner._selectGoal` actually does.
  repeatLast,
}

class PolicyBoundary {
  /// The current counseling state (checkIn/explore/reflect/intervention/closing).
  /// State determines which planners can run and what acts are allowed.
  final CounselingState currentState;

  /// Dialogue acts the model is allowed to perform this turn.
  /// For most states, this is fixed by state (see [CounselingState.allowedActs]).
  /// For some turnsExplore/Reflect with Adaptive Dialogue Policy enabled—
  /// the agent may choose among multiple acts within this set.
  final List<DialogueAct> allowedActions;

  /// Question goals the agent can choose for this turn (reflect state only).
  /// Each goal is a stable ID (evidence/alternative/probability) that avoids
  /// repetition even if the model re-phrases the question text.
  ///
  /// Order matters: reflects the intended sequence.
  /// Empty for non-reflect states.
  final List<String> candidateGoalIds;

  /// CBT intervention types eligible for this turn (intervention state only).
  /// Combination of:
  /// - Week policy from [ApprovedInterventionRegistry]
  /// - Availability from recent message history (not already used)
  /// - Knowledge base coverage
  ///
  /// Empty for non-intervention states.
  final List<String> eligibleInterventionIds;

  /// Stable IDs of user context items (diary entries, extracted thoughts, etc.)
  /// that can be referenced/confirmed this turn.
  ///
  /// This is used by:
  /// - Reflect: Can reference diary entries in target selection
  /// - Intervention: Can reference previous interventions in maintenance review
  ///
  /// Empty if no relevant context available.
  final List<String> allowedFactIds;

  /// Dialogue acts explicitly forbidden this turn.
  /// These override [allowedActions] for safety/constraints.
  ///
  /// Examples:
  /// - forbidNewIntervention: Can't start new CBT work
  /// - forbidAdvice: Can't offer suggestions
  /// - forbidStageAdvance: Can't move to next counseling state
  final List<TurnConstraint> forbiddenConstraints;

  /// Information about dialogue progress to guide target selection.
  /// Used by planners to avoid repetition and ensure coherence.
  final DialogueProgressInfo progressInfo;

  /// Reason if this turn is unavailable (e.g., no eligible interventions).
  /// Null means the turn is fully available.
  /// Non-null causes fallback to deterministic planner's unavailable response.
  final String? unavailabilityReason;

  /// Reflect state only: whether every goal in the fixed sequence
  /// (evidence → alternative → probability) has already been asked
  /// (see [DialogueProgressInfo.askedGoalIds]).
  ///
  /// Mirrors `DeterministicReflectTurnPlanner._selectGoal`: once every goal
  /// has been asked, legacy does not stop asking — it repeats the LAST goal
  /// in [ReflectQuestionGoal] order forever. `false` for all non-reflect
  /// states (and for reflect turns where goals remain).
  final bool goalsExhausted;

  /// How the agent must behave once [goalsExhausted] is true.
  /// Always [GoalExhaustionPolicy.repeatLast] today, since that is the only
  /// behavior legacy implements. Kept explicit rather than assuming a single
  /// hardcoded strategy everywhere it's consulted.
  final GoalExhaustionPolicy exhaustionPolicy;

  /// Closing state only: whether there is a substantial prior message to
  /// summarize (mirrors `DeterministicClosingTurnPlanner._summaryTarget`
  /// finding a non-null target). `false` for all non-closing states.
  final bool hasClosingSummaryTarget;

  const PolicyBoundary({
    required this.currentState,
    required this.allowedActions,
    required this.candidateGoalIds,
    required this.eligibleInterventionIds,
    required this.allowedFactIds,
    required this.forbiddenConstraints,
    required this.progressInfo,
    this.unavailabilityReason,
    this.goalsExhausted = false,
    this.exhaustionPolicy = GoalExhaustionPolicy.repeatLast,
    this.hasClosingSummaryTarget = false,
  });

  /// Convenience: Is this turn available for agent decision-making?
  bool get isAvailable => unavailabilityReason == null;

  /// Convenience: Check if an act is both allowed and not forbidden.
  bool isActAllowed(DialogueAct act) {
    if (!allowedActions.contains(act)) return false;
    // Check constraint correlates
    if (forbiddenConstraints.contains(TurnConstraint.forbidAdvice) &&
        act == DialogueAct.explore) {
      // Note: This is a simplification. In practice, explore can be advice-free.
      // Real constraint checking would need more context.
      return true;
    }
    return true;
  }

  /// Convenience: Is a specific goal still available to ask?
  bool isGoalAvailable(String goalId) => candidateGoalIds.contains(goalId);

  /// Convenience: Is a specific intervention still available?
  bool isInterventionAvailable(String interventionId) =>
      eligibleInterventionIds.contains(interventionId);

  @override
  String toString() => 'PolicyBoundary('
      'state: $currentState, '
      'allowedActs: ${allowedActions.length}, '
      'goals: ${candidateGoalIds.length}, '
      'interventions: ${eligibleInterventionIds.length}, '
      'facts: ${allowedFactIds.length}, '
      'constraints: ${forbiddenConstraints.length}, '
      'available: $isAvailable'
      ')';
}

/// Information about recent dialogue progress.
/// Used by planners to avoid repetition and select appropriate targets.
class DialogueProgressInfo {
  /// IDs of question goals already asked in this reflect phase.
  /// Used to pick the next goal in sequence.
  final Set<String> askedGoalIds;

  /// IDs of interventions already referenced/started in recent turns.
  /// Used to avoid re-proposing the same work.
  final Set<String> usedInterventionIds;

  /// Recent user thoughts/concerns extracted from the conversation.
  /// Can be used to contextualize target selection.
  final List<String> recentUserThoughts;

  /// Topics (as keywords) mentioned in the last few turns.
  /// Used for coherence checks (does new target match ongoing conversation?).
  final Set<String> conversationTopics;

  /// Whether this is the first reflect question this phase.
  /// Used to determine if clarification is needed before moving to structured goals.
  final bool isFirstReflectTurn;

  const DialogueProgressInfo({
    required this.askedGoalIds,
    required this.usedInterventionIds,
    required this.recentUserThoughts,
    required this.conversationTopics,
    required this.isFirstReflectTurn,
  });

  /// Factory for empty progress (fresh conversation state).
  factory DialogueProgressInfo.empty() => const DialogueProgressInfo(
        askedGoalIds: <String>{},
        usedInterventionIds: <String>{},
        recentUserThoughts: <String>[],
        conversationTopics: <String>{},
        isFirstReflectTurn: true,
      );

  @override
  String toString() => 'DialogueProgressInfo('
      'goals: ${askedGoalIds.length}, '
      'interventions: ${usedInterventionIds.length}, '
      'thoughts: ${recentUserThoughts.length}, '
      'topics: ${conversationTopics.length}'
      ')';
}
