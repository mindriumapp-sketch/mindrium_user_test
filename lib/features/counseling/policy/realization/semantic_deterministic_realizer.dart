import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../../response_realizer.dart';
import '../../surface_variation.dart';
import '../counselor_decision.dart';
import 'realization_spec.dart';

/// Phase 10.3: the first `ResponseRealizer` that actually reads
/// `RealizationRequest.realizationSpec` (Phase 10.2) instead of only
/// passing `deterministicDraft` straight through
/// (`DeterministicResponseRealizer`, still production default).
///
/// This is a PARALLEL implementation, not a replacement — see
/// `docs/counseling/chatbot_system.md` (tag counseling-handover-v1) for why it is not
/// wired into `counseling_harness.dart`'s default yet. It targets exactly
/// the two structural findings from `phase10_1_failure_taxonomy.md`:
///
/// - R1 (verbatim quoting): reflection wording is rebuilt from
///   `realizationSpec.reflectionTarget`'s raw text through a small
///   non-quoting template pool, instead of reusing the legacy
///   `"$target"라고...` sentence.
/// - R7/R8 (no intervention bridge, zero template variation): an explicit
///   "why this intervention now" clause is inserted, grounded in
///   `InterventionRationale` — a category already selected upstream, never
///   invented here — before the (unchanged) intervention question.
///
/// Phase 10.3B: classifies a raw [ReflectionTarget] string purely for
/// surface-rendering safety — never for selection or meaning. Two shapes
/// (`multiSentence`, `questionSentence`) are unsafe for the
/// suffix-concatenation template `_renderTargetText` uses
/// (`"$clean 부분이 마음에 걸리시는 것 같아요."`), and fall back to a generic
/// grounded acknowledgment instead of a broken concatenation — see
/// `docs/counseling/chatbot_system.md` (tag counseling-handover-v1) for the two
/// production-scenario examples that motivated this (`holdout_checkIn_3`,
/// `holdout_intervention_already_used_1`).
enum ReflectionTargetShape {
  /// A short fragment, not a full sentence (safe to suffix directly).
  phrase,

  /// A single declarative sentence (safe to suffix directly — this shape
  /// exists to name the case, not to render it differently from [phrase]
  /// today).
  declarativeSentence,

  /// Ends in a Korean question-form predicate ending (e.g. `-까요`,
  /// `-나요`) even when the literal source text has no `?` — user input in
  /// this app's fixtures/production consistently uses `-까요.` rather than
  /// `-까요?`. Unsafe to suffix with a declarative acknowledgment clause.
  questionSentence,

  /// Contains a sentence-terminal punctuation mark before the end of the
  /// string (i.e. more than one sentence). Unsafe to suffix as if it were
  /// one noun phrase.
  multiSentence,
}

/// Phase 10.3B: pure surface-shape classification, no NLP dependency.
/// Deliberately conservative — when in doubt, this errs toward
/// [ReflectionTargetShape.phrase]/[ReflectionTargetShape.declarativeSentence]
/// (the two shapes the existing template already handles safely), only
/// flagging the two clearly-unsafe shapes it can detect with confidence.
ReflectionTargetShape classifyReflectionTargetShape(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return ReflectionTargetShape.phrase;

  final withoutTrailingTerminator = trimmed.replaceFirst(
    RegExp(r'[.!?]+$'),
    '',
  );

  // A terminal punctuation mark followed by more non-space content means
  // there is at least one earlier sentence boundary inside the string.
  final hasInternalSentenceBoundary = RegExp(
    r'[.!?]+\s*\S',
  ).hasMatch(withoutTrailingTerminator);
  if (hasInternalSentenceBoundary) return ReflectionTargetShape.multiSentence;

  // Korean question-form predicate endings. Written without a literal `?`
  // in this app's data (see class doc), so this is a morphology check, not
  // a punctuation check.
  // Note: bare "-가요" is deliberately excluded — it's also the plain
  // declarative conjugation of 가다 ("간다" -> "가요" = "[I] go"), so
  // treating it as always-question would misclassify ordinary statements.
  // The other endings here are distinctive enough to Korean question forms
  // that this tradeoff isn't needed for them.
  const questionEndingPattern = r'(까요|나요|는가요|인가요|일까요)$';
  if (RegExp(questionEndingPattern).hasMatch(withoutTrailingTerminator)) {
    return ReflectionTargetShape.questionSentence;
  }

  const declarativeEndingPattern =
      r'(습니다|ㅂ니다|어요|아요|해요|예요|이에요|네요|군요|았어요|었어요|였어요)$';
  if (RegExp(declarativeEndingPattern).hasMatch(withoutTrailingTerminator)) {
    return ReflectionTargetShape.declarativeSentence;
  }

  return ReflectionTargetShape.phrase;
}

