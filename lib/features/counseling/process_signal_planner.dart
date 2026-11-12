part of 'turn_plan.dart';

/// 사용자가 상담 진행 방식 자체에 반응하는 두 가지 신호를 잡는다.
///
///   1. 질문을 그만하고 그냥 들어/공감해 달라는 요청
///   2. 상담이라는 과정 자체에 대한 회의적인 반응(저항)
///
/// 두 경우 모두 이번 턴의 상담 "내용"(발표, 인간관계 등)보다 그 요청에 먼저
/// 반응하는 것이 실제 상담에 가깝다. 질문 없이 인정하는 문장만 내고, 다음
/// 단계로는 넘어가지 않는다(state 는 그대로 유지되고, 다음 실질적인 발화가
/// 오면 원래 상태별 planner 가 이어받는다).
///
/// closing 상태는 이미 질문 없이 마무리하므로 여기서 다루지 않는다.
class DeterministicProcessSignalTurnPlanner implements CounselingTurnPlanner {
  static const List<String> defaultForbidden = [
    '행동 해결책을 제안하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    '다음 CBT 단계로 넘어가지 않는다.',
    '질문을 하지 않는다.',
  ];

  static final RegExp _requestsEmpathy = RegExp(
    r'(그냥\s*(힘든\s*)?(얘기|이야기)?\s*좀?\s*들어(주세요|주시면|만)|'
    r'들어(만)?\s*주(세요|시면)|'
    // Phase 13.9A (A): "왜 계속 물어봐" as well as "왜 자꾸 물어봐".
    r'왜\s*(자꾸|계속)\s*물어|'
    r'질문\s*(그만|말고)|'
    r'그만\s*(물어|질문)|'
    r'공감\s*(좀\s*)?(해주|해줘|해\s*주시)|'
    r'위로\s*(좀\s*)?(해주|해줘|해\s*주시))',
  );

  // Phase 13.9C: "소용없다 / 의미없다 / 도움 안 된다" is about the
  // conversation only when it points at it ("이런 거", "이 상담", "이거",
  // "이렇게 얘기해도"). "공부를 해봤자 소용없을 것 같아요" is a worry.
  static final RegExp _pointsAtConversation = RegExp(
    r'(이런\s*(거|걸|것|대화|상담|얘기)|이거|이걸|이것|이\s*(상담|대화|앱|채팅)|'
    r'상담(이|은|을|해)|대화(가|는|를|해)|이렇게\s*(얘기|이야기|말))',
  );
  static final RegExp _noUse = RegExp(
    r'(소용\s*없|의미\s*없|쓸모\s*없|필요\s*없|도움(이|은)?\s*(별로\s*|하나도\s*|전혀\s*)?(안|없)|'
    r'(안|못)\s*와\s*닿|와닿지\s*(않|안)|'
    r'(뭐가|뭐|무엇이)\s*(바뀌|달라지))',
  );

  static bool _conversationIsPointless(String text) =>
      _pointsAtConversation.hasMatch(text) && _noUse.hasMatch(text);

  static final RegExp _showsProcessResistance = RegExp(
    r'(뭐가\s*달라질까|'
    r'해결되는\s*것도\s*아니|'
    r'그냥\s*하라고\s*해서|'
    r'설명\s*필요\s*없고|'
    r'이런\s*거\s*(한다고|해서)|'
    r'말한다고\s*(뭐가|해결))',
  );

