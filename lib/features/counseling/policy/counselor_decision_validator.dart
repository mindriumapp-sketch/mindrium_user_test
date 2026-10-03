import 'counselor_decision.dart';
import 'decision_contract.dart';
import 'policy_boundary.dart';

/// Phase 8.4B / 9.2D: release-safe (non-`assert`) validation that a
/// [CounselorDecision] actually fits the [PolicyBoundary] it was supposed to
/// be chosen within, AND that its shape is one [TurnPlanMaterializer] can
/// actually realize.
///
/// [DeterministicCounselorAgent] already has an `assert`-based version of
/// this check, but asserts are stripped from release builds — so a bug (or,
/// later, a `RemoteCounselorAgent` returning something out of bounds) would
/// go undetected in production. This class is the always-on equivalent,
/// meant to sit between `CounselorAgent.decide()` and `TurnPlanAdapter.build`
/// in the production pipeline: a decision that fails here must not be handed
/// to the adapter as-is.
///
/// Phase 9.2D history: a real evaluation run against
/// `phase9_2b_frozen_v1`/`decide_v1` found that this class originally only
/// checked action/goal/intervention *membership* in the boundary — it never
/// checked whether `selectedGoalId`/`reflectionTarget` had the SHAPE
/// [TurnPlanMaterializer] requires for the given state/action (e.g. Reflect's
/// non-clarify branch reads `selectedGoalId!` unconditionally; several
/// materializer methods force-cast `reflectionTarget!` to
/// [ReflectionTargetText]). 37% of that run's validator-accepted decisions
/// crashed materialization as a result. [decisionRequirementsFor] is now the
/// single source of truth both this class and [TurnPlanMaterializer] agree
/// with, closing that gap.
class CounselorDecisionValidator {
  const CounselorDecisionValidator();

  /// Returns null when [decision] fits [policy]; otherwise a short,
  /// human-readable reason describing the first violation found.
  String? validate({
    required CounselorDecision decision,
    required PolicyBoundary policy,
  }) {
    if (decision.isUnavailable) {
      // An unavailable decision by definition doesn't need to fit an
      // allowed-actions/interventions boundary (most such boundaries are
      // themselves empty) — see DeterministicCounselorAgent's matching note.
      // This is unchanged from Phase 8.4B: the deterministic selectors
      // legitimately return `isUnavailable: true` even when
      // `policy.allowedActions` is non-empty (e.g. CheckIn/Explore for an
      // empty user message) — restricting this to
      // `policy.allowedActions.isEmpty` would reject decisions the
      // deterministic path has always produced. See
      // `docs/counseling/chatbot_system.md`'s Pass 2
      // findings for why the real fix for "no valid action exists" belongs
      // at the wire/prompt layer (an explicit unavailable outcome the
      // model can choose), not here.
      return null;
    }

    if (!policy.allowedActions.contains(decision.selectedAction)) {
      return 'selected action ${decision.selectedAction} is not in '
          'policy.allowedActions ${policy.allowedActions} for state '
          '${policy.currentState}';
    }

    if (decision.selectedGoalId != null &&
        !policy.candidateGoalIds.contains(decision.selectedGoalId)) {
      return 'selected goal ${decision.selectedGoalId} is not in '
          'policy.candidateGoalIds ${policy.candidateGoalIds}';
    }

    if (decision.selectedInterventionId != null &&
        !policy.eligibleInterventionIds.contains(
          decision.selectedInterventionId,
        )) {
      return 'selected intervention ${decision.selectedInterventionId} is '
          'not in policy.eligibleInterventionIds '
          '${policy.eligibleInterventionIds}';
    }

    final requirements = decisionRequirementsFor(
      state: policy.currentState,
      selectedAction: decision.selectedAction,
    );

    switch (requirements.goalRequirement) {
      case GoalRequirement.required:
        if (decision.selectedGoalId == null) {
          return 'selectedGoalId is required for state ${policy.currentState} '
              'action ${decision.selectedAction}, but was null';
        }
      case GoalRequirement.forbidden:
        if (decision.selectedGoalId != null) {
          return 'selectedGoalId must be null for state ${policy.currentState} '
              'action ${decision.selectedAction}, but was '
              '${decision.selectedGoalId}';
        }
      case GoalRequirement.optional:
        break;
    }

    switch (requirements.recoveryRequirement) {
      case RecoveryRequirement.required:
        if (decision.goalExhaustionRecovery == null) {
          return 'goalExhaustionRecovery is required for state '
              '${policy.currentState} action ${decision.selectedAction}, but '
              'was null';
        }
      case RecoveryRequirement.forbidden:
        if (decision.goalExhaustionRecovery != null) {
          return 'goalExhaustionRecovery must be null for state '
              '${policy.currentState} action ${decision.selectedAction}, but '
              'was ${decision.goalExhaustionRecovery}';
        }
    }

    switch (requirements.reflectionTargetRequirement) {
      case ReflectionTargetRequirement.textRequired:
        if (decision.reflectionTarget is! ReflectionTargetText) {
          return 'reflectionTarget must be ReflectionTargetText for state '
              '${policy.currentState} action ${decision.selectedAction}, '
              'but was ${decision.reflectionTarget}';
        }
      case ReflectionTargetRequirement.optional:
        if (decision.reflectionTarget == null) {
          return 'reflectionTarget must not be null (that means '
              '"unavailable", but isUnavailable is false) for state '
              '${policy.currentState} action ${decision.selectedAction}';
        }
    }

    if (requirements.interventionRequired &&
        decision.selectedInterventionId == null) {
      return 'selectedInterventionId is required for state '
          '${policy.currentState} action ${decision.selectedAction}, but '
          'was null';
    }

    return null;
  }

  /// Convenience boolean form of [validate].
  bool isValid({
    required CounselorDecision decision,
    required PolicyBoundary policy,
  }) => validate(decision: decision, policy: policy) == null;
}
