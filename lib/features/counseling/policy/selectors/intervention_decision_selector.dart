import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/episode_history.dart';
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
    // Phase 13.3: the technique's question was just asked, so this turn
    // integrates the user's answer instead of starting anything new.
    final pending = InterventionProgressTracker.pendingPromptTechniqueId(
      recentMessages,
    );
    if (pending != null && knowledge.any((item) => item.id == pending)) {
      final answer = userMessage.trim();
      return CounselorDecision(
        selectedAction: DialogueAct.reflect,
        selectedInterventionId: pending,
        reflectionTarget: ReflectionTarget.text(answer.isEmpty ? '…' : answer),
      );
    }

    final effectiveIntervention = UserThoughtExtractor.firstEffective(
      userContext,
    );
    final candidate = InterventionCandidateResolver.resolve(
      currentWeek: currentWeek,
      userMessage: userMessage,
      recentMessages: recentMessages,
      knowledge: knowledge,
      hasEffectiveIntervention: effectiveIntervention != null,
      registry: registry,
      episodes: userContext?.episodes ?? EpisodeHistory.empty,
    );
    if (candidate == null) {
      // Phase 13.2: nothing approved fits. A normal outcome — briefly
      // summarize and move on — never `unknown`, which StatePolicy would
      // not count as progress (N1 deadlock).
      final summaryTarget =
          UserThoughtExtractor.latestUserMessage(
            UserThoughtExtractor.semanticContent(recentMessages),
          ) ??
          userMessage.trim();
      return CounselorDecision(
        selectedAction: DialogueAct.summarize,
        reflectionTarget:
            summaryTarget.isEmpty
                ? const ReflectionTarget.none()
                : ReflectionTarget.text(summaryTarget),
      );
    }
    final policy = candidate.policy;
    final selected = candidate.item;

    // Phase 13.6 (Q2): this turn's message is usually the answer to reflect's
    // last question (evidence, another view), not the worry itself. The
    // technique is about the worry the reflect round started from.
    final roundWorry = UserThoughtExtractor.roundWorryThought(
      UserThoughtExtractor.semanticContent(recentMessages),
    );
    final behaviorType =
        policy.interventionType == InterventionType.behaviorPatternReview ||
        policy.interventionType == InterventionType.consequenceReview ||
        policy.interventionType == InterventionType.gainLossReview;
    final explicitThought =
        behaviorType
            // A behavior technique examines a behavior the user described;
            // otherwise it asks about behavior around the worry (the
            // materializer words the question by the target's shape).
            ? (InterventionEligibilityPredicates.looksLikeBehavior(userMessage) &&
                    UserThoughtExtractor.hasContent(userMessage)
                ? userMessage.trim()
                : roundWorry ??
                    UserThoughtExtractor.latestContentMessage(
                      UserThoughtExtractor.semanticContent(recentMessages),
                    ) ??
                    userMessage.trim())
            : policy.interventionType == InterventionType.balancedThought
            ? roundWorry ?? UserThoughtExtractor.thoughtShaped(userMessage)
            : policy.interventionType == InterventionType.maintenanceReview
            ? (InterventionEligibilityPredicates.looksLikeMaintenance(
                userMessage,
              )
                ? userMessage.trim()
                : null)
            : UserThoughtExtractor.thoughtShaped(userMessage);
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
        // Phase 13.9C (S1): never a non-answer or a question to the counselor.
        UserThoughtExtractor.latestContentMessage(
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

    // Personalization: a similar worry handled before, with the user's own
    // alternative thought — recalled for the balanced-thought question.
    final recalled =
        policy.interventionType == InterventionType.balancedThought
            ? userContext?.episodes.similarEpisodeWithAlternative(target)
            : null;

    return CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      selectedInterventionId: selected.id,
      reflectionTarget: ReflectionTarget.text(target),
      usedFactIds: usedFactIds,
      recalledAlternative: recalled?.alternativeThought?.trim(),
      recalledEpisodeId: recalled?.sessionId,
    );
  }
}
