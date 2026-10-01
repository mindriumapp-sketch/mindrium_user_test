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

  // Phase 13.9C: "생각" alone is not a thought — "별로 생각나는 게 없어요"
  // says there is none. It counts when it names one ("…라는 생각",
  // "생각이 들어", "생각뿐", "…하는 생각").
  static final RegExp _namesAThought = RegExp(
    r'(라는|하는|다는|는)\s*생각|생각(이|만)?\s*(들|뿐|자꾸|계속)',
  );

  static bool _hasThoughtShape(String text) =>
      _seemsLike.hasMatch(text) ||
      text.contains('것이다') ||
      text.contains('보일') ||
      _namesAThought.hasMatch(text) ||
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

  // Phase 13.10: doubt-form worries — "…건 아닐까 걱정돼", "몸이 안좋은걸까",
  // "떨어지는 건 아닌가 싶어". The doubt is about a state or outcome (건/게/걸),
  // so "점심 뭐 먹을까" stays a plain question.
  static final RegExp _doubtWorry = RegExp(
    r'(건|게|걸|것)\s*(아닐까|아닌가|아닐지|일까|인가)|'
    r'(안\s*좋은|나쁜|잘못된|문제가\s*생긴|문제\s*있는)\s*(건|게|걸|것)\S*\s*(까|가|지)|'
    r'(아닐까|아닌가)\s*(걱정|무서|불안|싶|두려)',
  );

  static bool _hasWorryThoughtForm(String text) =>
      _doubtWorry.hasMatch(text) ||
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
    if (RegExp(r'^(?:[0-9]|10)(?:점|정도)?(?:이에요|예요|입니다|이요|요)?$').hasMatch(compact)) {
      return true;
    }
    if (RegExp(
      r'^(네|넵|응|웅|어|음+|아니요?|맞아요?|(잘)?모르겠(어|어요|네|네요|다니까|다고|는데)|'
      r'(잘)?몰라(요)?|그냥(요)?|글쎄(요)?|딱히(요)?)$',
    ).hasMatch(compact)) {
      return true;
    }
    // Phase 13.9D: consonant-only chat shorthand of 1–3 letters ("ㅇㅇ",
    // "ㄴㄴ", "ㅁㄹ") carries no content either.
    if (RegExp(r'^[ㄱ-ㅎ]{1,3}$').hasMatch(compact)) return true;
    return _onlyNothingTokens(value);
  }

  // Phase 13.9C: a non-answer judged token by token. Every token is either
  // filler ("음", "그냥", "별로", "아무", "생각도") or a nothing/assent
  // predicate ("모르겠네요", "없는데", "안 나", "그래", "ㅇㅇ"), and at least
  // one is a predicate. Any other word — a topic, a person, a feeling — is
  // content, so "시험이 없어서 다행이에요" is not a non-answer.
  static final Set<String> _fillerTokens = {
    '음', '흠', '어', '아', '엥', '음음', '그냥', '별로', '딱히', '잘', '진짜', '정말', '좀',
    '뭐', '아무', '아무것도', '아무거나', '생각', '생각도', '생각이', '생각은', '생각나는', '떠오르는',
    '딱', '특별히', '게', '건', '것도', '거', '것', '안', '못', '그런', '거는', '것은', '이',
  };
  static final RegExp _nothingPredicate = RegExp(
    r'^(모르겠\S*|몰라\S*|모름|몰루|없\S*|나|나요|나네|나네요|떠올라\S*|떠오르지|떠오르는게|'
    r'생각나\S*|그래|그래요|그렇\S*|글쎄\S*|ㅇㅇ+|ㅇㅋ|ㅇ|응+|웅|네|넵|예|아니\S*|아뇨|노|'
    r'그냥|그냥요|별로|별로요|딱히|딱히요|[ㄱ-ㅎ]{1,3})$',
  );

  static bool _onlyNothingTokens(String value) {
    final tokens = value
        .replaceAll(RegExp(r'[.!?,~…ㅠㅜ]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty || tokens.length > 6) return false;
    var predicate = false;
    for (final raw in tokens) {
      final t = raw.endsWith('요') && raw.length > 1 && _fillerTokens.contains(raw.substring(0, raw.length - 1))
          ? raw.substring(0, raw.length - 1)
          : raw;
      if (_nothingPredicate.hasMatch(t)) {
        predicate = true;
      } else if (!_fillerTokens.contains(t)) {
        return false;
      }
    }
    return predicate;
  }

  /// Phase 13.9C (S2): addressed to the counselor rather than an answer —
  /// asking what it means, what it wants, or to say it more simply.
  static bool addressesCounselor(String value) {
    final t = value.trim();
    return RegExp(
      r'(쉽게|쉬운\s*말|다시|천천히)\s*(좀\s*)?(말|설명|얘기|이야기|물어)|'
      r'설명해|예시|예를\s*들|'
      // Phase 13.9D: a request aimed at how the counselor talks ("말을 좀
      // 쉽게 해줘", "짧게 말해 주세요").
      r'(쉽게|짧게|간단히|천천히)\s*(좀\s*)?(해|말해|얘기해)\s*(줘|주세요|봐|주면|줄래)|'
      r'뭘\s*(대답|말하|물어|하라|원하)|뭐라고\s*(대답|답|말)해야|'
      r'(하라는|말하라는|대답하라는|답하라는)\s*(거|건|게|말)|'
      r'무슨\s*(뜻|말|소리|질문|의도)|뭔\s*(소리|말|뜻)|'
      r'이해\s*(가|를)?\s*(안|못)|헷갈|애매|감이\s*안',
    ).hasMatch(t);
  }

  /// Phase 13.9C (S1): may this utterance be quoted back or used as the
  /// thing a sentence is about? Not a non-answer, not addressed to the
  /// counselor. A safety net for when the meta detector misses.
  ///
  /// Phase 13.9D (b): only a worry thought is quoted. A situation, a
  /// feeling, or anything the detectors didn't classify is reflected
  /// without quoting, so an undetected non-answer or complaint can't be
  /// quoted back as content (holdout v2), and quotes stay rare (dogfood
  /// feedback that quoting read awkwardly).
  static bool isQuotable(String value) =>
      hasContent(value) &&
      targetEligibility(thoughtSentence(value.trim())) == TargetEligibility.worryThought;

  // Phase 13.9D: sentence shapes that talk *to* the counselor rather than
  // answer its question — a question back ("…그게 뭔데", "…맞죠?"), unless
  // rhetorical ("끝나진 않겠죠..?"), or an honorific verb ending aimed at the
  // listener ("…하시네요").
  static final RegExp _questionBackEnding = RegExp(
    r'(\?|뭔데|건데|거야|뭐야|뭔가요|맞죠|인가요|건가요|나요|는데요\?)[.!?~ㅋㅎ\s]*$',
  );
  static final RegExp _whWord = RegExp(r'(무슨|뭔|뭐(?!든)|뭘|어떤|어떻게(?!든)|왜)');
  static final RegExp _talkingEnding = RegExp(r'(데|야|냐|니|돼요|되나요)[.!?~ㅋㅎ\s]*$');
  static final RegExp _rhetorical = RegExp(r'(겠죠|겠지|잖아|지\s*않을까|을까|ㄹ까|려나)');
  static final RegExp _honorificToListener = RegExp(
    r'(시네요|시네|세요|시는\s*거예요|시는데요?)[.!?~\s]*$',
  );

  /// Phase 13.9E: evidence that a reply actually does what a technique asks,
  /// by technique. Credit needs positive evidence, not just the absence of
  /// a detected complaint: undetected meta ("얘기할수록 더 답답해지네요")
  /// then can't be credited with a reframe it never made. Keys are
  /// `InterventionType` names, so this layer needn't depend on features/.
  static final Map<String, RegExp> _techniqueMove = {
    // a reframe: contrast, possibility, limiting the catastrophe
    'balancedThought': RegExp(
      r'(지만|해도|어도|아도|라도|더라도|수도|수\s*있|가능|아니|않|기회|괜찮|다음|정도|충분|전부는|끝은|일\s*뿐|뿐이)',
    ),
    // placing the behavior between avoiding and facing it
    'behaviorPatternReview': RegExp(
      r'(피하|피해|피했|회피|마주|직면|미루|미뤄|도망|부딪|해보|해 보|하는\s*편|편이|편인)',
    ),
    // short-term relief vs the longer run
    'consequenceReview': RegExp(
      r'(당장|지금은|나중|오래|결국|길게|편하|편해|도움|안심|잠깐|순간|장기|단기)',
    ),
    // what avoiding gives now
    'gainLossReview': RegExp(r'(좋은\s*점|편하|편해|안\s*해도|피하면|안심|덜\s*불안|이득|대신|잃|손해)'),
    // when/where to keep the practice
    'maintenanceReview': RegExp(
      r'(매일|아침|저녁|밤|주말|시간|전에|후에|할\s*때|꾸준|계속|습관|자기\s*전|일어나)',
    ),
  };

  static bool showsTechniqueMove(String value, String interventionType) =>
      _techniqueMove[interventionType]?.hasMatch(value) ?? true;

  /// Phase 13.9D: may this reply be credited as the user's answer to a
  /// technique question? Content that isn't directed back at the counselor.
  static bool isTechniqueAnswer(String value) {
    final t = value.trim();
    if (!hasContent(t)) return false;
    if (_honorificToListener.hasMatch(t)) return false;
    for (final sentence in t.split(RegExp(r'(?<=[.!?])\s+'))) {
      if (_questionBackEnding.hasMatch(sentence.trim()) && !_rhetorical.hasMatch(sentence)) {
        return false;
      }
    }
    // A question word plus a talking ending ("무슨 기준인데", "왜 그래야 돼요").
    // "어떻게든 / 뭐든" are not questions.
    if (_whWord.hasMatch(t) && _talkingEnding.hasMatch(t) && !_rhetorical.hasMatch(t)) {
      return false;
    }
    return true;
  }

  /// Phase 13.9C: carries content — not a non-answer, not addressed to the
  /// counselor. What may be credited as a technique answer or used as a
  /// fallback target; quoting in reflect needs the stricter [isQuotable].
  static bool hasContent(String value) {
    final t = value.trim();
    if (t.isEmpty || isLowInformation(t) || addressesCounselor(t)) return false;
    return t.replaceAll(RegExp(r'[\s.!?,~]'), '').length >= 4;
  }

  /// Phase 13.8 (P4): a reply that doesn't answer an open question — low
  /// information other than a number (a number answers the 0–10 rating).
  static bool isNonAnswer(String value) =>
      isLowInformation(value) &&
      !RegExp(r'^\s*(?:[0-9]|10)').hasMatch(value);

  /// Phase 13.8 (P2): what a user utterance can be used for as CBT content.
  /// The contract every content selector follows: only a worry thought may
  /// become a technique's target; interaction/meta and low-information
  /// utterances never may. [interaction] is known from the reply's repair
  /// metadata (see [semanticContent]), so an utterance judged alone is one
  /// of the other three.
  static TargetEligibility targetEligibility(String text) {
    if (isLowInformation(text)) return TargetEligibility.lowInformation;
    if (addressesCounselor(text)) return TargetEligibility.interaction;
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

  /// Phase 13.9A (D): the latest user message that has content (not a
  /// low-information reply), for fallbacks that quote or reflect it.
  static String? latestContentMessage(List<CounselingMessage> messages) {
    for (final message in messages.reversed) {
      if (message.isUser && hasContent(message.text)) {
        return message.text.trim();
      }
    }
    return null;
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
