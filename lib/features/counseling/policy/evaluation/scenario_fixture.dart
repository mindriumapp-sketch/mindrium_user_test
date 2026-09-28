import '../../../assistant/retrieval/personal_context_summary.dart';
import '../policy_boundary_request.dart';

/// Phase 9.2B: a single frozen, synthetic scenario used to evaluate a
/// [CounselorAgent]/[RemoteCounselorAgent] against the deterministic agent,
/// entirely outside production.
///
/// **Phase 9.2A.1 lesson — do NOT repeat**: [request] may only carry
/// UPSTREAM inputs (state, user message, user context, recent messages,
/// week, registry, knowledge, retrieval summary) — the raw materials a real
/// turn would have *before* any planner runs. It must never hardcode a
/// production-DERIVED field such as `PolicyBoundary.eligibleInterventionIds`,
/// `PolicyBoundary.candidateGoalIds`, or `PolicyBoundary.goalsExhausted`
/// directly on this fixture. Those fields only exist after
/// `DeterministicPolicyBoundaryBuilder.build(request)` runs, and a fixture
/// that bakes in a guess at their value (rather than letting the real
/// builder compute them from upstream inputs) can silently drift out of
/// sync with production logic without any test noticing. Every fixture in
/// `frozen_scenarios*.dart` must be buildable through the real builder, and
/// the invariant test asserts that build() never throws for any of them.
class ScenarioFixture {
  /// Stable identifier for this scenario, e.g. `explore_presentation_01`.
  /// Used to seed deterministic ordering in pairwise export.
  final String id;

  /// Human-readable label for reviewers, e.g. "Explore: presentation anxiety".
  final String label;

  /// Coarse category used for stratified aggregate reporting, e.g.
  /// `reflect_goal_evidence`, `intervention_balancedThought_success`.
  final String category;

  /// The ONLY thing that determines this scenario's boundary/decision —
  /// upstream inputs only. See class doc.
  final PolicyBoundaryRequest request;

  /// Pre-minimized personalization facts, built the same way production
  /// would build them (via [PersonalContextSummary.fromRetrievalSummary] or
  /// literal construction for a synthetic fixture). Never raw diary/session
  /// objects.
  final PersonalContextSummary personalContext;

  /// Best-effort classification of whether this scenario is expected to
  /// produce a PolicyBoundary with more than one legal choice (multiple
  /// allowed actions, multiple candidate goals, or multiple eligible
  /// interventions). This is NOT authoritative — the fixture invariant test
  /// in `test/counseling/evaluation/` recomputes the real value from the
  /// actual built [PolicyBoundary] and fails if it disagrees with this
  /// field. When it disagrees, fix the fixture's [request] (or this field)
  /// until they match — never make this class compute it itself, since that
  /// would just be re-deriving production logic a second time.
  final bool multiOption;

  const ScenarioFixture({
    required this.id,
    required this.label,
    required this.category,
    required this.request,
    this.personalContext = PersonalContextSummary.empty,
    required this.multiOption,
  });

  @override
  String toString() => 'ScenarioFixture($id, $category, multiOption: $multiOption)';
}