  /// Phase 11.2: catches complaints specifically about *repetition* of the
  /// interaction itself ("왜 똑같은 말을 반복하지?", "아까도 물어봤잖아") —
  /// the confirmed gap from `phase11_1_selection_interaction_repair_design.md`'s
  /// P2. Deliberately NOT a bare `contains('반복')` check: worry content
  /// routinely mentions repetition too ("같은 생각이 계속 반복돼요", "매일
  /// 똑같은 걱정을 해요") without being a process complaint at all. Every
  /// alternative below pairs a repetition cue with a cue that the thing
  /// repeating is the counselor's own question/statement (질문/물어/여쭤/
  /// 얘기+했 — never a bare 말/생각/걱정), so ordinary worry content about
  /// recurring thoughts or events never matches.
  static final RegExp _repeatsInteraction = RegExp(
    r'(왜\s*(똑같은|같은)\s*말(을|은)?\s*(계속\s*)?반복|'
    r'왜\s*(똑같은|같은)\s*질문(을|은)?\s*계속|'
    // Phase 13.9A (C): one pointer word may sit between ("아까도 이거
    // 물어본"); a named third party may not ("아까도 선생님이 물어본").
    r'아까도\s*((이|그)(거|걸|것|얘기|이야기|질문)\S{0,1}\s*)?(물어|여쭤)|'
    r'방금도\s*(그\s*)?(질문|얘기)\s*(했|말했)|'
    r'그\s*얘기\s*방금도\s*(했|말했)|'
    r'또\s*같은\s*(거|것|걸)\s*물어|'
    r'아까\s*(말한|물어본)\s*거(랑|와)\s*똑같|'
    r'계속\s*비슷한\s*질문)',
  );

  // Phase 12.3B: cue-composition predicates, added alongside (never
  // replacing) the three patterns above. Real dogfood showed users mostly
  // point at THEIR OWN earlier statement ("아까 말했잖아", "방금
  // 말했잖아") or name the repetition loosely ("왜 똑같은 말을 해?"),
  // which the fixed alternations above never modeled. Every rule pairs an
  // interaction cue (speech verb / 질문 / 묻다 / 듣다) with a repetition or
  // stop cue; none fires on a single keyword. A cue preceded by a
  // third-party subject ("선생님이 전에 말했잖아", "사람들이 자꾸 물어봐서")
  // is ignored, since that is worry content about someone else.

  /// R-A: the user points at their own earlier statement.
  static final RegExp _refersToOwnStatement = RegExp(
    r'(아까|방금|이미|벌써|전에|앞에서)\s*(도\s*)?(제가\s*|내가\s*|다\s*)?'
    r'(말했|말씀드렸|얘기했|이야기했|대답했|답했|말한\s*건|대답한\s*건|얘기한\s*건)',
  );

  /// R-A2: "이 얘기 아까 하지 않았어요?" — the topic first, then when.
  static final RegExp _topicAlreadyCovered = RegExp(
    r'(이|그|같은)\s*(얘기|이야기|말|질문)\S{0,2}\s*(아까|전에|방금|이미)\s*(도\s*)?'
    r'(했|하지\s*않았|나눴)',
  );

  /// R-B: the counselor keeps saying the same thing.
  static final RegExp _saysSameThing = RegExp(
    r'(왜|또|계속|자꾸|맨날)\s*(똑같은|같은|비슷한)\s*(말|소리|얘기|질문|거|것|걸)'
    r'(을|를|만|이|은)?\s*(또\s*|계속\s*|자꾸\s*|다시\s*)?'
    r'(해|하냐|하네|하시네|하세요|하시|하는\s*거|하는거|하지|물어|묻|반복|이야|이에요|예요)',
  );

  /// R-C: the question itself is named as repeating.
  static final RegExp _questionRepeats = RegExp(
    r'(질문(이|을|은|만)?\s*(또|다시|계속|자꾸|반복|거의\s*같|똑같|비슷)|'
    r'(또|다시|계속|자꾸)\s*(그\s*|같은\s*|똑같은\s*)?질문)',
  );

  /// S: explicit request to stop being asked / to just be listened to.
  static final RegExp _asksToStopQuestions = RegExp(
    r'(질문\S{0,2}\s*(좀\s*)?(그만|안\s*했으면|하지\s*마|하지\s*말|말고|없이)|'
    r'(더|그만|이제\s*그만)\s*(물어|묻|질문)|'
    r'들어\s*(만\s*)?(주면|줘|주실|주세요|줄래))',
  );

  /// "질문을 받다" is about being asked by others (interviews, class), not
  /// about this conversation.
  static final RegExp _beingAskedByOthers = RegExp(r'질문\S{0,2}\s*(\S+\s*)?받');

