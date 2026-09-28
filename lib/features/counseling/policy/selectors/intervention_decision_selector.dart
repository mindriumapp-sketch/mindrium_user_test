import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';

import '../../intervention_registry.dart';
import '../counselor_decision.dart';
import '../intervention_eligibility_predicates.dart';

/// Phase 8.3B: the actual deterministic *selection* made by
/// `DeterministicInterventionTurnPlanner.plan` — copied verbatim (not
/// reinterpreted) from `turn_plan.dart`. Reuses
/// [InterventionEligibilityPredicates] rather than re-copying its
/// conditions (Phase 8.3 already made that the single source of truth).
///
/// What is selected: the week-approved intervention policy, the first
/// matching knowledge item (`selectedInterventionId`), and the reflection
/// target (explicit thought / effective-intervention label / diary thought /
/// latest user message / raw message, per type). Question/reflection
/// sentence text and [ActivityRecommendation] construction stay surface
/// realization inside `DeterministicInterventionTurnPlanner`.
///
/// Encoding note (see [ReflectionTarget]): this state has two distinct
/// "nothing to do" outcomes in legacy — (a) return a full unavailable-plan
/// (`_unavailablePlan`) when policy/knowledge/type eligibility fails, vs.
/// (b) return bare `null` (no plan at all) when a target was computable in
/// principle but ended up empty. This selector distinguishes them via
/// [ReflectionTarget]:
///   - (a): `isUnavailable: true`, `reflectionTarget: null` (no
///     [ReflectionTarget] at all — the turn itself is impossible)
///   - (b): `isUnavailable: true`, `reflectionTarget:
///     ReflectionTarget.none()` (a real target search happened, found
///     nothing)
/// Callers must switch on `reflectionTarget` (`null` vs [ReflectionTargetNone])
/// to reproduce legacy's two different fallbacks.
class InterventionDecisionSelector {
  const InterventionDecisionSelector();

  CounselorDecision select({
    required int currentWeek,
    required String userMessage,
    required List<CounselingMessage> recentMessages,
    required List<CbtKnowledgeItem> knowledge,
    required MindriumCounselingContext? userContext,
    required ApprovedInterventionRegistry registry,
  }) {
    final policy = registry.policyForWeek(currentWeek);
    if (policy == null ||
        InterventionEligibilityPredicates.alreadyUsed(recentMessages, policy)) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }

    CbtKnowledgeItem? selected;
    for (final item in knowledge) {
      if (policy.accepts(item)) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }
    if (policy.interventionType == InterventionType.gainLossReview &&
        !InterventionEligibilityPredicates.looksLikeAvoidance(userMessage)) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }

    final effectiveIntervention = UserThoughtExtractor.firstEffective(
      userContext,
    );
    final explicitThought =
        policy.interventionType == InterventionType.behaviorPatternReview ||
                policy.interventionType == InterventionType.consequenceReview ||
                policy.interventionType == InterventionType.gainLossReview
            ? userMessage.trim()
            : policy.interventionType == InterventionType.maintenanceReview
            ? (InterventionEligibilityPredicates.looksLikeMaintenance(
                userMessage,
              )
                ? userMessage.trim()
                : null)
            : UserThoughtExtractor.thoughtShaped(userMessage);
    if (policy.interventionType == InterventionType.maintenanceReview &&
        explicitThought == null &&
        effectiveIntervention == null) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }

    final diary = UserThoughtExtractor.firstDiary(userContext);
    final diaryThought =
        policy.interventionType == InterventionType.behaviorPatternReview ||
                policy.interventionType == InterventionType.consequenceReview ||
                policy.interventionType == InterventionType.gainLossReview ||
                policy.interventionType == InterventionType.maintenanceReview
            ? null
            : UserThoughtExtractor.thoughtFromDiary(diary?.text);
    final target =
        explicitThought ??
        (policy.interventionType == InterventionType.maintenanceReview
            ? effectiveIntervention?.label
            : null) ??
        diaryThought ??
        UserThoughtExtractor.latestUserMessage(
          UserThoughtExtractor.semanticContent(recentMessages),
        ) ??
        userMessage.trim();

    if (target.isEmpty) {
      // Legacy returns bare `null` here (no plan at all), distinct from the
      // unavailable-plan branches above.
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
        reflectionTarget: ReflectionTarget.none(),
      );
    }

    final usedFactIds =
        policy.interventionType == InterventionType.maintenanceReview &&
                explicitThought == null &&
                effectiveIntervention != null
            ? [effectiveIntervention.id]
            : explicitThought == null && diaryThought != null
            ? [diary!.id]
            : const <String>[];

    return CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      selectedInterventionId: selected.id,
      reflectionTarget: ReflectionTarget.text(target),
      usedFactIds: usedFactIds,
    );
  }
}
