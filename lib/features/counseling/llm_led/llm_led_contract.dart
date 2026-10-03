// Phase 14.X: Bounded LLM-led path — context, output, validator, mapping.
// docs/counseling/phase14x_bounded_llm_led.md.
//
// Code narrows the world before the call (approved techniques up to this
// week, retrieved user facts, the app catalog, all with ids) and checks the
// answer after it. Anything the validator rejects falls back to the
// deterministic path for that turn.
import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/assistant/app_guide/app_guide_repository.dart';

import '../counseling_harness.dart' show CounselingSessionState;
import '../counseling_state.dart';
import '../intervention_registry.dart';
import '../policy/selectors/closing_decision_selector.dart';
import 'package:gad_app_team/data/counseling/episode_history.dart';
import 'term_glossary.dart';

const _domains = {'counseling', 'app_guide', 'mixed'};
const _moves = {
  'acknowledge', 'restate', 'reflect_emotion', 'clarify', 'open_question',
  'ask_evidence', 'ask_alternative', 'ask_probability', 'connect_past_record',
  'summarize', 'listen', 'repair', 'intervention_question', 'integrate',
  'answer_app', 'offer_close', 'finalize',
};
const _sessionActions = {'continue', 'offer_close', 'finalize'};

String _clip(String s, int n) => s.length <= n ? s : s.substring(0, n);

/// What the model may use this turn, with ids.
class LlmLedContext {
  final Map<String, dynamic> body;
  final Set<String> techniqueIds;
  final Map<String, String> techniqueTypes; // id -> InterventionType.name
  final Set<String> userFactIds;
  final Set<String> appFactIds;
  final List<String> appNames; // names a reply may only use with an app fact
  final String? pendingInterventionId;
  final bool closingProposed;
  final List<String> recentQuestions;
  final TermRequest? termRequest;
  final bool exploreClosed;

  /// The user asked to end now (code-detected); finalize is allowed on it.
  final bool userEndRequest;

  /// The user's message shares no topic with this round's worry so far
  /// (code-detected): new content, which exploration may take up.
  final bool newTopic;

  const LlmLedContext({
    required this.body,
    required this.techniqueIds,
    required this.techniqueTypes,
    required this.userFactIds,
    required this.appFactIds,
    required this.appNames,
    required this.pendingInterventionId,
    required this.closingProposed,
    this.recentQuestions = const [],
    this.termRequest,
    this.exploreClosed = false,
    this.userEndRequest = false,
    this.newTopic = false,
  });

