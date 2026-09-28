import 'scenario_runner.dart';

/// Phase 9.2B: a single stratum's computed statistics — the same shape is
/// reused for "overall" and every stratified breakdown.
class StratumStats {
  final int count;
  final int remoteAttempted;
  final int remoteSucceeded;
  final int parseSucceeded;
  final int validationPassed;
  final int materializationSucceeded;
  final int decisionsAgree;
  final int decisionsDiffer;
  final int reflectionTargetMismatch;
  final Map<String, int> failureCategoryHistogram;
  final double? latencyMeanMs;
  final double? latencyMedianMs;

  const StratumStats({
    required this.count,
    required this.remoteAttempted,
    required this.remoteSucceeded,
    required this.parseSucceeded,
    required this.validationPassed,
    required this.materializationSucceeded,
    required this.decisionsAgree,
    required this.decisionsDiffer,
    required this.reflectionTargetMismatch,
    required this.failureCategoryHistogram,
    this.latencyMeanMs,
    this.latencyMedianMs,
  });

  double? _rate(int numerator, int denominator) =>
      denominator == 0 ? null : numerator / denominator;

  double? get remoteSuccessRate => _rate(remoteSucceeded, remoteAttempted);
  double? get parseSuccessRate => _rate(parseSucceeded, remoteAttempted);
  double? get validationPassRate => _rate(validationPassed, remoteAttempted);
  double? get materializationSuccessRate =>
      _rate(materializationSucceeded, remoteAttempted);
  double? get agreementRate =>
      _rate(decisionsAgree, decisionsAgree + decisionsDiffer);

  Map<String, Object?> toJson() => {
    'count': count,
    'remote_attempted': remoteAttempted,
    'remote_succeeded': remoteSucceeded,
    'remote_success_rate': remoteSuccessRate,
    'parse_succeeded': parseSucceeded,
    'parse_success_rate': parseSuccessRate,
    'validation_passed': validationPassed,
    'validation_pass_rate': validationPassRate,
    'materialization_succeeded': materializationSucceeded,
    'materialization_success_rate': materializationSuccessRate,
    'decisions_agree': decisionsAgree,
    'decisions_differ': decisionsDiffer,
    'agreement_rate': agreementRate,
    'reflection_target_mismatch': reflectionTargetMismatch,
    'failure_category_histogram': failureCategoryHistogram,
    'latency_mean_ms': latencyMeanMs,
    'latency_median_ms': latencyMedianMs,
  };
}

/// Phase 9.2B: pure aggregation over a `List<ScenarioResult>`. Computes
/// reliability, decision-behavior, and operational statistics, both overall
/// and stratified across several dimensions relevant to Phase 9.3's
/// activation decision.
///
/// This class makes NO judgment about what counts as "good enough" —
/// defining that threshold (Phase 9.3 activation criteria) is explicitly
/// out of scope here; see this file's note at the bottom of
/// `frozen_scenarios.dart`'s sibling docs / the top-level report handed
/// back to the user.
class AggregateReport {
  final StratumStats overall;
  final StratumStats singleOption;
  final StratumStats multiOption;
  final StratumStats personalizationSensitive;
  final StratumStats interventionSensitive;
  final StratumStats goalExhaustion;

  const AggregateReport({
    required this.overall,
    required this.singleOption,
    required this.multiOption,
    required this.personalizationSensitive,
    required this.interventionSensitive,
    required this.goalExhaustion,
  });

