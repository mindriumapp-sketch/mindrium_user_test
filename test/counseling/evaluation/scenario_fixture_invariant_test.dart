// Phase 9.2B: proves every frozen scenario fixture builds a real
// PolicyBoundary without throwing, and that `multiOption` matches what the
// real boundary computes — never guessed independently (see
// ScenarioFixture's class doc on the Phase 9.2A.1 "no production-derived
// fields" lesson).
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/policy/evaluation/frozen_scenarios.dart';

bool _isMultiOption(PolicyBoundary policy) {
  return policy.allowedActions.length > 1 ||
      policy.candidateGoalIds.length > 1 ||
      policy.eligibleInterventionIds.length > 1;
}

void main() {
  const builder = DeterministicPolicyBoundaryBuilder();

  test('frozen scenario set has between 70 and 90 entries', () {
    expect(frozenScenarios.length, greaterThanOrEqualTo(70));
    expect(frozenScenarios.length, lessThanOrEqualTo(90));
  });

  test('all scenario ids are unique', () {
    final ids = frozenScenarios.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every scenario category is non-empty', () {
    for (final fixture in frozenScenarios) {
      expect(fixture.category, isNotEmpty, reason: fixture.id);
    }
  });

  group('build() succeeds and multiOption matches computed value', () {
    for (final fixture in frozenScenarios) {
      test(fixture.id, () {
        late PolicyBoundary? policy;
        expect(
          () => policy = builder.build(fixture.request),
          returnsNormally,
          reason: 'DeterministicPolicyBoundaryBuilder.build must not throw '
              'for scenario ${fixture.id}',
        );
        final resolved = policy;
        expect(
          resolved,
          isNotNull,
          reason:
              'PolicyBoundaryRequest for ${fixture.id} produced a null '
              'boundary',
        );

        final actual = _isMultiOption(resolved!);
        expect(
          actual,
          fixture.multiOption,
          reason:
              'Scenario ${fixture.id} (${fixture.category}) declares '
              'multiOption=${fixture.multiOption} but the real boundary '
              'computed multiOption=$actual '
              '(allowedActions=${resolved.allowedActions.length}, '
              'candidateGoalIds=${resolved.candidateGoalIds.length}, '
              'eligibleInterventionIds=${resolved.eligibleInterventionIds.length})',
        );
      });
    }
  });
}
