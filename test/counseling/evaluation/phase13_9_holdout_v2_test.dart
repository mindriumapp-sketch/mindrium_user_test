// Phase 13.9 — holdout v2: the session-flow gate on unseen users. See
// docs/counseling/chatbot_system.md.
//
// fixtures/phase13_9_holdout_v2.json was written by an agent without
// access to the code, avoiding every phrasing used before (dev v1, holdout
// v1, dev v2), and frozen before its first run (5408154). The utterances
// are never edited and never used to tune detectors. If this gate fails,
// the result is recorded, fixes go to a new dev set, and a fresh holdout
// takes over.
//
// Gate: the 15 session-flow metrics are 0. Detector coverage (metaIgnored,
// metaFalsePositive, the single-turn probe) is reported, not gated.
import 'package:flutter_test/flutter_test.dart';

import 'support/holdout_runner.dart';
import 'support/session_flow_metrics.dart';

void main() {
  late HoldoutResult result;

  setUpAll(() async {
    result = await runHoldout('test/counseling/evaluation/fixtures/phase13_9_holdout_v2.json');
    // ignore: avoid_print
    print(result.report('PHASE13_9_HOLDOUT_V2_REPORT'));
  });

  test('covers every holdout family in weeks 1–8', () {
    expect(result.runs, hasLength(result.familyCount * 8));
  });

  // Holdout v2 FAILED on its first run (2026-09-30): metaAsTarget 33,
  // repeatedClarifyRun 14, nonAnswerCredited 2. Recorded here; the gate is
  // not met. Now seen, v2 can no longer certify a fix either. See
  // docs/counseling/chatbot_system.md, "holdout v2".
  //
  // Re-run after 13.9D on this now-seen set: all 0. Informational only; the
  // gate moved to holdout v3.
  // Phase 14.3 (2026-10-02): repeatedClarifyRun 1. A contentful-looking
  // reply now resets the no-progress pressure (so a user who keeps talking
  // is never wrapped up); a non-answer the rules don't recognize ("머리가 하얘요")
  // passes as content and gets one more question. Accepted trade-off;
  // recognizing it is 14.2B. B-tier, well under 1% of user turns.
  const seenSetRerun = <String, int>{'repeatedClarifyRun': 1};
  group('holdout v2 (seen set): re-run recorded, not a pass', () {
    for (final metric in flowGateMetrics) {
      test(metric, () {
        expect(result.metrics.counts[metric], seenSetRerun[metric] ?? 0,
            reason: 'holdout v2 changed; update the record deliberately.\n'
                '${result.metrics.failures[metric]?.join('\n')}');
      });
    }
  });
}
