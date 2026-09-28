import 'frozen_scenarios_checkin_explore.dart';
import 'frozen_scenarios_intervention.dart';
import 'frozen_scenarios_personalization_closing_mixed.dart';
import 'frozen_scenarios_reflect.dart';
import 'scenario_fixture.dart';

/// Phase 9.2C: this dataset is FROZEN as `phase9_2b_frozen_v1` (89
/// scenarios). Once the first real API run against it has happened, do not
/// edit, add to, or remove from the `frozen_scenarios_*.dart` files that
/// compose it — that would silently invalidate any evaluation result
/// already recorded against `frozenScenariosVersion`. If the scenario set
/// needs to change (new category, fixed fixture, different distribution),
/// create a new versioned set (`frozen_scenarios_v2.dart` /
/// `frozenScenariosV2`, bump [frozenScenariosVersion] there) rather than
/// mutating this one in place. See
/// `docs/counseling/phase9_2_activation_criteria.md` for why this matters
/// (evaluating against a moving dataset makes "activation criteria met"
/// unfalsifiable).
const String frozenScenariosVersion = 'phase9_2b_frozen_v1';

/// Phase 9.2B: the complete frozen scenario set used to evaluate
/// `CounselorAgent`/`RemoteCounselorAgent` outside production. Barrel list
/// combining every category file under this directory.
///
/// See each `frozen_scenarios_*.dart` file's doc comment for what it
/// covers. `test/counseling/evaluation/scenario_fixture_invariant_test.dart`
/// asserts every entry here builds a real `PolicyBoundary` without throwing
/// and that `multiOption` matches what the real boundary computes.
final List<ScenarioFixture> frozenScenarios = [
  ...buildCheckInAndExploreScenarios(),
  ...buildReflectScenarios(),
  ...buildInterventionScenarios(),
  ...buildPersonalizationClosingMixedScenarios(),
];
