import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';

import '../../turn_plan.dart' show ReflectQuestionGoal;
import '../counselor_decision.dart';
import '../dialogue_progress_ledger.dart';

/// Phase 8.3B: the actual deterministic *selection* made by
/// `DeterministicReflectTurnPlanner.plan` — copied verbatim (not
/// reinterpreted) from `turn_plan.dart`. This is the single source of truth
/// for: (1) which [ReflectQuestionGoal] this turn pursues — or, once every
/// goal has been asked, which [GoalExhaustionRecovery] it takes instead
/// (Phase 11.3; see [ReflectGoalSelection]) — and (2) the 6-step
/// reflection-target priority search (explicit current thought >
/// substantive current message > recent explicit thought > diary thought >
/// substantive current message fallback > latest user message > raw
/// current text).
///
/// What stays OUT of this class (surface realization, kept inside
/// `DeterministicReflectTurnPlanner`/`TurnPlanMaterializer.reflect`): the
/// actual reflection/question sentence text and its rotation among
/// candidate phrasings.
///
/// Encoding note: unlike other states, Reflect never returns
/// `isUnavailable: true` for a "no plan produced" case — a reflect turn is
/// always producible (the normal socraticQuestion turn, the "clarify" turn
/// asking for more detail, or — once goals are exhausted — a recovery
/// turn). The clarify case is signaled by `selectedAction ==
/// DialogueAct.explore` and `selectedGoalId == null`; the recovery case by
/// `selectedAction == DialogueAct.reflect` and `goalExhaustionRecovery !=
/// null` (never `DialogueAct.summarize` — that would trigger
/// `CounselingState._acceleratesFrom`'s reflect->intervention
/// acceleration, which a recovery turn must not cause).
class ReflectDecisionSelector {
  const ReflectDecisionSelector();

  /// Goal usage order. Policy, not something the model or agent chooses.
  static const List<ReflectQuestionGoal> goalOrder = [
    ReflectQuestionGoal.evidence,
    ReflectQuestionGoal.alternative,
    ReflectQuestionGoal.probability,
  ];

  CounselorDecision select({
    required String userMessage,
    required List<CounselingMessage> recentMessages,
    required MindriumCounselingContext? userContext,
  }) =>
      _select(userMessage, recentMessages, userContext).decision;

