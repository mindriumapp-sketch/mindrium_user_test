// Phase 11.1: additive-only semantic contracts for the Selection Policy &
// Interaction Repair phase. See
// docs/counseling/phase11_1_selection_interaction_repair_design.md for the
// full problem grounding (exact code locations, exact regex coverage
// gaps, exact `GoalExhaustionPolicy.repeatLast` location) this was
// designed against.
//
// Nothing in lib/ or test/ constructs these yet. They exist so 11.2/11.3
// have a frozen vocabulary to implement against, not to change any
// behavior in this commit.

/// Names *why* a turn is being redirected into interaction-repair mode,
/// instead of continuing ordinary worry-content selection.
///
/// Grounded in `DeterministicProcessSignalTurnPlanner`
/// (`lib/features/counseling/turn_plan.dart`), which already detects
/// [stopQuestioning] and [processFrustration] today via its
/// `_requestsEmpathy`/`_showsProcessResistance` regexes — this enum names
/// both the already-handled cases and the confirmed gap ([repeatedQuestion])
/// uniformly, ahead of Phase 11.2 restructuring the detection code itself.
enum InteractionRepairReason {
  /// "왜 똑같은 말을 반복하지?" / "아까도 물어봤잖아" — the complaint is
  /// specifically that the same thing keeps being asked. Distinct from
  /// [stopQuestioning]: the user isn't asking to stop, they're pointing
  /// out non-progress. **Not detected today** — confirmed gap, see design
  /// doc P2.
  repeatedQuestion,

  /// "질문 그만해" / "그만 물어" / "그냥 얘기 좀 들어주세요". **Already
  /// detected today** via `_requestsEmpathy`.
  stopQuestioning,

  /// "뭐가 달라질까" / "소용 없어" / "의미 없어". **Already detected
  /// today** via `_showsProcessResistance`.
  processFrustration,
}

/// Names the recovery actions available once every `ReflectQuestionGoal`
/// has been asked (`ReflectDecisionSelector._selectGoal`'s exhaustion
/// case, `lib/features/counseling/policy/selectors/reflect_decision_selector.dart`).
///
/// [repeatLast] is today's only behavior and stays the explicit final
/// fallback — not deleted — so a future recovery selector that can't
/// confidently choose one of the other options still has a defined exit.
enum GoalExhaustionRecovery {
  /// Hand off to a closing-style summary of what's been covered, without
  /// asking anything new.
  summarize,

  /// The process-signal-style "no question this turn" response shape —
  /// already exists as a turn shape in
  /// `DeterministicProcessSignalTurnPlanner`, just never chosen by goal
  /// exhaustion itself today.
  listenWithoutQuestion,

  /// Pull a different topic into `reflectionTarget` instead of the
  /// exhausted one. **Design note**: needs a same-session "other topics
  /// raised earlier this session" tracker that does not fully exist yet
  /// — `CounselingProvider._carriedUnfinishedIssue` only carries a topic
  /// *across* sessions today. See design doc P1 before implementing this
  /// in Phase 11.3.
  revisitPreviousIssue,

  /// End reflect early and move to intervention/closing, via the
  /// existing `CounselingStatePolicy` acceleration mechanism.
  transition,

  /// Today's only behavior (`return goalOrder.last`). Kept as the
  /// explicit last-resort member of this enum, not removed.
  repeatLast,
}
