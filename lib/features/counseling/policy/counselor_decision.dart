import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../turn_plan.dart';

/// Phase 8.5: what [CounselorDecision.reflectionTarget] holds, replacing the
/// old `String?` where `null` and `''` carried two different meanings that
/// were documented only in comments (see git history of this file / this
/// class's predecessor). The distinction matters because two states
/// (Intervention, Closing) can end up with "nothing to reflect on" for two
/// causally different reasons:
///
/// - [ReflectionTargetText]: a normal turn — the string the reflection
///   sentence is built around.
/// - [ReflectionTargetNone]: a target was searched for but none was found,
///   yet the turn is still real (e.g. Closing summarizes with a generic
///   sentence instead; Intervention's "computable in principle but ended up
///   empty" branch, which legacy returned bare `null` — no plan — for).
///
/// [CounselorDecision.reflectionTarget] being `null` itself (i.e. no
/// [ReflectionTarget] at all, not even [ReflectionTargetNone]) is reserved
/// for "this turn is not merely target-less, it's entirely impossible" —
/// e.g. Intervention with no eligible policy/knowledge/type this week, where
/// legacy built a full unavailable-plan instead of returning nothing.
sealed class ReflectionTarget {
  const ReflectionTarget();

  const factory ReflectionTarget.text(String value) = ReflectionTargetText;

  const factory ReflectionTarget.none() = ReflectionTargetNone;
}

/// A concrete string the reflection/question sentence is built around.
final class ReflectionTargetText extends ReflectionTarget {
  final String value;

  const ReflectionTargetText(this.value);
}

/// No target was found, but the turn itself is still real (contrast with
/// [CounselorDecision.reflectionTarget] being `null`, which means the turn
/// itself is unavailable).
final class ReflectionTargetNone extends ReflectionTarget {
  const ReflectionTargetNone();
}

/// Phase 8.3: the minimal output of a [CounselorAgent] — a SELECTION made
/// within the boundaries computed by [PolicyBoundary]. This is not yet a
/// [CounselingTurnPlan]: it carries only what `turn_plan_adapter.dart` needs
/// to build one (ids/enums, no drafted sentence text).
class CounselorDecision {
  /// The dialogue act chosen for this turn. Must be a member of
  /// `policy.allowedActions` (enforced by [DeterministicCounselorAgent] via
  /// assertion).
  final DialogueAct selectedAction;

  /// Reflect state only: which goal (evidence/alternative/probability) this
  /// turn pursues. Must be a member of `policy.candidateGoalIds`. Null for
  /// non-reflect states.
  final String? selectedGoalId;

  /// Intervention state only: the id of the CBT knowledge item selected for
  /// this turn (matches `CounselingTurnPlan.interventionPlan.selectedCbtId`
  /// / `cbtContextIds`). Must be a member of
  /// `policy.eligibleInterventionIds`. Null for non-intervention states.
  final String? selectedInterventionId;

  /// What `CounselingTurnPlan.reflectionTarget` ends up holding, or the
  /// reason it doesn't apply. See [ReflectionTarget] for the three states:
  /// a concrete string ([ReflectionTargetText]), a real turn with no target
  /// found ([ReflectionTargetNone]), or — when this field itself is `null`
  /// — a turn that is entirely unavailable (the legacy planner wouldn't
  /// produce a plan at all).
  final ReflectionTarget? reflectionTarget;

  /// Stable id of user-context items (diary entries, effective
  /// interventions) actually used to build [reflectionTarget]/the
  /// intervention target this turn. Subset of `policy.allowedFactIds`.
  final List<String> usedFactIds;

  /// Whether this decision represents an "unavailable" turn (mirrors
  /// [TurnPlanningStatus.unavailable]) — i.e. the policy had no available
  /// action and the adapter must fall back to an unavailable-shaped plan.
  final bool isUnavailable;

  /// Phase 11.3: Reflect state only, and only when every
  /// `ReflectQuestionGoal` has already been asked this reflect phase (see
  /// `PolicyBoundary.goalsExhausted`) — which recovery action this turn
  /// takes instead of pursuing a (no longer available) goal. Mutually
  /// exclusive with [selectedGoalId] by construction:
  /// `ReflectDecisionSelector` sets exactly one of the two, never both,
  /// never neither, for a reflect-state decision — see
  /// `decisionRequirementsFor`'s three reflect branches (clarify / normal
  /// goal / exhaustion recovery), which `CounselorDecisionValidator`
  /// enforces release-safely. `null` for every non-reflect state and for
  /// every reflect decision made while a goal is still available.
  final GoalExhaustionRecovery? goalExhaustionRecovery;

  const CounselorDecision({
    required this.selectedAction,
    this.selectedGoalId,
    this.selectedInterventionId,
    this.reflectionTarget,
    this.usedFactIds = const [],
    this.isUnavailable = false,
    this.goalExhaustionRecovery,
  });
}