  ({CounselorDecision decision, bool clarifyBranch}) _select(
    String userMessage,
    List<CounselingMessage> recentMessages,
    MindriumCounselingContext? userContext,
  ) {
    // Phase 13.7 (E3): a round reopened at closing is about a new worry, so
    // goals and content are read from the current round only.
    final roundMessages = UserThoughtExtractor.currentRound(recentMessages);
    final goalSelection = _selectGoalOrRecover(roundMessages);
    final isFollowUp = switch (goalSelection) {
      SelectedReflectGoal(:final goal) => goal != ReflectQuestionGoal.evidence,
      // Exhausted goals means this is never the first (evidence) question —
      // matches legacy repeatLast's `goalOrder.last != evidence` shape, so
      // reflection-target selection below is unaffected by this change.
      ExhaustedReflectGoals() => true,
    };
    // Content reads use the semantic view; goal/recovery bookkeeping above
    // still reads the full history.
    final content = UserThoughtExtractor.semanticContent(roundMessages);
    final currentText = userMessage.trim();
    final currentIsSubstantive = !UserThoughtExtractor.isLowInformation(currentText);

    // 반영 대상 우선순위:
    //   1. 현재 발화에 드러난 명시적 핵심 생각
    //   2. 현재 발화가 실질적인 상황/경험이면 그 내용
    //   3. 현재 발화가 숫자·필러일 때만 최근 명시적 생각
    //   4. 그래도 없을 때만 저장된 일기의 생각
    final explicitThought =
        isFollowUp ? null : UserThoughtExtractor.evaluativeThought(currentText);
    final currentHasOwnThought =
        UserThoughtExtractor.thoughtShaped(currentText) != null;
    final recentCandidate =
        !isFollowUp && explicitThought == null
            ? _explicitThoughtFromRecent(content)
            : null;
    final recentThought =
        recentCandidate != null &&
                (!currentIsSubstantive ||
                    !currentHasOwnThought ||
                    _sharesTopic(currentText, recentCandidate))
            ? recentCandidate
            : null;

    final selectedUserItem = UserThoughtExtractor.firstDiary(userContext);
    final diaryCandidate =
        !isFollowUp && explicitThought == null && recentThought == null
            ? UserThoughtExtractor.thoughtFromDiary(selectedUserItem?.text)
            : null;
    final diarySituation = UserThoughtExtractor.situationFromDiary(
      selectedUserItem?.text,
    );
    final diaryThought =
        diaryCandidate != null &&
                (!currentIsSubstantive ||
                    _sharesTopic(currentText, diaryCandidate) ||
                    (diarySituation != null &&
                        _sharesTopic(currentText, diarySituation)))
            ? diaryCandidate
            : null;

    // Phase 13.9D (a): the worry this round is about, wherever it was said
    // (often the opening message: "…망칠 것 같아"). Without it, a user who
    // stated the thought up front and then answered cooperatively kept
    // getting clarify questions.
    final roundThought =
        !isFollowUp &&
                explicitThought == null &&
                recentThought == null &&
                diaryThought == null &&
                !currentHasOwnThought
            ? UserThoughtExtractor.roundWorryThought(content)
            : null;

    final target =
        (isFollowUp && currentIsSubstantive ? currentText : null) ??
        explicitThought ??
        recentThought ??
        diaryThought ??
        roundThought ??
        (currentIsSubstantive ? currentText : null) ??
        // Phase 13.9A (D): never fall back to a non-answer ("몰라", "7점이요").
        // With nothing substantive, the target is empty and the clarify
        // question reflects nothing verbatim.
        UserThoughtExtractor.latestContentMessage(content) ??
        '';

    final hasRealThought =
        explicitThought != null ||
        recentThought != null ||
        diaryThought != null ||
        roundThought != null ||
        (!isFollowUp && UserThoughtExtractor.thoughtShaped(target) != null);

    if (!isFollowUp && !hasRealThought) {
      // Phase 14.3: the last turn was already a clarify question and this
      // reply brought nothing new, so asking the same kind of question again
      // repeats itself ("구체적인 계기는?" → "무슨 계기" → "구체적으로
      // 말씀해 주실 수 있을까요?"). Listen without a question instead; a
      // further reply without content ends in the no-progress wrap-up.
      if (DialogueProgressLedger.clarifyWouldRepeat(roundMessages, currentText)) {
        return (
          decision: CounselorDecision(
            selectedAction: DialogueAct.reflect,
            goalExhaustionRecovery: GoalExhaustionRecovery.listenWithoutQuestion,
            awaitingThought: true,
            reflectionTarget: ReflectionTarget.text(
              UserThoughtExtractor.latestContentMessage(content) ?? target,
            ),
          ),
          clarifyBranch: true,
        );
      }
      // Clarify branch: no usable thought found yet.
      return (
        decision: CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text(target),
        ),
        clarifyBranch: true,
      );
    }

    if (goalSelection is ExhaustedReflectGoals) {
      // Phase 11.3: every ReflectQuestionGoal already asked this reflect
      // phase — take an explicit recovery action instead of re-asking one.
      // `DialogueAct.reflect` (not `.socraticQuestion`, and specifically
      // not `.summarize`) is required here; see the class doc.
      // Phase 13.7 (E3): a low-info reply is never the thing summarized; the
      // round's worry is.
      final recoveryTarget = currentIsSubstantive
          ? target
          : UserThoughtExtractor.roundWorryThought(content) ?? target;
      return (
        decision: CounselorDecision(
        selectedAction: DialogueAct.reflect,
        goalExhaustionRecovery: _selectRecovery(recentMessages),
        reflectionTarget: ReflectionTarget.text(recoveryTarget),
        usedFactIds: diaryThought != null ? [selectedUserItem!.id] : const [],
      ),
        clarifyBranch: false,
      );
    }

