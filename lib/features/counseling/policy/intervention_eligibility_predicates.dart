import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../intervention_registry.dart';

/// Phase 8.3: pure predicate functions shared between the legacy
/// `DeterministicInterventionTurnPlanner` (turn_plan.dart) and
/// `DeterministicPolicyBoundaryBuilder` (policy_boundary_request.dart).
///
/// These were previously duplicated (byte-for-byte) in both places. This
/// file is the single source of truth; both call sites now call into it
/// instead of keeping private copies. Logic/signatures/return values are
/// unchanged from the originals — this is a behavior-preserving move, not a
/// rewrite.
class InterventionEligibilityPredicates {
  const InterventionEligibilityPredicates._();

  /// Mirrors the legacy `_alreadyUsed`: was this intervention policy already
  /// referenced or textually signaled in a recent assistant message?
  static bool alreadyUsed(
    List<CounselingMessage> messages,
    ApprovedInterventionPolicy policy,
  ) {
    return messages.any(
      (message) =>
          !message.isUser &&
          (message.referencedCbtIds.contains(policy.requiredId) ||
              textSignalsType(message.text, policy.interventionType)),
    );
  }

  /// Mirrors the legacy `_textSignalsType`: does this message text signal
  /// that this intervention type was already discussed?
  static bool textSignalsType(String text, InterventionType type) {
    switch (type) {
      case InterventionType.balancedThought:
        return text.contains('균형') && text.contains('문장');
      case InterventionType.behaviorPatternReview:
        return text.contains('회피') && text.contains('직면');
      case InterventionType.consequenceReview:
        return text.contains('단기') && text.contains('장기');
      case InterventionType.gainLossReview:
        return text.contains('회피 행동') &&
            (text.contains('이득') || text.contains('좋은 점'));
      case InterventionType.valueBasedChoice:
        return false;
      case InterventionType.maintenanceReview:
        return text.contains('이어가') || text.contains('유지');
    }
  }

  /// Mirrors the legacy `_looksLikeAvoidance`: does the user's message look
  /// avoidance-shaped (gainLossReview eligibility)?
  static bool looksLikeAvoidance(String text) {
    return RegExp(r'(피하|회피|미루|빠지|않고|안\s|줄이|원고만|벗어나)').hasMatch(text);
  }

  /// Phase 13.6 (Q2): does the message describe something the user does
  /// (a behavior a behavior-type technique can examine), rather than a
  /// feeling or a thought?
  static bool looksLikeBehavior(String text) {
    return looksLikeAvoidance(text) ||
        RegExp(r'(게\s*돼|게\s*되|하고\s*있|했어요|했더니|해\s*버리|확인하|찾아보|연습하|준비하)')
            .hasMatch(text);
  }

  /// Mirrors the legacy `_looksLikeMaintenance`: does the user's message
  /// describe an ongoing practice with a felt benefit (maintenanceReview
  /// eligibility)?
  static bool looksLikeMaintenance(String text) {
    final hasPractice = RegExp(r'(연습|습관|호흡|이완|방법|행동)').hasMatch(text);
    final hasBenefit = RegExp(r'(도움|효과|나아|편안|좋았|계속|유지|이어가)').hasMatch(text);
    return hasPractice && hasBenefit;
  }
}

/// Phase 13.2: the one approved technique chosen for this intervention
/// turn, or none.
class InterventionCandidate {
  final ApprovedInterventionPolicy policy;
  final CbtKnowledgeItem item;
  const InterventionCandidate(this.policy, this.item);
}

/// Phase 13.2: single source of truth for which approved technique (if any)
/// fits this turn. Used by both `DeterministicPolicyBoundaryBuilder` and
/// `InterventionDecisionSelector`, so the boundary and the decision can't
/// disagree (the Phase 9.2D failure mode).
///
/// Candidates are every approved policy up to the current week, most
/// recently introduced first (never a future week). The existing per-policy
/// gates still apply: not already used this session, its knowledge item is
/// available, gain/loss needs an avoidance-shaped message, and maintenance
/// needs a maintenance-shaped message or an effective-intervention record.
/// Returns null when nothing fits. That is a normal outcome
/// (`noEligibleIntervention`), not a failure.
class InterventionCandidateResolver {
  const InterventionCandidateResolver._();

  static InterventionCandidate? resolve({
    required int currentWeek,
    required String userMessage,
    required List<CounselingMessage> recentMessages,
    required List<CbtKnowledgeItem> knowledge,
    required bool hasEffectiveIntervention,
    required ApprovedInterventionRegistry registry,
  }) {
    for (final policy in registry.policiesUpTo(currentWeek)) {
      if (InterventionEligibilityPredicates.alreadyUsed(recentMessages, policy)) {
        continue;
      }
      CbtKnowledgeItem? item;
      for (final candidate in knowledge) {
        if (policy.accepts(candidate)) {
          item = candidate;
          break;
        }
      }
      if (item == null) continue;
      if (policy.interventionType == InterventionType.gainLossReview &&
          !InterventionEligibilityPredicates.looksLikeAvoidance(userMessage)) {
        continue;
      }
      if (policy.interventionType == InterventionType.maintenanceReview &&
          !InterventionEligibilityPredicates.looksLikeMaintenance(userMessage) &&
          !hasEffectiveIntervention) {
        continue;
      }
      return InterventionCandidate(policy, item);
    }
    return null;
  }
}

/// Phase 13.3: tracks where the intervention is in ask → answer → integrate.
/// Shared by the boundary builder and the selector (same reason as
/// [InterventionCandidateResolver]).
class InterventionProgressTracker {
  const InterventionProgressTracker._();

  /// The technique id whose question is still waiting for an answer: the
  /// most recent assistant turn was that technique's prompt. Repair turns in
  /// between are skipped, since they don't answer anything.
  static String? pendingPromptTechniqueId(List<CounselingMessage> messages) {
    for (final message in messages.reversed) {
      if (message.isUser) continue;
      if (message.interactionRepairReason != null) continue;
      if (message.interventionStep != InterventionStep.prompt) return null;
      return message.referencedCbtIds.isEmpty
          ? null
          : message.referencedCbtIds.first;
    }
    return null;
  }
}