/// Everything this class says must be traceable to
/// [RealizationRequest.realizationSpec] plus the legacy per-sentence
/// fields it kept around ([RealizationRequest.reflectionSentenceRaw] /
/// [RealizationRequest.questionSentenceRaw]) — it never invents a new
/// question, a new CBT technique, or a new user fact. The actual question
/// wording for every state is reused byte-for-byte from
/// [RealizationRequest.questionSentenceRaw] (already selected by
/// `TurnPlanMaterializer`), so the number and content of questions per turn
/// is provably unchanged from the legacy path.
class SemanticDeterministicResponseRealizer implements ResponseRealizer {
  final DeterministicSurfaceVariation surfaceVariation;

  const SemanticDeterministicResponseRealizer({
    this.surfaceVariation = const DeterministicSurfaceVariation(),
  });

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    final spec = request.realizationSpec;
    if (spec == null) {
      // Invariant H: no semantic contract available (e.g. a plan built by
      // a legacy `Deterministic*TurnPlanner`) — fall back to the exact
      // legacy behavior rather than guessing.
      return RealizationResult(
        reply: request.deterministicDraft,
        source: RealizationSource.deterministic,
        latency: Duration.zero,
        validationResult: RealizationValidationResult.valid,
        chosenAct: request.requiredAct,
      );
    }

    final reflection = _renderReflection(
      spec.reflectionTarget,
      fallback: request.reflectionSentenceRaw,
      recentMessages: request.recentConversation,
    );

    final bridge =
        spec.intervention == null
            ? null
            : _renderInterventionBridge(
              spec.intervention!,
              recentMessages: request.recentConversation,
            );

    final question = request.questionSentenceRaw.trim();

    final parts = <String>[
      reflection.trim(),
      if (bridge != null) bridge.trim(),
      question,
    ].where((sentence) => sentence.isNotEmpty).toList();

