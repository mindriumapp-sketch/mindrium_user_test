part of 'llm_led_contract.dart';

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

  /// respond_v11: the past episode code chose to recall this turn (the user
  /// referred to the past), or null. The reply must state it, not ask for it.
  final RecallRequest? recall;
  final bool exploreClosed;

  /// The user asked to end now (code-detected); finalize is allowed on it.
  final bool userEndRequest;

  /// This turn's user message (for affirmation / example-request checks).
  final String userMessage;
  final bool patternAnalysisRequested;

  /// The last two assistant replies (for repeated-reply checks).
  final List<String> recentReplies;

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
    this.recall,
    this.exploreClosed = false,
    this.userEndRequest = false,
    this.newTopic = false,
    this.userMessage = '',
    this.patternAnalysisRequested = false,
    this.recentReplies = const [],
  });

  static LlmLedContext build({
    required String requestId,
    required CounselingSessionState session,
    required String userMessage,
    bool? patternAnalysisRequested,
    required CbtKnowledgeRepository knowledge,
    required AppGuideRepository appGuide,
    TermGlossary glossary = TermGlossary.empty,
    ApprovedInterventionRegistry registry =
        const ApprovedInterventionRegistry(),
  }) {
    final messages = session.messages;
    final round = UserThoughtExtractor.currentRound(messages);
    final lastAssistant = messages.reversed.where((m) => !m.isUser).firstOrNull;
    final pending =
        lastAssistant?.interventionStep == InterventionStep.prompt
            ? lastAssistant!.referencedCbtIds.firstOrNull
            : null;

    // conversation: the last 11 messages plus this user message (12 max)
    final conversation = [
      for (final m
          in messages.length > 11
              ? messages.sublist(messages.length - 11)
              : messages)
        {'role': m.isUser ? 'user' : 'assistant', 'text': _clip(m.text, 1200)},
      {'role': 'user', 'text': _clip(userMessage, 1200)},
    ];

    // user facts
    final ctx = session.userContext;
    final facts = <Map<String, String>>[];
    // Only offer patterns related to the current turn, never after an opt-out.
    final optedOut = [
      ...messages.where((m) => m.isUser).map((m) => m.text),
      userMessage,
    ].any(CounselingPatterns.optedOut);
    if (!optedOut && !CounselingPatterns.rejectsAnalysis(userMessage)) {
      final explicitPattern =
          patternAnalysisRequested ??
          CounselingPatterns.explicitlyRequested(userMessage);
      final selectedPatterns =
          ctx?.patterns?.relevant(userMessage, explicit: explicitPattern) ??
          const <CounselingPattern>[];
      if (explicitPattern && selectedPatterns.isNotEmpty) {
        facts.add({
          'id': 'pattern:scope',
          'kind': 'record_pattern',
          'text':
              '최근 ${ctx!.patterns!.windowDays}일 일기 ${ctx.patterns!.diaryCount}건',
        });
      }
      for (final p in selectedPatterns) {
        facts.add({
          'id': 'pattern:${p.id}',
          'kind': 'record_pattern',
          'text': _clip(explicitPattern ? (p.aiText ?? p.text) : p.text, 300),
        });
      }
    }

    for (final e in (ctx?.episodes.episodes ?? const [])
        .where((e) => e.isCompleted)
        .take(5)) {
      final alt =
          e.interventionOutcome == 'credited' ? e.alternativeThought : null;
      final core = e.coreThought ?? e.mainConcern;
      if (core == null) continue;
      facts.add({
        'id': 'session:${e.sessionId}',
        'kind': 'past_episode',
        'text': _clip(
          '걱정: $core${alt != null ? ' / 그때 정리한 생각: $alt' : ''}',
          600,
        ),
      });
    }
    for (final item in (ctx?.relevantItems ?? const <UserContextItem>[]).take(
      8,
    )) {
      facts.add({
        'id': item.id,
        'kind': item.type.name,
        'text': _clip(item.text, 300),
      });
    }
    for (final ei in (ctx?.effectiveInterventions ??
            const <EffectiveIntervention>[])
        .take(3)) {
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
        'question_guide': _clip(
          item.paragraphs.length > 1 ? item.paragraphs[1] : '',
          600,
        ),
      });
    }

    // app catalog: each feature with its navigation path(s), plus the
    // how-to manual. Screens and paths are folded into the feature text so
    // the whole catalog fits the request (screen names stay checkable below).
    final appFacts = <Map<String, String>>[];
    final appNames = <String>[];
    for (final f in appGuide.features) {
      final paths = [
        for (final n in appGuide.navigationPaths)
          if (n.to == f.featureId) n.steps.join(' → '),
      ];
      appFacts.add({
        'id': 'feature:${f.featureId}',
        'kind': 'feature',
        'text': _clip(
          '${f.name}(${f.aliases.join(', ')}): ${f.description}'
          '${f.available ? '' : ' [사용 불가: 앱에 없거나 준비 중]'}'
          '${paths.isEmpty ? '' : ' 경로: ${paths.join(' / ')}'}',
          900,
        ),
      });
      appNames
        ..add(f.name)
        ..addAll(f.aliases.where((a) => a.length >= 3));
    }
    for (final m in appGuide.manualEntries) {
      appFacts.add({
        'id': 'manual:${m.knowledgeId}',
        'kind': 'manual',
        'text': _clip('${m.title}: ${m.content}', 600),
      });
    }
    for (final s in appGuide.screens) {
      appNames.add(s.displayName);
    }

    // respond_v4: the term this message asks about, resolved by code.
    final termRequest = glossary.resolve(userMessage, knowledge);

    // respond_v2: structured progress evidence (advisory).
    final roundWorry = UserThoughtExtractor.roundWorryThought(
      UserThoughtExtractor.semanticContent(round),
    );

    // respond_v11: recall resolved by code, like term grounding.
    final recall = RecallRequest.resolve(
      userMessage: userMessage,
      round: round,
      episodes: ctx?.episodes ?? EpisodeHistory.empty,
    );
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
    final recentQuestions =
        [
          for (final m in messages.reversed.where((m) => !m.isUser).take(6))
            for (final q in RegExp(r'[^.!?\n]*\?').allMatches(m.text))
              q.group(0)!.trim(),
        ].where((q) => q.isNotEmpty).take(3).toList();
    // respond_v3: exploration has run its course once a worry thought is known
    // and three exploratory questions were asked this round (five without one).
    final exploratory =
        round
            .where(
              (m) =>
                  !m.isUser &&
                  m.text.contains('?') &&
                  m.interventionStep == null &&
                  m.closingStep == null &&
                  m.interactionRepairReason == null,
            )
            .length;
    final exploreClosed =
        (roundWorry != null && exploratory >= 3) || exploratory >= 5;
    final progress = {
      'explore_closed': exploreClosed,
      'exploratory_questions': exploratory,
      'concern_identified':
          round.any(
            (m) => m.isUser && UserThoughtExtractor.hasContent(m.text),
          ) ||
          UserThoughtExtractor.hasContent(userMessage),
      'thought_identified': roundWorry != null,
      'evidence_explored': askedGoals.contains('evidence'),
      'alternative_explored': askedGoals.contains('alternative'),
      'intervention_available': types.isNotEmpty,
      'intervention_completed': round.any(
        (m) => !m.isUser && m.interventionStep == InterventionStep.integration,
      ),
      'recent_no_progress_turns': noProgress,
      'exchange_count': messages.where((m) => m.isUser).length + 1,
      'recent_questions': recentQuestions,
      'stage': session.state.wireName,
      'round_worry': roundWorry,
      'asked_goals': askedGoals.toList(),
      'intervention_pending': pending,
      'intervention_used':
          <String>{
            for (final m in messages)
              if (!m.isUser) ...m.referencedCbtIds,
          }.toList(),
      'closing_proposed': lastAssistant?.closingStep == ClosingStep.proposed,
      'continuation_used': messages.any(
        (m) => !m.isUser && m.closingStep == ClosingStep.continued,
      ),
    };

    return LlmLedContext(
      body: {
        'request_id': requestId,
        'current_week': session.currentWeek,
        'conversation': conversation,
        'progress': progress,
        'user_facts': facts.take(20).toList(),
        'techniques': techniques.take(10).toList(),
        'app_facts': appFacts.take(60).toList(),
        'term_request': termRequest?.toJson(),
        'recall': recall?.toJson(),
      },
      techniqueIds: types.keys.toSet(),
      techniqueTypes: types,
      userFactIds: facts.take(20).map((f) => f['id']!).toSet(),
      appFactIds: appFacts.take(60).map((f) => f['id']!).toSet(),
      appNames: appNames.where((n) => n.trim().length >= 2).toList(),
      pendingInterventionId: pending,
      closingProposed: lastAssistant?.closingStep == ClosingStep.proposed,
      recentQuestions: recentQuestions,
      termRequest: termRequest,
      recall: recall,
      exploreClosed: exploreClosed,
      userEndRequest: ClosingDecisionSelector.isExplicitEnd(userMessage),
      userMessage: userMessage,
      patternAnalysisRequested:
          patternAnalysisRequested ??
          CounselingPatterns.explicitlyRequested(userMessage),
      recentReplies: [
        for (final m in session.messages.reversed
            .where((m) => !m.isUser)
            .take(2))
          m.text,
      ],
      newTopic: _newTopic(userMessage, round, roundWorry),
    );
  }
}

