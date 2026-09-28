import 'aggregate_report.dart';
import 'human_review.dart';

/// Phase 9.2C follow-up: `p95(decide) + p95(realize)` is NOT the same
/// statistic as `p95(decide + realize)` — summing two independently-computed
/// percentiles is a conservative proxy, not the actual end-to-end
/// percentile a user experiences. This helper computes the real thing from
/// PAIRED per-scenario latencies (the decide and realize call that happened
/// for the *same* turn), when both are available for the same run.
///
/// Prefer this over summing two separate p95s whenever the evaluation run
/// can produce paired latencies. See
/// `docs/counseling/phase9_2_activation_criteria.md`'s Operational gates
/// section for why this distinction matters and when the conservative proxy
/// is still an acceptable fallback.
int computePairedEndToEndP95Ms(
  List<({int decideMs, int realizeMs})> pairedLatencies,
) {
  if (pairedLatencies.isEmpty) {
    throw ArgumentError('pairedLatencies must not be empty');
  }
  final sums = pairedLatencies.map((p) => p.decideMs + p.realizeMs).toList()
    ..sort();
  final index = (0.95 * (sums.length - 1)).round();
  return sums[index];
}

/// Phase 9.2C (frozen numbers finalized before any real API run — see
/// `docs/counseling/phase9_2_activation_criteria.md`'s Operational gates
/// section for the rationale behind each number): the automatically-
/// checkable thresholds. Freeze these BEFORE looking at real evaluation
/// results — that's the whole point of this class existing separately from
/// ad-hoc post-hoc judgment.
class ActivationThresholds {
  /// "Parsing/transport success ≥ 98%" — measured as
  /// `StratumStats.remoteSuccessRate` (transport + parse both succeeding),
  /// on the `overall` stratum.
  final double minRemoteSuccessRate;

  /// p95 latency in milliseconds for the `/counseling/decide` call alone.
  /// 2500ms: `/counseling/decide`'s own backend timeout budget is
  /// connect=3s/read=6s (see `backend/app/routers/counseling_decide.py`),
  /// but decide is a short selection task (`_MAX_OUTPUT_TOKENS = 200`) with
  /// no drafted prose — its P95 should sit well inside that ceiling, not
  /// approach it, since a second remote call (`/counseling/realize`) still
  /// has to happen after it in the same turn.
  final int maxDecideP95LatencyMs;

  /// p95 latency in milliseconds for decide + realize COMBINED — the actual
  /// user-facing wait if both stages run remotely in one turn. 8000ms
  /// matches the upper bound of `/counseling/realize`'s own already-
  /// documented "total deadline 5~8초" policy
  /// (`docs/counseling/remote_gpt_realizer_integration.md` §9) — i.e. this
  /// gate does not grant decide any additional budget beyond what realize
  /// alone was already allowed; decide's latency must fit within realize's
  /// existing envelope, not extend it.
  final int maxEndToEndP95LatencyMs;

  const ActivationThresholds({
    this.minRemoteSuccessRate = 0.98,
    this.maxDecideP95LatencyMs = 2500,
    this.maxEndToEndP95LatencyMs = 8000,
  });
}

/// One named gate's outcome. `passed == null` means this gate could not be
/// automatically evaluated (e.g. no human review data supplied yet) — it is
/// deliberately distinct from `false`, since "not yet answered" and "failed"
/// must not be conflated when deciding whether to activate.
class ActivationGateResult {
  final String name;
  final bool? passed;
  final String detail;

  const ActivationGateResult({
    required this.name,
    required this.passed,
    required this.detail,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'passed': passed,
    'detail': detail,
  };
}

/// Phase 9.2C: the combined result of checking every gate in
/// `phase9_2_activation_criteria.md` against one evaluation run.
///
/// This class does not decide "activate or don't" on its own authority —
/// `readyForActivation` reflects exactly what the frozen criteria say, but
/// the actual Phase 9.3 go/no-go decision is a human one. What this class
/// guarantees is that the decision is checked against criteria that were
/// written down before the run happened, not invented afterward to fit the
/// result.
class ActivationGateEvaluation {
  final List<ActivationGateResult> gates;

  const ActivationGateEvaluation({required this.gates});

  /// True only if every gate that COULD be evaluated passed, AND none are
  /// still unanswered (`passed == null`). If any gate is unanswered
  /// (typically: human review not yet collected), this is false — an
  /// incomplete evaluation cannot recommend activation, only a complete
  /// failure or a complete pass can.
  bool get readyForActivation =>
      gates.isNotEmpty && gates.every((g) => g.passed == true);

  bool get hasAnyFailure => gates.any((g) => g.passed == false);

  bool get hasAnyPending => gates.any((g) => g.passed == null);

  List<ActivationGateResult> get failedGates =>
      gates.where((g) => g.passed == false).toList();

  List<ActivationGateResult> get pendingGates =>
      gates.where((g) => g.passed == null).toList();

  Map<String, Object?> toJson() => {
    'ready_for_activation': readyForActivation,
    'has_any_failure': hasAnyFailure,
    'has_any_pending': hasAnyPending,
    'gates': gates.map((g) => g.toJson()).toList(),
  };
}

/// Phase 9.2C: evaluates the automatically-checkable subset of
/// `phase9_2_activation_criteria.md` against one run's `AggregateReport`
/// (+ optional human review data). It never converts human judgment
/// (naturalness, appropriateness) into a numeric score itself — for
/// anything that needs a person's read, it either takes an already-computed
/// [HumanReviewSummary] or reports that gate as pending (`passed: null`).
class ActivationGateEvaluator {
  const ActivationGateEvaluator();

