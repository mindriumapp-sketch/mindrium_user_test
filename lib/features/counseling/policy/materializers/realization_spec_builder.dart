import '../../turn_plan.dart';
import '../counselor_decision.dart';

/// Phase 10.2: pure, side-effect-free construction of a
/// [CounselingRealizationSpec] per state — kept separate from
/// `TurnPlanMaterializer`'s existing sentence-building methods so the two
/// concerns (legacy strings vs. the new semantic contract) are visibly
/// distinct in source, not interleaved inside the same method bodies. Every
/// function here reads only already-selected fields off a
/// [CounselorDecision] (or, for intervention, an already-resolved
/// [InterventionType]) — none of them make a new selection.
class RealizationSpecBuilder {
  const RealizationSpecBuilder._();

  static CounselingRealizationSpec checkIn(CounselorDecision decision) {
    return CounselingRealizationSpec(
      reflectionTarget: decision.reflectionTarget,
      transitionIntent: TransitionIntent.assessSeverity,
      questionGoal: '현재 사용자가 느끼는 불안의 주관적 정도를 0에서 10 사이로 확인한다.',
    );
  }

  static CounselingRealizationSpec explore({
    required CounselorDecision decision,
    required bool askedMoment,
    required bool isSudResponse,
    required String questionGoal,
    int? sudRatingValue,
  }) {
    final transition =
        askedMoment
            ? TransitionIntent.exploreAnticipatedOutcome
            : isSudResponse
            ? TransitionIntent.exploreTrigger
            : TransitionIntent.exploreMoment;
    return CounselingRealizationSpec(
      reflectionTarget: decision.reflectionTarget,
      transitionIntent: transition,
      questionGoal: questionGoal,
      sudRatingValue: sudRatingValue,
    );
  }

  static CounselingRealizationSpec reflectClarify(
    CounselorDecision decision,
  ) {
    return CounselingRealizationSpec(
      reflectionTarget: decision.reflectionTarget,
      transitionIntent: TransitionIntent.clarify,
      questionGoal: '아직 명확한 생각을 확인하지 못했으니 조금 더 구체적으로 묻는다.',
    );
  }

  static CounselingRealizationSpec reflect({
    required CounselorDecision decision,
    required ReflectQuestionGoal goal,
  }) {
    final transition = switch (goal) {
      ReflectQuestionGoal.evidence => TransitionIntent.askForEvidence,
      ReflectQuestionGoal.alternative => TransitionIntent.exploreAlternative,
      ReflectQuestionGoal.probability => TransitionIntent.exploreProbability,
    };
    return CounselingRealizationSpec(
      reflectionTarget: decision.reflectionTarget,
      transitionIntent: transition,
      questionGoal: goal.goal,
    );
  }

  static CounselingRealizationSpec intervention({
    required CounselorDecision decision,
    required InterventionType type,
    required String questionGoal,
    required String target,
  }) {
    return CounselingRealizationSpec(
      reflectionTarget: decision.reflectionTarget,
      transitionIntent: TransitionIntent.bridgeToIntervention,
      questionGoal: questionGoal,
      intervention: InterventionRealizationSpec(
        interventionId: decision.selectedInterventionId!,
        rationale: InterventionRationale.forType(type),
        relevantTarget: target,
      ),
    );
  }

  static CounselingRealizationSpec interventionUnavailable(String target) {
    return CounselingRealizationSpec(
      reflectionTarget: ReflectionTarget.text(target),
      transitionIntent: TransitionIntent.none,
      questionGoal: '승인된 CBT 근거가 준비될 때까지 현재 내용을 더 확인한다.',
    );
  }

  static CounselingRealizationSpec closing({
    required CounselorDecision decision,
    required String? target,
  }) {
    return CounselingRealizationSpec(
      reflectionTarget: decision.reflectionTarget,
      transitionIntent: TransitionIntent.prepareClosing,
      questionGoal: '새로운 내용을 추가하지 않고 현재 대화를 마무리한다.',
      closingIntent:
          target == null
              ? ClosingIntent.summarizeGeneric
              : ClosingIntent.summarizeWithTopic,
    );
  }
}