/// A past episode to recall this turn. Code decides: the user refers to the
/// past ("예전에도", "지난번에") and a completed episode shares the topic of
/// this message or this round; one with a credited alternative thought first.
class RecallRequest {
  final String factId;
  final String worry;
  final String? alternative;

  const RecallRequest({
    required this.factId,
    required this.worry,
    this.alternative,
  });

  static final RegExp _pastCue = RegExp(
    r'(예전|전에도|전에\s*(도|는|한|했)|지난번|저번|이전에|옛날|그때)',
  );

  static RecallRequest? resolve({
    required String userMessage,
    required List<CounselingMessage> round,
    required EpisodeHistory episodes,
  }) {
    if (episodes.isEmpty || !_pastCue.hasMatch(userMessage)) return null;
    final topics = {
      ...EpisodeHistory.topicKeys(userMessage),
      for (final m in round)
        if (m.isUser) ...EpisodeHistory.topicKeys(m.text),
    };
    if (topics.isEmpty) return null;
    // The episode sharing the most topic words wins; a credited alternative
    // breaks ties (device check: a stray shared word must not beat the
    // episode that is actually about the same thing).
    PreviousSession? best;
    var bestScore = 0;
    for (final e in episodes.episodes) {
      if (!e.isCompleted) continue;
      final past = {
        ...EpisodeHistory.topicKeys(e.coreThought ?? ''),
        ...EpisodeHistory.topicKeys(e.mainConcern ?? ''),
      };
      final overlap = past.intersection(topics).length;
      if (overlap == 0) continue;
      final hasAlt =
          e.interventionOutcome == 'credited' &&
          (e.alternativeThought?.trim().isNotEmpty ?? false);
      final score = overlap * 2 + (hasAlt ? 1 : 0);
      if (score > bestScore) {
        best = e;
        bestScore = score;
      }
    }
    final worry = best?.coreThought ?? best?.mainConcern;
    if (best == null || worry == null) return null;
    return RecallRequest(
      factId: 'session:${best.sessionId}',
      worry: worry,
      alternative:
          best.interventionOutcome == 'credited'
              ? best.alternativeThought?.trim()
              : null,
    );
  }

