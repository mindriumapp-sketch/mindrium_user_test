import 'counseling_models.dart';

/// 사용자 발화와 기록에서 상담에 쓸 조각을 뽑는 결정론적 도구.
///
/// planner 여러 곳에서 같은 규칙이 필요해 한곳에 모았다. LLM 을 쓰지 않는다.
///
/// 생각 판별기가 둘인 것은 의도적이다. 개입 단계는 대상 행동/생각을 넓게 잡아도
/// 되지만, 되짚기 단계는 상황 서술("답하지 못할까 봐 걱정")을 생각으로 승격시키면
/// 사용자가 하지 않은 평가를 상담자가 대신 만들어내게 된다.
/// Phase 13.8 (P2): what a user utterance may be used for as CBT content.
enum TargetEligibility {
  /// A thought about a feared outcome or oneself: may be a technique target.
  worryThought,

  /// A situation or feeling without a thought: context, not a thought target.
  situation,

  /// About the conversation itself (answered with a repair): never content.
  interaction,

  /// No content ("몰라", "응", "7"): never content.
  lowInformation,
}

class UserThoughtExtractor {
  const UserThoughtExtractor._();

  /// 생각의 형태만 갖추면 받아들인다. 개입 단계에서 쓴다.
  static String? thoughtShaped(String message) {
    final text = message.trim();
    if (text.isEmpty) return null;
    return _hasThoughtShape(text) ? text : null;
  }

  /// 자기/타인에 대한 평가까지 있어야 받아들인다. 되짚기 단계에서 쓴다.
  static String? evaluativeThought(String message) {
    final text = message.trim();
    if (text.isEmpty) return null;
    final hasEvaluation =
        text.contains('사람들이') ||
        text.contains('나는 ') ||
        text.contains('제가 ') ||
        text.contains('저를 ');
    return hasEvaluation && _hasThoughtShape(text) ? text : null;
  }

  // Phase 13.7 (D3): "것같아" is often typed without the space.
  static final RegExp _seemsLike = RegExp(r'것\s*같');

  static bool _hasThoughtShape(String text) =>
      _seemsLike.hasMatch(text) ||
      text.contains('것이다') ||
      text.contains('보일') ||
      text.contains('생각') ||
      _hasWorryThoughtForm(text);

  // Phase 12.3 (N3): common worry-thought forms that name a feared outcome
  // or a specific concern, seen in device dogfood. A plain feeling ("그냥
  // 걱정돼요") or a situation plus feeling ("발표가 내일이라 걱정돼") is not a
  // thought and still goes to clarify.
  //   - "~할까 봐 (걱정돼/불안해/신경 쓰여)": feared outcome. "해볼까 봐" is
  //     "I think I'll try", so it's excluded.
  //   - "~하면 어떡하지": catastrophic "what if".
  //   - "X가 (가장) 마음에 걸려 / 신경 쓰여": a named concern. Requires a
  //     subject directly before it, so "시험이 있어서 신경 쓰여" (reason +
  //     feeling) stays a situation.
  static final RegExp _fearedOutcome = RegExp(r'까\s*봐');
  static final RegExp _tryingIntent = RegExp(r'해\s*볼까\s*봐');
  static final RegExp _whatIf = RegExp(r'(면|하면)\s*(어떡하지|어떡해|어떡하나|어떻게\s*하지)');
  static final RegExp _namedConcern = RegExp(
    r'[가-힣](이|가)\s*(가장\s*|제일\s*|계속\s*|너무\s*|좀\s*)?'
    r'(마음에\s*걸|신경\s*쓰)',
  );

  static bool _hasWorryThoughtForm(String text) =>
      (_fearedOutcome.hasMatch(text) && !_tryingIntent.hasMatch(text)) ||
      _whatIf.hasMatch(text) ||
      _namedConcern.hasMatch(text);

  /// `상황: ... / 생각: ... / 감정: ...` 형태에서 한 항목을 꺼낸다.
  static String? fieldFromDiary(String? text, String label) {
    if (text == null) return null;
    // `[그룹명] 상황: ...` 처럼 접두사 뒤에 오는 경우도 잡는다.
    final match = RegExp(
      '(?:^|[/|\\]])\\s*$label\\s*:\\s*([^/|]+)',
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? thoughtFromDiary(String? text) => fieldFromDiary(text, '생각');

  static String? situationFromDiary(String? text) =>
      fieldFromDiary(text, '상황');

  static String? emotionFromDiary(String? text) => fieldFromDiary(text, '감정');

  static String? behaviorFromDiary(String? text) => fieldFromDiary(text, '행동');

  /// `[그룹명] ...` 접두사에서 걱정 그룹 이름을 꺼낸다.
  static String? groupFromItem(String? text) {
    if (text == null) return null;
    final match = RegExp(r'^\s*\[([^\]]+)\]').firstMatch(text);
    final group = match?.group(1)?.trim();
    return group == null || group.isEmpty ? null : group;
  }

  static UserContextItem? firstDiary(MindriumCounselingContext? context) {
    if (context == null) return null;
    for (final item in context.relevantItems) {
      if (item.type == UserContextType.diary) return item;
    }
    return null;
  }

  static EffectiveIntervention? firstEffective(
    MindriumCounselingContext? context,
  ) {
    if (context == null) return null;
    for (final intervention in context.effectiveInterventions) {
      if (intervention.improved) return intervention;
    }
    return null;
  }

  /// [messages] without the user messages the system answered with an
  /// interaction-repair turn. Those were about the conversation itself
  /// (repetition, "stop asking", "what's the point"), not the user's worry,
  /// so they must not become reflection/intervention/closing content. The
  /// history itself is not changed; only content selectors read this view.
  ///
  /// A turn is judged by the assistant message that closes it (the last
  /// assistant message before the next user message), so an instant-empathy
  /// bubble in between doesn't hide the repair metadata.
  static List<CounselingMessage> semanticContent(
    List<CounselingMessage> messages,
  ) {
    final result = <CounselingMessage>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.isUser && _answeredWithRepair(messages, i)) continue;
      result.add(message);
    }
    return result;
  }

