import 'package:gad_app_team/data/counseling/counseling_models.dart';
import '../counseling_state.dart';
import '../turn_plan.dart';
import 'counselor_decision.dart';
import 'materializers/turn_plan_materializer.dart';
import 'policy_boundary.dart';
import 'policy_boundary_request.dart';

/// Phase 8.4B: converts a [CounselorDecision] (already selected within a
/// [PolicyBoundary] by a [CounselorAgent]) into the final
/// [CounselingTurnPlan], via [TurnPlanMaterializer].
///
/// Unlike Phase 8.4's version of this class, this adapter no longer holds
/// `Deterministic*TurnPlanner` instances or calls their `plan()` methods —
/// it has zero dependency on `DeterministicCheckInTurnPlanner`,
/// `DeterministicExploreTurnPlanner`, `DeterministicReflectTurnPlanner`,
/// `DeterministicInterventionTurnPlanner`, or
/// `DeterministicClosingTurnPlanner`. The [decision] passed in is what
/// determines the resulting plan's content — this is what makes
/// `CounselorAgent.decide()`'s output causally load-bearing in production
/// (see `production_turn_planner.dart`).
///
/// Surface realization (drafted sentences, rotation among candidate
/// phrasings) lives in [TurnPlanMaterializer], which both this adapter and
/// the legacy `Deterministic*TurnPlanner` classes in `turn_plan.dart` call —
/// a single source of truth for how a decision becomes a plan.
class TurnPlanAdapter {
  final TurnPlanMaterializer materializer;

  const TurnPlanAdapter({this.materializer = const TurnPlanMaterializer()});

  /// Builds the [CounselingTurnPlan] for [request]'s state from [decision].
  /// Returns null when [decision] represents an unavailable turn that the
  /// legacy planner would also have returned null for (mirrors each state's
  /// null-vs-unavailable-plan distinction — see [CounselorDecision.reflectionTarget]
  /// and [ReflectionTarget]'s three states: `null` (turn entirely
  /// unavailable), [ReflectionTargetNone] (real turn, no target found), and
  /// [ReflectionTargetText] (a concrete target)).
  CounselingTurnPlan? build({
    required PolicyBoundaryRequest request,
    required PolicyBoundary policy,
    required CounselorDecision decision,
  }) {
    switch (request.currentState) {
      case CounselingState.checkIn:
        if (decision.isUnavailable) return null;
        return materializer.checkIn(decision);

      case CounselingState.explore:
        if (decision.isUnavailable) return null;
        return materializer.explore(
          decision,
          userMessage: request.userMessage,
          recentMessages: request.recentMessages,
          allowedActsForTurn: request.currentState.allowedActs,
        );

      case CounselingState.reflect:
        // The deterministic ReflectDecisionSelector never sets
        // `isUnavailable: true` (a reflect turn is always producible — see
        // that selector's doc comment), but a remote decision is not
        // guaranteed to respect that — guard the same way checkIn/explore
        // do rather than let materializer.reflect's `reflectionTarget!`
        // dereference crash on a decision claiming unavailability.
        if (decision.isUnavailable) return null;
        return materializer.reflect(
          decision,
          recentMessages: request.recentMessages,
          allowedActsForTurn: request.currentState.allowedActs,
        );

      case CounselingState.intervention:
        if (decision.isUnavailable) {
          // Two distinct "nothing to do" outcomes, per
          // InterventionDecisionSelector's encoding note: `reflectionTarget
          // == null` (no ReflectionTarget at all) means legacy would build
          // the full unavailable-plan; `ReflectionTargetNone` means legacy
          // would return bare `null`.
          return switch (decision.reflectionTarget) {
            null => materializer.interventionUnavailable(
              request.userMessage,
              request.recentMessages,
            ),
            ReflectionTargetNone() => null,
            ReflectionTargetText() => null,
          };
        }
        if (decision.selectedAction == DialogueAct.reflect) {
          return materializer.interventionIntegration(
            decision,
            currentWeek: request.currentWeek,
            knowledge: request.knowledge,
            recentMessages: request.recentMessages,
          );
        }
        if (decision.selectedAction == DialogueAct.summarize) {
          return materializer.interventionNoEligible(
            decision,
            recentMessages: request.recentMessages,
            userMessage: request.userMessage,
          );
        }
        return materializer.intervention(
          decision,
          currentWeek: request.currentWeek,
          knowledge: request.knowledge,
          recentMessages: request.recentMessages,
          userMessage: request.userMessage,
        );

      case CounselingState.closing:
        // The deterministic ClosingDecisionSelector never sets
        // `isUnavailable: true` (closing always has *something* to say —
        // see that selector's doc comment), but this branch was missing
        // the same guard checkIn/explore/intervention already have. Phase
        // 9.2D's real evaluation run found this: a remote decision claiming
        // `isUnavailable: true` (with `reflectionTarget: null`) reached
        // `materializer.closing`'s `reflectionTarget!` dereference and
        // crashed instead of being treated as "no plan", exactly like the
        // other four states already handle it.
        if (decision.isUnavailable) return null;
        return materializer.closing(decision);
    }
  }
}
