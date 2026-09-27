import 'package:gad_app_team/features/assistant/assistant_intent.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision_validator.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/turn_plan_adapter.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

import 'remote_counselor_agent.dart';

/// Phase 9.2A: feature flag gating whether [RemoteCounselorShadowRunner]
/// is allowed to actually call [RemoteCounselorAgent.decideAsync].
///
/// Default is `enabled: false`. This is not merely "ignore the result when
/// off" — [RemoteCounselorShadowRunner.evaluate] checks this flag *before*
/// constructing a request or touching [RemoteCounselorAgent] at all, so
/// "off" guarantees zero network calls by construction, not by discarding
/// a response after the fact.
class ShadowEvaluationConfig {
  final bool enabled;

  const ShadowEvaluationConfig({this.enabled = false});
}

/// The outcome of one shadow evaluation of a single counseling turn.
///
/// This is a pure comparison/diagnostic record. Nothing in this class (or
/// anything that produces it) is read by `CounselingHarness`,
/// `PolicyPipelineTurnPlanner`, or any other production call path — see
/// `RemoteCounselorShadowRunner` doc for where this is intended to be
/// consumed instead (test harnesses / a future opt-in hook, Phase 9.2B).
class ShadowEvaluationResult {
  /// The decision production actually used this turn (already computed
  /// before this class is ever invoked — this class never recomputes it).
  final CounselorDecision deterministicDecision;

  /// The remote agent's decision, if the call succeeded and parsed.
  final CounselorDecision? remoteDecision;

  final bool parseSucceeded;
  final bool validationPassed;
  final String? validationFailureReason;
  final bool materializationSucceeded;
  final int? latencyMs;

  /// One of: timeout / httpError / networkError / malformedResponse /
  /// emptyResponse / none (no failure).
  final String? failureCategory;

  final String? modelIdentifier;
  final String? promptVersion;
  final int? inputTokens;
  final int? outputTokens;

  /// Whether the remote decision's selection fields (action/goal/
  /// intervention/reflection-target shape) differ from the deterministic
  /// decision's. A difference is expected/normal and is not itself a
  /// failure signal.
  final bool decisionsDiffer;

  const ShadowEvaluationResult({
    required this.deterministicDecision,
    this.remoteDecision,
    this.parseSucceeded = false,
    this.validationPassed = false,
    this.validationFailureReason,
    this.materializationSucceeded = false,
    this.latencyMs,
    this.failureCategory = 'none',
    this.modelIdentifier,
    this.promptVersion,
    this.inputTokens,
    this.outputTokens,
    this.decisionsDiffer = false,
  });

  /// Non-sensitive structured metadata only — no raw user message, no
  /// [PersonalContextSummary] text fields, no transcript. Safe to log.
  Map<String, Object?> toLogEntry() => {
    'deterministic_action': deterministicDecision.selectedAction.name,
    'deterministic_goal_id': deterministicDecision.selectedGoalId,
    'deterministic_intervention_id':
        deterministicDecision.selectedInterventionId,
    'deterministic_unavailable': deterministicDecision.isUnavailable,
    'remote_action': remoteDecision?.selectedAction.name,
    'remote_goal_id': remoteDecision?.selectedGoalId,
    'remote_intervention_id': remoteDecision?.selectedInterventionId,
    'remote_unavailable': remoteDecision?.isUnavailable,
    'parse_succeeded': parseSucceeded,
    'validation_passed': validationPassed,
    'validation_failure_reason': validationFailureReason,
    'materialization_succeeded': materializationSucceeded,
    'latency_ms': latencyMs,
    'failure_category': failureCategory,
    'model_identifier': modelIdentifier,
    'prompt_version': promptVersion,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'decisions_differ': decisionsDiffer,
  };
}

/// Phase 9.2A: evaluates [RemoteCounselorAgent] against an already-computed
/// production ([deterministicDecision]) decision, entirely outside the
/// production pipeline.
///
/// **Not wired into `CounselingHarness`, `PolicyPipelineTurnPlanner`, or
/// `MindRiumAssistantHarness` in this phase.** Nothing in those files calls
/// this class. It is designed to be invoked from a separate assembly point
/// (test code today; potentially a fire-and-forget hook added to
/// `CounselingProvider` in a later phase) that already has both a
/// [PolicyBoundaryRequest]/[PolicyBoundary] pair and the
/// [CounselorDecision] production used for the turn.
///
/// Contract:
/// - Never throws. Every failure mode (flag off, transport failure, parse
///   failure, validation failure, materialization failure) is captured in
///   the returned [ShadowEvaluationResult] instead of propagating an
///   exception — a shadow evaluation must never be able to disrupt the
///   caller's real turn.
/// - Never mutates session/turn state, never returns something a caller
///   could use in place of [deterministicDecision].
/// - Reuses [CounselorDecisionValidator], [TurnPlanAdapter], and
///   [TurnPlanMaterializer] as-is — no new validation/materialization logic.
class RemoteCounselorShadowRunner {
  final RemoteCounselorAgent agent;
  final ShadowEvaluationConfig config;
  final CounselorDecisionValidator validator;
  final TurnPlanAdapter turnPlanAdapter;

