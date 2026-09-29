import 'package:gad_app_team/data/counseling/counseling_models.dart';

import '../../intervention_registry.dart';
import '../../surface_variation.dart';
import '../../turn_plan.dart';
import '../counselor_decision.dart';
import '../intervention_eligibility_predicates.dart';
import 'realization_spec_builder.dart';

/// Phase 8.4B: shared *surface realization* for all five counseling states.
///
/// Selection (which target/goal/intervention this turn pursues) is already
/// decided by the time a [CounselorDecision] reaches this class — see
/// `policy/selectors/*.dart`. This class does the second half of the job:
/// turning that decision into the actual drafted sentences and the final
/// [CounselingTurnPlan] shape.
///
/// This is the single source of truth for that realization. Both the legacy
/// `Deterministic*TurnPlanner` classes in `turn_plan.dart` (via
/// `selector.select(...)` followed by a call into this class) and
/// `TurnPlanAdapter` (via a [CounselorDecision] coming from a
/// [CounselorAgent]) call these same methods, so there is exactly one place
/// that knows how to turn a decision into a plan.
///
/// Contract: methods here never make a new selection. They read
/// `selectedAction`/`selectedGoalId`/`selectedInterventionId`/
/// `reflectionTarget`/`usedFactIds` off the given [CounselorDecision] as
/// authoritative input. The only additional inputs they take are things
/// needed purely for wording (sentence rotation against `recentMessages`) or
/// for looking up already-selected objects by id (matching
/// `selectedInterventionId` against `knowledge`).
class TurnPlanMaterializer {
  final DeterministicSurfaceVariation surfaceVariation;
  final ActivityRecommendationPolicy activityPolicy;
  final ApprovedInterventionRegistry registry;

  const TurnPlanMaterializer({
    this.surfaceVariation = const DeterministicSurfaceVariation(),
    this.activityPolicy = const ActivityRecommendationPolicy(),
    this.registry = const ApprovedInterventionRegistry(),
  });

  /// Phase 9.2D: replaces the four unsafe `reflectionTarget! as
  /// ReflectionTargetText` casts this class used to have. Every caller of
  /// this class (`TurnPlanAdapter` and the legacy `Deterministic*TurnPlanner`
  /// classes) is expected to have already gated `decision.isUnavailable` and
  /// checked `CounselorDecisionValidator`'s `ReflectionTargetRequirement`
  /// for the relevant state/action — so hitting either branch below
  /// indicates a genuine contract violation slipped through, not a normal
  /// runtime outcome. A descriptive [StateError] here is strictly better
  /// than the raw `TypeError`/`Null check operator used on a null value`
  /// the old cast produced: it names which state's realization was called
  /// and what shape it actually got.
  String _requireText(ReflectionTarget? target, String realizationMethod) {
    return switch (target) {
      ReflectionTargetText(:final value) => value,
      ReflectionTargetNone() => throw StateError(
        'TurnPlanMaterializer.$realizationMethod: reflectionTarget must be '
        'ReflectionTargetText, but got ReflectionTargetNone. This state '
        'requires text — CounselorDecisionValidator should have rejected '
        'this decision before it reached materialization.',
      ),
      null => throw StateError(
        'TurnPlanMaterializer.$realizationMethod: reflectionTarget is null '
        '(the decision claims the turn is entirely unavailable), but '
        'isUnavailable was not handled by the caller before reaching this '
        'realization method.',
      ),
    };
  }

  // ───────────────────────────────────────────────────────────────────
  // CheckIn
  // ───────────────────────────────────────────────────────────────────

  static const List<String> checkInForbidden = [
    '진단하거나 원인을 단정하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    'CBT 개입을 시작하지 않는다.',
    '질문을 여러 개 하지 않는다.',
  ];