  ActivationGateEvaluation evaluate({
    required AggregateReport report,
    /// Manually-supplied count of "critical failures" as defined in
    /// `phase9_2_activation_criteria.md` (policy-outside-boundary decision
    /// that somehow reached the user, unrelated personal context referenced
    /// as fact, exhaustion/repetition policy violated, a semantically
    /// impossible decision for closing/intervention, etc). This is not
    /// derivable from `AggregateReport` alone — it requires reviewing
    /// individual `ScenarioResult`s (and often the human pairwise review)
    /// against the critical-failure definitions.
    required int criticalFailureCount,
    HumanReviewSummary? humanReview,
    /// p95 latency in ms for the `/counseling/decide` call alone, computed
    /// externally from this run's raw per-scenario latencies.
    int? decideP95LatencyMs,
    /// p95 latency in ms for `/counseling/realize` alone, measured/estimated
    /// separately (this evaluation only exercises `/counseling/decide` —
    /// `ScenarioRunner` never calls the realizer over the network). Used
    /// only as the fallback "conservative proxy" (summed with
    /// [decideP95LatencyMs]) when [pairedEndToEndP95LatencyMs] isn't
    /// supplied — see that parameter's doc.
    int? realizerP95LatencyMs,
    /// The PREFERRED end-to-end latency figure: `p95(decide + realize)`
    /// computed from paired per-scenario latencies (same turn's decide call
    /// and realize call summed, then the 95th percentile taken over those
    /// sums) via [computePairedEndToEndP95Ms]. This is the actual
    /// end-to-end percentile users experience — not the same statistic as
    /// summing [decideP95LatencyMs] and [realizerP95LatencyMs] independently
    /// (`p95(a) + p95(b) != p95(a + b)` in general). When supplied, this
    /// takes priority over the sum-of-independent-p95s fallback below.
    int? pairedEndToEndP95LatencyMs,
    ActivationThresholds thresholds = const ActivationThresholds(),
  }) {
    final bool usedPairedLatency = pairedEndToEndP95LatencyMs != null;
    final endToEndP95LatencyMs =
        pairedEndToEndP95LatencyMs ??
        ((decideP95LatencyMs != null && realizerP95LatencyMs != null)
            ? decideP95LatencyMs + realizerP95LatencyMs
            : null);
    final overall = report.overall;
    final gates = <ActivationGateResult>[
      ActivationGateResult(
        name: 'materialization_no_regression',
        passed: overall.validationPassed == overall.materializationSucceeded,
        detail:
            'validation_passed=${overall.validationPassed}, '
            'materialization_succeeded=${overall.materializationSucceeded} '
            '(every validated decision must materialize — Phase 9.2A.1 gap '
            'must not have reappeared)',
      ),
      ActivationGateResult(
        name: 'critical_failure_count_zero',
        passed: criticalFailureCount == 0,
        detail: 'critical_failure_count=$criticalFailureCount (must be 0)',
      ),
      ActivationGateResult(
        name: 'remote_success_rate_minimum',
        passed:
            overall.remoteSuccessRate != null
                ? overall.remoteSuccessRate! >= thresholds.minRemoteSuccessRate
                : null,
        detail:
            'remote_success_rate=${overall.remoteSuccessRate} '
            '(threshold: ${thresholds.minRemoteSuccessRate})',
      ),
      ActivationGateResult(
        name: 'decide_p95_latency_operational',
        passed:
            decideP95LatencyMs != null
                ? decideP95LatencyMs <= thresholds.maxDecideP95LatencyMs
                : null,
        detail:
            'decide_p95_latency_ms=$decideP95LatencyMs '
            '(threshold: ${thresholds.maxDecideP95LatencyMs}, supply '
            'externally — AggregateReport only tracks mean/median)',
      ),
      ActivationGateResult(
        name: 'end_to_end_p95_latency_operational',
        passed:
            endToEndP95LatencyMs != null
                ? endToEndP95LatencyMs <= thresholds.maxEndToEndP95LatencyMs
                : null,
        detail:
            'end_to_end_p95_latency_ms=$endToEndP95LatencyMs '
            '(method=${usedPairedLatency ? "paired_p95(decide+realize)" : "conservative_proxy_sum_of_independent_p95s(decide_p95=$decideP95LatencyMs, realizer_p95=$realizerP95LatencyMs)"}, '
            'threshold: ${thresholds.maxEndToEndP95LatencyMs} — this must fit '
            'inside /counseling/realize\'s already-documented total-deadline '
            'budget, not extend it)',
      ),
      ActivationGateResult(
        name: 'multi_option_no_clear_degradation',
        passed:
            report.multiOption.count == 0
                ? null
                : report.multiOption.remoteSuccessRate != null
                ? report.multiOption.remoteSuccessRate! >=
                    thresholds.minRemoteSuccessRate
                : null,
        detail:
            'multi_option stratum reliability as a floor check; the actual '
            'quality judgment ("no clear degradation") is the human '
            'pairwise review restricted to multi-option scenarios, not this '
            'reliability number alone',
      ),
      ActivationGateResult(
        name: 'human_pairwise_better_than_worse',
        passed: humanReview?.remoteBetterThanWorse,
        detail:
            humanReview == null
                ? 'no HumanReviewSummary supplied yet'
                : 'remote_better=${humanReview.remoteBetterCount}, '
                    'remote_worse=${humanReview.remoteWorseCount}, '
                    'tie=${humanReview.tieCount}, '
                    'both_poor=${humanReview.bothPoorCount}',
      ),
    ];

    return ActivationGateEvaluation(gates: gates);
  }
}
