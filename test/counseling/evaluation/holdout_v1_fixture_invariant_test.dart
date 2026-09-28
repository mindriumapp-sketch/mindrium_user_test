// Phase 9.2E: invariant test for `phase9_2e_holdout_v1` — mirrors
// `scenario_fixture_invariant_test.dart`'s guarantee for `frozen_v1`.
// Every holdout fixture must build a real PolicyBoundary without throwing,
// and its `multiOption` label must match what the real boundary computes
// (Phase 9.2A.1's lesson, re-applied to the new dataset).
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/holdout_v1_scenarios.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';

void main() {
  final fixtures = buildHoldoutV1Scenarios();
  const builder = DeterministicPolicyBoundaryBuilder();

  test('holdout_v1 has a healthy scenario count and no duplicate ids', () {
    expect(fixtures.length, greaterThanOrEqualTo(60));
    final ids = fixtures.map((f) => f.id).toSet();
    expect(ids.length, fixtures.length, reason: 'scenario ids must be unique');
  });

  test('minimum coverage per Phase 9.2E spec', () {
    bool isMulti(f) => f.multiOption;
    bool isSingle(f) => !f.multiOption;
    bool isPersonalization(f) =>
        (f.category as String).contains('personalization') ||
        (f.category as String).contains('diary');
    bool isIntervention(f) => (f.category as String).contains('intervention');
    bool isRepetition(f) => (f.category as String).contains('exhausted');

    expect(fixtures.where(isMulti).length, greaterThanOrEqualTo(30));
    expect(fixtures.where(isSingle).length, greaterThanOrEqualTo(12));
    expect(fixtures.where(isPersonalization).length, greaterThanOrEqualTo(12));
    expect(fixtures.where(isIntervention).length, greaterThanOrEqualTo(12));
    expect(fixtures.where(isRepetition).length, greaterThanOrEqualTo(6));
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
