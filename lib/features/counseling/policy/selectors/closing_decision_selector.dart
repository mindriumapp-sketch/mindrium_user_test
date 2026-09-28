import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../counselor_decision.dart';

/// Phase 8.3B: the actual deterministic *selection* made by
/// `DeterministicClosingTurnPlanner.plan` — copied verbatim (not
/// reinterpreted) from `turn_plan.dart`.
///
/// What is selected: whether there is a substantial message to summarize
/// (the current message, or else the most recent substantial user message),
/// and if so, which one. The final "오늘은 ... 나눴습니다" sentence stays
/// surface realization inside `DeterministicClosingTurnPlanner`.
class ClosingDecisionSelector {
  const ClosingDecisionSelector();

  static final RegExp _closingOnly = RegExp(
    r'^(고마워요|감사해요|감사합니다|네|알겠어요|그만할게요|마칠게요)[.!\s]*$',
  );

  /// Mirrors `DeterministicClosingTurnPlanner._summaryTarget`. Closing
  /// always produces a plan (empty `reflectionTarget` when no summary
  /// target is found), so this never returns `isUnavailable: true`.
  CounselorDecision select({
    required String userMessage,
    required List<CounselingMessage> recentMessages,
  }) {
    final target = _summaryTarget(userMessage, recentMessages);
    return CounselorDecision(
      selectedAction: DialogueAct.closing,
      reflectionTarget:
          target != null
              ? ReflectionTarget.text(target)
              : const ReflectionTarget.none(),
    );
  }

  String? _summaryTarget(
    String userMessage,
    List<CounselingMessage> recentMessages,
  ) {
    final current = userMessage.trim();
    if (current.isNotEmpty && !_closingOnly.hasMatch(current)) return current;
    for (final message in recentMessages.reversed) {
      final text = message.text.trim();
      if (message.isUser && text.isNotEmpty && !_closingOnly.hasMatch(text)) {
        return text;
      }
    }
    return null;
  }
}
