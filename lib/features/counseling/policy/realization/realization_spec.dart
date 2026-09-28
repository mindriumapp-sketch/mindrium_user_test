import '../../intervention_registry.dart';
import '../counselor_decision.dart';

/// Phase 10.2: the semantic half of what used to be fused inside
/// `TurnPlanMaterializer`'s finished-sentence strings.
///
/// Per `docs/counseling/phase10_1_realization_inventory.md`, today's
/// `TurnPlanMaterializer` both (a) decides *what this turn means* — how the
/// reflection connects to the next question, why an intervention starts now
/// — and (b) writes the final Korean sentence for it, in the same string.
/// This file gives (a) a home that is NOT a string: a small set of grounded
/// enums/values a realizer can turn into wording, instead of a wording
/// itself. See `phase10_2_failure_mapping.md` for how each Phase 10.1
/// failure category (R1-R12) maps onto fields here.
///
/// This class and everything in it is purely additive: it does not replace
/// `reflectionSentence`/`questionSentence`/`deterministicReply`, which stay
/// exactly as they are (`docs/counseling/phase10_realization_quality.md`'s
/// compatibility-path requirement). Nothing in this file changes what any
/// user sees.
enum TransitionIntent {
  /// No question follows this turn's reflection (e.g. `Closing`).
  none,

  /// CheckIn: move from acknowledging the check-in text to asking for a
  /// 0-10 severity rating.
  assessSeverity,

  /// Explore (default branch): move from reflection to asking for a
  /// concrete worrying moment within the situation.
  exploreMoment,

  /// Explore (`askedMoment` branch): move from reflection to asking the
  /// user to concretize one anticipated bad outcome.
  exploreAnticipatedOutcome,

  /// Explore (`isSudResponse` branch): move from acknowledging a bare
  /// severity-rating answer to asking what triggered that rating.
  exploreTrigger,

  /// Reflect, clarify branch: no usable thought was found yet — ask a more
  /// specific follow-up instead of a `ReflectQuestionGoal` question.
  clarify,

  /// Reflect, `ReflectQuestionGoal.evidence`.
  askForEvidence,

  /// Reflect, `ReflectQuestionGoal.alternative`.
  exploreAlternative,

  /// Reflect, `ReflectQuestionGoal.probability`.
  exploreProbability,

  /// Move from reflecting on the target thought/behavior into starting a
  /// CBT intervention exercise. See [InterventionRealizationSpec.rationale]
  /// for *why this intervention specifically*.
  bridgeToIntervention,

  /// Closing: move from the session summary into ending the turn (asks no
  /// question — `TurnConstraint.requireNoQuestion`).
  prepareClosing,
}

/// Phase 10.2: grounded semantic reasons a CBT intervention starts now,
/// one per `InterventionType` (see `intervention_registry.dart`). Deliberately
/// an enum, not free text — "why this intervention" must stay traceable to
/// the approved intervention taxonomy, not become a new place for an LLM or
/// a template author to invent an untethered justification.
enum InterventionRationale {
  /// `InterventionType.balancedThought` — the target thought itself is what
  /// gets examined and rebalanced.
  examineThought,

  /// `InterventionType.behaviorPatternReview` — the target behavior is
  /// checked for whether it avoids or faces the feared situation.
  reviewAvoidancePattern,

  /// `InterventionType.consequenceReview` — the target behavior's
  /// short-term relief is weighed against its longer-term helpfulness.
  compareShortLongTermConsequences,

  /// `InterventionType.gainLossReview` — the immediate gain from an
  /// avoidance behavior is weighed against its cost.
  exploreAmbivalence,

  /// `InterventionType.maintenanceReview` — a technique already found
  /// helpful gets a concrete plan to continue it.
  supportMaintenance;

  /// The one rationale each approved [InterventionType] maps to. Mirrors
  /// `TurnPlanMaterializer._goalFor`/`_reflectionFor`/`_questionFor`'s
  /// existing per-type switches — same taxonomy, semantic form instead of a
  /// drafted sentence.
  static InterventionRationale forType(InterventionType type) {
    switch (type) {
      case InterventionType.balancedThought:
        return InterventionRationale.examineThought;
      case InterventionType.behaviorPatternReview:
        return InterventionRationale.reviewAvoidancePattern;
      case InterventionType.consequenceReview:
        return InterventionRationale.compareShortLongTermConsequences;
      case InterventionType.gainLossReview:
        return InterventionRationale.exploreAmbivalence;
      case InterventionType.maintenanceReview:
        return InterventionRationale.supportMaintenance;
      case InterventionType.valueBasedChoice:
        throw StateError('아직 승인되지 않은 intervention type: $type');
    }
  }
}

/// Phase 10.2: why *this* intervention, connected to *what* the user said —
/// without pre-drafting the sentence that says so (that is R7 in
/// `phase10_1_failure_taxonomy.md`: today's `InterventionPlan` has no such
/// field at all).
class InterventionRealizationSpec {
  final String interventionId;
  final InterventionRationale rationale;

  /// The reflectionTarget this intervention connects back to, when one
  /// exists. Still raw text (unchanged from today), but now travels
  /// alongside an explicit [rationale] instead of only inside a finished
  /// sentence.
  final String? relevantTarget;

  const InterventionRealizationSpec({
    required this.interventionId,
    required this.rationale,
    this.relevantTarget,
  });
}

/// Phase 10.2: `Closing`'s two branches (`turn_plan_materializer.dart`'s
/// `closing` method), named semantically instead of only distinguished by a
/// null check inline in the sentence-building code.
enum ClosingIntent {
  /// A concrete topic was reflected on this session; summary should name it.
  summarizeWithTopic,

  /// No specific topic was found; summary is generic.
  summarizeGeneric,
}

/// Phase 10.2: the semantic realization contract for one turn. Produced by
/// `TurnPlanMaterializer` alongside (not instead of) its existing
/// `reflectionSentence`/`questionSentence` strings, from the same
/// [CounselorDecision] — see each materializer method's `realizationSpec`
/// construction. A future `ResponseRealizer` implementation can consume
/// this instead of (or in addition to) the legacy strings; today's
/// `DeterministicResponseRealizer` still only reads `deterministicDraft`
/// and ignores this entirely, by design — this phase changes no production
/// output.
class CounselingRealizationSpec {
  final ReflectionTarget? reflectionTarget;
  final TransitionIntent transitionIntent;

  /// Semantic goal of this turn's question — already existed as
  /// `CounselingTurnPlan.questionGoal` (never shown to the user); carried
  /// here too so a realizer has everything it needs in one place.
  final String questionGoal;

  final InterventionRealizationSpec? intervention;
  final ClosingIntent? closingIntent;

  /// Phase 10.5A.2 Track B: the 0-10 rating the user just gave, when this
  /// turn's target is a bare SUD-style numeric reply (`TransitionIntent
  /// .exploreTrigger`) — grounded, structured signal so a realizer can
  /// acknowledge the number naturally instead of skipping past it (a
  /// pattern found in Phase 10.5A's human review across all three
  /// realization paths tested). Null whenever this turn isn't that case.
  final int? sudRatingValue;

  const CounselingRealizationSpec({
    required this.reflectionTarget,
    required this.transitionIntent,
    required this.questionGoal,
    this.intervention,
    this.sudRatingValue,
    this.closingIntent,
  });
}