  static final RegExp _subjectMarker = RegExp(r'([가-힣]+)(이|가|께서)\s');
  static const _selfSubjects = {'제가', '내가', '우리가', '저희가'};

  static bool _matchesAsInteraction(RegExp pattern, String text) {
    for (final match in pattern.allMatches(text)) {
      final prefix = text.substring(0, match.start);
      final thirdParty = _subjectMarker
          .allMatches(prefix)
          .any((m) => !_selfSubjects.contains(m.group(0)!.trim()));
      if (thirdParty) continue;
      if (text.substring(match.start).startsWith('안 들어')) continue;
      return true;
    }
    return false;
  }

  static bool _generalizedStop(String text) =>
      !_beingAskedByOthers.hasMatch(text) &&
      _matchesAsInteraction(_asksToStopQuestions, text) &&
      !RegExp(r'안\s*들어').hasMatch(text);

  // Phase 13.9C: more ways to say "you keep asking the same thing".
  //   R-D: the same thing named, then that it keeps coming ("같은 거 계속
  //        물어보네", "같은 질문 몇 번째").
  //   R-E: what was already said is being said again ("했던 말 또 하네").
  //   R-F: how many times ("몇 번을 말해야 돼"), or a loop ("무한반복").
  static final RegExp _sameThingAgain = RegExp(
    r'(같은|똑같은|비슷한)\s*(거|것|걸|말|질문|얘기|소리)\S{0,2}\s*'
    r'(계속|자꾸|또|몇\s*번|반복|맨날)',
  );
  static final RegExp _saidBeforeAgain = RegExp(
    r'(했던|한|물었던|물어본)\s*(말|질문|얘기|거)\S{0,2}\s*(또|계속|자꾸|다시)',
  );
  static final RegExp _howManyTimes = RegExp(
    r'몇\s*번(을|이나|째)?\s*(말해|얘기해|대답해|물어|해야)|무한\s*반복|도돌이표',
  );

  /// R-D/E/F describe what the counselor keeps doing, so neither a third
  /// party nor the user may be the one doing it ("제가 왜 같은 말을 자꾸
  /// 하는지", "면접에서 같은 질문을 또 받을까 봐").
  static bool _counselorRepeats(RegExp pattern, String text) {
    if (_beingAskedByOthers.hasMatch(text)) return false;
    for (final match in pattern.allMatches(text)) {
      final prefix = text.substring(0, match.start);
      if (_subjectMarker.hasMatch(prefix)) continue;
      return true;
    }
    return false;
  }

  static bool _generalizedRepeat(String text) =>
      _counselorRepeats(_sameThingAgain, text) ||
      _counselorRepeats(_saidBeforeAgain, text) ||
      _counselorRepeats(_howManyTimes, text) ||
      _matchesAsInteraction(_refersToOwnStatement, text) ||
      _matchesAsInteraction(_topicAlreadyCovered, text) ||
      _matchesAsInteraction(_saysSameThing, text) ||
      (!_beingAskedByOthers.hasMatch(text) &&
          _matchesAsInteraction(_questionRepeats, text));

  // Phase 13.8 (P1): the user didn't understand the counselor. Composed
  // from two cue families, never a single keyword: something that points at
  // the counselor's words, plus non-understanding. A bare "잘 모르겠어" has
  // no pointer and stays a low-information answer; "선생님이 무슨 말 하는지
  // 모르겠어" points at a third party and stays worry content.

  /// Points at the counselor or what it just said.
  static final RegExp _pointsAtCounselor = RegExp(
    r'(^|\s)(너|네가|니가|너가|당신)(가|는)?\s|'
    r'(방금|아까)\s*(한|하신|그)?\s*(말|질문|얘기|이야기|설명)|'
    r'(그|이)\s*(말|질문|설명)(이|은|을)?|'
    r'^그게\s|^그건\s|'
    r'^질문(이|을|은)?\s|^설명(이|을|은)?\s',
  );

  /// Says it wasn't understood.
  static final RegExp _notUnderstood = RegExp(
    r'(모르겠|이해(가|를)?\s*(안|못)|헷갈|무슨\s*(뜻|의미|말|소리)|'
    r'뭔\s*(뜻|말|소리)|뭐라는|뭔지\s*모르)',
  );