    final goal = (goalSelection as SelectedReflectGoal).goal;
    return (
      decision: CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      selectedGoalId: goal.name,
      reflectionTarget: ReflectionTarget.text(target),
      usedFactIds: diaryThought != null ? [selectedUserItem!.id] : const [],
    ),
      clarifyBranch: false,
    );
  }

  /// Whether the clarify branch (see [select]'s doc) would trigger for this
  /// input, without computing the full selection. Used by
  /// `DeterministicPolicyBoundaryBuilder` to decide whether the reflect
  /// boundary must additionally allow [DialogueAct.explore] this turn.
  bool wouldClarify({
    required String userMessage,
    required List<CounselingMessage> recentMessages,
    required MindriumCounselingContext? userContext,
  }) {
    // The clarify branch (no usable thought yet), whether it asks or — when a
    // clarify would repeat — listens.
    return _select(userMessage, recentMessages, userContext).clarifyBranch;
  }

  /// 아직 하지 않은 질문 목표를 순서대로 고른다. 모두 소진되면
  /// [ExhaustedReflectGoals]를 반환한다 (Phase 11.3 — 예전
  /// `GoalExhaustionPolicy.repeatLast`의 "마지막 목표를 계속 반복" 동작을
  /// 대체).
  ReflectGoalSelection _selectGoalOrRecover(List<CounselingMessage> messages) {
    final askedIds =
        messages
            .where((message) => !message.isUser)
            .map((message) => message.dialogueGoalId)
            .whereType<String>()
            .toSet();

    for (final goal in goalOrder) {
      if (!askedIds.contains(goal.name)) return SelectedReflectGoal(goal);
    }
    return const ExhaustedReflectGoals();
  }

  /// Phase 11.3: which [GoalExhaustionRecovery] this turn takes, once goals
  /// are exhausted. Looks only at the immediately preceding message (the
  /// last turn) — never any earlier occurrence — per the design freeze: a
  /// repair acknowledgment from last turn (the user pointed out repetition,
  /// or asked to stop being asked things) means simply re-summarizing would
  /// itself repeat the pattern just complained about, so this picks the
  /// quieter [GoalExhaustionRecovery.listenWithoutQuestion] instead of the
  /// default [GoalExhaustionRecovery.summarize].
  GoalExhaustionRecovery _selectRecovery(List<CounselingMessage> messages) {
    final previous = messages.isNotEmpty ? messages.last : null;
    final previousRepair =
        previous != null && !previous.isUser
            ? previous.interactionRepairReason
            : null;
    final preferred = switch (previousRepair) {
      InteractionRepairReason.repeatedQuestion ||
      InteractionRepairReason.stopQuestioning =>
        GoalExhaustionRecovery.listenWithoutQuestion,
      InteractionRepairReason.processFrustration ||
      InteractionRepairReason.assistantNotUnderstood ||
      null =>
        GoalExhaustionRecovery.summarize,
    };
    // Phase 12.3C (F1): never the same recovery twice in a row. Read from
    // the previous turn's recovery metadata, not its text. The two
    // selectable recoveries simply alternate.
    final previousRecovery =
        previous != null && !previous.isUser
            ? previous.goalExhaustionRecovery
            : null;
    if (preferred != previousRecovery) return preferred;
    return preferred == GoalExhaustionRecovery.summarize
        ? GoalExhaustionRecovery.listenWithoutQuestion
        : GoalExhaustionRecovery.summarize;
  }

  String? _explicitThoughtFromRecent(List<CounselingMessage> messages) {
    for (final message in messages.reversed) {
      if (!message.isUser) continue;
      final thought = UserThoughtExtractor.evaluativeThought(message.text);
      if (thought != null) return thought;
    }
    return null;
  }

  bool _sharesTopic(String left, String right) {
    Set<String> words(String value) =>
        value
            .toLowerCase()
            .split(RegExp(r'[^0-9a-z가-힣]+'))
            .map(
              (word) => word.replaceFirst(
                RegExp(r'(?:은|는|이|가|을|를|에|에서|와|과|도|만)$'),
                '',
              ),
            )
            .where((word) => word.length >= 2)
            .toSet();

    final leftWords = words(left);
    final rightWords = words(right);
    return leftWords.any(rightWords.contains);
  }
}

/// Phase 11.3: the outcome of [ReflectDecisionSelector]'s per-turn goal
/// lookup — mirrors [ReflectionTarget]'s sealed-class pattern in
/// `counselor_decision.dart` for the same reason: a plain nullable
/// `ReflectQuestionGoal?` would leave "no goal because exhausted" and "no
/// goal because clarify branch" indistinguishable from the type alone.
sealed class ReflectGoalSelection {
  const ReflectGoalSelection();
}

/// A goal from [ReflectDecisionSelector.goalOrder] not yet asked this
/// reflect phase.
final class SelectedReflectGoal extends ReflectGoalSelection {
  final ReflectQuestionGoal goal;

  const SelectedReflectGoal(this.goal);
}

/// Every [ReflectQuestionGoal] has already been asked this reflect phase —
/// [ReflectDecisionSelector.select] must take an explicit
/// [GoalExhaustionRecovery] action instead of picking a goal.
final class ExhaustedReflectGoals extends ReflectGoalSelection {
  const ExhaustedReflectGoals();
}