  static LlmLedContext build({
    required String requestId,
    required CounselingSessionState session,
    required String userMessage,
    required CbtKnowledgeRepository knowledge,
    required AppGuideRepository appGuide,
    TermGlossary glossary = TermGlossary.empty,
    ApprovedInterventionRegistry registry = const ApprovedInterventionRegistry(),
  }) {
    final messages = session.messages;
    final round = UserThoughtExtractor.currentRound(messages);
    final lastAssistant = messages.reversed.where((m) => !m.isUser).firstOrNull;
    final pending = lastAssistant?.interventionStep == InterventionStep.prompt
        ? lastAssistant!.referencedCbtIds.firstOrNull
        : null;

    // conversation: the last 11 messages plus this user message (12 max)
    final conversation = [
      for (final m in messages.length > 11 ? messages.sublist(messages.length - 11) : messages)
        {'role': m.isUser ? 'user' : 'assistant', 'text': _clip(m.text, 1200)},
      {'role': 'user', 'text': _clip(userMessage, 1200)},
    ];

    // user facts
    final ctx = session.userContext;
    final facts = <Map<String, String>>[];
    for (final e in (ctx?.episodes.episodes ?? const []).where((e) => e.isCompleted).take(5)) {
      final alt = e.interventionOutcome == 'credited' ? e.alternativeThought : null;
      final core = e.coreThought ?? e.mainConcern;
      if (core == null) continue;
      facts.add({
        'id': 'session:${e.sessionId}',
        'kind': 'past_episode',
        'text': _clip('걱정: $core${alt != null ? ' / 그때 정리한 생각: $alt' : ''}', 600),
      });
    }
    for (final item in (ctx?.relevantItems ?? const <UserContextItem>[]).take(8)) {
      facts.add({'id': item.id, 'kind': item.type.name, 'text': _clip(item.text, 300)});
    }
    for (final ei in (ctx?.effectiveInterventions ?? const <EffectiveIntervention>[]).take(3)) {
      facts.add({
        'id': ei.id,
        'kind': 'effective_intervention',
        'text': _clip(
          '${ei.label}${ei.preSud != null && ei.postSud != null ? ' (불안 ${ei.preSud}→${ei.postSud})' : ''}',
          300,
        ),
      });
    }

    // approved techniques up to this week (cumulative, never a future week)
    final techniques = <Map<String, Object>>[];
    final types = <String, String>{};
    for (final p in registry.policiesUpTo(session.currentWeek)) {
      final item = knowledge.getById(p.requiredId);
      if (item == null) continue;
      types[p.requiredId] = p.interventionType.name;
      techniques.add({
        'id': p.requiredId,
        'name': _clip(item.title, 120),
        'week': p.week,
        'purpose': _clip(item.paragraphs.firstOrNull ?? item.title, 600),
        'question_guide': _clip(item.paragraphs.length > 1 ? item.paragraphs[1] : '', 600),
      });
    }

    // app catalog (small: the whole thing, with ids)
    final appFacts = <Map<String, String>>[];
    final appNames = <String>[];
    for (final f in appGuide.features) {
      appFacts.add({
        'id': 'feature:${f.featureId}',
        'kind': 'feature',
        'text': _clip('${f.name}(${f.aliases.join(', ')}): ${f.description}${f.available ? '' : ' [사용 불가]'}', 600),
      });
      appNames
        ..add(f.name)
        ..addAll(f.aliases.where((a) => a.length >= 3));
    }
    for (final s in appGuide.screens) {
      appFacts.add({
        'id': 'screen:${s.screenId}',
        'kind': 'screen',
        'text': _clip('${s.displayName}: ${s.description}', 600),
      });
      appNames.add(s.displayName);
    }
    for (final n in appGuide.navigationPaths) {
      appFacts.add({
        'id': 'nav:${n.from}->${n.to}',
        'kind': 'navigation',
        'text': _clip('${n.from} → ${n.to}: ${n.steps.join(' → ')}', 600),
      });
    }

    // respond_v4: the term this message asks about, resolved by code.
    final termRequest = glossary.resolve(userMessage, knowledge);

    // respond_v2: structured progress evidence (advisory).
    final roundWorry = UserThoughtExtractor.roundWorryThought(UserThoughtExtractor.semanticContent(round));
    final askedGoals = {
      for (final m in round)
        if (!m.isUser && m.dialogueGoalId != null) m.dialogueGoalId!,
    };
    var noProgress = 0;
    for (final m in [...messages.reversed.where((m) => m.isUser)]) {
      if (UserThoughtExtractor.isContentfulContribution(m.text)) break;
      noProgress++;
    }
    if (UserThoughtExtractor.isContentfulContribution(userMessage)) {
      noProgress = 0;
    } else {
      noProgress++;
    }
    final recentQuestions = [
      for (final m in messages.reversed.where((m) => !m.isUser).take(6))
        for (final q in RegExp(r'[^.!?\n]*\?').allMatches(m.text)) q.group(0)!.trim(),
    ].where((q) => q.isNotEmpty).take(3).toList();
    // respond_v3: exploration has run its course once a worry thought is known
    // and three exploratory questions were asked this round (five without one).
    final exploratory = round.where((m) =>
        !m.isUser &&
        m.text.contains('?') &&
        m.interventionStep == null &&
        m.closingStep == null &&
        m.interactionRepairReason == null).length;
    final exploreClosed = (roundWorry != null && exploratory >= 3) || exploratory >= 5;
    final progress = {
      'explore_closed': exploreClosed,
      'exploratory_questions': exploratory,
      'concern_identified': round.any((m) => m.isUser && UserThoughtExtractor.hasContent(m.text)) ||
          UserThoughtExtractor.hasContent(userMessage),
      'thought_identified': roundWorry != null,
      'evidence_explored': askedGoals.contains('evidence'),
      'alternative_explored': askedGoals.contains('alternative'),
      'intervention_available': types.isNotEmpty,
      'intervention_completed': round.any((m) => !m.isUser && m.interventionStep == InterventionStep.integration),
      'recent_no_progress_turns': noProgress,
      'exchange_count': messages.where((m) => m.isUser).length + 1,
      'recent_questions': recentQuestions,
      'stage': session.state.wireName,
      'round_worry': roundWorry,
      'asked_goals': askedGoals.toList(),
      'intervention_pending': pending,
      'intervention_used': <String>{
        for (final m in messages)
          if (!m.isUser) ...m.referencedCbtIds,
      }.toList(),
      'closing_proposed': lastAssistant?.closingStep == ClosingStep.proposed,
      'continuation_used': messages.any((m) => !m.isUser && m.closingStep == ClosingStep.continued),
    };

    return LlmLedContext(
      body: {
        'request_id': requestId,
        'current_week': session.currentWeek,
        'conversation': conversation,
        'progress': progress,
        'user_facts': facts.take(20).toList(),
        'techniques': techniques.take(10).toList(),
        'app_facts': appFacts.take(40).toList(),
        'term_request': termRequest?.toJson(),
      },
      techniqueIds: types.keys.toSet(),
      techniqueTypes: types,
      userFactIds: facts.take(20).map((f) => f['id']!).toSet(),
      appFactIds: appFacts.take(40).map((f) => f['id']!).toSet(),
      appNames: appNames.where((n) => n.trim().length >= 2).toList(),
      pendingInterventionId: pending,
      closingProposed: lastAssistant?.closingStep == ClosingStep.proposed,
      recentQuestions: recentQuestions,
      termRequest: termRequest,
      exploreClosed: exploreClosed,
      userEndRequest: ClosingDecisionSelector.isExplicitEnd(userMessage),
      newTopic: _newTopic(userMessage, round, roundWorry),
    );
  }
}

