import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

import 'intervention_eligibility_predicates.dart';
import 'policy_boundary.dart';
import 'selectors/reflect_decision_selector.dart';

/// Input specification for building a [PolicyBoundary].
///
/// This captures all the information a planner needs to decide:
/// - What acts are allowed?
/// - What goals can be pursued?
/// - What interventions are eligible?
/// - What user facts can be referenced?
///
/// These are the minimum fields used by current deterministic planners.
/// The builder then constructs a [PolicyBoundary] from these inputs.
class PolicyBoundaryRequest {
  /// The current counseling state (determines available planners).
  final CounselingState currentState;

  /// Current turn's user message.
  final String userMessage;

  /// User's emotional context: diary entries, extracted thoughts, past interventions.
  /// Can be null for stateless scenarios (e.g., first check-in).
  final MindriumCounselingContext? userContext;

  /// Recent counseling messages (for tracking goals, interventions, repetition).
  final List<CounselingMessage> recentMessages;

  /// Current week in the counseling program.
  /// Used to look up intervention eligibility policy.
  final int currentWeek;

  /// Registry of approved interventions (week-based policy).
  /// Used to determine which intervention types are eligible this week.
  final ApprovedInterventionRegistry interventionRegistry;

  /// CBT knowledge base (for intervention planner to find matching items).
  final List<CbtKnowledgeItem> knowledge;

  /// Summaries from retrieval (current: unused, ready for future retrieval-based planning).
  /// Kept here for forward compatibility but not required by current planners.
  final RetrievalSummary retrievalSummary;

  const PolicyBoundaryRequest({
    required this.currentState,
    required this.userMessage,
    this.userContext,
    required this.recentMessages,
    required this.currentWeek,
    required this.interventionRegistry,
    required this.knowledge,
    required this.retrievalSummary,
  });

  @override
  String toString() => 'PolicyBoundaryRequest('
      'state: $currentState, '
      'week: $currentWeek, '
      'msgLen: ${userMessage.length}, '
      'recentCount: ${recentMessages.length}, '
      'knowledgeCount: ${knowledge.length}, '
      'userContext: ${userContext != null}'
      ')';
}

/// Phase 8.2 Placeholder:
/// A builder that converts [PolicyBoundaryRequest] → [PolicyBoundary].
///
/// This is NOT implemented in Phase 8.1 (design-only).
/// Phase 8.2 will:
/// 1. Run deterministic planners to extract their current decision space
/// 2. Build corresponding [PolicyBoundary] objects
/// 3. Validate that agent-generated plans fit within the boundary
abstract class PolicyBoundaryBuilder {
  /// Build a [PolicyBoundary] from the given request.
  /// May return null if the turn is fundamentally unavailable (e.g., no intervention for week).
  PolicyBoundary? build(PolicyBoundaryRequest request);
}

/// Deterministic implementation (mirrors current planner logic).
///
/// This is a reference implementation to validate that [PolicyBoundary]
/// captures the essence of current deterministic decisions.
///
/// Phase 8.2: this builder computes only the *boundary* (what is allowed
/// this turn) — never the final selection (which sentence, which exact
/// target). The final selection stays entirely inside the existing
/// `turn_plan.dart` sub-planners, which are not modified by this class.
///
/// The conditions below are copied/mirrored from the corresponding
/// `Deterministic*TurnPlanner` in `turn_plan.dart` so the boundary and the
/// legacy plan agree on what is eligible. See
/// `test/counseling/phase8_policy_boundary_equivalence_test.dart` for the
/// equivalence checks against the actual legacy planner output.
class DeterministicPolicyBoundaryBuilder implements PolicyBoundaryBuilder {
  final ApprovedInterventionRegistry interventionRegistry;
  final ReflectDecisionSelector reflectSelector;

  const DeterministicPolicyBoundaryBuilder({
    this.interventionRegistry = const ApprovedInterventionRegistry(),
    this.reflectSelector = const ReflectDecisionSelector(),
  });

