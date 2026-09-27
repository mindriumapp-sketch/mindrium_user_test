import '../../turn_plan.dart';
import '../counselor_agent.dart';
import '../counselor_decision.dart';
import '../counselor_decision_validator.dart';
import '../deterministic_counselor_agent.dart';
import '../policy_boundary.dart';
import '../policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_agent.dart';
import '../turn_plan_adapter.dart';
import 'scenario_fixture.dart';

/// Phase 9.2B: the full per-scenario outcome captured by [ScenarioRunner].
///
/// Every field is either directly comparable (deterministic vs remote) or
/// diagnostic (why a step failed). `toJson()` is the shape fed into
/// `AggregateReport`/external analysis — it is deliberately structural only
/// (ids/enums/booleans/numbers), mirroring `ShadowEvaluationResult.toLogEntry`'s
/// no-sensitive-data discipline: it never includes the raw user message or
/// personalization text, only ids and computed booleans.
class ScenarioResult {
  final String scenarioId;
  final String scenarioLabel;
  final String category;
  final bool multiOptionActual;

  final CounselorDecision deterministicDecision;
  final CounselorDecision? remoteDecision;

  final CounselingTurnPlan? deterministicTurnPlan;
  final CounselingTurnPlan? remoteTurnPlan;

  /// Drafted text before any LLM-based realization — see
  /// `CounselingTurnPlan.deterministicReply`. Pure computation, no network
  /// call. Never null when the corresponding turn plan is non-null.
  final String? deterministicResponseText;
  final String? remoteResponseText;

  /// True iff a remote decision was successfully obtained and parsed
  /// (mirrors `ShadowEvaluationResult.parseSucceeded`).
  final bool parseSucceeded;
  final bool remoteValidationPassed;
  final String? remoteValidationFailureReason;
  final bool remoteMaterializationSucceeded;

  /// One of: timeout / httpError / networkError / malformedResponse /
  /// emptyResponse / noRemoteAgent / none.
  final String? failureCategory;

  final int? latencyMs;
  final String? modelIdentifier;
  final String? promptVersion;
  final int? inputTokens;
  final int? outputTokens;

  const ScenarioResult({
    required this.scenarioId,
    required this.scenarioLabel,
    required this.category,
    required this.multiOptionActual,
    required this.deterministicDecision,
    this.remoteDecision,
    this.deterministicTurnPlan,
    this.remoteTurnPlan,
    this.deterministicResponseText,
    this.remoteResponseText,
    this.parseSucceeded = false,
    this.remoteValidationPassed = false,
    this.remoteValidationFailureReason,
    this.remoteMaterializationSucceeded = false,
    this.failureCategory = 'none',
    this.latencyMs,
    this.modelIdentifier,
    this.promptVersion,
    this.inputTokens,
    this.outputTokens,
  });

  /// Whether the remote decision's selection fields differ from the
  /// deterministic decision's. A difference is expected/normal, not itself
  /// a failure signal (mirrors `ShadowEvaluationResult.decisionsDiffer`).
  bool get decisionsDiffer {
    final remote = remoteDecision;
    if (remote == null) return false;
    return remote.selectedAction != deterministicDecision.selectedAction ||
        remote.selectedGoalId != deterministicDecision.selectedGoalId ||
        remote.selectedInterventionId !=
            deterministicDecision.selectedInterventionId ||
        remote.isUnavailable != deterministicDecision.isUnavailable;
  }