  Map<String, Object?> toJson() => {
    'fact_id': factId,
    'worry': worry,
    'alternative': alternative,
  };

  /// The recall in code's words, from the stored record only.
  String get sentence =>
      alternative != null
          ? "지난번에도 '$worry'라는 걱정을 이야기하셨어요. 그때 '$alternative'라고 정리해 보셨죠."
          : "지난번에도 '$worry'라는 걱정을 이야기하셨어요.";

  String get followUp =>
      alternative != null
          ? '그 생각이 이번에도 도움이 될 것 같으세요?'
          : '이번에는 그때와 어떤 점이 비슷하거나 다른 것 같으세요?';

  /// Demo check (v11): the model stated the recall 2 times in 5 and asked
  /// it back otherwise. When the reply does not state it, code states it:
  /// the model's first sentence (its acknowledgment) + the stored record +
  /// a fixed follow-up. Nothing the record does not say is added.
  LlmLedOutput ensureStated(LlmLedOutput o, String userMessage) {
    if (statedIn(o.statement, userMessage) &&
        o.usedUserFactIds.contains(factId)) {
      return o;
    }
    final first = o.statement.split(RegExp(r'(?<=[.!])\s+')).first.trim();
    final ack =
        first.contains(RegExp('[?？]')) || first.isEmpty ? '' : '$first ';
    return LlmLedOutput(
      domain: o.domain,
      moves:
          {
            ...o.moves.where((m) => m != 'open_question' && m != 'listen'),
            'connect_past_record',
          }.toList(),
      interventionId: null,
      interventionStep: null,
      usedUserFactIds: {...o.usedUserFactIds, factId}.toList(),
      usedAppFactIds: o.usedAppFactIds,
      definitionId: o.definitionId,
      sessionAction: 'continue',
      statement: '$ack$sentence',
      question: followUp,
    );
  }