  /// Mirrors `DeterministicCheckInTurnPlanner.plan`'s realization. Caller
  /// must have already checked `decision.isUnavailable` and returned null.
  CounselingTurnPlan checkIn(CounselorDecision decision) {
    final target = _requireText(decision.reflectionTarget, 'checkIn');
    final clean = target.replaceFirst(RegExp(r'[.!?]+$'), '');

    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: '현재 사용자가 느끼는 불안의 주관적 정도를 0에서 10 사이로 확인한다.',
      reflectionSentence: '“$clean”라고 말씀해 주셨군요.',
      questionSentence: '지금 느끼는 불안을 0에서 10 사이로 표현하면 어느 정도인가요?',
      forbidden: checkInForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      requiredAct: DialogueAct.explore,
      userContextIds: const [],
      cbtContextIds: const [],
      realizationSpec: RealizationSpecBuilder.checkIn(decision),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Closing
  // ───────────────────────────────────────────────────────────────────

  static const List<String> closingForbidden = [
    '새로운 CBT 개입을 시작하지 않는다.',
    '사용자가 말하지 않은 변화나 성과를 만들지 않는다.',
    '진단하거나 미래의 호전을 약속하지 않는다.',
    '새로운 질문이나 과제를 제시하지 않는다.',
  ];

  /// Phase 13.5: the one controlled continuation after a closing proposal.
  /// No question mark (it's an invitation, not a new probe), and it reopens
  /// reflect via [StageProgress.reopen].
  CounselingTurnPlan closingContinuation(CounselorDecision decision) {
    return CounselingTurnPlan(
      reflectionTarget: '',
      questionGoal: '사용자가 더 이야기하고 싶어 하므로 한 번 더 이어간다.',
      reflectionSentence: '좋아요, 조금 더 이야기해 볼게요. 지금 가장 마음에 걸리는 부분을 편하게 말씀해 주세요.',
      questionSentence: '',
      forbidden: closingForbidden,
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
      closingStep: ClosingStep.continued,
      stageProgress: StageProgress.reopen,
    );
  }

  /// Mirrors `DeterministicClosingTurnPlanner.plan`'s realization.
  CounselingTurnPlan closing(CounselorDecision decision) {
    if (decision.closingStep == ClosingStep.continued) {
      return closingContinuation(decision);
    }
    final target = switch (decision.reflectionTarget!) {
      ReflectionTargetText(:final value) => value,
      ReflectionTargetNone() => null,
    };
    // Phase 13.5: the final closing no longer quotes the user's words back
    // (dogfood session 6 closed on "오늘은 “왜 벌써 상담을 끝내”라는 이야기를
    // 나눴습니다"). The target stays in the plan and spec for grounding only.
    return CounselingTurnPlan(
      reflectionTarget: target ?? '',
      questionGoal: '새로운 내용을 추가하지 않고 현재 대화를 마무리한다.',
      reflectionSentence:
          '오늘 이야기 나눠 주셔서 감사합니다. 오늘 함께 살펴본 생각을 필요할 때 다시 떠올려 보세요.',
      questionSentence: '',
      forbidden: closingForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireNoQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      requiredAct: DialogueAct.closing,
      userContextIds: const [],
      cbtContextIds: const [],
      realizationSpec: RealizationSpecBuilder.closing(
        decision: decision,
        target: target,
      ),
      closingStep: ClosingStep.finalized,
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Explore
  // ───────────────────────────────────────────────────────────────────

  static const List<String> exploreForbidden = [
    '행동 해결책을 제안하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    '직전 상담자의 질문을 반복하지 않는다.',
    '생각을 평가하거나 다음 CBT 단계로 넘어가지 않는다.',
  ];

  /// Mirrors `DeterministicExploreTurnPlanner.plan`'s realization.
  ///
  /// [userMessage] is only used for the `isSudResponse` wording check — a
  /// pure formatting derivation from the raw current message, not a new
  /// selection (the selector already decided the actual `reflectionTarget`).
  CounselingTurnPlan explore(
    CounselorDecision decision, {
    required String userMessage,
    required List<CounselingMessage> recentMessages,
    required List<DialogueAct> allowedActsForTurn,
  }) {
    final current = userMessage.trim();
    final target = _requireText(decision.reflectionTarget, 'explore');
    final isSudResponse = _isSudResponse(current);
    final askedMoment = recentMessages.any(
      (message) =>
          !message.isUser &&
          (message.text.contains('어떤 순간') ||
              message.text.contains('가장 걱정되는 순간')),
    );
    final question =
        askedMoment
            ? '그 순간에 어떤 일이 생길까 봐 가장 걱정되나요?'
            : target.contains('발표')
            ? '발표에서 가장 걱정되는 순간은 언제인가요?'
            : '그 상황에서 가장 걱정되는 순간은 언제인가요?';

    final questionGoalText =
        askedMoment
            ? '사용자가 걱정하는 예상 결과를 하나 구체화한다.'
            : isSudResponse
            ? '$current이라고 답한 불안 정도를 짧게 인정하고, “${_withoutTerminalPunctuation(target)}”라고 느끼게 된 구체적인 계기를 하나 확인한다.'
            : '사용자가 걱정하는 상황의 구체적인 순간을 하나 확인한다.';

    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: questionGoalText,
      reflectionSentence: surfaceVariation.select(
        candidates: [
          '“${_withoutTerminalPunctuation(target)}”라고 느끼고 계시는군요.',
          '말씀을 들어보니 “${_withoutTerminalPunctuation(target)}”라는 부분이 마음에 걸리시는 것 같아요.',
          '지금은 “${_withoutTerminalPunctuation(target)}”라는 점이 가장 신경 쓰이시는군요.',
          '방금 하신 이야기가 계속 마음에 남아 있는 것 같아요.',
        ],
        recentMessages: recentMessages,
        seed: target,
        repetitionMarkers: const [
          '라고 느끼고 계시는군요',
          '말씀을 들어보니',
          '가장 신경 쓰이시는군요',
          '계속 마음에 남아 있는 것 같아요',
        ],
      ),
      questionSentence: question,
      forbidden: exploreForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidStageAdvance,
      ],
      requiredAct: DialogueAct.explore,
      userContextIds: const [],
      cbtContextIds: const [],
      allowedActsForTurn: allowedActsForTurn,
      realizationSpec: RealizationSpecBuilder.explore(
        decision: decision,
        askedMoment: askedMoment,
        isSudResponse: isSudResponse,
        questionGoal: questionGoalText,
        sudRatingValue: _extractSudValue(current),
      ),
    );
  }

  String _withoutTerminalPunctuation(String value) {
    return value.replaceFirst(RegExp(r'[.!?]+$'), '');
  }

  bool _isSudResponse(String value) {
    return RegExp(
      r'^(?:[0-9]|10)\s*(?:점|정도)?\s*(?:이에요|예요|입니다|요)?[.!]?$',
    ).hasMatch(value.trim());
  }

  /// Phase 10.5A.2 Track B: extracts a 0-10 rating from a short reply for
  /// the realization layer only — grounds `sudRatingValue` on
  /// [CounselingRealizationSpec] so a realizer can acknowledge the number
  /// the user just gave instead of ignoring it (found via the Phase 10.5A
  /// human review: real replies skipped acknowledging a bare SUD answer
  /// even when `recent_conversation` already showed the 0-10 question).
  ///
  /// Deliberately a separate, wider pattern from [_isSudResponse] — that
  /// method gates an existing wording *branch* and changing its match set
  /// would change which sentence template gets selected (a behavior
  /// change outside this track's scope). This one only feeds an additive
  /// semantic signal, so it can safely match more phrasings (e.g. "한
  /// 8점 정도요" — a leading "한"/"약" qualifier `_isSudResponse` doesn't
  /// match) without touching any existing branch/selection decision.
  int? _extractSudValue(String value) {
    final match = RegExp(r'(\d{1,2})\s*점').firstMatch(value.trim());
    if (match == null) return null;
    final parsed = int.tryParse(match.group(1)!);
    if (parsed == null || parsed < 0 || parsed > 10) return null;
    return parsed;
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect
  // ───────────────────────────────────────────────────────────────────

  static const List<String> reflectForbidden = [
    '행동 해결책을 제안하지 않는다.',
    '새로운 사실을 만들지 않는다.',
    '이미 답이 주어진 질문을 반복하지 않는다.',
    '다음 CBT 단계로 넘어가지 않는다.',
  ];

  /// Mirrors `DeterministicReflectTurnPlanner.plan`'s realization.
  CounselingTurnPlan reflect(
    CounselorDecision decision, {
    required List<CounselingMessage> recentMessages,
    required List<DialogueAct> allowedActsForTurn,
  }) {
    final target = _requireText(decision.reflectionTarget, 'reflect');

    if (decision.selectedAction == DialogueAct.explore) {
      // Clarify branch: no usable thought found yet.
      return CounselingTurnPlan(
        reflectionTarget: target,
        questionGoal: '아직 명확한 생각을 확인하지 못했으니 조금 더 구체적으로 묻는다.',
        reflectionSentence: _clarifyingReflectionSentence(
          target,
          recentMessages,
        ),
        questionSentence: _clarifyingQuestionSentence(recentMessages),
        forbidden: reflectForbidden,
        constraints: const [
          TurnConstraint.requireReflection,
          TurnConstraint.requireExactlyOneQuestion,
          TurnConstraint.forbidAdvice,
          TurnConstraint.forbidNewUserFacts,
          TurnConstraint.forbidStageAdvance,
        ],
        requiredAct: DialogueAct.explore,
        userContextIds: const [],
        cbtContextIds: const [],
        realizationSpec: RealizationSpecBuilder.reflectClarify(decision),
        // Phase 13.4: no usable thought yet, so reflect isn't done.
        stageProgress: StageProgress.inProgress,
      );
    }

    if (decision.goalExhaustionRecovery != null) {
      return _reflectRecovery(decision, target: target);
    }

    final goal = ReflectQuestionGoal.values.byName(decision.selectedGoalId!);
    final isFollowUp = goal != ReflectQuestionGoal.evidence;

    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: goal.goal,
      reflectionSentence:
          isFollowUp
              ? _followUpReflectionSentence(target, recentMessages)
              : _reflectionSentence(target, recentMessages),
      questionSentence: goal.question,
      forbidden: reflectForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidStageAdvance,
      ],
      requiredAct: DialogueAct.socraticQuestion,
      userContextIds: decision.usedFactIds,
      cbtContextIds: const [],
      allowedActsForTurn: allowedActsForTurn,
      progressGoalId: goal.name,
      realizationSpec: RealizationSpecBuilder.reflect(
        decision: decision,
        goal: goal,
      ),
      // Phase 13.4: goals are asked in order, so any goal after `evidence`
      // means the user has already answered at least one reflective goal —
      // enough material for intervention. The first goal question alone
      // isn't.
      stageProgress:
          isFollowUp ? StageProgress.complete : StageProgress.inProgress,
    );
  }

