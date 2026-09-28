import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';

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
  // Phase 13.5: answers to the closing proposal.
  static final RegExp _wantsToContinue = RegExp(
    r'(아니|아직|더\s*(이야기|얘기|말|하고|할래)|계속|잠깐|벌써|끝내지|안\s*끝|좀\s*더)',
  );
  static final RegExp _agrees = RegExp(
    r'^(네|넵|응|웅|어|그래|좋아|괜찮|알겠|고마워|고맙|감사|그만|마칠|마무리|여기까지|됐어|끝낼|끝내요|그렇게)',
  );

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
      closingStep: _closingStep(userMessage, recentMessages),
    );
  }

  /// Phase 13.5: the closing handshake. After a proposal, the user either
  /// agrees (finalize) or wants to keep talking (one continuation per
  /// session). A substantive new message counts as wanting to continue. With
  /// no pending proposal (e.g. the session-length cap), or once the
  /// continuation is used, the session is finalized.
  ClosingStep _closingStep(
    String userMessage,
    List<CounselingMessage> recentMessages,
  ) {
    ClosingStep? previous;
    for (final message in recentMessages.reversed) {
      if (!message.isUser) {
        previous = message.closingStep;
        break;
      }
    }
    if (previous != ClosingStep.proposed) return ClosingStep.finalized;
    final continuationUsed = recentMessages.any(
      (m) => !m.isUser && m.closingStep == ClosingStep.continued,
    );
    if (continuationUsed) return ClosingStep.finalized;

    final text = userMessage.trim();
    if (_wantsToContinue.hasMatch(text)) return ClosingStep.continued;
    if (_agrees.hasMatch(text) || _closingOnly.hasMatch(text) || text.isEmpty) {
      return ClosingStep.finalized;
    }
    return ClosingStep.continued;
  }

  String? _summaryTarget(
    String userMessage,
    List<CounselingMessage> recentMessages,
  ) {
    final current = userMessage.trim();
    if (current.isNotEmpty && !_closingOnly.hasMatch(current)) return current;
    final content = UserThoughtExtractor.semanticContent(recentMessages);
    for (final message in content.reversed) {
      final text = message.text.trim();
      if (message.isUser && text.isNotEmpty && !_closingOnly.hasMatch(text)) {
        return text;
      }
    }
    return null;
  }
}