  /// The reply states the recalled content: at least two content stems of
  /// the alternative (or of the worry when there is none) that the user's
  /// message did not already supply.
  bool statedIn(String reply, String userMessage) {
    Set<String> stems(String x) => EpisodeHistory.topicKeys(x);
    final target = stems(alternative ?? worry).difference(stems(userMessage));
    return stems(reply).intersection(target).length >= 2;
  }
}

bool _newTopic(
  String userMessage,
  List<CounselingMessage> round,
  String? roundWorry,
) {
  if (!UserThoughtExtractor.isContentfulContribution(userMessage)) return false;
  final now = EpisodeHistory.topicKeys(userMessage);
  if (now.isEmpty) return false;
  final before = <String>{
    if (roundWorry != null) ...EpisodeHistory.topicKeys(roundWorry),
    for (final m in round)
      if (m.isUser) ...EpisodeHistory.topicKeys(m.text),
  };
  if (before.isNotEmpty && now.intersection(before).isEmpty) return true;
  return _newWorry(userMessage, round, roundWorry);
}

// A worry thought ("친구가 사과를 안 받아주면 어떡하지?") not voiced earlier in
// this round is new content even when it shares the topic's words.
final RegExp _worryCue = RegExp(
  r'(어떡하지|어떻게\s*하지|면\s*어쩌|할까\s*봐|일까\s*봐|으면\s*어떡|걱정돼|걱정이에요|무서워|두려워)',
);

bool _newWorry(
  String userMessage,
  List<CounselingMessage> round,
  String? roundWorry,
) {
  if (!_worryCue.hasMatch(userMessage)) return false;
  Set<String> words(String x) => {
    for (final w in x.split(RegExp(r'[^가-힣A-Za-z0-9]+')))
      if (w.length >= 2) w,
  };
  final now = words(userMessage);
  for (final earlier in [
    if (roundWorry != null) roundWorry,
    for (final m in round)
      if (m.isUser) m.text,
  ]) {
    final b = words(earlier);
    final union = now.union(b).length;
    if (union > 0 && now.intersection(b).length / union >= 0.5) return false;
  }
  return true;
}
