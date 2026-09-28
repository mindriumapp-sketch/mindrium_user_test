// Phase 10.5B: invariant test for `phase10_5b_holdout_v2` — mirrors
// `holdout_v1_fixture_invariant_test.dart`'s guarantee. Every fixture must
// build a real PolicyBoundary without throwing, and its `multiOption` label
// must match what the real boundary computes.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/holdout_v2_realization_scenarios.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';

void main() {
  final fixtures = buildHoldoutV2Scenarios();
  const builder = DeterministicPolicyBoundaryBuilder();
  const remoteEligibleStates = {CounselingState.explore, CounselingState.reflect};

  test('holdout_v2 has a healthy scenario count and no duplicate ids', () {
    expect(fixtures.length, greaterThanOrEqualTo(45));
    final ids = fixtures.map((f) => f.id).toSet();
    expect(ids.length, fixtures.length, reason: 'scenario ids must be unique');
  });

  test('every fixture is remote-eligible (explore/reflect only) by construction', () {
    for (final fixture in fixtures) {
      expect(
        remoteEligibleStates.contains(fixture.request.currentState),
        isTrue,
        reason:
            '${fixture.id}: holdout_v2 is scoped to explore/reflect only — '
            'checkIn/intervention/closing add no realization-evaluation '
            'value since HybridTurnRouter never allows a real realizer to '
            'run for them',
      );
    }
  });

  test('minimum coverage per Phase 10.5B spec', () {
    bool isSud(f) => (f.category as String).contains('sud_response');
    bool isExhausted(f) => (f.category as String).contains('exhausted_repeat');
    bool isPersonalization(f) =>
        (f.category as String).contains('personalization') ||
        (f.category as String).contains('diary');

    expect(fixtures.where(isSud).length, greaterThanOrEqualTo(8));
    expect(fixtures.where(isExhausted).length, greaterThanOrEqualTo(6));
    expect(fixtures.where(isPersonalization).length, greaterThanOrEqualTo(8));
  });

  test('no recentMessages carry a "goal:" placeholder (the Phase 10.5A.2 Track A bug)', () {
    for (final fixture in fixtures) {
      for (final message in fixture.request.recentMessages) {
        expect(
          message.text.startsWith('goal:'),
          isFalse,
          reason:
              '${fixture.id}: recentMessages must carry realistic prior '
              'assistant text, never the assistantGoalMessage() placeholder '
              '— see docs/counseling/phase10_5a2_context_audit.md',
        );
      }
    }
  });

  group('build() succeeds and multiOption matches computed value', () {
    for (final fixture in fixtures) {
      test(fixture.id, () {
        final policy = builder.build(fixture.request);
        expect(
          policy,
          isNotNull,
          reason: '${fixture.id}: DeterministicPolicyBoundaryBuilder.build '
              'must not throw / return null',
        );
        final actual = policy!.allowedActions.length > 1 ||
            policy.candidateGoalIds.length > 1;
        expect(
          fixture.multiOption,
          actual,
          reason: '${fixture.id}: multiOption=${fixture.multiOption} but the '
              'real boundary computed multiOption=$actual — fix the fixture, '
              'not this test',
        );
      });
    }
  });
}