bool _newTopic(String userMessage, List<CounselingMessage> round, String? roundWorry) {
  if (!UserThoughtExtractor.isContentfulContribution(userMessage)) return false;
  final now = EpisodeHistory.topicKeys(userMessage);
  if (now.isEmpty) return false;
  final before = <String>{
    if (roundWorry != null) ...EpisodeHistory.topicKeys(roundWorry),
    for (final m in round)
      if (m.isUser) ...EpisodeHistory.topicKeys(m.text),
  };
  return before.isNotEmpty && now.intersection(before).isEmpty;
}

/// The model's answer (backend `output`).
class LlmLedOutput {
  final String domain;
  final List<String> moves;
  final String? interventionId;
  final String? interventionStep;
  final List<String> usedUserFactIds;
  final List<String> usedAppFactIds;
  final String? definitionId;
  final String sessionAction;
  final String statement;
  final String? question;

  /// What the user sees: the statement, then the one question if any.
  String get text => question == null ? statement : '$statement $question';

  const LlmLedOutput({
    required this.domain,
    required this.moves,
    required this.interventionId,
    required this.interventionStep,
    required this.usedUserFactIds,
    required this.usedAppFactIds,
    this.definitionId,
    required this.sessionAction,
    required this.statement,
    required this.question,
  });

  /// Null when the shape or an enum is off (respond_v2 shape: statement +
  /// optional single question; intervention as one {id, step} object).
  static LlmLedOutput? tryParse(Object? json) {
    if (json is! Map) return null;
    final moves = json['dialogue_moves'];
    final userIds = json['used_user_fact_ids'];
    final appIds = json['used_app_fact_ids'];
    final statement = json['statement'];
    final question = json['question'];
    final iv = json['intervention'];
    if (!_domains.contains(json['domain']) ||
        !_sessionActions.contains(json['session_action']) ||
        moves is! List || moves.isEmpty || !moves.every(_moves.contains) ||
        userIds is! List || appIds is! List ||
        statement is! String || statement.trim().isEmpty ||
        (question != null && question is! String) ||
        (iv != null &&
            (iv is! Map || iv['id'] is! String ||
                (iv['step'] != 'prompt' && iv['step'] != 'integration')))) {
      return null;
    }
    final q = (question as String?)?.trim();
    return LlmLedOutput(
      domain: json['domain'] as String,
      moves: moves.cast<String>(),
      interventionId: iv == null ? null : (iv as Map)['id'] as String,
      interventionStep: iv == null ? null : (iv as Map)['step'] as String,
      usedUserFactIds: userIds.whereType<String>().toList(),
      usedAppFactIds: appIds.whereType<String>().toList(),
      definitionId: json['definition_id'] is String ? json['definition_id'] as String : null,
      sessionAction: json['session_action'] as String,
      statement: statement.trim(),
      question: q == null || q.isEmpty ? null : q,
    );
  }
}

