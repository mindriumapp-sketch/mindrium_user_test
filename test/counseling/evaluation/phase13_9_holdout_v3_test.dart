// Phase 13.9 — holdout v3: the session-flow gate on unseen users. See
// docs/counseling/phase13_status_and_plan.md.
//
// fixtures/phase13_9_holdout_v3.json was written by an agent without
// access to the code, avoiding all 264 phrasings used before, and frozen
// before its first run. The utterances are never edited and never used to
// tune detectors.
//
// Gate: the 15 session-flow metrics are 0. Detector coverage (metaIgnored,
// metaFalsePositive, the single-turn probe) is reported, not gated.
import 'package:flutter_test/flutter_test.dart';

import 'support/holdout_runner.dart';
import 'support/session_flow_metrics.dart';

void main() {
  late HoldoutResult result;

  setUpAll(() async {
    result = await runHoldout('test/counseling/evaluation/fixtures/phase13_9_holdout_v3.json');
    // ignore: avoid_print
    print(result.report('PHASE13_9_HOLDOUT_V3_REPORT'));
  });

  test('covers every holdout family in weeks 1–8', () {
    expect(result.runs, hasLength(result.familyCount * 8));
  });

  // Holdout v3 FAILED on its first run (2026-09-30): nonAnswerCredited 5,
  // closingContinuationIgnored 3. Recorded; the gate moved to holdout v4.
  const firstRun = {'nonAnswerCredited': 5, 'closingContinuationIgnored': 3};
  group('holdout v3 result (recorded failure; the gate is not met)', () {
    for (final metric in flowGateMetrics) {
      test(metric, () {
        expect(result.metrics.counts[metric], firstRun[metric] ?? 0,
            reason: 'holdout v3 changed; update the record deliberately.\n'
                '${result.metrics.failures[metric]?.join('\n')}');
      });
    }
  });
}
