// Phase 13.9B — holdout v1, now a seen set. See
// docs/counseling/phase13_status_and_plan.md.
//
// The utterances in fixtures/phase13_9b_holdout.json were written blind and
// frozen before the first run (3f714c2). That first run failed the flow
// gate: stateLoop 2, nonAnswerCredited 17, metaAsTarget 54,
// repeatedClarifyRun 30. Once seen, a holdout can't certify a fix, so the
// gate moved to holdout v2 (phase13_9_holdout_v2_test.dart). This file only
// records how v1 behaves now, as information; remaining v1 misses are not
// fixed from v1.
import 'package:flutter_test/flutter_test.dart';

import 'support/holdout_runner.dart';
import 'support/session_flow_metrics.dart';

void main() {
  late HoldoutResult result;

  setUpAll(() async {
    result = await runHoldout('test/counseling/evaluation/fixtures/phase13_9b_holdout.json');
    // ignore: avoid_print
    print(result.report('PHASE13_9B_REPORT'));
  });

  test('covers every holdout family in weeks 1–8', () {
    expect(result.runs, hasLength(result.familyCount * 8));
  });

  // Re-run after the 13.9C safety nets and dev-v2 widening.
  const seenSetRerun = {'metaAsTarget': 3};
  group('holdout v1 (seen set): re-run recorded, not a pass', () {
    for (final metric in flowGateMetrics) {
      test(metric, () {
        expect(result.metrics.counts[metric], seenSetRerun[metric] ?? 0,
            reason: 'holdout v1 changed; update the record deliberately.\n'
                '${result.metrics.failures[metric]?.join('\n')}');
      });
    }
  });
}