  Map<String, Object?> toJson() => {
    'scenario_id': scenarioId,
    'scenario_label': scenarioLabel,
    'category': category,
    'multi_option_actual': multiOptionActual,
    'deterministic_action': deterministicDecision.selectedAction.name,
    'deterministic_goal_id': deterministicDecision.selectedGoalId,
    'deterministic_intervention_id':
        deterministicDecision.selectedInterventionId,
    'deterministic_unavailable': deterministicDecision.isUnavailable,
    'remote_action': remoteDecision?.selectedAction.name,
    'remote_goal_id': remoteDecision?.selectedGoalId,
    'remote_intervention_id': remoteDecision?.selectedInterventionId,
    'remote_unavailable': remoteDecision?.isUnavailable,
    'decisions_differ': decisionsDiffer,
    'parse_succeeded': parseSucceeded,
    'remote_validation_passed': remoteValidationPassed,
    'remote_validation_failure_reason': remoteValidationFailureReason,
    'remote_materialization_succeeded': remoteMaterializationSucceeded,
    'failure_category': failureCategory,
    'latency_ms': latencyMs,
    'model_identifier': modelIdentifier,
    'prompt_version': promptVersion,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
  };
}

/// Phase 9.2B: runs a [ScenarioFixture] through the deterministic agent
/// (always) and, optionally, a [RemoteCounselorAgent] (when supplied),
/// producing a comparable [ScenarioResult] for each.
///
/// **Sync-vs-async note**: [CounselorAgent.decide] is synchronous — used
/// as-is for [deterministicAgent], unchanged. [RemoteCounselorAgent] only
/// exposes an async `decideAsync`, and that interface is explicitly not
/// touched by this phase either. Rather than widening `CounselorAgent` (a
/// production interface this phase must not modify) to `Future`-returning,
/// [run]/[runAll] are themselves `async` methods that take `remoteAgent` as
/// a plain extra parameter — never through the `CounselorAgent` interface —
/// so the deterministic (sync) and remote (async) paths run side by side
/// inside one async method without changing either agent's contract.
///
/// **ResponseRealizer note**: full LLM-based realization
/// (`ResponseRealizer`/`RemoteLlmRealizer`) is NOT invoked here — it
/// requires a real network-backed LLM call, which has no meaning in a dry,
/// offline scenario run. Instead, [ScenarioResult.deterministicResponseText]
/// / [ScenarioResult.remoteResponseText] use
/// `CounselingTurnPlan.deterministicReply`, which is a pure, local
/// string-concatenation getter (`reflectionSentence` + `questionSentence`)
/// requiring no network call and already fully populated by
/// `TurnPlanMaterializer`. This still lets pairwise export compare
/// deterministic vs. remote-selected text without depending on any
/// unavailable LLM backend.
///
/// Failure absorption reuses the same never-throw discipline as
/// `RemoteCounselorShadowRunner.evaluate` (see that class): every remote
/// failure mode (transport, parse, validation, materialization) is
/// captured into the result rather than propagated, so [runAll] can never
/// abort partway through a batch because of one bad scenario.
class ScenarioRunner {
  final DeterministicPolicyBoundaryBuilder boundaryBuilder;
  final CounselorAgent deterministicAgent;
  final CounselorDecisionValidator validator;
  final TurnPlanAdapter turnPlanAdapter;

  const ScenarioRunner({
    this.boundaryBuilder = const DeterministicPolicyBoundaryBuilder(),
    this.deterministicAgent = const DeterministicCounselorAgent(),
    this.validator = const CounselorDecisionValidator(),
    this.turnPlanAdapter = const TurnPlanAdapter(),
  });