/// Post-call boundary. Empty list = accepted.
class LlmLedValidator {
  const LlmLedValidator._();

  static final RegExp _diagnosis = RegExp(r'(진단|장애(입니다|예요|에요|가 있)|병(입니다|이에요)|우울증|공황장애)');
  static final RegExp _guarantee = RegExp(
    r'(잘\s*될\s*거|괜찮을\s*거|문제\s*없을|걱정\s*(안\s*해도|하지\s*않아도)|반드시\s*(좋아|나아)|분명히?\s*(괜찮|잘)|나을\s*거|낫게\s*해)',
  );
  static final RegExp _directive = RegExp(r'(해야\s*(합니다|해요|돼요)|하셔야|(하|보|써|적어|해)\s*세요[.!]?(\s|$)|하십시오)');
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
  static final RegExp _appTerms = RegExp(r'(메뉴|화면|탭|버튼|설정에서|홈에서|들어가)');
  static final RegExp _secondPerson = RegExp(r'당신');
  static final RegExp _noQuestionPromise = RegExp(
    r'(질문\s*(을|은)?\s*(그만|안\s*할|하지\s*않|줄이|드리지\s*않)|더\s*(묻지|여쭙지|여쭤보지)\s*않)',
  );

  static Set<String> _words(String s) =>
      {for (final w in s.split(RegExp(r'[\s.,!?~]+'))) if (w.length >= 2) w};

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

