// Phase 9.2C: HumanReviewSummary — merges blind PairwiseReview verdicts with
// the hidden PairwiseMappingRow identity mapping, and only after that merge
// exposes remote-vs-deterministic preference counts.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/human_review.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/pairwise_export.dart';

void main() {
  test('resolves aBetter/bBetter into remoteBetter/remoteWorse via mapping', () {
    final reviews = [
      // s1: reviewer preferred A. Mapping says A is NOT remote -> remote lost.
      const PairwiseReview(
        scenarioId: 's1',
        preference: PairwisePreference.aBetter,
      ),
      // s2: reviewer preferred B. Mapping says A is NOT remote (so B is
      // remote) -> remote won.
      const PairwiseReview(
        scenarioId: 's2',
        preference: PairwisePreference.bBetter,
      ),
      // s3: reviewer preferred A. Mapping says A IS remote -> remote won.
      const PairwiseReview(
        scenarioId: 's3',
        preference: PairwisePreference.aBetter,
      ),
      const PairwiseReview(scenarioId: 's4', preference: PairwisePreference.tie),
      const PairwiseReview(
        scenarioId: 's5',
        preference: PairwisePreference.bothPoor,
      ),
    ];
    final mapping = const [
      PairwiseMappingRow(scenarioId: 's1', aIsRemote: false),
      PairwiseMappingRow(scenarioId: 's2', aIsRemote: false),
      PairwiseMappingRow(scenarioId: 's3', aIsRemote: true),
      PairwiseMappingRow(scenarioId: 's4', aIsRemote: true),
      PairwiseMappingRow(scenarioId: 's5', aIsRemote: false),
    ];

    final summary = HumanReviewSummary.merge(reviews: reviews, mapping: mapping);

    expect(summary.remoteBetterCount, 2); // s2, s3
    expect(summary.remoteWorseCount, 1); // s1
    expect(summary.tieCount, 1); // s4
    expect(summary.bothPoorCount, 1); // s5
    expect(summary.remoteBetterThanWorse, isTrue);
  });

  test('a review with no matching mapping row is dropped, not guessed', () {
    final summary = HumanReviewSummary.merge(
      reviews: const [
        PairwiseReview(scenarioId: 'unknown', preference: PairwisePreference.aBetter),
      ],
      mapping: const [],
    );

    expect(summary.resolved, isEmpty);
    expect(summary.remoteBetterThanWorse, isFalse);
  });

  test('remoteBetterThanWorse is strict > , not >=', () {
    final summary = HumanReviewSummary.merge(
      reviews: const [
        PairwiseReview(scenarioId: 's1', preference: PairwisePreference.aBetter),
        PairwiseReview(scenarioId: 's2', preference: PairwisePreference.bBetter),
      ],
      mapping: const [
        PairwiseMappingRow(scenarioId: 's1', aIsRemote: true), // remote better
        PairwiseMappingRow(scenarioId: 's2', aIsRemote: true), // remote worse
      ],
    );

    expect(summary.remoteBetterCount, 1);
    expect(summary.remoteWorseCount, 1);
    expect(summary.remoteBetterThanWorse, isFalse);
  });
}