  /// A short question that is about the counselor's words by itself:
  /// "무슨 말이야", "뭐라는거야", "무슨 소리예요", "지금 무슨 이야기를 하는거야".
  static final RegExp _bareNotUnderstood = RegExp(
    r'^(지금\s*)?(무슨|뭔)\s*(말|소리|얘기|이야기)(이야|이에요|예요|야|이지|이죠|인데|이냐|임|씀|를\s*하는\s*(거|건)\S*|을\s*하는\s*(거|건)\S*)?$|'
    r'^뭐라는\s*(거|건|게)?\S*$|'
    r'^뭔\s*소리\S*$',
  );

  // Phase 13.9C: families beyond "pointer + non-understanding".
  //   N-A: asks the counselor to say it again or more simply, as a request
  //        ("다시 설명해 줘", "쉽게 물어봐 줄 수 있어?"). A reported request
  //        ("다시 설명해 달라고 하면") is not addressed to the counselor.
  //   N-B: relays the counselor's ask back ("뭘 말하라는 건지", "내가 뭘
  //        하면 되는데?").
  //   N-C: a short reaction on its own ("이해가 잘 안 가요", "뭔 소린지").
  //   N-D: asks what a word the counselor used means ("근거라는 게 뭐예요?").
  //   N-E: judges the question itself ("질문이 너무 어려워요"), unless the
  //        question belongs to someone else ("교수님 질문이 너무 어려워서").
  static final RegExp _asksToRephrase = RegExp(
    r'(쉽게|쉬운\s*말로|다시|천천히|한\s*번\s*더|짧게|간단히)\s*(좀\s*)?'
    r'(말해|말씀해|설명해|물어봐|물어|얘기해|이야기해|해)\s*'
    r'(줘|주세요|주실래요|주실\s*수|줄래|줄\s*수|봐|주시겠)',
  );
  static final RegExp _relaysTheAsk = RegExp(
    r'(뭘|무엇을|뭐를)\s*(말하|대답하|답하|하|적)라는|'
    r'(말하|대답하|답하|적)라는\s*(거|건|게|말)|'
    r'내가\s*뭘\s*하면\s*(되는데|돼|되나|될까)',
  );
  static final RegExp _shortNotUnderstood = RegExp(
    r'^(이해(가|를)?\s*(잘\s*)?(안|못)\s*(가|감|돼|되|했|하겠)\S*|'
    r'뭔\s*소린지\S*|뭔\s*말인지\S*|무슨\s*말인지\S*)$',
  );
  static final RegExp _asksWhatTermMeans = RegExp(
    r'\S+(라는|란)\s*(게|건|말은|말이|것은|것이)\s*(뭐|뭔|무슨|어떤|정확히)',
  );
  static final RegExp _judgesTheQuestion = RegExp(
    r'(^|(그|이|방금|아까|네|니|너의|방금\s*한)\s+)?질문(이|은|을)?\s*'
    r'((너무|좀|잘|되게|진짜)\s*)?(어려|애매|이상|헷갈|이해\s*(가\s*)?안|뭐야|뭔데|뭐예요)',
  );
  static const _questionOwners = {
    '교수님',
    '선생님',
    '면접관',
    '친구',
    '엄마',
    '아빠',
    '부모님',
    '사람들',
    '면접',
    '시험',
    '발표',
    '강의',
    '수업',
    '교수',
    '선생',
    '상사',
    '팀장님',
    '선배',
  };

  static bool _judgesThisQuestion(String t) {
    for (final m in _judgesTheQuestion.allMatches(t)) {
      final before =
          t.substring(0, m.start).trim().split(RegExp(r'\s+')).lastOrNull;
      if (before != null && _questionOwners.contains(before)) continue;
      return true;
    }
    return false;
  }

