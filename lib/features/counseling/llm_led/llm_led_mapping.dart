part of 'llm_led_contract.dart';

/// Maps an accepted answer onto the existing turn metadata, so persistence,
/// episodic memory and a later deterministic fallback keep working.
class LlmLedMapping {
  final CounselingState nextState;
  final DialogueAct act;
  final String? goalId;
  final bool isClarify;
  final InterventionStep? interventionStep;
  final List<String> cbtIds;
  final bool? credited;
  final ClosingStep? closingStep;

  const LlmLedMapping({
    required this.nextState,
    required this.act,
    required this.goalId,
    required this.isClarify,
    required this.interventionStep,
    required this.cbtIds,
    required this.credited,
    required this.closingStep,
  });

  static LlmLedMapping of(
    LlmLedOutput o,
    LlmLedContext c,
    CounselingState current,
    String userMessage,
  ) {
    final m = o.moves.toSet();
    final goal =
        m.contains('ask_evidence')
            ? 'evidence'
            : m.contains('ask_alternative')
            ? 'alternative'
            : m.contains('ask_probability')
            ? 'probability'
            : null;
    final step = switch (o.interventionStep) {
      'prompt' => InterventionStep.prompt,
      'integration' => InterventionStep.integration,
      _ => null,
    };
    final cbtId =
        o.interventionId ??
        (step == InterventionStep.integration ? c.pendingInterventionId : null);
    bool? credited;
    if (step == InterventionStep.integration && cbtId != null) {
      final type = c.techniqueTypes[cbtId];
      credited =
          UserThoughtExtractor.isTechniqueAnswer(userMessage) &&
          (type == null ||
              UserThoughtExtractor.showsTechniqueMove(userMessage, type));
    }
    final closing =
        o.sessionAction == 'finalize'
            ? ClosingStep.finalized
            : o.sessionAction == 'offer_close'
            ? ClosingStep.proposed
            : (c.closingProposed ? ClosingStep.continued : null);

    final CounselingState next;
    if (closing == ClosingStep.finalized || closing == ClosingStep.proposed) {
      next = CounselingState.closing;
    } else if (closing == ClosingStep.continued) {
      next = CounselingState.reflect;
    } else if (step != null) {
      next = CounselingState.intervention;
    } else if (goal != null &&
        (current == CounselingState.checkIn ||
            current == CounselingState.explore)) {
      next = CounselingState.reflect;
    } else if (current == CounselingState.checkIn) {
      next = CounselingState.explore;
    } else if (current == CounselingState.closing) {
      next = CounselingState.reflect;
    } else {
      next = current;
    }

    final act =
        closing == ClosingStep.finalized
            ? DialogueAct.closing
            : (step == InterventionStep.prompt || goal != null)
            ? DialogueAct.socraticQuestion
            : (m.contains('clarify') || m.contains('open_question'))
            ? DialogueAct.explore
            : m.contains('summarize')
            ? DialogueAct.summarize
            : DialogueAct.reflect;

    return LlmLedMapping(
      nextState: next,
      act: act,
      goalId: goal,
      isClarify: m.contains('clarify'),
      interventionStep: step,
      cbtIds: cbtId == null ? const [] : [cbtId],
      credited: credited,
      closingStep: closing,
    );
  }
}
