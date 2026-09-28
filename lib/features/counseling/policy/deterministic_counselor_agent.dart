import '../counseling_state.dart';
import 'counselor_agent.dart';
import 'counselor_decision.dart';
import 'policy_boundary.dart';
import 'policy_boundary_request.dart';
import 'selectors/checkin_decision_selector.dart';
import 'selectors/closing_decision_selector.dart';
import 'selectors/explore_decision_selector.dart';
import 'selectors/intervention_decision_selector.dart';
import 'selectors/reflect_decision_selector.dart';

/// Phase 8.3B: dispatches to the per-state deterministic selector for
/// [context.currentState], then asserts that what the selector chose
/// actually falls inside the [PolicyBoundary] the builder computed
/// independently.
///
/// Unlike Phase 8.3's version of this class, this agent no longer holds
/// `Deterministic*TurnPlanner` instances or calls their `plan()` methods —
/// selection logic now lives in `policy/selectors/*.dart`, and
/// `turn_plan.dart`'s legacy planners call the SAME selectors (see each
/// selector's doc comment). This class is therefore a pure dispatcher: it
/// contributes nothing but the state -> selector switch and the boundary
/// assertion below. Surface realization (final sentences) is not this
/// class's job — that is `TurnPlanAdapter`'s (Phase 8.4 concern).
class DeterministicCounselorAgent implements CounselorAgent {
  final CheckInDecisionSelector checkInSelector;
  final ExploreDecisionSelector exploreSelector;
  final ReflectDecisionSelector reflectSelector;
  final InterventionDecisionSelector interventionSelector;
  final ClosingDecisionSelector closingSelector;

  const DeterministicCounselorAgent({
    this.checkInSelector = const CheckInDecisionSelector(),
    this.exploreSelector = const ExploreDecisionSelector(),
    this.reflectSelector = const ReflectDecisionSelector(),
    this.interventionSelector = const InterventionDecisionSelector(),
    this.closingSelector = const ClosingDecisionSelector(),
  });

  @override
  CounselorDecision decide({
    required PolicyBoundaryRequest context,
    required PolicyBoundary policy,
  }) {
    final CounselorDecision decision;
    switch (context.currentState) {
      case CounselingState.checkIn:
        decision = checkInSelector.select(userMessage: context.userMessage);
      case CounselingState.explore:
        decision = exploreSelector.select(
          userMessage: context.userMessage,
          recentMessages: context.recentMessages,
        );
      case CounselingState.reflect:
        decision = reflectSelector.select(
          userMessage: context.userMessage,
          recentMessages: context.recentMessages,
          userContext: context.userContext,
        );
      case CounselingState.intervention:
        decision = interventionSelector.select(
          currentWeek: context.currentWeek,
          userMessage: context.userMessage,
          recentMessages: context.recentMessages,
          knowledge: context.knowledge,
          userContext: context.userContext,
          registry: context.interventionRegistry,
        );
      case CounselingState.closing:
        decision = closingSelector.select(
          userMessage: context.userMessage,
          recentMessages: context.recentMessages,
        );
    }

    _assertFitsBoundary(decision, policy);
    return decision;
  }

  void _assertFitsBoundary(CounselorDecision decision, PolicyBoundary policy) {
    if (decision.isUnavailable) {
      // An unavailable decision by definition has an empty
      // allowedActions/eligibleInterventionIds boundary in most states, so
      // it never "fits" one; that's expected, not a violation.
      return;
    }
    assert(
      policy.allowedActions.contains(decision.selectedAction),
      'DeterministicCounselorAgent: selected action '
      '${decision.selectedAction} is not in policy.allowedActions '
      '${policy.allowedActions} for state ${policy.currentState}',
    );
    if (decision.selectedInterventionId != null) {
      assert(
        policy.eligibleInterventionIds.contains(
          decision.selectedInterventionId,
        ),
        'DeterministicCounselorAgent: selected intervention '
        '${decision.selectedInterventionId} is not in '
        'policy.eligibleInterventionIds ${policy.eligibleInterventionIds}',
      );
    }
    if (decision.selectedGoalId != null) {
      assert(
        policy.candidateGoalIds.contains(decision.selectedGoalId),
        'DeterministicCounselorAgent: selected goal '
        '${decision.selectedGoalId} is not in policy.candidateGoalIds '
        '${policy.candidateGoalIds}',
      );
    }
  }
}