  static bool _assistantNotUnderstood(String text) {
    final t = text.trim().replaceFirst(RegExp(r'[?.!~\s]+$'), '');
    if (_bareNotUnderstood.hasMatch(t)) return true;
    if (_shortNotUnderstood.hasMatch(t)) return true;
    if (_matchesAsInteraction(_asksToRephrase, t)) return true;
    if (_matchesAsInteraction(_relaysTheAsk, t)) return true;
    if (_matchesAsInteraction(_asksWhatTermMeans, t) && t.length <= 30) {
      return true;
    }
    if (_judgesThisQuestion(t)) return true;
    return _pointsAtCounselor.hasMatch(t) && _notUnderstood.hasMatch(t);
  }

  /// Phase 13.8 (P1): the question the user didn't understand, asked again
  /// in plainer words. Read from the last substantive assistant turn's
  /// metadata (never its text): a pending technique prompt, a reflective
  /// goal, or otherwise a general "what worries you most".
  static String _simplerReask(List<CounselingMessage> messages) {
    CounselingMessage? pending;
    for (final m in messages.reversed) {
      if (m.isUser || m.interactionRepairReason != null) continue;
      pending = m;
      break;
    }
    if (pending?.interventionStep == InterventionStep.prompt &&
        pending!.referencedCbtIds.isNotEmpty) {
      final type =
          const ApprovedInterventionRegistry()
              .policyForItemId(pending.referencedCbtIds.first)
              ?.interventionType;
      switch (type) {
        case InterventionType.balancedThought:
          return '그 걱정을 조금 더 균형 있게, 덜 겁나게 바꿔 말해 본다면 어떤 문장이 될까요?';
        case InterventionType.behaviorPatternReview:
          return '그 걱정이 들 때 주로 피하는 편인가요, 아니면 마주하는 편인가요?';
        case InterventionType.consequenceReview:
          return '그 걱정이 들 때 하는 행동이 당장은 편하게 해 주는지, 나중에도 도움이 되는지 어떤가요?';
        case InterventionType.gainLossReview:
          return '피했을 때 당장 좋은 점이 있다면 무엇인가요?';
        case InterventionType.maintenanceReview:
          return '그 방법을 언제 다시 해 볼 수 있을까요?';
        case InterventionType.valueBasedChoice:
        case null:
          break;
      }
    }
    switch (ReflectQuestionGoal.values.asNameMap()[pending?.dialogueGoalId]) {
      case ReflectQuestionGoal.evidence:
        return '그렇게 생각하게 된 일이 있었다면 하나만 말씀해 주시겠어요?';
      case ReflectQuestionGoal.alternative:
        return '그 일을 조금 다르게 볼 수도 있을까요?';
      case ReflectQuestionGoal.probability:
        return '그 일이 실제로 일어날 것 같은 정도는 어느 정도인가요?';
      case null:
        return '지금 가장 걱정되는 것 한 가지만 편하게 말씀해 주시겠어요?';
    }
  }

  static const Map<InteractionRepairReason, List<String>> _repairSentences = {
    InteractionRepairReason.stopQuestioning: [
      '질문보다 지금 마음을 그대로 들어드리는 게 먼저인 것 같아요. 편하게 이야기해 주세요.',
      '네, 질문은 여기서 멈출게요. 하고 싶은 이야기가 있으면 편하게 이어서 해 주세요.',
    ],
    InteractionRepairReason.processFrustration: [
      '이 대화가 정말 도움이 될지 확신이 안 서는 마음, 자연스러운 거예요.',
      '지금은 이 대화가 잘 와닿지 않으실 수 있어요. 그런 마음이 드는 것도 충분히 이해돼요.',
    ],
    InteractionRepairReason.assistantNotUnderstood: [
      '제 말이 헷갈리게 들렸나 봐요. 쉽게 다시 여쭤볼게요.',
      '제 말이 헷갈리게 들렸나 봐요. 더 짧게 여쭤볼게요.',
    ],
    InteractionRepairReason.repeatedQuestion: [
      '맞아요, 비슷한 질문을 반복해서 드렸네요. 같은 내용을 다시 여쭙지 않고 지금 말씀해 주신 내용을 기준으로 이어갈게요.',
      '계속 같은 말을 드려서 답답하셨을 것 같아요. 이미 말씀해 주신 내용은 충분히 들었으니, 그대로 이어서 들을게요.',
    ],
  };

