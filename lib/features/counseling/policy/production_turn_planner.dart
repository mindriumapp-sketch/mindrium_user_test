import '../intervention_registry.dart';
import '../turn_plan.dart';
import 'counselor_agent.dart';
import 'counselor_decision_validator.dart';
import 'deterministic_counselor_agent.dart';
import 'policy_boundary_request.dart';
import 'turn_plan_adapter.dart';

/// Phase 8.4 / 8.4B: the production [CounselingTurnPlanner].
///
/// Wires `PolicyBoundaryBuilder -> CounselorAgent -> TurnPlanAdapter` in for
/// the five counseling states, while keeping the two Hard Guard planners
/// (`DeterministicInputGuardTurnPlanner`, `DeterministicProcessSignalTurnPlanner`)
/// exactly as they run today — same order, same logic, untouched.
///
/// This is a drop-in replacement for `DeterministicCounselingTurnPlanner` as
/// the harness's `turnPlanner`: `CounselingHarness.handleTurn()` still calls
/// a single `turnPlanner?.plan(planningContext)` — only what that call
/// resolves to changes.
///
/// Phase 8.4B fix: unlike Phase 8.4's version, [counselorAgent]'s decision is
/// no longer discarded. It is validated ([CounselorDecisionValidator], a
/// release-safe check — not an `assert`) and, if it fits [PolicyBoundary],
/// passed straight into [turnPlanAdapter], which materializes it into the
/// actual [CounselingTurnPlan]. This is what makes the agent's decision
/// causally responsible for what the user sees, instead of merely being
/// computed and thrown away.
///
/// If a decision fails validation, this planner falls back to a fresh
/// [DeterministicCounselorAgent] decision for the same request (which is
/// always boundary-fit for anything the deterministic selectors can
/// produce, per the Phase 8.3B equivalence tests). This is the fallback
/// boundary a future `RemoteCounselorAgent` is meant to use: if it ever
/// returns something outside the boundary, production falls back to the
/// deterministic decision rather than serving an invalid plan. If even the
/// deterministic fallback fails validation (which would indicate a bug in
/// the selectors/boundary builder themselves, not in [counselorAgent]), this
/// throws — silently returning an invalid plan is worse than a loud failure
/// here.
class PolicyPipelineTurnPlanner implements CounselingTurnPlanner {
  final CounselingTurnPlanner inputGuardPlanner;
  final CounselingTurnPlanner processSignalPlanner;
  final DeterministicPolicyBoundaryBuilder boundaryBuilder;
  final CounselorAgent counselorAgent;
  final DeterministicCounselorAgent fallbackAgent;
  final CounselorDecisionValidator decisionValidator;
  final TurnPlanAdapter turnPlanAdapter;
  final ApprovedInterventionRegistry interventionRegistry;

  const PolicyPipelineTurnPlanner({
    this.inputGuardPlanner = const DeterministicInputGuardTurnPlanner(),
    this.processSignalPlanner = const DeterministicProcessSignalTurnPlanner(),
    this.boundaryBuilder = const DeterministicPolicyBoundaryBuilder(),
    this.counselorAgent = const DeterministicCounselorAgent(),
    this.fallbackAgent = const DeterministicCounselorAgent(),
    this.decisionValidator = const CounselorDecisionValidator(),
    this.turnPlanAdapter = const TurnPlanAdapter(),
    this.interventionRegistry = const ApprovedInterventionRegistry(),
  });

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    // Hard Guard: identical order, identical logic to
    // `DeterministicCounselingTurnPlanner.plan` — input validity first,
    // then process-signal reactions. Neither depends on the new pipeline.
    final guarded =
        inputGuardPlanner.plan(context) ?? processSignalPlanner.plan(context);
    if (guarded != null) return guarded;

    // Normal counseling turn: build the boundary, let the agent select
    // within it, validate the selection release-safely, then materialize
    // the actual plan from that (validated) decision.
    final request = PolicyBoundaryRequest(
      currentState: context.state,
      userMessage: context.userMessage,
      userContext: context.userContext,
      recentMessages: context.recentMessages,
      currentWeek: context.currentWeek,
      interventionRegistry: interventionRegistry,
      knowledge: context.knowledge,
      retrievalSummary: context.retrievalSummary,
    );

    final boundary = boundaryBuilder.build(request);
    if (boundary == null) return null;

    var decision = counselorAgent.decide(context: request, policy: boundary);
    if (decisionValidator.validate(decision: decision, policy: boundary) !=
        null) {
      // Invalid decision: fall back to the deterministic agent, which is
      // always boundary-fit for what the selectors can produce.
      decision = fallbackAgent.decide(context: request, policy: boundary);
      final fallbackViolation = decisionValidator.validate(
        decision: decision,
        policy: boundary,
      );
      if (fallbackViolation != null) {
        throw StateError(
          'PolicyPipelineTurnPlanner: fallback deterministic decision also '
          'failed boundary validation ($fallbackViolation) — this indicates '
          'a bug in the selectors or boundary builder themselves.',
        );
      }
    }

    return turnPlanAdapter.build(
      request: request,
      policy: boundary,
      decision: decision,
    );
  }
}