  Future<ScenarioResult> run(
    ScenarioFixture fixture, {
    RemoteCounselorAgent? remoteAgent,
  }) async {
    final policy = boundaryBuilder.build(fixture.request);
    if (policy == null) {
      // The deterministic builder in this codebase never actually returns
      // null (it always encodes "unavailable" via
      // `PolicyBoundary.unavailabilityReason` instead) — but the
      // `PolicyBoundaryBuilder` interface allows it, so this stays a hard
      // failure recorded rather than a crash.
      throw StateError(
        'ScenarioRunner: DeterministicPolicyBoundaryBuilder.build returned '
        'null for scenario ${fixture.id} — fixture.request violates the '
        'builder contract.',
      );
    }

    final multiOptionActual = _isMultiOption(policy);

    final deterministicDecision = deterministicAgent.decide(
      context: fixture.request,
      policy: policy,
    );
    final deterministicTurnPlan = turnPlanAdapter.build(
      request: fixture.request,
      policy: policy,
      decision: deterministicDecision,
    );
    final deterministicResponseText = deterministicTurnPlan?.deterministicReply;

    if (remoteAgent == null) {
      return ScenarioResult(
        scenarioId: fixture.id,
        scenarioLabel: fixture.label,
        category: fixture.category,
        multiOptionActual: multiOptionActual,
        deterministicDecision: deterministicDecision,
        deterministicTurnPlan: deterministicTurnPlan,
        deterministicResponseText: deterministicResponseText,
        failureCategory: 'noRemoteAgent',
      );
    }

    final stopwatch = Stopwatch()..start();
    RemoteCounselorDecisionOutcome outcome;
    try {
      outcome = await remoteAgent.decideAsync(
        context: fixture.request,
        policy: policy,
        personalContext: fixture.personalContext,
      );
    } on RemoteCounselorFailure catch (e) {
      stopwatch.stop();
      return ScenarioResult(
        scenarioId: fixture.id,
        scenarioLabel: fixture.label,
        category: fixture.category,
        multiOptionActual: multiOptionActual,
        deterministicDecision: deterministicDecision,
        deterministicTurnPlan: deterministicTurnPlan,
        deterministicResponseText: deterministicResponseText,
        latencyMs: stopwatch.elapsedMilliseconds,
        failureCategory: e.kind.name,
      );
    } catch (_) {
      // Absorb any other unexpected failure too — a bad scenario must never
      // abort runAll (see class doc).
      stopwatch.stop();
      return ScenarioResult(
        scenarioId: fixture.id,
        scenarioLabel: fixture.label,
        category: fixture.category,
        multiOptionActual: multiOptionActual,
        deterministicDecision: deterministicDecision,
        deterministicTurnPlan: deterministicTurnPlan,
        deterministicResponseText: deterministicResponseText,
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
    final remoteValidationPassed = validationFailureReason == null;

    CounselingTurnPlan? remoteTurnPlan;
    var remoteMaterializationSucceeded = false;
    if (remoteValidationPassed) {
      try {
        remoteTurnPlan = turnPlanAdapter.build(
          request: fixture.request,
          policy: policy,
          decision: remoteDecision,
        );
        remoteMaterializationSucceeded = true;
      } catch (_) {
        remoteMaterializationSucceeded = false;
      }
    }

    return ScenarioResult(
      scenarioId: fixture.id,
      scenarioLabel: fixture.label,
      category: fixture.category,
      multiOptionActual: multiOptionActual,
      deterministicDecision: deterministicDecision,
      remoteDecision: remoteDecision,
      deterministicTurnPlan: deterministicTurnPlan,
      remoteTurnPlan: remoteTurnPlan,
      deterministicResponseText: deterministicResponseText,
      remoteResponseText: remoteTurnPlan?.deterministicReply,
      parseSucceeded: true,
      remoteValidationPassed: remoteValidationPassed,
      remoteValidationFailureReason: validationFailureReason,
      remoteMaterializationSucceeded: remoteMaterializationSucceeded,
      latencyMs: stopwatch.elapsedMilliseconds,
      failureCategory: 'none',
      modelIdentifier: outcome.modelIdentifier,
      promptVersion: outcome.promptVersion,
      inputTokens: outcome.inputTokens,
      outputTokens: outcome.outputTokens,
    );
  }

  Future<List<ScenarioResult>> runAll(
    List<ScenarioFixture> fixtures, {
    RemoteCounselorAgent? remoteAgent,
  }) async {
    final results = <ScenarioResult>[];
    for (final fixture in fixtures) {
      results.add(await run(fixture, remoteAgent: remoteAgent));
    }
    return results;
  }

  bool _isMultiOption(PolicyBoundary policy) {
    return policy.allowedActions.length > 1 ||
        policy.candidateGoalIds.length > 1 ||
        policy.eligibleInterventionIds.length > 1;
  }
}