  static int _consecutiveRepairs(
    List<CounselingMessage> messages,
    InteractionRepairReason reason,
  ) {
    var count = 0;
    for (final message in messages.reversed) {
      if (message.isUser) continue;
      if (message.interactionRepairReason != reason) break;
      count++;
    }
    return count;
  }

  const DeterministicProcessSignalTurnPlanner();

  // Phase 13.8 (P4): wrap-up sentences, then the usual closing proposal.
  static const Map<EarlyWrapUp, String> _wrapUpSentences = {
    EarlyWrapUp.lowInformation: '지금은 바로 떠오르지 않을 수 있어요. 억지로 떠올리지 않아도 괜찮아요.',
    EarlyWrapUp.notUnderstood: '제 말이 계속 헷갈리게 들렸다면 미안해요. 억지로 답하지 않으셔도 괜찮아요.',
    EarlyWrapUp.noProgress: '지금은 딱 떠오르는 게 없을 수 있어요. 억지로 찾지 않아도 괜찮아요.',
  };

  static CounselingMessage? _lastAssistant(List<CounselingMessage> messages) {
    for (final m in messages.reversed) {
      if (!m.isUser) return m;
    }
    return null;
  }

  static CounselingMessage? _lastUser(List<CounselingMessage> messages) {
    for (final m in messages.reversed) {
      if (m.isUser) return m;
    }
    return null;
  }

  static bool _complains(String text) {
    final t = text.trim();
    return _requestsEmpathy.hasMatch(t) ||
        _generalizedStop(t) ||
        _repeatsInteraction.hasMatch(t) ||
        _generalizedRepeat(t);
  }

  CounselingTurnPlan _wrapUpPlan(TurnPlanningContext context, EarlyWrapUp why) {
    return CounselingTurnPlan(
      reflectionTarget: context.userMessage.trim(),
      questionGoal: '더 묻지 않고 부담 없이 받아 준 뒤 마무리를 제안한다.',
      // Phase 13.10: a complaint in the same turn ("모른다니까 왜 계속
      // 물어봐") is acknowledged before the wrap-up offer.
      reflectionSentence:
          _complains(context.userMessage) && why != EarlyWrapUp.notUnderstood
              ? '계속 질문이 이어져서 답답하셨을 것 같아요. ${_wrapUpSentences[why]!}'
              : _wrapUpSentences[why]!,
      questionSentence: TurnPlanMaterializer.closingProposalQuestion,
      forbidden: defaultForbidden.where((f) => f != '질문을 하지 않는다.').toList(),
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      requiredAct:
          context.state == CounselingState.explore
              ? DialogueAct.explore
              : DialogueAct.reflect,
      userContextIds: const [],
      cbtContextIds: const [],
      interactionRepairReason:
          why == EarlyWrapUp.notUnderstood
              ? InteractionRepairReason.assistantNotUnderstood
              : null,
      stageProgress: StageProgress.wrapUp,
      closingStep: ClosingStep.proposed,
      earlyWrapUp: why,
    );
  }

  static final RegExp _wantsMoreAtProposal = RegExp(
    r'(아직|좀\s*더|조금\s*더|더\s*(얘기|이야기|말|하고|할래|들어|해)|계속\s*(할|하고|얘기|이야기))',
  );