  @override
  PolicyBoundary? build(PolicyBoundaryRequest request) {
    switch (request.currentState) {
      case CounselingState.checkIn:
        return _buildCheckInBoundary(request);
      case CounselingState.explore:
        return _buildExploreBoundary(request);
      case CounselingState.reflect:
        return _buildReflectBoundary(request);
      case CounselingState.intervention:
        return _buildInterventionBoundary(request);
      case CounselingState.closing:
        return _buildClosingBoundary(request);
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // CheckIn
  // ───────────────────────────────────────────────────────────────────

  PolicyBoundary _buildCheckInBoundary(PolicyBoundaryRequest request) {
    // Mirrors DeterministicCheckInTurnPlanner: requiredAct is always
    // explore, no goals/interventions/facts involved, and advice/new
    // facts/new interventions are forbidden.
    return PolicyBoundary(
      currentState: request.currentState,
      allowedActions: const [DialogueAct.explore],
      candidateGoalIds: const [],
      eligibleInterventionIds: const [],
      allowedFactIds: const [],
      forbiddenConstraints: const [
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      progressInfo: DialogueProgressInfo.empty(),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Explore
  // ───────────────────────────────────────────────────────────────────

  PolicyBoundary _buildExploreBoundary(PolicyBoundaryRequest request) {
    // Mirrors DeterministicExploreTurnPlanner: requiredAct is explore, but
    // allowedActsForTurn is the state's full allowedActs (explore/reflect)
    // — the same set this builder exposes as allowedActions. Explore does
    // not reference diary/CBT items, so allowedFactIds stays empty.
    return PolicyBoundary(
      currentState: request.currentState,
      allowedActions: request.currentState.allowedActs,
      candidateGoalIds: const [],
      eligibleInterventionIds: const [],
      allowedFactIds: const [],
      forbiddenConstraints: const [
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidStageAdvance,
      ],
      progressInfo: _buildProgressInfo(request.recentMessages),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect
  // ───────────────────────────────────────────────────────────────────

  PolicyBoundary _buildReflectBoundary(PolicyBoundaryRequest request) {
    final askedGoalIds = _askedGoalIds(request.recentMessages);
    final candidateGoals = _candidateGoals(askedGoalIds);

    final diary = UserThoughtExtractor.firstDiary(request.userContext);
    final goalsExhausted = DeterministicReflectTurnPlanner.goalOrder.every(
      (goal) => askedGoalIds.contains(goal.name),
    );

    // Boundary mismatch fix (Phase 8.3B): when no usable thought can be
    // found yet, `ReflectDecisionSelector`/`DeterministicReflectTurnPlanner`
    // pick DialogueAct.explore ("clarify" branch) instead of the normal
    // socraticQuestion — but explore is not in
    // `CounselingState.reflect.allowedActs`. Detect that condition the same
    // way the selector does (rather than re-deriving it independently) and
    // widen allowedActions for just this turn so the boundary actually
    // reflects what legacy can produce.
    final wouldClarify = reflectSelector.wouldClarify(
      userMessage: request.userMessage,
      recentMessages: request.recentMessages,
      userContext: request.userContext,
    );
    final allowedActions =
        wouldClarify
            ? [...request.currentState.allowedActs, DialogueAct.explore]
            : request.currentState.allowedActs;

    return PolicyBoundary(
      currentState: request.currentState,
      allowedActions: allowedActions,
      candidateGoalIds: candidateGoals,
      eligibleInterventionIds: const [],
      allowedFactIds: diary != null ? [diary.id] : const [],
      forbiddenConstraints: const [
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidStageAdvance,
      ],
      progressInfo: _buildProgressInfo(
        request.recentMessages,
        askedGoalIds: askedGoalIds,
        isFirstReflectTurn: !askedGoalIds.contains(
          ReflectQuestionGoal.evidence.name,
        ),
      ),
      goalsExhausted: goalsExhausted,
      exhaustionPolicy: GoalExhaustionPolicy.repeatLast,
    );
  }

  /// Mirrors `DeterministicReflectTurnPlanner._selectGoal`'s bookkeeping:
  /// goals already asked are read from non-user messages'
  /// [CounselingMessage.dialogueGoalId].
  Set<String> _askedGoalIds(List<CounselingMessage> messages) {
    return messages
        .where((message) => !message.isUser)
        .map((message) => message.dialogueGoalId)
        .whereType<String>()
        .toSet();
  }

  /// Candidates still open to ask, in the fixed evidence → alternative →
  /// probability sequence used by `DeterministicReflectTurnPlanner.goalOrder`.
  /// If every goal has already been asked, the legacy planner repeats the
  /// last goal in sequence — so that goal alone remains the candidate.
  List<String> _candidateGoals(Set<String> askedGoalIds) {
    final remaining =
        DeterministicReflectTurnPlanner.goalOrder
            .where((goal) => !askedGoalIds.contains(goal.name))
            .map((goal) => goal.name)
            .toList();
    if (remaining.isNotEmpty) return remaining;
    return [DeterministicReflectTurnPlanner.goalOrder.last.name];
  }

  // ───────────────────────────────────────────────────────────────────
  // Intervention
  // ───────────────────────────────────────────────────────────────────

  PolicyBoundary _buildInterventionBoundary(PolicyBoundaryRequest request) {
    final usedInterventionIds = _usedInterventionIds(request.recentMessages);
    final effectiveIntervention = UserThoughtExtractor.firstEffective(
      request.userContext,
    );
    // Phase 13.2: same resolver as InterventionDecisionSelector — cumulative
    // approved techniques up to the current week, never a future week.
    final candidate = InterventionCandidateResolver.resolve(
      currentWeek: request.currentWeek,
      userMessage: request.userMessage,
      recentMessages: request.recentMessages,
      knowledge: request.knowledge,
      hasEffectiveIntervention: effectiveIntervention != null,
      registry: interventionRegistry,
    );

    if (candidate == null) {
      // noEligibleIntervention: a normal outcome whose only action is a
      // brief summary (DialogueAct.summarize). Not `unavailable`, so the
      // session can progress.
      return PolicyBoundary(
        currentState: request.currentState,
        allowedActions: const [DialogueAct.summarize],
        candidateGoalIds: const [],
        eligibleInterventionIds: const [],
        allowedFactIds: const [],
        forbiddenConstraints: const [
          TurnConstraint.forbidAdvice,
          TurnConstraint.forbidNewUserFacts,
          TurnConstraint.forbidNewIntervention,
        ],
        progressInfo: _buildProgressInfo(
          request.recentMessages,
          usedInterventionIds: usedInterventionIds,
        ),
      );
    }

    final policy = candidate.policy;
    final diary = UserThoughtExtractor.firstDiary(request.userContext);
    final List<String> allowedFactIds;
    if (policy.interventionType == InterventionType.maintenanceReview) {
      allowedFactIds =
          effectiveIntervention != null ? [effectiveIntervention.id] : const [];
    } else if (policy.interventionType == InterventionType.balancedThought) {
      allowedFactIds = diary != null ? [diary.id] : const [];
    } else {
      allowedFactIds = const [];
    }

    return PolicyBoundary(
      currentState: request.currentState,
      allowedActions: const [DialogueAct.socraticQuestion],
      candidateGoalIds: const [],
      eligibleInterventionIds: [candidate.item.id],
      allowedFactIds: allowedFactIds,
      forbiddenConstraints: const [
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      progressInfo: _buildProgressInfo(
        request.recentMessages,
        usedInterventionIds: usedInterventionIds,
      ),
    );
  }

  Set<String> _usedInterventionIds(List<CounselingMessage> messages) {
    return messages
        .where((message) => !message.isUser)
        .expand((message) => message.referencedCbtIds)
        .toSet();
  }

  // ───────────────────────────────────────────────────────────────────
  // Closing
  // ───────────────────────────────────────────────────────────────────

  static final RegExp _closingOnly = RegExp(
    r'^(고마워요|감사해요|감사합니다|네|알겠어요|그만할게요|마칠게요)[.!\s]*$',
  );

  PolicyBoundary _buildClosingBoundary(PolicyBoundaryRequest request) {
    // Mirrors DeterministicClosingTurnPlanner: requiredAct is always
    // closing, no question is produced, and no new content may be
    // introduced. Summary-target detection ("is there a substantial
    // message to summarize?") is a boundary decision per the Phase 8.1
    // inventory, but the closing plan is always producible either way
    // (with or without a target) — so this never becomes unavailable.
    return PolicyBoundary(
      currentState: request.currentState,
      allowedActions: const [DialogueAct.closing],
      candidateGoalIds: const [],
      eligibleInterventionIds: const [],
      allowedFactIds: const [],
      forbiddenConstraints: const [
        TurnConstraint.requireNoQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      progressInfo: DialogueProgressInfo.empty(),
      hasClosingSummaryTarget: hasClosingSummaryTarget(request),
    );
  }

  /// Whether the closing state has a substantial message to summarize.
  /// Mirrors `DeterministicClosingTurnPlanner._summaryTarget`'s detection
  /// logic (without performing the final target-string selection itself).
  ///
  /// Kept as a standalone helper (in addition to being folded into
  /// [PolicyBoundary.hasClosingSummaryTarget] for closing boundaries) since
  /// existing call sites/tests invoke it directly on the builder.
  bool hasClosingSummaryTarget(PolicyBoundaryRequest request) {
    final current = request.userMessage.trim();
    if (current.isNotEmpty && !_closingOnly.hasMatch(current)) return true;
    for (final message in request.recentMessages.reversed) {
      final text = message.text.trim();
      if (message.isUser && text.isNotEmpty && !_closingOnly.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────
  // Shared progress info
  // ───────────────────────────────────────────────────────────────────

  DialogueProgressInfo _buildProgressInfo(
    List<CounselingMessage> recentMessages, {
    Set<String> askedGoalIds = const {},
    Set<String> usedInterventionIds = const {},
    bool isFirstReflectTurn = true,
  }) {
    final recentUserThoughts = <String>[];
    final conversationTopics = <String>{};
    for (final message in recentMessages) {
      if (!message.isUser) continue;
      final text = message.text.trim();
      if (text.isEmpty) continue;
      recentUserThoughts.add(text);
      conversationTopics.addAll(
        text
            .split(RegExp(r'[^0-9a-zA-Z가-힣]+'))
            .where((word) => word.length >= 2),
      );
    }
    return DialogueProgressInfo(
      askedGoalIds: askedGoalIds,
      usedInterventionIds: usedInterventionIds,
      recentUserThoughts: recentUserThoughts,
      conversationTopics: conversationTopics,
      isFirstReflectTurn: isFirstReflectTurn,
    );
  }
}
