import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';

import '../counselor_decision.dart';

/// Phase 8.3B: the actual deterministic *selection* made by
/// `DeterministicExploreTurnPlanner.plan` — copied verbatim (not
/// reinterpreted) from `turn_plan.dart`.
///
/// What is actually *selected* in Explore: whether the current message is a
/// bare SUD-scale answer (in which case the target reverts to the previous
/// substantive concern instead of the number itself), and — if so — which
/// prior message that is. Question-sentence wording (rotation, "발표"
/// detection, "그 순간" follow-up phrasing) stays surface realization inside
/// `DeterministicExploreTurnPlanner`, since it doesn't change what target is
/// selected.
class ExploreDecisionSelector {
  const ExploreDecisionSelector();

  /// Mirrors `DeterministicExploreTurnPlanner.plan`'s guard + target
  /// selection. Returns `isUnavailable: true` for an empty message —
  /// callers should treat that like the legacy planner returning `null`.
  CounselorDecision select({
    required String userMessage,
    required List<CounselingMessage> recentMessages,
  }) {
    final current = userMessage.trim();
    if (current.isEmpty) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }

    final isSudResponse = _isSudResponse(current);
    final target =
        isSudResponse
            ? (_previousConcern(
                    UserThoughtExtractor.semanticContent(recentMessages),
                  ) ??
                  current)
            : current;

    return CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text(target),
    );
  }

  bool _isSudResponse(String value) {
    return RegExp(
      r'^(?:[0-9]|10)\s*(?:점|정도)?\s*(?:이에요|예요|입니다|요)?[.!]?$',
    ).hasMatch(value.trim());
  }

  String? _previousConcern(List<CounselingMessage> messages) {
    var skippedCurrentSud = false;
    for (final message in messages.reversed) {
      if (!message.isUser) continue;
      final text = message.text.trim();
      if (text.isEmpty) continue;
      if (!skippedCurrentSud && _isSudResponse(text)) {
        skippedCurrentSud = true;
        continue;
      }
      if (!_isSudResponse(text)) return text;
    }
    return null;
  }
}
