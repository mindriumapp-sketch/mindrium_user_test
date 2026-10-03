// Phase 13.9 — holdout v3: the session-flow gate on unseen users. See
// docs/counseling/chatbot_system.md (tag counseling-handover-v1).
//
// fixtures/holdout_v3.json was written by an agent without
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
    result = await runHoldout('test/counseling/regression/fixtures/holdout_v3.json');
    // ignore: avoid_print
    print(result.report('PHASE13_9_HOLDOUT_V3_REPORT'));
  });

  test('covers every holdout family in weeks 1–8', () {
    expect(result.runs, hasLength(result.familyCount * 8));
  });

  // Holdout v3 FAILED on its first run (2026-09-30): nonAnswerCredited 5,
  // closingContinuationIgnored 3. Recorded; the gate moved to holdout v4.
  // Re-run after 13.9E on this now-seen set: all 0 (informational).
  // Phase 14.3 (2026-10-02): repeatedClarifyRun 1. A contentful-looking
  // reply now resets the no-progress pressure (so a user who keeps talking
  // is never wrapped up); a non-answer the rules don't recognize ("그런 건 생각 안 해봤어요")
  // passes as content and gets one more question. Accepted trade-off;
  // recognizing it is 14.2B. B-tier, well under 1% of user turns.
  const seenSetRerun = <String, int>{'repeatedClarifyRun': 1};
  group('holdout v3 (seen set): re-run recorded, not a pass', () {
    for (final metric in flowGateMetrics) {
      test(metric, () {
        expect(result.metrics.counts[metric], seenSetRerun[metric] ?? 0,
            reason: 'holdout v3 changed; update the record deliberately.\n'
                '${result.metrics.failures[metric]?.join('\n')}');
      });
    }
  });
}