  /// Phase 11.3: goal-exhaustion recovery branch — every `ReflectQuestionGoal`
  /// has already been asked this reflect phase, so this turn takes an
  /// explicit recovery action instead of pursuing a (no longer available)
  /// goal. No `realizationSpec` yet: Remote Realizer is deliberately not
  /// invoked for recovery surfaces for now (deterministic only), matching
  /// `DeterministicProcessSignalTurnPlanner`'s same omission for its own
  /// "no new question" turns.
  CounselingTurnPlan _reflectRecovery(
    CounselorDecision decision, {
    required String target,
  }) {
    final clean = target.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    final String questionGoal;
    final String reflectionSentence;
    switch (decision.goalExhaustionRecovery!) {
      case GoalExhaustionRecovery.summarize:
        questionGoal = '새로운 질문 없이 지금까지 나눈 내용을 짧게 정리한다.';
        reflectionSentence =
            clean.isEmpty
                ? '지금까지 나눈 이야기를 여기서 한 번 정리하고 갈게요.'
                : '지금까지 “$clean”라는 이야기를 중심으로 함께 살펴봤어요. 여기서 한 번 정리하고 갈게요.';
      case GoalExhaustionRecovery.listenWithoutQuestion:
        questionGoal = '새로운 탐색 없이 지금 느끼시는 마음을 그대로 인정한다.';
        reflectionSentence = '말씀해 주신 내용 잘 듣고 있어요. 지금은 새로운 질문 없이, 지금 느끼시는 마음에 조금 더 머물러볼게요.';
      case GoalExhaustionRecovery.revisitPreviousIssue:
      case GoalExhaustionRecovery.transition:
      case GoalExhaustionRecovery.repeatLast:
        throw StateError(
          'TurnPlanMaterializer.reflect: '
          '${decision.goalExhaustionRecovery} is not yet implemented — '
          'Phase 11.3 scope freeze (see '
          'docs/counseling/phase11_1_selection_interaction_repair_design.md).',
        );
    }

    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: questionGoal,
      reflectionSentence: reflectionSentence,
      questionSentence: '',
      forbidden: reflectForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireNoQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      // Must not be `.summarize` (would trigger reflect->intervention
      // acceleration via `CounselingState._acceleratesFrom`) or
      // `.socraticQuestion` (implies a goal was pursued) — `.reflect` keeps
      // this turn's state progression on the ordinary turn-budget schedule
      // only, exactly like `DeterministicProcessSignalTurnPlanner`'s reason
      // for the same choice.
      requiredAct: DialogueAct.reflect,
      userContextIds: decision.usedFactIds,
      cbtContextIds: const [],
      goalExhaustionRecovery: decision.goalExhaustionRecovery,
      stageProgress: StageProgress.complete,
    );
  }

  String _clarifyingReflectionSentence(
    String target,
    List<CounselingMessage> recentMessages,
  ) {
    final clean = target.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    if (clean.isEmpty) {
      return surfaceVariation.select(
        candidates: const ['지금 조금 힘드신 것 같아요.', '말씀해 주신 부분을 조금 더 들어보고 싶어요.'],
        recentMessages: recentMessages,
        seed: target,
        repetitionMarkers: const ['조금 힘드신 것 같아요', '조금 더 들어보고 싶어요'],
      );
    }
    return surfaceVariation.select(
      candidates: [
        '“$clean”라고 말씀해 주셨네요.',
        '방금 말씀하신 내용이 계속 마음에 걸리시는 것 같네요.',
        '“$clean”라고 하셨군요.',
      ],
      recentMessages: recentMessages,
      seed: target,
      repetitionMarkers: const ['라고 말씀해 주셨네요', '계속 마음에 걸리시는 것 같네요', '라고 하셨군요'],
    );
  }

  String _clarifyingQuestionSentence(List<CounselingMessage> recentMessages) {
    return surfaceVariation.select(
      candidates: const [
        '지금 마음에 가장 걸리는 부분을 조금 더 구체적으로 이야기해 주실 수 있을까요?',
        '그 상황에서 어떤 생각이 스쳐 지나갔는지 조금 더 말씀해 주시겠어요?',
      ],
      recentMessages: recentMessages,
      seed: 'clarify',
      repetitionMarkers: const ['조금 더 구체적으로', '어떤 생각이 스쳐 지나갔는지'],
    );
  }

  String _reflectionSentence(
    String target,
    List<CounselingMessage> recentMessages,
  ) {
    var sentence = target.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    sentence = sentence
        .replaceAll('답을 못하면', '답하지 못하면')
        .replaceAll('것이다', '것 같다는 생각');
    sentence = sentence.replaceFirst(RegExp(r'것 같(?:아요|습니다|아)$'), '것 같다는 생각');
    sentence = sentence.replaceFirst(RegExp(r'생각이 들(?:어요|었어요|습니다)?$'), '생각');
    if (!sentence.endsWith('생각')) sentence = '$sentence라는 생각';
    return surfaceVariation.select(
      candidates: [
        '$sentence이 특히 걱정되는군요.',
        '지금 가장 마음에 걸리는 건 $sentence인 것 같아요.',
        '$sentence이 현재 걱정의 중심에 있는 것 같네요.',
      ],
      recentMessages: recentMessages,
      seed: target,
      repetitionMarkers: const ['특히 걱정되는군요', '지금 가장 마음에 걸리는 건', '현재 걱정의 중심에'],
    );
  }

  String _followUpReflectionSentence(
    String target,
    List<CounselingMessage> recentMessages,
  ) {
    final clean = target.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    return surfaceVariation.select(
      candidates: [
        '“$clean”라고 말씀해 주셨군요.',
        '그 이야기를 들으니 지금 느끼시는 마음이 더 잘 이해가 돼요.',
        '그 경험이 있어서 “$clean”라고 느끼시는군요.',
        '말씀하신 “$clean”라는 부분을 함께 살펴볼게요.',
      ],
      recentMessages: recentMessages,
      seed: target,
      repetitionMarkers: const [
        '라고 말씀해 주셨군요',
        '더 잘 이해가 돼요',
        '그 경험이 있어서',
        '함께 살펴볼게요',
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Intervention
  // ───────────────────────────────────────────────────────────────────

  static const List<String> interventionForbidden = [
    '새로운 CBT 기법을 제안하지 않는다.',
    '이완 기법으로 전환하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    '여러 개의 과제를 제시하지 않는다.',
  ];

  /// Mirrors `DeterministicInterventionTurnPlanner.plan`'s realization for
  /// the non-unavailable branch. Caller resolves the two "nothing to do"
  /// branches (see [CounselorDecision.reflectionTarget]'s null-vs-empty
  /// encoding note) before calling this.
  CounselingTurnPlan intervention(
    CounselorDecision decision, {
    required int currentWeek,
    required List<CbtKnowledgeItem> knowledge,
    List<CounselingMessage> recentMessages = const [],
    String userMessage = '',
  }) {
    // Phase 13.2: techniques are cumulative, so the policy is the one that
    // approves the selected item, which may be from an earlier week.
    final selected = knowledge.firstWhere(
      (item) => item.id == decision.selectedInterventionId,
    );
    // Callers that hand-build a decision around a non-registry item (surface
    // tests) keep the pre-13.2 contract: the current week's policy.
    final policy =
        registry.policyForItemId(selected.id) ??
        registry.policyForWeek(currentWeek)!;
    final target = _requireText(decision.reflectionTarget, 'intervention');

    final cleanTarget = target.replaceFirst(RegExp(r'[.!?]+$'), '');
    // Phase 13.6 (Q2): a behavior technique whose target is a worry rather
    // than a described behavior asks about behavior around that worry.
    final aboutWorry = _isBehaviorType(policy.interventionType) &&
        !InterventionEligibilityPredicates.looksLikeBehavior(target);
    final question = aboutWorry
        ? _worryAnchoredQuestionFor(policy.interventionType)
        : _questionFor(policy.interventionType);
    final plan = InterventionPlan(
      type: policy.interventionType,
      target: target,
      promptSentence: question,
      selectedCbtId: selected.id,
      forbidden: interventionForbidden,
      recommendation: activityPolicy.recommend(
        type: policy.interventionType,
        source: selected,
      ),
    );

    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: _goalFor(policy.interventionType),
      reflectionSentence: _withReflectAnswerAck(
        aboutWorry
            ? '“$cleanTarget”라는 걱정과 관련된 행동을 함께 살펴볼게요.'
            : _reflectionFor(policy.interventionType, cleanTarget),
        recentMessages: recentMessages,
        userMessage: userMessage,
      ),
      questionSentence: question,
      forbidden: interventionForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      requiredAct: DialogueAct.socraticQuestion,
      userContextIds: decision.usedFactIds,
      cbtContextIds: [selected.id],
      interventionPlan: plan,
      // Phase 13.3: the question was asked; the answer is still pending.
      interventionStep: InterventionStep.prompt,
      stageProgress: StageProgress.inProgress,
      realizationSpec: RealizationSpecBuilder.intervention(
        decision: decision,
        type: policy.interventionType,
        questionGoal: _goalFor(policy.interventionType),
        target: target,
      ),
    );
  }

  static const List<String> noEligibleForbidden = [
    '새로운 CBT 기법을 제안하지 않는다.',
    '새로운 사용자 사실을 만들지 않는다.',
    '새로운 상담 질문을 하지 않는다(마무리 제안만).',
  ];

  /// Phase 13.5: the closing proposal every intervention completion ends on.
  static const String closingProposalQuestion =
      '오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?';

  static const String _lowInfoAck = '바로 떠오르지 않아도 괜찮아요.';

  static final RegExp _lowInfoAnswer = RegExp(
    r'^(몰라|모르겠|잘\s*모르|글쎄|그냥|음+|네|응|아니)',
  );

  /// An answer that asks to stop rather than attempting the technique
  /// ("오늘은 여기까지 할게요"). Crediting it with a technique outcome would put
  /// words in the user's mouth.
  ///
  /// Phase 13.7 (D1): "다음에" and "그만" alone are not stop requests ("다음에
  /// 더 열심히 하면 돼" is a balanced thought, "그만큼" is not "그만"); they
  /// count only with a verb of stopping or postponing the talk.
  static final RegExp _wantsToStop = RegExp(
    r'(여기까지|그만\s*(할|하|둘|두|해)|마칠|마무리|끝낼|끝내|'
    r'다음에\s*(할게|하자|해요|이야기|얘기|말할))',
  );

  /// Phase 13.3: integrate the user's answer to the technique's question,
  /// then propose closing. The answer is acknowledged in the technique's own
  /// terms, never quoted verbatim, and no new technique or fact is added.
  /// A low-information answer ("모르겠어") gets a no-pressure acknowledgment.
  CounselingTurnPlan interventionIntegration(
    CounselorDecision decision, {
    required int currentWeek,
    required List<CbtKnowledgeItem> knowledge,
    required List<CounselingMessage> recentMessages,
  }) {
    final selected = knowledge.firstWhere(
      (item) => item.id == decision.selectedInterventionId,
    );
    final policy =
        registry.policyForItemId(selected.id) ??
        registry.policyForWeek(currentWeek)!;
    final answer = _requireText(decision.reflectionTarget, 'interventionIntegration');
    final lowInfo =
        _lowInfoAnswer.hasMatch(answer.trim()) || _wantsToStop.hasMatch(answer);
    // Phase 13.7 (E1): the prompt may already have opened with "바로 떠오르지
    // 않아도 괜찮아요" (a low-info reflect answer); don't say it twice in a row.
    final previousOpensSame = recentMessages.reversed
        .where((m) => !m.isUser)
        .take(1)
        .any((m) => m.text.startsWith(_lowInfoAck));
    final reflection =
        lowInfo
            ? '${previousOpensSame ? '지금 바로 답하기 어려우셔도 괜찮아요.' : _lowInfoAck} '
                '이렇게 한 번 생각해 보려고 한 것만으로도 충분히 의미가 있어요.'
            : _integrationFor(policy.interventionType);
    return CounselingTurnPlan(
      reflectionTarget: answer,
      questionGoal: '사용자의 답을 기법의 관점에서 짧게 인정하고 마무리를 제안한다.',
      reflectionSentence: reflection,
      questionSentence: closingProposalQuestion,
      forbidden: interventionForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      requiredAct: DialogueAct.reflect,
      userContextIds: const [],
      cbtContextIds: [selected.id],
      interventionStep: InterventionStep.integration,
      stageProgress: StageProgress.complete,
      closingStep: ClosingStep.proposed,
    );
  }

  String _integrationFor(InterventionType type) {
    switch (type) {
      case InterventionType.balancedThought:
        return '그렇게 보면 걱정되는 마음은 남아 있어도, 결과를 조금 더 현실적으로 바라볼 수 있겠네요.';
      case InterventionType.behaviorPatternReview:
        return '그 행동이 불안과 어떻게 이어져 있는지 스스로 살펴보신 것 자체가 중요한 관찰이에요.';
      case InterventionType.consequenceReview:
        return '당장의 안도감과 시간이 지난 뒤의 영향을 나눠서 보신 것이 앞으로의 선택에 도움이 될 수 있겠어요.';
      case InterventionType.gainLossReview:
        return '그 행동이 당장 주는 것과 대신 잃게 하는 것을 함께 따져 보신 게 의미 있어요.';
      case InterventionType.valueBasedChoice:
        throw StateError('아직 승인되지 않은 intervention type: $type');
      case InterventionType.maintenanceReview:
        return '이어갈 때와 상황을 구체적으로 정해 두신 것이 꾸준히 해 나가는 데 도움이 될 거예요.';
    }
  }

  /// Phase 13.2: noEligibleIntervention — no approved technique fits this
  /// turn. A brief, generic wrap-up of what was discussed, with no question
  /// and no technique. `DialogueAct.summarize` (never `unknown`), so the
  /// session progresses instead of looping (N1). It doesn't quote the user
  /// verbatim (see N6).
  CounselingTurnPlan interventionNoEligible(
    CounselorDecision decision, {
    required List<CounselingMessage> recentMessages,
    String userMessage = '',
  }) {
    final target = switch (decision.reflectionTarget) {
      ReflectionTargetText(:final value) => value,
      _ => '',
    };
    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: '새로운 방법을 제안하지 않고 오늘 나눈 이야기를 짧게 정리한다.',
      reflectionSentence: _withReflectAnswerAck(surfaceVariation.select(
        candidates: const [
          '지금은 새로운 방법을 더 제안하기보다, 오늘 이야기해 주신 걱정을 짧게 정리해 볼게요. 마음에 걸리는 부분을 차분히 살펴본 것만으로도 의미가 있어요.',
          '오늘은 새로운 방법보다, 지금까지 나눈 이야기를 정리하는 데 집중해 볼게요. 걱정되는 마음을 이렇게 말로 꺼내 보신 것도 중요한 한 걸음이에요.',
        ],
        recentMessages: recentMessages,
        seed: target,
        repetitionMarkers: const ['짧게 정리해 볼게요', '정리하는 데 집중해 볼게요'],
      ), recentMessages: recentMessages, userMessage: userMessage),
      questionSentence: closingProposalQuestion,
      forbidden: noEligibleForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      requiredAct: DialogueAct.summarize,
      userContextIds: const [],
      cbtContextIds: const [],
      interventionStep: InterventionStep.noEligible,
      stageProgress: StageProgress.complete,
      closingStep: ClosingStep.proposed,
    );
  }

  /// Mirrors `DeterministicInterventionTurnPlanner._unavailablePlan`. Used
  /// when `decision.isUnavailable && decision.reflectionTarget == null`.
  CounselingTurnPlan interventionUnavailable(
    String userMessage,
    List<CounselingMessage> recentMessages,
  ) {
    final target = userMessage.trim();
    final clean = target.replaceFirst(RegExp(r'[.!?]+$'), '');
    return CounselingTurnPlan(
      reflectionTarget: target,
      questionGoal: '승인된 CBT 근거가 준비될 때까지 현재 내용을 더 확인한다.',
      reflectionSentence:
          clean.isEmpty
              ? '말씀해 주신 내용을 계속 살펴보고 있습니다.'
              : surfaceVariation.select(
                candidates: [
                  '“$clean”라고 느끼고 계시는군요.',
                  '지금 하신 이야기, 계속 마음에 담아 듣고 있어요.',
                ],
                recentMessages: recentMessages,
                seed: target,
                repetitionMarkers: const ['라고 느끼고 계시는군요', '계속 마음에 담아 듣고 있어요'],
              ),
      questionSentence: '지금 떠오르는 생각이나 느낌을 조금 더 말씀해 주시겠어요?',
      forbidden: interventionForbidden,
      constraints: const [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      requiredAct: DialogueAct.unknown,
      userContextIds: const [],
      cbtContextIds: const [],
      planningStatus: TurnPlanningStatus.unavailable,
      realizationSpec: RealizationSpecBuilder.interventionUnavailable(target),
    );
  }

  bool _isBehaviorType(InterventionType type) =>
      type == InterventionType.behaviorPatternReview ||
      type == InterventionType.consequenceReview ||
      type == InterventionType.gainLossReview;

  String _worryAnchoredQuestionFor(InterventionType type) {
    switch (type) {
      case InterventionType.behaviorPatternReview:
        return '그 걱정이 들 때 보통 어떻게 하시는지 떠올려 보면, 피하는 쪽과 마주하는 쪽 중 어디에 더 가까운가요?';
      case InterventionType.consequenceReview:
        return '그 걱정이 들 때 주로 하게 되는 행동은 당장 불안을 얼마나 줄여주고, 시간이 지난 뒤에도 도움이 된다고 느끼시나요?';
      case InterventionType.gainLossReview:
        return '그 걱정 때문에 피하게 되는 일이 있다면, 피했을 때 당장 얻을 수 있는 좋은 점은 무엇인가요?';
      case InterventionType.balancedThought:
      case InterventionType.valueBasedChoice:
      case InterventionType.maintenanceReview:
        return _questionFor(type);
    }
  }

  /// Phase 13.6 (Q1): the turn that completes reflect still asks a
  /// reflective question, and the answer arrives here, in intervention.
  /// Acknowledge it (without quoting) before moving on, so it isn't
  /// silently dropped. The wording holds whatever the answer says, since
  /// its content isn't judged here. Only when reflect's goal question is the one being
  /// answered; repair turns in between are skipped.
  String _withReflectAnswerAck(
    String sentence, {
    required List<CounselingMessage> recentMessages,
    required String userMessage,
  }) {
    CounselingMessage? previous;
    for (final m in recentMessages.reversed) {
      if (m.isUser || m.interactionRepairReason != null) continue;
      previous = m;
      break;
    }
    final goalId = previous?.dialogueGoalId;
    final answer = userMessage.trim();
    if (goalId == null || answer.isEmpty || _wantsToStop.hasMatch(answer)) {
      return sentence;
    }
    final ack = _lowInfoAnswer.hasMatch(answer)
        ? _lowInfoAck
        : switch (ReflectQuestionGoal.values.asNameMap()[goalId]) {
            ReflectQuestionGoal.evidence => '그 걱정이 어디서 오는지 조금 더 알 것 같아요.',
            ReflectQuestionGoal.alternative => '말씀해 주신 생각도 함께 담아 둘게요.',
            ReflectQuestionGoal.probability => '말씀해 주신 느낌도 함께 담아 둘게요.',
            null => null,
          };
    return ack == null ? sentence : '$ack $sentence';
  }

  String _questionFor(InterventionType type) {
    switch (type) {
      case InterventionType.balancedThought:
        return '이 생각을 조금 더 균형 있게 바꾼다면 어떤 문장이 될 수 있을까요?';
      case InterventionType.behaviorPatternReview:
        return '그 행동은 불안을 피하려는 쪽과 마주하려는 쪽 중 어디에 더 가깝다고 느끼시나요?';
      case InterventionType.consequenceReview:
        return '그 행동이 당장은 불안을 얼마나 줄여주고, 시간이 지난 뒤에도 도움이 된다고 느끼시나요?';
      case InterventionType.gainLossReview:
        return '이 회피 행동을 했을 때 당장 얻을 수 있는 좋은 점은 무엇인가요?';
      case InterventionType.valueBasedChoice:
        throw StateError('아직 승인되지 않은 intervention type: $type');
      case InterventionType.maintenanceReview:
        return '이 방법을 앞으로도 이어가기 위해 가장 현실적으로 정할 수 있는 시간이나 상황은 언제인가요?';
    }
  }

  String _goalFor(InterventionType type) {
    switch (type) {
      case InterventionType.balancedThought:
        return '극단적인 예측을 단정하지 않고 조금 더 균형 잡힌 문장 하나를 만든다.';
      case InterventionType.behaviorPatternReview:
        return '현재 행동이 불안을 회피하는 행동인지 직면하는 행동인지 하나만 구분한다.';
      case InterventionType.consequenceReview:
        return '현재 행동의 단기적인 안도감과 장기적인 도움을 나누어 살펴본다.';
      case InterventionType.gainLossReview:
        return '회피 행동의 이득과 손실을 따지는 첫 단계로 즉각적인 이득 하나를 확인한다.';
      case InterventionType.valueBasedChoice:
        throw StateError('아직 승인되지 않은 intervention type: $type');
      case InterventionType.maintenanceReview:
        return '도움이 확인된 방법 하나를 언제 이어갈지 구체적으로 정한다.';
    }
  }

  String _reflectionFor(InterventionType type, String target) {
    switch (type) {
      case InterventionType.balancedThought:
        return '“$target”라는 생각을 함께 살펴보겠습니다.';
      case InterventionType.behaviorPatternReview:
        return '“$target”라는 행동을 하고 계시는군요.';
      case InterventionType.consequenceReview:
        return '“$target”라는 행동의 영향을 함께 살펴보겠습니다.';
      case InterventionType.gainLossReview:
        return '“$target”라는 회피 행동의 이득과 손실을 차례로 살펴보겠습니다.';
      case InterventionType.valueBasedChoice:
        throw StateError('아직 승인되지 않은 intervention type: $type');
      case InterventionType.maintenanceReview:
        return '“$target”와 관련해 앞으로 이어갈 계획을 함께 세워보겠습니다.';
    }
  }
}
