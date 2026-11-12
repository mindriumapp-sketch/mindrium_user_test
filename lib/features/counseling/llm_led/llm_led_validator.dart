part of 'llm_led_contract.dart';

/// Post-call boundary. Empty list = accepted.
class LlmLedValidator {
  const LlmLedValidator._();

  static final RegExp _diagnosis = RegExp(
    r'(진단|장애(입니다|예요|에요|가 있)|병(입니다|이에요)|우울증|공황장애)',
  );
  static final RegExp _guarantee = RegExp(
    r'(잘\s*될\s*거|괜찮을\s*거|문제\s*없을|걱정\s*(안\s*해도|하지\s*않아도)|반드시\s*(좋아|나아)|분명히?\s*(괜찮|잘)|나을\s*거|낫게\s*해)',
  );
  static final RegExp _directive = RegExp(
    r'(해야\s*(합니다|해요|돼요)|하셔야|(하|보|써|적어|해)\s*세요[.!]?(\s|$)|하십시오)',
  );
  // An invitation to talk ("편하게 이야기해 보세요", "말씀해 주세요") asks the
  // user to speak; it is not a behavioral directive.
  // Greetings ("안녕하세요", "안녕히 가세요") are not directives either.
  static final RegExp _invitationToTalk = RegExp(
    r'((이야기|얘기|말씀|말)(을|를)?\s*(편하게\s*)?(해|하)\s*(보|주)?\s*세요|(나눠|털어놓아|들려)\s*(보|주)\s*세요|안녕(하|히)\s*(세요|가세요|계세요))',
  );
  // respond_v3: the counselor always speaks 해요체. A sentence ending in a
  // banmal ending (not followed by 요) is rejected.
  static final RegExp _banmalSentence = RegExp(
    r'(?<![가-힣]요)(?:어|아|야|지|니|자|래|네|구나|거든|냐|해|돼|줘|게|까|봐|줄래|볼래|을까|ㄹ까|군)\s*[.?!~]*$',
  );
  static const String _definitional =
      r'(말합니다|뜻합니다|의미합니다|말해요|뜻해요|의미해요|말이에요|뜻이에요|것입니다|것이에요|거예요|방법입니다|방법이에요|연습입니다|연습이에요|입니다|이에요|예요)';

  /// "X는/란/이란 … (말합니다|뜻해요|…)": a definition of X.
  static bool _definesName(String text, String name) => RegExp(
    '${RegExp.escape(name)}\\S{0,3}\\s*(은|는|이란|란|이라는\\s*것은|라는\\s*것은)[^.?!]{0,80}$_definitional',
  ).hasMatch(text);
  // Phase 3: counseling advice. A recommendation ("~하는 것이 도움이 될 수
  // 있어요", "~것이 중요합니다") or an exhortation ("노력해 보세요", "~하시길
  // 바랍니다"). Reflecting the user's own idea ("~라는 생각이 드시는군요")
  // and affirming a plan the user just named are not advice.
  static final RegExp _recommendation = RegExp(
    r'((것이|게|건)\s*(중요|필요)(하|해|할)|'
    r'(는|보는|두는)\s*(것|게|건)\s*(도|이|은|가)?\s*(좋|도움|중요|필요|방법))',
  );
  // "~이 중요해요/필요해요" is a norm, never an affirmation of the user's plan.
  static final RegExp _normative = RegExp(r'(중요|필요)');
  static final RegExp _exhortation = RegExp(
    r'((노력|시도)해\s*보(세요|시)|시길\s*(바랍|바라)|는\s*편이\s*나[아을])',
  );
  static final RegExp _reflecting = RegExp(
    r'(생각이\s*드|생각하시|말씀|하셨|느끼시|라고|다고|겠다는|려는)',
  );
  static final RegExp _quoted = RegExp('["“\'‘][^"”\'’]*["”\'’]');
  // An example of a balanced/alternative thought before the user tried one.
  static final RegExp _example = RegExp(r'예를\s*들(어|면)|예시로');
  static final RegExp _alternativeTalk = RegExp(
    r'(균형|대안|다른\s*(생각|관점|문장)|바꿔|바꾸)',
  );
  // ...or asks what the technique is ("그게 뭐야?", "무슨 말이야").
  static final RegExp _asksExample = RegExp(
    r'(예시|예를|예로|어떻게\s*(써|적|해|하)|모르겠|뭐야|뭔데|뭐예요|뭔가요|무슨|이해가\s*안|감이\s*안)',
  );

  static String _unquoted(String s) => s.replaceAll(_quoted, ' ');

  /// Content words (2+ chars, first two syllables) shared with the user.
  static bool _echoesUser(String sentence, String user) {
    Set<String> stems(String x) => {
      for (final w in x.split(RegExp(r'[^가-힣A-Za-z0-9]+')))
        if (w.length >= 2) w.substring(0, 2),
    };
    return stems(sentence).intersection(stems(user)).isNotEmpty;
  }