  /// Phase 13.8 (P1): in closing the Hard Guard stays off, except that a
  /// closing proposal the user didn't understand is asked again plainly.
  /// The proposal stays pending, so the next answer goes to the handshake.
  CounselingTurnPlan? _closingReask(TurnPlanningContext context) {
    final current = context.userMessage.trim();
    if (_lastAssistant(context.recentMessages)?.closingStep !=
        ClosingStep.proposed) {
      return null;
    }
    // Phase 13.9E: "아직 정리할 기분 아냐 좀 더 들어줘" asks to keep going; a
    // wish to continue goes to the handshake before the complaint rule
    // below (whose "들어줘" cue it shares).
    if (_wantsMoreAtProposal.hasMatch(current)) return null;

    // Phase 13.9A (B): a complaint about the questions themselves at the
    // proposal ("모르겠다고, 왜 계속 같은말해 짜증나게"). Its "계속" is not a
    // wish to continue, and asking anything again would repeat what the
    // user is complaining about: apologize and end.
    final complaint =
        _requestsEmpathy.hasMatch(current) || _generalizedStop(current)
            ? InteractionRepairReason.stopQuestioning
            : _repeatsInteraction.hasMatch(current) ||
                _generalizedRepeat(current)
            ? InteractionRepairReason.repeatedQuestion
            : null;
    if (complaint != null) {
      return CounselingTurnPlan(
        reflectionTarget: current,
        questionGoal: '불편을 인정하고 더 묻지 않고 마무리한다.',
        reflectionSentence:
            '같은 질문이 이어져서 답답하셨을 것 같아요. 오늘은 여기까지 할게요. 이야기 나눠 주셔서 감사합니다.',
        questionSentence: '',
        forbidden: defaultForbidden,
        constraints: const [
          TurnConstraint.requireReflection,
          TurnConstraint.requireNoQuestion,
          TurnConstraint.forbidAdvice,
          TurnConstraint.forbidNewUserFacts,
          TurnConstraint.forbidNewIntervention,
        ],
        requiredAct: DialogueAct.closing,
        userContextIds: const [],
        cbtContextIds: const [],
        interactionRepairReason: complaint,
        closingStep: ClosingStep.finalized,
      );
    }
    if (!_assistantNotUnderstood(current)) return null;
    final variants =
        _repairSentences[InteractionRepairReason.assistantNotUnderstood]!;
    return CounselingTurnPlan(
      reflectionTarget: current,
      questionGoal: '헷갈리게 한 것을 인정하고 마무리 제안을 더 쉬운 말로 다시 묻는다.',
      reflectionSentence:
          variants[_consecutiveRepairs(
                context.recentMessages,
                InteractionRepairReason.assistantNotUnderstood,
              ) %
              variants.length],
      questionSentence: '오늘은 여기서 마칠까요, 아니면 조금 더 이야기할까요?',
      forbidden: defaultForbidden.where((f) => f != '질문을 하지 않는다.').toList(),
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      requiredAct: DialogueAct.closing,
      userContextIds: const [],
      cbtContextIds: const [],
      interactionRepairReason: InteractionRepairReason.assistantNotUnderstood,
      closingStep: ClosingStep.proposed,
    );
  }