    return RealizationResult(
      reply: parts.join(' '),
      source: RealizationSource.deterministic,
      latency: Duration.zero,
      validationResult: RealizationValidationResult.valid,
      chosenAct: request.requiredAct,
    );
  }

  /// R1: rebuilds the reflection sentence from the raw target text through
  /// a non-quoting template pool, instead of reusing a `"$target"라고...`
  /// legacy sentence. Preserves the target's actual words (no paraphrase
  /// beyond stripping trailing punctuation) — this softens *quotation
  /// marks and the fixed acknowledgment phrase*, not the content.
  String _renderReflection(
    ReflectionTarget? target, {
    required String fallback,
    required List<CounselingMessage> recentMessages,
  }) {
    return switch (target) {
      ReflectionTargetText(:final value) => _renderTargetText(
        value,
        recentMessages,
      ),
      // No target found, or no semantic spec at all for this part: the
      // legacy sentence for these branches already doesn't quote a target
      // (e.g. Closing's generic summary, Reflect's empty-clarify fallback)
      // — reuse it rather than inventing new wording for an empty case.
      ReflectionTargetNone() => fallback,
      null => fallback,
    };
  }

  String _renderTargetText(
    String value,
    List<CounselingMessage> recentMessages,
  ) {
    final clean = value.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    if (clean.isEmpty) return _groundedAcknowledgmentFallback(recentMessages, seed: value);

    // Phase 10.3B: `multiSentence`/`questionSentence` targets break the
    // suffix-concatenation candidates below (see this file's
    // `ReflectionTargetShape` doc for the two concrete examples that
    // motivated this gate) — a grounded, non-specific acknowledgment is
    // safer than a grammatically broken specific one.
    final shape = classifyReflectionTargetShape(value);
    if (shape == ReflectionTargetShape.multiSentence ||
        shape == ReflectionTargetShape.questionSentence) {
      return _groundedAcknowledgmentFallback(recentMessages, seed: clean);
    }
    // Phase 12.3 (N5): the templates below put the target in a noun
    // position ("X 부분이…", "X 때문에…"), which only works for a noun
    // phrase. Device dogfood produced "미팅준비가 가장 마음에 걸려 부분이
    // 마음에 걸리시는 것 같아요" from a verb-final clause. Declarative and
    // predicate-final targets now get the generic acknowledgment, which also
    // avoids parroting the user's sentence back verbatim.
    if (shape == ReflectionTargetShape.declarativeSentence ||
        _endsWithPredicate(clean)) {
      return _groundedAcknowledgmentFallback(recentMessages, seed: clean);
    }

    return surfaceVariation.select(
      candidates: [
        '$clean 부분이 마음에 걸리시는 것 같아요.',
        '지금 $clean 때문에 마음이 무거우신 것 같네요.',
        '$clean 생각이 계속 신경 쓰이시는군요.',
      ],
      recentMessages: recentMessages,
      seed: clean,
      repetitionMarkers: const [
        '부분이 마음에 걸리시는 것 같아요',
        '때문에 마음이 무거우신 것 같네요',
        '생각이 계속 신경 쓰이시는군요',
      ],
    );
  }

  /// Casual verb/adjective endings ("걸려", "어색해", "있어", "것 같아",
  /// "7점이요"). Errs toward the generic acknowledgment: a noun that happens
  /// to end in one of these syllables ("여행지") just loses specificity,
  /// never grammar.
  static final RegExp _predicateFinal = RegExp(
    r'(어|아|해|돼|워|려|야|지|네|요|다|죠|까|래|게|고|서|데|니|냐|봐|줘|와|겠)$',
  );

  static bool _endsWithPredicate(String clean) =>
      _predicateFinal.hasMatch(clean.trim());

  /// Phase 10.3B: used whenever the target can't be safely suffixed as a
  /// noun phrase (empty, multi-sentence, or question-shaped). Deliberately
  /// generic — it names no specific content from the target, so it cannot
  /// misrepresent or garble it, at the cost of being less specific than
  /// the normal template.
  String _groundedAcknowledgmentFallback(
    List<CounselingMessage> recentMessages, {
    required String seed,
  }) {
    return surfaceVariation.select(
      candidates: const [
        '지금 이 부분이 계속 마음에 걸리시는 것 같아요.',
        '말씀해 주신 내용이 마음에 남아 있는 것 같네요.',
        '지금 이야기해 주신 부분을 계속 함께 살펴보고 있어요.',
      ],
      recentMessages: recentMessages,
      seed: seed,
      repetitionMarkers: const [
        '지금 이 부분이 계속 마음에 걸리시는 것 같아요',
        '말씀해 주신 내용이 마음에 남아 있는 것 같네요',
        '지금 이야기해 주신 부분을 계속 함께 살펴보고 있어요',
      ],
    );
  }

  /// R7/R8: names why this intervention starts now, grounded in the
  /// already-selected [InterventionRationale] — never a new technique, only
  /// a bridging clause for a decision made upstream.
  String _renderInterventionBridge(
    InterventionRealizationSpec intervention, {
    required List<CounselingMessage> recentMessages,
  }) {
    final candidates = switch (intervention.rationale) {
      InterventionRationale.examineThought => const [
        '이 생각을 조금 다른 관점에서도 살펴보면 도움이 될 것 같아요.',
        '지금 떠오른 생각이 사실과 얼마나 맞닿아 있는지 함께 살펴볼게요.',
      ],
      InterventionRationale.reviewAvoidancePattern => const [
        '지금 하시는 행동이 불안을 피하는 쪽인지 마주하는 쪽인지 함께 짚어볼게요.',
        '이 행동이 불안과 어떤 관계에 있는지 같이 살펴보면 좋겠어요.',
      ],
      InterventionRationale.compareShortLongTermConsequences => const [
        '이 행동이 지금과 나중에 각각 어떤 영향을 주는지 나눠서 살펴볼게요.',
        '당장의 안도감과 시간이 지난 뒤의 도움을 함께 견주어 볼게요.',
      ],
      InterventionRationale.exploreAmbivalence => const [
        '이 행동에서 얻는 것과 잃는 것을 함께 정리해 볼게요.',
        '이 회피가 주는 득과 실을 차례로 살펴보면 좋겠어요.',
      ],
      InterventionRationale.supportMaintenance => const [
        '지금까지 도움이 됐던 방법을 계속 이어갈 방법을 함께 정해볼게요.',
        '이 방법을 앞으로도 이어가기 위한 계획을 같이 세워볼게요.',
      ],
    };
    return surfaceVariation.select(
      candidates: candidates,
      recentMessages: recentMessages,
      seed: '${intervention.rationale.name}:${intervention.relevantTarget ?? ''}',
      repetitionMarkers: candidates,
    );
  }
}