  /// Per sentence: in app guidance only a sentence about the app itself
  /// (an app term or feature name) may recommend; the counseling sentence
  /// next to it ("그런 감정은 기록해 두는 것이 좋습니다") may not.
  static bool _advises(LlmLedOutput o, LlmLedContext c) {
    final appGuided = o.domain != 'counseling' && o.usedAppFactIds.isNotEmpty;
    for (final raw in _unquoted(o.statement).split(RegExp(r'(?<=[.?!])\s+'))) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (appGuided && (_appTerms.hasMatch(t) || c.appNames.any(t.contains))) {
        continue;
      }
      if (_exhortation.hasMatch(t)) return true;
      if (!_recommendation.hasMatch(t) || _reflecting.hasMatch(t)) continue;
      final affirms = !_normative.hasMatch(t) && _echoesUser(t, c.userMessage);
      if (!affirms) return true;
    }
    return false;
  }

  static final RegExp _appTerms = RegExp(r'(메뉴|화면|탭|버튼|설정에서|홈에서|들어가)');
  static final RegExp _secondPerson = RegExp(r'당신');
  static final RegExp _noQuestionPromise = RegExp(
    r'(질문\s*(을|은)?\s*(그만|안\s*할|하지\s*않|줄이|드리지\s*않)|더\s*(묻지|여쭙지|여쭤보지)\s*않)',
  );

  static Set<String> _words(String s) => {
    for (final w in s.split(RegExp(r'[\s.,!?~]+')))
      if (w.length >= 2) w,
  };

  /// Token Jaccard ≥ 0.6 with a recent question = asked again.
  static bool _repeats(String q, List<String> recent) {
    final a = _words(q);
    if (a.isEmpty) return false;
    for (final r in recent) {
      final b = _words(r);
      final inter = a.intersection(b).length;
      final union = a.union(b).length;
      if (union > 0 && inter / union >= 0.6) return true;
    }
    return false;
  }

  /// Word Jaccard ≥ 0.7 with one of the last two assistant replies.
  static bool _repeatsReply(String text, List<String> recent) {
    final a = _words(text);
    if (a.length < 4) return false;
    for (final r in recent) {
      final b = _words(r);
      final union = a.union(b).length;
      if (union > 0 && a.intersection(b).length / union >= 0.7) return true;
    }
    return false;
  }

  static bool _hasBanmal(String text) {
    for (final sentence in text.split(RegExp(r'(?<=[.?!])\s+'))) {
      final t = sentence.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'(요|니다|니까|세요|죠)\s*[.?!~]*$').hasMatch(t)) continue;
      if (RegExp(r'^(네|예|아니요|아뇨)\s*[.!~]*$').hasMatch(t)) {
        continue; // polite one-word replies
      }
      if (_banmalSentence.hasMatch(t)) return true;
    }
    return false;
  }

  static List<String> validate(LlmLedOutput o, LlmLedContext c) {
    final v = <String>[];
    if (o.interventionId != null &&
        !c.techniqueIds.contains(o.interventionId)) {
      v.add('unauthorized_intervention');
    }
    if (o.interventionStep == 'prompt' && o.interventionId == null) {
      v.add('prompt_without_intervention');
    }
    if (o.interventionStep == 'integration' &&
        o.interventionId == null &&
        c.pendingInterventionId == null) {
      v.add('integration_without_prompt');
    }
    if (!o.usedUserFactIds.every(c.userFactIds.contains)) {
      v.add('unsupported_user_fact');
    }
    if (c.patternAnalysisRequested) {
      final offered =
          (c.body['user_facts'] as List)
              .whereType<Map>()
              .where((f) => f['kind'] == 'record_pattern')
              .map((f) => f['id'])
              .whereType<String>();
      if (!offered.every(o.usedUserFactIds.contains)) {
        v.add('pattern_facts_omitted');
      }
    }
    // Numeric pattern facts must be quoted exactly; an ID alone does not
    // prove that the generated count or time is faithful to the record.
    final facts = c.body['user_facts'] as List;
    String normalizePattern(String value) =>
        value.replaceAll(RegExp(r'평균(?:은|는|이|으로)'), '평균');
    for (final id in o.usedUserFactIds.where(
      (id) => id.startsWith('pattern:'),
    )) {
      final matches = facts.whereType<Map>().where((f) => f['id'] == id);
      if (matches.isEmpty ||
          !normalizePattern(
            o.text,
          ).contains(normalizePattern(matches.first['text'] as String))) {
        v.add('pattern_fact_mismatch');
      }
    }
    if (c.patternAnalysisRequested) {
      final numeric = RegExp(r'\d+(?:\.\d+)?');
      final allowedNumbers =
          facts
              .whereType<Map>()
              .where((f) => f['kind'] == 'record_pattern')
              .expand(
                (f) => numeric
                    .allMatches(f['text'] as String)
                    .map((m) => m.group(0)!),
              )
              .toSet();
      if (numeric
          .allMatches(o.text)
          .any((m) => !allowedNumbers.contains(m.group(0)))) {
        v.add('pattern_number_unsupported');
      }
    }

    if (!o.usedAppFactIds.every(c.appFactIds.contains)) {
      v.add('unsupported_app_fact');
    }
    // "점심 메뉴" is food, not an app menu.
    final appText = o.text.replaceAll(RegExp(r'(점심|저녁|아침|식사|음식|식당)\s*메뉴'), ' ');
    final mentionsApp =
        _appTerms.hasMatch(appText) ||
        c.appNames.any((n) => appText.contains(n));
    if (mentionsApp && o.usedAppFactIds.isEmpty && o.domain != 'counseling') {
      v.add('app_claim_without_fact');
    }
    if (RegExp('[?？؟]').allMatches(o.text).length > 1) {
      v.add('too_many_questions');
    }
    // respond_v5 E2b: a model kept off "?" wrote "؟" instead; never shown
    if (o.text.contains('؟')) v.add('foreign_question_mark');
    // respond_v2 r2: a question mark inside the statement is only a format
    // slip when the reply still has one question in total (the user sees the
    // same text), so only the total is checked (too_many_questions above).
    if (o.question != null && !RegExp(r'[?？]\s*$').hasMatch(o.question!)) {
      v.add('question_shape');
    }
    if (_secondPerson.hasMatch(o.text)) v.add('second_person');
    if (o.question != null && _noQuestionPromise.hasMatch(o.statement)) {
      v.add('question_after_no_question_promise');
    }
    if (o.question != null &&
        o.sessionAction != 'offer_close' &&
        _repeats(o.question!, c.recentQuestions)) {
      v.add('repeated_question');
    }
    // Device check: the same explanation or reply twice in a row ("안녕?" →
    // the identical answer again) reads as a script, however it is phrased.
    if (_repeatsReply(o.text, c.recentReplies)) v.add('repeated_reply');
    if (_diagnosis.hasMatch(o.text)) v.add('diagnosis');
    if (_guarantee.hasMatch(o.text)) v.add('outcome_guarantee');
    // A directive is an app operation in app guidance ("설정에서 찾아보세요"),
    // and approved technique guidance in a technique prompt; in counseling it
    // is unapproved advice.
    if (_directive.hasMatch(
          _unquoted(o.text).replaceAll(_invitationToTalk, ' '),
        ) &&
        !(o.domain != 'counseling' && o.usedAppFactIds.isNotEmpty) &&
        o.interventionStep != 'prompt') {
      v.add('directive');
    }
    if (o.sessionAction == 'finalize' &&
        !c.closingProposed &&
        !c.userEndRequest) {
      v.add('finalize_without_proposal');
    }
    // respond_v11: a recall code resolved is stated, not asked back.
    final r = c.recall;
    if (r != null &&
        (!o.usedUserFactIds.contains(r.factId) ||
            !r.statedIn(o.statement, c.userMessage))) {
      v.add('recall_not_stated');
    }
    // respond_v4: a definition is tied to the term code resolved.
    final t = c.termRequest;
    if (t != null && t.approved) {
      if (o.definitionId != t.termId) v.add('definition_mismatch');
    } else {
      if (o.definitionId != null) v.add('definition_without_request');
      if (t != null && _definesName(o.text, t.name)) {
        v.add('unknown_term_defined');
      }
    }
    // quoted words are someone's sentence, not the counselor's speech
    if (_hasBanmal(_unquoted(o.text))) v.add('banmal_reply');
    // Phase 3: advice, domain-aware like directives — app guidance tied to
    // app facts and an approved technique prompt may guide; counseling may not.
    if (o.interventionStep != 'prompt' && _advises(o, c)) v.add('advice');
    if (_example.hasMatch(o.text) &&
        _quoted.hasMatch(o.text) &&
        _alternativeTalk.hasMatch(o.text) &&
        !_asksExample.hasMatch(c.userMessage)) {
      v.add('premature_example');
    }
    if (c.exploreClosed &&
        !c.newTopic &&
        !o.moves.contains('repair') &&
        o.question != null &&
        o.interventionStep != 'prompt' &&
        o.sessionAction != 'offer_close' &&
        !o.moves.contains('clarify') &&
        !o.moves.contains('answer_app')) {
      v.add('exploring_after_closed');
    }
    if (o.text.length > 600) v.add('too_long');
    return v;
  }
}
