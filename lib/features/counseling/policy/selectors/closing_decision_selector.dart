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
    r'(아니|아직|더\s*(이야기|얘기|말|하고|할래|하자|해요|할게)|계속|잠깐|벌써|끝내지|안\s*끝|좀\s*더|좀만\s*더|조금만?\s*더)',
  );
  /// The continue cues other than a bare "아니", which in "아니 싫어 그만해"
  /// is a refusal, not a wish to keep talking.
  static final RegExp _stronglyContinues = RegExp(
    r'(아직|더\s*(이야기|얘기|말|하고|할래|하자|해요|할게)|계속|잠깐|벌써|끝내지|안\s*끝|좀\s*더|좀만\s*더|조금만?\s*더)',
  );
  /// Phase 14.X: the user asks to end now, without a pending proposal
  /// ("오늘은 여기까지", "그만할게", "더 안 해 끝", "정리하자"), unless a strong
  /// continue cue is also there. Evidence the LLM-led path may finalize on.
  // Phase 4: "그만큼", "이만큼", "여기까지 오는 데" are not end requests;
  // these words count only with a verb of stopping or at the end.
  static final RegExp _endRequest = RegExp(
    r'(여기까지\s*(할|하|만|요|$|[.!~]|정리|마무리)|이만\s*(할|하|마|줄|끝|$)|이쯤\s*(할|하|에서|마|끝|정리|$)|'
    r'그만\s*(할래|할게|하자|할까|하겠|할\s*거|둘게|두자|둘래)|(^|\s)끝(\s|$|[.!~]|이야|낼|내자)|종료|'
    r'정리\s*(하자|할게|하죠|할래|해요|하겠|할까|해\s*주)|마무리\s*(하자|할게|하죠|할래|해요|해도|하겠|할까|해\s*주)|마칠게|마칠래|마칠까)',
  );

  // "그만해", "그만 물어봐" ask to stop the questions (a repair), not to end.
  static final RegExp _aboutQuestions = RegExp(r'(물어|묻|질문)');

  static bool isExplicitEnd(String text) {
    final t = text.trim();
    return _endRequest.hasMatch(t) && !_stronglyContinues.hasMatch(t) && !_aboutQuestions.hasMatch(t);
  }

  /// Phase 4: a short message that only asks to end ("종료", "오늘은 이쯤
  /// 할게요", "네 이제 정리해 주셔도 돼요"). The deterministic path ends the
  /// session on it from any stage; a long message with an end cue may carry
  /// new content and goes through the normal flow.
  static bool isEndOnly(String text) => isExplicitEnd(text) && text.trim().length <= 30;

  static final RegExp _agrees = RegExp(
    r'^(네|넵|응|웅|어|그래|좋아|괜찮|알겠|고마워|고맙|감사|그만|마칠|마무리|여기까지|됐어|끝낼|끝내요|그렇게)',
  );

  /// Phase 13.7 (D2): taking up the proposal's own words ("정리해보자",
  /// "여기까지 할게") anywhere in the reply, not only at its start.
  static final RegExp _wrapsUp = RegExp(
    r'(정리|마무리|여기까지|그만\s*(할|하|두|해)|마칠|끝내|끝낼)',
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
      continuationDeclined: _continuationDeclined(userMessage, recentMessages),
    );
  }

  /// Phase 13.5: the closing handshake. After a proposal, the user either
  /// agrees (finalize) or wants to keep talking (one continuation per
  /// session). A substantive new message counts as wanting to continue. With
  /// no pending proposal (e.g. the session-length cap), or once the
  /// continuation is used, the session is finalized.
  // Phase 13.10: wants more ("더", "예시로 설명해주면") at a proposal after
  // the one continuation was used.
  static final RegExp _asksForMore = RegExp(r'(설명해|예시|알려\s*줘|도와\s*줘|도움이\s*될)');

  bool _continuationDeclined(String userMessage, List<CounselingMessage> recentMessages) {
    final previous = recentMessages.reversed.where((m) => !m.isUser).firstOrNull;
    if (previous?.closingStep != ClosingStep.proposed) return false;
    final used = recentMessages.any((m) => !m.isUser && m.closingStep == ClosingStep.continued);
    final text = userMessage.trim();
    return used && (_wantsToContinue.hasMatch(text) || _asksForMore.hasMatch(text));
  }

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
    // Phase 14.3: refusal takes precedence over continuing. An explicit
    // wrap-up ("그만해", "끝낼래") finalizes unless a strong continue cue is
    // also there ("아직 끝내지 말자", "좀 더 하고 그만할래").
    if (_wrapsUp.hasMatch(text) && !_stronglyContinues.hasMatch(text)) {
      return ClosingStep.finalized;
    }
    if (isExplicitEnd(text)) return ClosingStep.finalized;
    if (_wantsToContinue.hasMatch(text)) return ClosingStep.continued;
    // Phase 13.8 (P4): "몰라" to "정리할까요, 더 이야기할까요?" is not a wish
    // to keep talking; reopening would ask the same kind of question again.
    // An explicit "아니" was already read as continue above.
    if (_agrees.hasMatch(text) ||
        _wrapsUp.hasMatch(text) ||
        UserThoughtExtractor.isLowInformation(text) ||
        _closingOnly.hasMatch(text) ||
        text.isEmpty) {
      return ClosingStep.finalized;
    }
    // Phase 4: at a proposal only new content reopens the talk; anything
    // else ("ㅇㅇ", "그럴게요", "종료요") is taken as agreeing to wrap up.
    return UserThoughtExtractor.isContentfulContribution(text)
        ? ClosingStep.continued
        : ClosingStep.finalized;
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
