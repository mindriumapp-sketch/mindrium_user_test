// Phase 13.9 — holdout v5: the two-tier gate (13.9F, fixed before this set
// was written). See docs/counseling/phase13_status_and_plan.md.
//
// fixtures/phase13_9_holdout_v5.json was written by an agent without
// access to the code, avoiding the 443 phrasings used before, and frozen
// before its first run. Never edited, never used to tune detectors.
import 'package:flutter_test/flutter_test.dart';

import 'support/holdout_runner.dart';
import 'support/session_flow_metrics.dart';

void main() {
  late HoldoutResult result;

  setUpAll(() async {
    result = await runHoldout('test/counseling/evaluation/fixtures/phase13_9_holdout_v5.json');
    // ignore: avoid_print
    print(result.report('PHASE13_9_HOLDOUT_V5_REPORT'));
  });

  test('covers every holdout family in weeks 1–8', () {
    expect(result.runs, hasLength(result.familyCount * 8));
  });

  group('tier A: structural metrics are 0', () {
    for (final metric in flowStructuralMetrics) {
      test(metric, () {
        expect(result.metrics.counts[metric], 0,
            reason: result.metrics.failures[metric]?.join('\n'));
      });
    }
  });

  test('tier B: detection-dependent hits stay at or below 1% of user turns', () {
    final turns = result.runs.fold<int>(0, (n, r) => n + r.steps.length);
    final hits = flowDetectionDependentMetrics.fold<int>(0, (n, m) => n + result.metrics.counts[m]!);
    expect(hits / turns, lessThanOrEqualTo(detectionDependentMaxRate),
        reason: '$hits hits in $turns turns\n'
            '${[for (final m in flowDetectionDependentMetrics) ...?result.metrics.failures[m]].join('\n')}');
  });
}
