import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../counseling_state.dart';

/// Phase 9.2D: whether a [CounselorDecision.selectedGoalId] is required,
/// optional, or must be absent for a given (state, selectedAction) pair.
enum GoalRequirement { required, optional, forbidden }

/// Phase 9.2D: whether [CounselorDecision.reflectionTarget] must be a
/// concrete [ReflectionTargetText], or may also legitimately be
/// [ReflectionTargetNone] (a real turn with nothing found to reflect on).
///
/// There is no `noneRequired` case today — every "selectable" (available)
/// decision either needs real text, or tolerates either shape (only
/// Closing). A turn that has genuinely nothing to say is expressed via
/// [CounselorDecision.isUnavailable], not via a forced-None text
/// requirement — see `decisionRequirementsFor`'s doc.
enum ReflectionTargetRequirement { textRequired, optional }

/// Phase 11.3: whether [CounselorDecision.goalExhaustionRecovery] is
/// required or must be absent for a given (state, selectedAction) pair.
/// Paired with [GoalRequirement] to enforce, at the contract level, that a
/// reflect decision sets exactly one of `selectedGoalId` /
/// `goalExhaustionRecovery` — never both, never neither (see
/// `decisionRequirementsFor`'s three reflect branches).
enum RecoveryRequirement { required, forbidden }

/// Phase 9.2D: the single source of truth for what shape a *selectable*
/// (non-unavailable) [CounselorDecision] must have, given the state and the
/// action it selected. Both [CounselorDecisionValidator] and
/// [TurnPlanMaterializer] must agree with this — that agreement is exactly
/// what Phase 9.2B's real evaluation run found broken (a `RemoteCounselorAgent`
/// decision could pass validation yet crash materialization because the two
/// had different, un-shared assumptions about required shape).
///
/// This does NOT cover [CounselorDecision.isUnavailable] — that is a
/// separate, orthogonal outcome (see `CounselorDecisionValidator`'s
/// unavailable handling) checked before these requirements ever apply.
class DecisionRequirements {
  final GoalRequirement goalRequirement;
  final ReflectionTargetRequirement reflectionTargetRequirement;
  final bool interventionRequired;
  final RecoveryRequirement recoveryRequirement;

  const DecisionRequirements({
    required this.goalRequirement,
    required this.reflectionTargetRequirement,
    required this.interventionRequired,
    this.recoveryRequirement = RecoveryRequirement.forbidden,
  });
}

const _noGoalTextRequired = DecisionRequirements(
  goalRequirement: GoalRequirement.forbidden,
  reflectionTargetRequirement: ReflectionTargetRequirement.textRequired,
  interventionRequired: false,
);

/// Phase 9.2D: computes the [DecisionRequirements] a *selectable* decision
/// must satisfy for [state] having chosen [selectedAction]. Derived
/// directly from what `TurnPlanMaterializer`'s five realization methods
/// actually read off a [CounselorDecision] — see each method's body in
/// `materializers/turn_plan_materializer.dart` for the ground truth this
/// mirrors:
///
/// - CheckIn: always `explore`; reflectionTarget always dereferenced as
///   text; goal never read.
/// - Explore: reflectionTarget always dereferenced as text regardless of
///   which allowed action was picked; goal never read.
/// - Reflect: three branches, distinguished by `selectedAction`.
///   `explore` is the *clarify* branch (Phase 8.3B) — goal is never read
///   there. `reflect` is the Phase 11.3 *goal-exhaustion recovery* branch —
///   `goalExhaustionRecovery` is read instead of a goal, and
///   `selectedGoalId` must be absent (materializer branches on recovery
///   type, never reads a goal id for this branch). Any other selected
///   action (`socraticQuestion`, the normal path) reads `selectedGoalId!`
///   to look up a [ReflectQuestionGoal] and crashes if absent — so it is
///   required, and `goalExhaustionRecovery` must be absent. reflectionTarget
///   is always dereferenced as text in all three branches.
/// - Intervention (selectable branch only — see [CounselorDecisionValidator]
///   for the separate `isUnavailable` outcome): reflectionTarget always
///   dereferenced as text; `selectedInterventionId` is always looked up in
///   `knowledge` and crashes if absent or unmatched — required; goal never
///   read.
/// - Closing: accepts either a concrete target or [ReflectionTarget.none]
///   (generic closing wording) — the one state where "no target" is a
///   normal, valid outcome, not an unavailable one; goal never read.
DecisionRequirements decisionRequirementsFor({
  required CounselingState state,
  required DialogueAct selectedAction,
}) {
  switch (state) {
    case CounselingState.checkIn:
    case CounselingState.explore:
      return _noGoalTextRequired;

    case CounselingState.reflect:
      if (selectedAction == DialogueAct.explore) {
        // Clarify branch: goal is not read by the materializer at all, so
        // it is neither required nor forbidden — simply not applicable.
        return const DecisionRequirements(
          goalRequirement: GoalRequirement.optional,
          reflectionTargetRequirement: ReflectionTargetRequirement.textRequired,
          interventionRequired: false,
        );
      }
      if (selectedAction == DialogueAct.reflect) {
        // Phase 11.3: goal-exhaustion recovery branch. Deliberately a
        // different act from both the clarify branch (`explore`) and the
        // normal branch (`socraticQuestion`) — see
        // `ReflectDecisionSelector`'s doc for why `reflect`, specifically,
        // was chosen (must not accelerate reflect->intervention the way
        // `summarize` would via `CounselingState._acceleratesFrom`).
        // `selectedGoalId` is forbidden (there is no goal left to pursue,
        // that's the whole premise); `goalExhaustionRecovery` is required
        // instead — this is the XOR contract's other half from the normal
        // branch below.
        return const DecisionRequirements(
          goalRequirement: GoalRequirement.forbidden,
          reflectionTargetRequirement: ReflectionTargetRequirement.textRequired,
          interventionRequired: false,
          recoveryRequirement: RecoveryRequirement.required,
        );
      }
      return const DecisionRequirements(
        goalRequirement: GoalRequirement.required,
        reflectionTargetRequirement: ReflectionTargetRequirement.textRequired,
        interventionRequired: false,
      );

    case CounselingState.intervention:
      return const DecisionRequirements(
        goalRequirement: GoalRequirement.forbidden,
        reflectionTargetRequirement: ReflectionTargetRequirement.textRequired,
        interventionRequired: true,
      );

    case CounselingState.closing:
      return const DecisionRequirements(
        goalRequirement: GoalRequirement.forbidden,
        reflectionTargetRequirement: ReflectionTargetRequirement.optional,
        interventionRequired: false,
      );
  }
}