  const RemoteCounselorShadowRunner({
    required this.agent,
    this.config = const ShadowEvaluationConfig(),
    this.validator = const CounselorDecisionValidator(),
    this.turnPlanAdapter = const TurnPlanAdapter(),
  });

  Future<ShadowEvaluationResult> evaluate({
    required PolicyBoundaryRequest request,
    required PolicyBoundary policy,
    required PersonalContextSummary personalContext,
    required CounselorDecision deterministicDecision,
  }) async {
    // Flag OFF: do not construct a request, do not touch the agent, do not
    // make a network call. This is the structural guarantee, not a
    // post-hoc discard.
    if (!config.enabled) {
      return ShadowEvaluationResult(
        deterministicDecision: deterministicDecision,
        failureCategory: 'disabled',
      );
    }

    final stopwatch = Stopwatch()..start();
    RemoteCounselorDecisionOutcome outcome;
    try {
      outcome = await agent.decideAsync(
        context: request,
        policy: policy,
        personalContext: personalContext,
      );
    } on RemoteCounselorFailure catch (e) {
      stopwatch.stop();
      return ShadowEvaluationResult(
        deterministicDecision: deterministicDecision,
        parseSucceeded: false,
        validationPassed: false,
        materializationSucceeded: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: e.kind.name,
      );
    } catch (_) {
      // Absorb any other unexpected failure too — shadow evaluation must
      // never propagate an exception into the caller.
      stopwatch.stop();
      return ShadowEvaluationResult(
        deterministicDecision: deterministicDecision,
        parseSucceeded: false,
        validationPassed: false,
        materializationSucceeded: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: 'malformedResponse',
      );
    }
    stopwatch.stop();
    final remoteDecision = outcome.decision;

    final validationFailureReason = validator.validate(
      decision: remoteDecision,
      policy: policy,
    );
    final validationPassed = validationFailureReason == null;

    var materializationSucceeded = false;
    if (validationPassed) {
      try {
        // Dry-run only: the built plan is discarded, never surfaced,
        // stored, or returned to any caller beyond a success boolean.
        turnPlanAdapter.build(
          request: request,
          policy: policy,
          decision: remoteDecision,
        );
        materializationSucceeded = true;
      } catch (_) {
        materializationSucceeded = false;
      }
    }

    final decisionsDiffer =
        remoteDecision.selectedAction != deterministicDecision.selectedAction ||
        remoteDecision.selectedGoalId != deterministicDecision.selectedGoalId ||
        remoteDecision.selectedInterventionId !=
            deterministicDecision.selectedInterventionId ||
        remoteDecision.isUnavailable != deterministicDecision.isUnavailable;

    return ShadowEvaluationResult(
      deterministicDecision: deterministicDecision,
      remoteDecision: remoteDecision,
      parseSucceeded: true,
      validationPassed: validationPassed,
      validationFailureReason: validationFailureReason,
      materializationSucceeded: materializationSucceeded,
      latencyMs: stopwatch.elapsedMilliseconds,
      failureCategory: 'none',
      modelIdentifier: outcome.modelIdentifier,
      promptVersion: outcome.promptVersion,
      inputTokens: outcome.inputTokens,
      outputTokens: outcome.outputTokens,
      decisionsDiffer: decisionsDiffer,
    );
  }
}

/// Phase 9.2A: decides whether a shadow evaluation is even eligible to run
/// for this turn, reusing signals the production pipeline already computed
/// rather than re-deriving new conditions.
///
/// - `handledByHardGuard` should be `true` whenever
///   `CounselingTurnResult.handledBySafety` was `true` for this turn (the
///   Hard Guard / safety gate already produced the response — see
///   `CounselingHarness.handleTurn`'s `safety.isNormal` check and
///   `_safetyTurn`), or more generally whenever no normal turn plan was
///   produced.
/// - `safetyLevel` should be the `SafetyResult.level` for this turn
///   (elevated/crisis both disqualify per `SafetyGate` semantics —
///   `SafetyResult.isNormal` is the only "continue as usual" level).
/// - `intent` should be the `AssistantIntent` `MindRiumAssistantHarness`
///   already computed via `detectIntent` — `isAppGuideOnly` turns never
///   reach `CounselingHarness` at all, so shadow evaluation (which only
///   makes sense for a counseling turn) must not run for them.
bool shouldRunShadow({
  required AssistantIntent intent,
  required bool handledByHardGuard,
  SafetyLevel safetyLevel = SafetyLevel.normal,
}) {
  if (handledByHardGuard) return false;
  if (safetyLevel != SafetyLevel.normal) return false;
  if (intent.isAppGuideOnly) return false;
  // counselingOnly or mixed (counseling half of a mixed turn).
  return intent.isCounselingOnly || intent.isMixed;
}