  @override
  CounselingTurnPlan? plan(TurnPlanningContext context) {
    if (context.state == CounselingState.closing) return _closingReask(context);

    final current = context.userMessage.trim();
    if (current.isEmpty) return null;

    // Phase 13.9C (S3): reflect would clarify a third time in a row. Two
    // clarify questions got nothing usable, whatever the user said, so offer
    // to wrap up instead of asking again. A net for non-answers the
    // low-information check doesn't recognize.
    // Phase 13.9D (c): only when the round has no worry to work on — a
    // cooperative user who already said one is never cut off.
    final round = UserThoughtExtractor.currentRound(context.recentMessages);
    // Phase 13.10: and never on a substantive message that voices worry
    // ("…건 아닐까 걱정되네"), even if its thought form isn't recognized —
    // cutting off a cooperative user is worse than one more question.
    if (context.state == CounselingState.reflect &&
        // Phase 14.3: clarify-type turns answered without new content. A
        // contentful reply anywhere resets the run, so a user who keeps
        // talking ("돈이 부족해서 걱정이야") is never wrapped up here.
        DialogueProgressLedger.stagnantClarifyRun(round, current) >= 2 &&
        UserThoughtExtractor.roundWorryThought(
              UserThoughtExtractor.semanticContent(round),
            ) ==
            null &&
        const ReflectDecisionSelector().wouldClarify(
          userMessage: current,
          recentMessages: context.recentMessages,
          userContext: context.userContext,
        )) {
      return _wrapUpPlan(context, EarlyWrapUp.noProgress);
    }

    // Phase 13.8 (P4): a second non-answer in a row, in explore/reflect.
    // Intervention has its own no-pressure integration for "모르겠어".
    final previousUser = _lastUser(context.recentMessages);
    if ((context.state == CounselingState.explore ||
            context.state == CounselingState.reflect) &&
        UserThoughtExtractor.isNonAnswer(current) &&
        previousUser != null &&
        UserThoughtExtractor.isNonAnswer(previousUser.text)) {
      return _wrapUpPlan(context, EarlyWrapUp.lowInformation);
    }

    // Fixed precedence: stop asking > process resistance > repeated question
    // > not understood.
    final wantsEmpathy =
        _requestsEmpathy.hasMatch(current) || _generalizedStop(current);
    final resists =
        !wantsEmpathy &&
        (_showsProcessResistance.hasMatch(current) ||
            _conversationIsPointless(current));
    final repeatsInteraction =
        !wantsEmpathy &&
        !resists &&
        (_repeatsInteraction.hasMatch(current) || _generalizedRepeat(current));
    final notUnderstood =
        !wantsEmpathy &&
        !resists &&
        !repeatsInteraction &&
        _assistantNotUnderstood(current);
    if (!wantsEmpathy && !resists && !repeatsInteraction && !notUnderstood) {
      return null;
    }

    final InteractionRepairReason reason;
    if (wantsEmpathy) {
      reason = InteractionRepairReason.stopQuestioning;
    } else if (resists) {
      reason = InteractionRepairReason.processFrustration;
    } else if (repeatsInteraction) {
      reason = InteractionRepairReason.repeatedQuestion;
    } else {
      reason = InteractionRepairReason.assistantNotUnderstood;
    }
    // Phase 13.8 (P4): a second "I don't understand you" in a row — asking
    // once more in other words didn't help, so offer to wrap up.
    if (reason == InteractionRepairReason.assistantNotUnderstood &&
        _lastAssistant(context.recentMessages)?.interactionRepairReason ==
            InteractionRepairReason.assistantNotUnderstood) {
      return _wrapUpPlan(context, EarlyWrapUp.notUnderstood);
    }

    // Phase 12.3D (F6): a second complaint in a row must not get the same
    // acknowledgment word for word. Alternate by how many immediately
    // preceding assistant turns were repairs for the same reason (metadata,
    // not text). The first variant is the original sentence.
    final variants = _repairSentences[reason]!;
    final reflectionSentence =
        variants[_consecutiveRepairs(context.recentMessages, reason) %
            variants.length];

    // Phase 13.8 (P1): not understanding is the one repair that asks again —
    // the same question in plainer words, so the user can still answer it.
    final reasks = reason == InteractionRepairReason.assistantNotUnderstood;
    return CounselingTurnPlan(
      reflectionTarget: current,
      questionGoal:
          reasks
              ? '헷갈리게 한 것을 인정하고 방금 질문을 더 쉬운 말로 다시 묻는다.'
              : '상담 내용보다 지금 표현한 요청/반응을 먼저 인정한다.',
      reflectionSentence: reflectionSentence,
      questionSentence: reasks ? _simplerReask(context.recentMessages) : '',
      forbidden:
          reasks
              ? defaultForbidden.where((f) => f != '질문을 하지 않는다.').toList()
              : defaultForbidden,
      constraints: [
        TurnConstraint.requireReflection,
        reasks
            ? TurnConstraint.requireExactlyOneQuestion
            : TurnConstraint.requireNoQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidStageAdvance,
      ],
      // explore 상태에서 reflect act 를 쓰면 되비추기로 오인돼 상태가 앞당겨
      // 진행된다(CounselingStatePolicy._acceleratesFrom). 이번 턴은 상담
      // 내용을 진전시키는 턴이 아니므로, 상태가 원래 쓰는 진행 속도를
      // 그대로 유지하는 act를 고른다.
      requiredAct:
          context.state == CounselingState.reflect ||
                  context.state == CounselingState.intervention
              ? DialogueAct.reflect
              : DialogueAct.explore,
      userContextIds: const [],
      cbtContextIds: const [],
      interactionRepairReason: reason,
    );
  }
}