  static bool _answeredWithRepair(List<CounselingMessage> messages, int i) {
    CounselingMessage? reply;
    for (var j = i + 1; j < messages.length && !messages[j].isUser; j++) {
      reply = messages[j];
    }
    return reply?.interactionRepairReason != null;
  }

  /// Phase 13.6 (Q2): the worry this reflect round was about — the user
  /// message the round's first reflective-goal question answered. A round
  /// starts at the session start or at the last closing continuation.
  /// Later answers (evidence, another view) are about that worry, not a new
  /// one, so they must not become an intervention's target. Null when no
  /// goal question has been asked. Pass [semanticContent] so repair turns
  /// are skipped.
  ///
  /// Phase 13.8 (P2): the message right before that question is not
  /// necessarily the worry — on device it was "너가 무슨말 하는지 모르겠어".
  /// The worry is the latest user utterance up to that question that is
  /// eligible as a worry thought ([targetEligibility]).
  ///
  /// When reflect ended without any goal question (clarify and repair turns
  /// used up its turns, as in dogfood session 4), the worry is the latest
  /// eligible utterance of the round.
  static String? roundWorryThought(List<CounselingMessage> messages) {
    final round = currentRound(messages);
    final firstGoal = round.indexWhere(
      (m) => !m.isUser && m.dialogueGoalId != null,
    );
    final end = firstGoal < 0 ? round.length : firstGoal;
    for (var j = end - 1; j >= 0; j--) {
      final candidate = round[j];
      if (!candidate.isUser) continue;
      final sentence = thoughtSentence(candidate.text.trim());
      if (targetEligibility(sentence) == TargetEligibility.worryThought) {
        return sentence;
      }
    }
    return null;
  }

  /// Phase 13.8 (P2): whether a user utterance carries no content to work
  /// with — a bare number, a filler, or "I don't know" in any register
  /// ("잘 모르겠어", "몰라요", "모르겠다니까"). Judged on the whole utterance:
  /// "모르겠어, 발표 망칠까 봐 걱정돼" has content.
  static bool isLowInformation(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s.!?,~]+'), '');
    if (compact.isEmpty) return true;
    if (RegExp(r'^(?:[0-9]|10)(?:점|정도)?(?:이에요|예요|입니다|요)?$').hasMatch(compact)) {
      return true;
    }
    return RegExp(
      r'^(네|넵|응|웅|어|음+|아니요?|맞아요?|(잘)?모르겠(어|어요|네|네요|다니까|다고|는데)|'
      r'(잘)?몰라(요)?|그냥(요)?|글쎄(요)?|딱히(요)?)$',
    ).hasMatch(compact);
  }

  /// Phase 13.8 (P2): what a user utterance can be used for as CBT content.
  /// The contract every content selector follows: only a worry thought may
  /// become a technique's target; interaction/meta and low-information
  /// utterances never may. [interaction] is known from the reply's repair
  /// metadata (see [semanticContent]), so an utterance judged alone is one
  /// of the other three.
  static TargetEligibility targetEligibility(String text) {
    if (isLowInformation(text)) return TargetEligibility.lowInformation;
    if (_hasThoughtShape(text.trim())) return TargetEligibility.worryThought;
    return TargetEligibility.situation;
  }

  /// Phase 13.7 (E3): the messages of the current conversation round — since
  /// the last closing continuation, or the whole history if there was none.
  /// A reopened round is about a new worry, so its reflective goals and
  /// content are counted afresh.
  static List<CounselingMessage> currentRound(List<CounselingMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isUser && messages[i].closingStep == ClosingStep.continued) {
        return messages.sublist(i + 1);
      }
    }
    return messages;
  }

  /// Phase 13.7 (E2): the sentence that carries the thought, when a message
  /// has several ("처음 해보는 발표라 떨려. 실수할까봐 걱정돼" → "실수할까봐
  /// 걱정돼"). The last thought-shaped sentence wins; a message with one
  /// sentence, or none thought-shaped, is returned whole.
  static String thoughtSentence(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.length < 2) return text;
    for (final sentence in sentences.reversed) {
      if (_hasThoughtShape(sentence)) {
        return sentence.replaceFirst(RegExp(r'[.!?]+$'), '');
      }
    }
    return text;
  }

  static String? latestUserMessage(List<CounselingMessage> messages) {
    for (final message in messages.reversed) {
      if (message.isUser && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return null;
  }
}
