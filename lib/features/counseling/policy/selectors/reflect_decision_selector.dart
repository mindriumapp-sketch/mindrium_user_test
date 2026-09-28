import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';

import '../../turn_plan.dart' show ReflectQuestionGoal;
import '../counselor_decision.dart';

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
  }) {
    final goalSelection = _selectGoalOrRecover(recentMessages);
    final isFollowUp = switch (goalSelection) {
      SelectedReflectGoal(:final goal) => goal != ReflectQuestionGoal.evidence,
      // Exhausted goals means this is never the first (evidence) question —
      // matches legacy repeatLast's `goalOrder.last != evidence` shape, so
      // reflection-target selection below is unaffected by this change.
      ExhaustedReflectGoals() => true,
    };
    final currentText = userMessage.trim();
    final currentIsSubstantive = !_isLowInformationReply(currentText);

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
            ? _explicitThoughtFromRecent(recentMessages)
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

    final target =
        (isFollowUp && currentIsSubstantive ? currentText : null) ??
        explicitThought ??
        recentThought ??
        diaryThought ??
        (currentIsSubstantive ? currentText : null) ??
        UserThoughtExtractor.latestUserMessage(recentMessages) ??
        currentText;

    final hasRealThought =
        explicitThought != null ||
        recentThought != null ||
        diaryThought != null ||
        (!isFollowUp && UserThoughtExtractor.thoughtShaped(target) != null);

    if (!isFollowUp && !hasRealThought) {
      // Clarify branch: no usable thought found yet.
      return CounselorDecision(
        selectedAction: DialogueAct.explore,
        reflectionTarget: ReflectionTarget.text(target),
      );
    }

    if (goalSelection is ExhaustedReflectGoals) {
      // Phase 11.3: every ReflectQuestionGoal already asked this reflect
      // phase — take an explicit recovery action instead of re-asking one.
      // `DialogueAct.reflect` (not `.socraticQuestion`, and specifically
      // not `.summarize`) is required here; see the class doc.
      return CounselorDecision(
        selectedAction: DialogueAct.reflect,
        goalExhaustionRecovery: _selectRecovery(recentMessages),
        reflectionTarget: ReflectionTarget.text(target),
        usedFactIds: diaryThought != null ? [selectedUserItem!.id] : const [],
      );
    }

    final goal = (goalSelection as SelectedReflectGoal).goal;
    return CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      selectedGoalId: goal.name,
      reflectionTarget: ReflectionTarget.text(target),
      usedFactIds: diaryThought != null ? [selectedUserItem!.id] : const [],
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
    final decision = select(
      userMessage: userMessage,
      recentMessages: recentMessages,
      userContext: userContext,
    );
    return decision.selectedAction == DialogueAct.explore;
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
    return switch (previousRepair) {
      InteractionRepairReason.repeatedQuestion ||
      InteractionRepairReason.stopQuestioning =>
        GoalExhaustionRecovery.listenWithoutQuestion,
      InteractionRepairReason.processFrustration || null =>
        GoalExhaustionRecovery.summarize,
    };
  }

  String? _explicitThoughtFromRecent(List<CounselingMessage> messages) {
    for (final message in messages.reversed) {
      if (!message.isUser) continue;
      final thought = UserThoughtExtractor.evaluativeThought(message.text);
      if (thought != null) return thought;
    }
    return null;
  }

  bool _isLowInformationReply(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s.!?]+'), '');
    if (compact.isEmpty) return true;
    if (RegExp(r'^(?:[0-9]|10)(?:점|정도)?(?:이에요|예요|입니다|요)?$').hasMatch(compact)) {
      return true;
    }
    return const {
      '네',
      '아니요',
      '맞아요',
      '모르겠어요',
      '잘모르겠어요',
      '그냥요',
      '글쎄요',
    }.contains(compact);
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
