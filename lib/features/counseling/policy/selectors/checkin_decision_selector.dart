import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../counselor_decision.dart';

/// Phase 8.3B: the actual deterministic *selection* made by
/// `DeterministicCheckInTurnPlanner.plan` — copied verbatim (not
/// reinterpreted) from `turn_plan.dart`.
///
/// CheckIn's selection is intentionally trivial: the reflection target is
/// just the trimmed current message (there is no target-priority search),
/// and the SUD question is a fixed sentence chosen entirely by surface
/// realization, not by selection. This class exists mainly so CheckIn
/// follows the same `Context -> CounselorDecision` shape as every other
/// state, and so both the legacy planner and [DeterministicCounselorAgent]
/// share one source of truth for "is there anything to reflect on".
class CheckInDecisionSelector {
  const CheckInDecisionSelector();

  /// Mirrors `DeterministicCheckInTurnPlanner.plan`'s guard + target
  /// selection. Returns `isUnavailable: true` when there is nothing to
  /// check in on (empty message) — callers should treat that the same way
  /// the legacy planner treats returning `null` (no plan for this turn).
  CounselorDecision select({required String userMessage}) {
    final target = userMessage.trim();
    if (target.isEmpty) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }
    return CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text(target),
    );
  }
}