  static bool _hasBanmal(String text) {
    for (final sentence in text.split(RegExp(r'(?<=[.?!])\s+'))) {
      final t = sentence.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'(요|니다|니까|세요|죠)\s*[.?!~]*$').hasMatch(t)) continue;
      if (RegExp(r'^(네|예|아니요|아뇨)\s*[.!~]*$').hasMatch(t)) continue; // polite one-word replies
      if (_banmalSentence.hasMatch(t)) return true;
    }
    return false;
  }

  static List<String> validate(LlmLedOutput o, LlmLedContext c) {
    final v = <String>[];
    if (o.interventionId != null && !c.techniqueIds.contains(o.interventionId)) {
      v.add('unauthorized_intervention');
    }
    if (o.interventionStep == 'prompt' && o.interventionId == null) v.add('prompt_without_intervention');
    if (o.interventionStep == 'integration' && o.interventionId == null && c.pendingInterventionId == null) {
      v.add('integration_without_prompt');
    }
    if (!o.usedUserFactIds.every(c.userFactIds.contains)) v.add('unsupported_user_fact');
    if (!o.usedAppFactIds.every(c.appFactIds.contains)) v.add('unsupported_app_fact');
    final mentionsApp = _appTerms.hasMatch(o.text) || c.appNames.any((n) => o.text.contains(n));
    if (mentionsApp && o.usedAppFactIds.isEmpty && o.domain != 'counseling') {
      v.add('app_claim_without_fact');
    }
    if ('?'.allMatches(o.text).length + '？'.allMatches(o.text).length > 1) v.add('too_many_questions');
    // respond_v2 r2: a question mark inside the statement is only a format
    // slip when the reply still has one question in total (the user sees the
    // same text), so only the total is checked (too_many_questions above).
    if (o.question != null && !RegExp(r'[?？]\s*$').hasMatch(o.question!)) v.add('question_shape');
    if (_secondPerson.hasMatch(o.text)) v.add('second_person');
    if (o.question != null && _noQuestionPromise.hasMatch(o.statement)) v.add('question_after_no_question_promise');
    if (o.question != null && o.sessionAction != 'offer_close' && _repeats(o.question!, c.recentQuestions)) {
      v.add('repeated_question');
    }
    if (_diagnosis.hasMatch(o.text)) v.add('diagnosis');
    if (_guarantee.hasMatch(o.text)) v.add('outcome_guarantee');
    // A directive is an app operation in app guidance ("설정에서 찾아보세요"),
    // and approved technique guidance in a technique prompt; in counseling it
    // is unapproved advice.
    if (_directive.hasMatch(o.text) &&
        !(o.domain != 'counseling' && o.usedAppFactIds.isNotEmpty) &&
        o.interventionStep != 'prompt') {
      v.add('directive');
    }
    if (o.sessionAction == 'finalize' && !c.closingProposed && !c.userEndRequest) {
      v.add('finalize_without_proposal');
    }
    // respond_v4: a definition is tied to the term code resolved.
    final t = c.termRequest;
    if (t != null && t.approved) {
      if (o.definitionId != t.termId) v.add('definition_mismatch');
    } else {
      if (o.definitionId != null) v.add('definition_without_request');
      if (t != null && _definesName(o.text, t.name)) v.add('unknown_term_defined');
    }
    if (_hasBanmal(o.text)) v.add('banmal_reply');
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

/// Maps an accepted answer onto the existing turn metadata, so persistence,
/// episodic memory and a later deterministic fallback keep working.
class LlmLedMapping {
  final CounselingState nextState;
  final DialogueAct act;
  final String? goalId;
  final bool isClarify;
  final InterventionStep? interventionStep;
  final List<String> cbtIds;
  final bool? credited;
  final ClosingStep? closingStep;

  const LlmLedMapping({
    required this.nextState,
    required this.act,
    required this.goalId,
    required this.isClarify,
    required this.interventionStep,
    required this.cbtIds,
    required this.credited,
    required this.closingStep,
  });

  static LlmLedMapping of(LlmLedOutput o, LlmLedContext c, CounselingState current, String userMessage) {
    final m = o.moves.toSet();
    final goal = m.contains('ask_evidence')
        ? 'evidence'
        : m.contains('ask_alternative')
        ? 'alternative'
        : m.contains('ask_probability')
        ? 'probability'
        : null;
    final step = switch (o.interventionStep) {
      'prompt' => InterventionStep.prompt,
      'integration' => InterventionStep.integration,
      _ => null,
    };
    final cbtId = o.interventionId ?? (step == InterventionStep.integration ? c.pendingInterventionId : null);
    bool? credited;
    if (step == InterventionStep.integration && cbtId != null) {
      final type = c.techniqueTypes[cbtId];
      credited = UserThoughtExtractor.isTechniqueAnswer(userMessage) &&
          (type == null || UserThoughtExtractor.showsTechniqueMove(userMessage, type));
    }
    final closing = o.sessionAction == 'finalize'
        ? ClosingStep.finalized
        : o.sessionAction == 'offer_close'
        ? ClosingStep.proposed
        : (c.closingProposed ? ClosingStep.continued : null);

    final CounselingState next;
    if (closing == ClosingStep.finalized || closing == ClosingStep.proposed) {
      next = CounselingState.closing;
    } else if (closing == ClosingStep.continued) {
      next = CounselingState.reflect;
    } else if (step != null) {
      next = CounselingState.intervention;
    } else if (goal != null && (current == CounselingState.checkIn || current == CounselingState.explore)) {
      next = CounselingState.reflect;
    } else if (current == CounselingState.checkIn) {
      next = CounselingState.explore;
    } else if (current == CounselingState.closing) {
      next = CounselingState.reflect;
    } else {
      next = current;
    }

    final act = closing == ClosingStep.finalized
        ? DialogueAct.closing
        : (step == InterventionStep.prompt || goal != null)
        ? DialogueAct.socraticQuestion
        : (m.contains('clarify') || m.contains('open_question'))
        ? DialogueAct.explore
        : m.contains('summarize')
        ? DialogueAct.summarize
        : DialogueAct.reflect;

    return LlmLedMapping(
      nextState: next,
      act: act,
      goalId: goal,
      isClarify: m.contains('clarify'),
      interventionStep: step,
      cbtIds: cbtId == null ? const [] : [cbtId],
      credited: credited,
      closingStep: closing,
    );
  }
}