  factory AggregateReport.compute(List<ScenarioResult> results) {
    // Phase 9.2E: these were originally exact-match/startsWith checks tied
    // to frozen_v1's literal category names (e.g. `personalization_...`,
    // `reflect_goal_exhausted_repeat`) — a newer dataset using a different
    // naming convention (holdout_v1's `holdout_personalization_...`,
    // `holdout_reflect_exhausted_...`) silently produced empty (count: 0)
    // strata instead of failing loudly, which would have made a real
    // report claim those subgroups didn't exist. `contains()` is
    // dataset-version-agnostic as long as category names keep using these
    // substrings, which every `frozen_scenarios_*.dart`/
    // `holdout_v1_scenarios.dart` category still does.
    bool isPersonalizationSensitive(ScenarioResult r) =>
        r.category.contains('personalization') || r.category.contains('diary');
    bool isInterventionSensitive(ScenarioResult r) =>
        r.category.contains('intervention');
    bool isGoalExhaustion(ScenarioResult r) =>
        r.category.contains('exhausted');

    return AggregateReport(
      overall: _computeStratum(results),
      singleOption: _computeStratum(
        results.where((r) => !r.multiOptionActual).toList(),
      ),
      multiOption: _computeStratum(
        results.where((r) => r.multiOptionActual).toList(),
      ),
      personalizationSensitive: _computeStratum(
        results.where(isPersonalizationSensitive).toList(),
      ),
      interventionSensitive: _computeStratum(
        results.where(isInterventionSensitive).toList(),
      ),
      goalExhaustion: _computeStratum(
        results.where(isGoalExhaustion).toList(),
      ),
    );
  }

  static StratumStats _computeStratum(List<ScenarioResult> results) {
    final remoteAttempted =
        results.where((r) => r.failureCategory != 'noRemoteAgent').toList();
    final remoteSucceeded =
        remoteAttempted.where((r) => r.failureCategory == 'none').toList();
    final parseSucceeded =
        remoteAttempted.where((r) => r.parseSucceeded).toList();
    final validationPassed =
        remoteAttempted.where((r) => r.remoteValidationPassed).toList();
    final materializationSucceeded =
        remoteAttempted.where((r) => r.remoteMaterializationSucceeded).toList();

    var decisionsAgree = 0;
    var decisionsDiffer = 0;
    var reflectionTargetMismatch = 0;
    for (final r in remoteAttempted) {
      if (r.remoteDecision == null) continue;
      if (r.decisionsDiffer) {
        decisionsDiffer++;
      } else {
        decisionsAgree++;
      }
      final detTarget = r.deterministicDecision.reflectionTarget;
      final remTarget = r.remoteDecision!.reflectionTarget;
      if (detTarget.runtimeType != remTarget.runtimeType) {
        reflectionTargetMismatch++;
      }
    }

    final histogram = <String, int>{};
    for (final r in remoteAttempted) {
      final key = r.failureCategory ?? 'none';
      histogram[key] = (histogram[key] ?? 0) + 1;
    }

    final latencies =
        remoteAttempted
            .map((r) => r.latencyMs)
            .whereType<int>()
            .toList()
          ..sort();
    double? mean;
    double? median;
    if (latencies.isNotEmpty) {
      mean = latencies.reduce((a, b) => a + b) / latencies.length;
      final mid = latencies.length ~/ 2;
      median =
          latencies.length.isOdd
              ? latencies[mid].toDouble()
              : (latencies[mid - 1] + latencies[mid]) / 2.0;
    }

    return StratumStats(
      count: results.length,
      remoteAttempted: remoteAttempted.length,
      remoteSucceeded: remoteSucceeded.length,
      parseSucceeded: parseSucceeded.length,
      validationPassed: validationPassed.length,
      materializationSucceeded: materializationSucceeded.length,
      decisionsAgree: decisionsAgree,
      decisionsDiffer: decisionsDiffer,
      reflectionTargetMismatch: reflectionTargetMismatch,
      failureCategoryHistogram: histogram,
      latencyMeanMs: mean,
      latencyMedianMs: median,
    );
  }

  Map<String, Object?> toJson() => {
    'overall': overall.toJson(),
    'single_option': singleOption.toJson(),
    'multi_option': multiOption.toJson(),
    'personalization_sensitive': personalizationSensitive.toJson(),
    'intervention_sensitive': interventionSensitive.toJson(),
    'goal_exhaustion': goalExhaustion.toJson(),
  };
}
