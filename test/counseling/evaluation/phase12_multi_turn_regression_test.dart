// Phase 12.2 — Multi-turn frozen evaluation. See
// docs/counseling/phase12_conversation_robustness.md.
//
// Each scenario runs 4-8 user turns sequentially through the real
// deterministic `CounselingHarness` (SafetyGate -> retrieval ->
// PolicyPipelineTurnPlanner -> StatePolicy), syncing `session.messages`
// the way `CounselingProvider` does with instant empathy off (history is
// appended after each turn). Metrics are computed from the turn trace.
//
// Detector misses on unseen meta expressions are NOT fixed here (Phase 12
// rule: failure -> reproduce -> classify -> frozen test -> root cause).
// They are frozen in [_knownDetectorMisses]; the suite fails if that set
// changes in either direction, so a later detector fix must update the
// corpus deliberately.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

Future<String> _load(String path) => File(path).readAsString();

enum _Kind {
  /// Ordinary worry content (includes repetition-about-life phrasing).
  content,

  /// Meta feedback using a phrasing the 11.2 detector was built from.
  metaSeen,

  /// Meta feedback using a phrasing the detector has never seen.
  metaUnseen,

  /// Low-information reply ("몰라요").
  lowInfo,

  /// Meta feedback that is only recognizable from context (e.g. restating
  /// one's own words with "~다고"). Reported, not gated.
  metaImplicit,
}

class _Turn {
  final String text;
  final _Kind kind;
  const _Turn(this.text, [this.kind = _Kind.content]);
  bool get isMeta => kind == _Kind.metaSeen || kind == _Kind.metaUnseen;
  bool get isImplicitMeta => kind == _Kind.metaImplicit;
}

class _Scenario {
  final String id;
  final String family;
  final CounselingState start;
  final List<CounselingMessage> seed;

  /// True when the scenario starts from a hand-built history rather than
  /// a natural checkIn start.
  final bool synthetic;

  /// Route explore/reflect through the real RemoteLlmRealizer backed by an
  /// adversarial API that always copies the previous assistant message
  /// (the N2 behavior seen on device).
  final bool copyingRealizer;
  final List<_Turn> turns;
  const _Scenario({
    required this.id,
    required this.family,
    required this.turns,
    this.start = CounselingState.checkIn,
    this.seed = const [],
    this.synthetic = false,
    this.copyingRealizer = false,
  });
}

class _Step {
  final _Turn turn;
  final CounselingState before;
  final CounselingState after;
  final int turnsInStateBefore;
  final CounselingMessage? reply;
  final Object? error;
  _Step(
    this.turn,
    this.before,
    this.after,
    this.turnsInStateBefore,
    this.reply,
    this.error,
  );
  bool get isRepairOrRecovery =>
      reply?.interactionRepairReason != null ||
      reply?.goalExhaustionRecovery != null;
  bool get asksQuestion => (reply?.text ?? '').contains('?');
}

CounselingMessage _goal(String goal, int i) => CounselingMessage(
  id: 'seed_${goal}_$i',
  role: 'assistant',
  text: 'goal:$goal',
  createdAt: DateTime(2026, 9, 1),
  dialogueAct: DialogueAct.socraticQuestion,
  dialogueGoalId: goal,
);

List<CounselingMessage> _exhaustedSeed(String tag) => [
  for (final (i, g) in ['evidence', 'alternative', 'probability'].indexed)
    _goal(g, i),
  CounselingMessage(
    id: 'seed_user_$tag',
    role: 'user',
    text: '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
    createdAt: DateTime(2026, 9, 1),
  ),
];

const _worry = '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.';

final _scenarios = <_Scenario>[
  // M1. Normal progression, natural start, all five states.
  const _Scenario(
    id: 'M1_natural_full_session',
    family: 'M1 normal progression',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('7점 정도요.'),
      _Turn(_worry),
      _Turn('예전에 발표하다 말이 막힌 적이 있어서요.'),
      _Turn('다르게 보면 한 번 실수한 걸로 무능하다고 하진 않을 것 같아요.'),
      _Turn('조금 더 균형 있게 생각해볼게요.'),
      _Turn('오늘은 여기까지 할게요.'),
    ],
  ),
  // M2. Goal exhaustion -> recovery -> follow-ups.
  _Scenario(
    id: 'M2_exhaustion_followups',
    family: 'M2 goal exhaustion',
    start: CounselingState.reflect,
    seed: _exhaustedSeed('m2'),
    synthetic: true,
    turns: const [
      _Turn('그래도 여전히 걱정돼요.'),
      _Turn('네, 그렇긴 한데 마음이 편해지진 않아요.'),
      _Turn('그 방법 한번 해볼게요.'),
      _Turn('고마워요.'),
    ],
  ),
  // M3. Repeated-question repair mid-reflect, seen phrasing (control).
  const _Scenario(
    id: 'M3a_repair_seen_phrase',
    family: 'M3 repeated-question repair',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('6점이요.'),
      _Turn(_worry),
      _Turn('아까도 물어봤잖아요.', _Kind.metaSeen),
      _Turn('네, 그냥 계속 걱정되긴 해요.'),
      _Turn('다르게 생각해볼 수도 있을 것 같아요.'),
    ],
  ),
  // M3. Same flow, unseen phrasings.
  const _Scenario(
    id: 'M3b_repair_unseen_phrases',
    family: 'M3 repeated-question repair',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('6점이요.'),
      _Turn(_worry),
      _Turn('우리 이 얘기 아까 하지 않았어요?', _Kind.metaUnseen),
      _Turn('그 질문 또 하는 거예요?', _Kind.metaUnseen),
      _Turn('네, 그냥 계속 걱정되긴 해요.'),
    ],
  ),
  // M3 on an exhausted reflect: repair then recovery must not loop.
  _Scenario(
    id: 'M3c_repair_on_exhausted_reflect',
    family: 'M3 repeated-question repair',
    start: CounselingState.reflect,
    seed: _exhaustedSeed('m3c'),
    synthetic: true,
    turns: const [
      _Turn('왜 같은 질문을 계속 해요?', _Kind.metaSeen),
      _Turn('네, 그냥 계속 걱정되긴 해요.'),
      _Turn('이거 전에 대답했던 것 같은데', _Kind.metaUnseen),
      _Turn('그래도 해볼게요.'),
    ],
  ),
  // M4. Stop-questioning, seen + unseen.
  const _Scenario(
    id: 'M4a_stop_questioning_seen',
    family: 'M4 stop-questioning',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('질문 그만하고 그냥 들어주세요.', _Kind.metaSeen),
      _Turn('발표 생각만 하면 속이 울렁거려요.'),
      _Turn('7점 정도요.'),
      _Turn(_worry),
    ],
  ),
  const _Scenario(
    id: 'M4b_stop_questioning_unseen',
    family: 'M4 stop-questioning',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('이제 질문은 좀 안 했으면 좋겠어요', _Kind.metaUnseen),
      _Turn('그냥 제 얘기만 들어주면 안 돼요?', _Kind.metaUnseen),
      _Turn('더 물어보는 건 지금 부담돼요', _Kind.metaUnseen),
      _Turn('발표 생각만 하면 속이 울렁거려요.'),
    ],
  ),
  // M5. Repetition in worry content must stay content.
  const _Scenario(
    id: 'M5_worry_repetition_not_meta',
    family: 'M5 false-positive guard',
    turns: [
      _Turn('요즘 같은 생각이 계속 반복돼요.'),
      _Turn('또 그런 실수를 할까 봐 걱정돼요.'),
      _Turn('매일 똑같은 일이 생기는 것 같아요.'),
      _Turn('아까도 그 사람이 비슷하게 말했어요.'),
      _Turn('계속 같은 장면이 떠올라요.'),
    ],
  ),
  // M6. Low-info replies on an exhausted reflect.
  _Scenario(
    id: 'M6_lowinfo_exhausted',
    family: 'M6 low-info + exhaustion',
    start: CounselingState.reflect,
    seed: _exhaustedSeed('m6'),
    synthetic: true,
    turns: const [
      _Turn('몰라요.', _Kind.lowInfo),
      _Turn('그냥요.', _Kind.lowInfo),
      _Turn('몰라요.', _Kind.lowInfo),
      _Turn('글쎄요.', _Kind.lowInfo),
    ],
  ),
  // M6 natural: low-info all the way from checkIn.
  const _Scenario(
    id: 'M6b_lowinfo_natural',
    family: 'M6 low-info + exhaustion',
    turns: [
      _Turn('그냥요.', _Kind.lowInfo),
      _Turn('몰라요.', _Kind.lowInfo),
      _Turn('그냥요.', _Kind.lowInfo),
      _Turn('몰라요.', _Kind.lowInfo),
      _Turn('글쎄요.', _Kind.lowInfo),
      _Turn('네.', _Kind.lowInfo),
    ],
  ),
  // M7. Repair exactly on reflect's budget-exhausting turn.
  const _Scenario(
    id: 'M7_repair_at_reflect_budget_edge',
    family: 'M7 state-budget boundary',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('7점이요.'),
      _Turn(_worry),
      _Turn('왜 똑같은 말을 반복하지?', _Kind.metaSeen),
      _Turn('네 알겠어요.'),
    ],
  ),
  // M8. Repair in reflect, then into intervention and closing.
  const _Scenario(
    id: 'M8_repair_then_intervention',
    family: 'M8 intervention boundary',
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('7점이요.'),
      _Turn(_worry),
      _Turn('또 같은 걸 물어보네요.', _Kind.metaSeen),
      _Turn('한 번 실수했다고 무능한 건 아닐 수도 있겠네요.'),
      _Turn('이런 거 한다고 뭐가 달라질까 싶어요.', _Kind.metaSeen),
      _Turn('그래도 해볼게요.'),
      _Turn('오늘은 여기까지 할게요.'),
    ],
  ),
];

/// Phase 12.3D extension set.
final _extensionScenarios = <_Scenario>[
  // Real dogfood sessions (12.1), replayed at week 4 (weeks 1-3 are N1,
  // Phase 13).
  const _Scenario(
    id: 'M9a_dogfood_s1',
    family: 'M9 dogfood replay',
    turns: [
      _Turn('내일 발표를 해야되는데 준비를 아직 못해서 불안해'),
      _Turn('7'),
      _Turn('준비를 못한게 티가나서 혼날 것 같아'),
      _Turn('저번주 발표때 정말 열심히 준비했는데도 부족하다고 혼났어'),
      _Turn('아까 말했잖아 지금 준비를 못해서 불안하다고', _Kind.metaUnseen),
      _Turn('빨리 집중해서 준비해야하는데 불안해서 집중이 잘 안돼'),
    ],
  ),
  const _Scenario(
    id: 'M9b_dogfood_s2',
    family: 'M9 dogfood replay',
    turns: [
      _Turn('다음주에 여행이 계획 되어있는데 같이가는 친구들이랑 어색해'),
      _Turn('6'),
      _Turn('재밌게 놀아야하는데 어색해서 서로 조금 불편하게 놀까봐 걱정돼'),
      _Turn('서로 불편할까봐 걱정된다고', _Kind.metaImplicit),
      _Turn('방금 말했잖아', _Kind.metaUnseen),
    ],
  ),
  const _Scenario(
    id: 'M9c_dogfood_s3',
    family: 'M9 dogfood replay',
    turns: [
      _Turn('내일 시험이 있어'),
      _Turn('4'),
      _Turn('내일 시험을 잘 못보면 어떡하지?'),
      _Turn('왜 똑같은 말을해?', _Kind.metaUnseen),
      _Turn('왜 똑같은 말 하냐고', _Kind.metaUnseen),
    ],
  ),
  // Holdback phrasings (not used to design the 12.3B detector).
  const _Scenario(
    id: 'M10a_holdback_repair',
    family: 'M10 holdback repair',
    turns: [
      _Turn('요즘 면접 때문에 잠을 잘 못 자요.'),
      _Turn('8점이요.'),
      _Turn('면접에서 대답을 못하면 떨어질 것 같아요.'),
      _Turn('이미 말씀드렸는데요', _Kind.metaUnseen),
      _Turn('그래도 면접 생각만 하면 긴장돼요.'),
      _Turn('조금 다르게 생각해볼게요.'),
    ],
  ),
  const _Scenario(
    id: 'M10b_holdback_stop',
    family: 'M10 holdback repair',
    turns: [
      _Turn('요즘 면접 때문에 잠을 잘 못 자요.'),
      _Turn('질문 말고 그냥 들어줘', _Kind.metaUnseen),
      _Turn('면접에서 대답을 못하면 떨어질 것 같아요.'),
      _Turn('이제 그만 물어봐', _Kind.metaUnseen),
      _Turn('그래도 해볼게요.'),
    ],
  ),
  // N2 worst case: every realization copies the previous assistant turn.
  const _Scenario(
    id: 'M11a_copying_realizer_s3',
    family: 'M11 N2 copying realizer',
    copyingRealizer: true,
    turns: [
      _Turn('내일 시험이 있어'),
      _Turn('4'),
      _Turn('내일 시험을 잘 못보면 어떡하지?'),
      _Turn('예전에 시험을 망친 적이 있어서요'),
      _Turn('조금 다르게 생각해볼게요'),
    ],
  ),
  const _Scenario(
    id: 'M11b_copying_realizer_repair',
    family: 'M11 N2 copying realizer',
    copyingRealizer: true,
    turns: [
      _Turn('요즘 발표 때문에 좀 불안해요.'),
      _Turn('7점이요.'),
      _Turn(_worry),
      _Turn('왜 똑같은 말을해?', _Kind.metaUnseen),
      _Turn('네, 그냥 계속 걱정되긴 해요.'),
    ],
  ),
];

class _CopyPreviousApi implements CounselingRealizeApi {
  static int calls = 0;

  @override
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs = const [],
    String? affect,
    String tone = 'warm, calm, concise',
    List<Map<String, String>> recentConversation = const [],
    List<String> allowedCbtFacts = const [],
    List<String> forbiddenBehaviors = const [],
    String promptVersion = 'remote-realizer-v1',
    Duration timeout = const Duration(seconds: 8),
    int? sudRatingValue,
  }) async {
    calls++;
    final previous = recentConversation.lastWhere(
      (m) => m['role'] == 'assistant',
      orElse: () => {'text': deterministicDraft},
    );
    return {
      'request_id': requestId,
      'reply': previous['text'],
      'chosen_act': requiredAct,
      'model': 'copy-previous-fake',
      'prompt_version': promptVersion,
      'latency_ms': 1,
    };
  }
}

/// Before-record (Phase 12.2): unseen meta expressions the 11.2 detector
/// missed. Phase 12.3B's detector detects all of them; kept for provenance.
// ignore: unused_element
const _knownDetectorMissesBefore12_3B = <String>{
  '우리 이 얘기 아까 하지 않았어요?',
  '그 질문 또 하는 거예요?',
  '이거 전에 대답했던 것 같은데',
  '이제 질문은 좀 안 했으면 좋겠어요',
  '그냥 제 얘기만 들어주면 안 돼요?',
  '더 물어보는 건 지금 부담돼요',
};

class _Metrics {
  int immediateSameGoalRepeat = 0;
  int repeatedRecoveryLoop = 0;
  int ignoredMetaFeedbackSeen = 0;
  int ignoredMetaFeedbackUnseen = 0;
  int metaFalsePositive = 0;
  int abnormalEarlyTransition = 0;
  int unauthorizedCbtDecision = 0;
  int validatorOrMaterializerFailure = 0;
  int deadEndConversation = 0;
  int maximumConsecutiveSameGoal = 0;
  int maximumConsecutiveSameRecovery = 0;

  /// Meta feedback given in closing, where the Hard Guard is off by design.
  int metaInClosingUnhandled = 0;

  /// Intervention/closing replies that quote a meta-feedback turn as the
  /// user's thought (e.g. restructuring "아까도 물어봤잖아요").
  int metaTextUsedAsTarget = 0;

  /// Subset of [metaTextUsedAsTarget] where the quoted turn WAS detected
  /// (its reply carried interactionRepairReason). Phase 12.3A gate: 0.
  int metaContentLeakage = 0;

  /// The rest: the quoted turn was never detected (F2 miss or closing, F5),
  /// so there is no metadata to exclude it by.
  int untaggedMetaLeakage = 0;

  /// Intervention/closing replies that quote a low-info turn ("몰라요").
  int lowInfoTextUsedAsTarget = 0;
  final missedUnseen = <String>{};
  final targetedMeta = <String>{};

  /// Phase 12.3D (N2): assistant replies shown to the user that repeat the
  /// previous assistant message's question.
  int repeatedQuestionShown = 0;

  /// F6: the exact same assistant text twice in a row (e.g. the repair
  /// acknowledgment repeated after a second complaint).
  int consecutiveIdenticalReply = 0;
  int implicitMetaDetected = 0;
  int implicitMetaTotal = 0;

  Map<String, Object> toJson() => {
    'immediateSameGoalRepeat': immediateSameGoalRepeat,
    'repeatedRecoveryLoop': repeatedRecoveryLoop,
    'ignoredMetaFeedback_seen': ignoredMetaFeedbackSeen,
    'ignoredMetaFeedback_unseen': ignoredMetaFeedbackUnseen,
    'metaFalsePositive': metaFalsePositive,
    'abnormalEarlyTransition': abnormalEarlyTransition,
    'unauthorizedCbtDecision': unauthorizedCbtDecision,
    'validatorOrMaterializerFailure': validatorOrMaterializerFailure,
    'deadEndConversation': deadEndConversation,
    'maximumConsecutiveSameGoal': maximumConsecutiveSameGoal,
    'maximumConsecutiveSameRecovery': maximumConsecutiveSameRecovery,
    'metaInClosingUnhandled': metaInClosingUnhandled,
    'metaTextUsedAsTarget': metaTextUsedAsTarget,
    'metaContentLeakage': metaContentLeakage,
    'untaggedMetaLeakage': untaggedMetaLeakage,
    'lowInfoTextUsedAsTarget': lowInfoTextUsedAsTarget,
    'repeatedQuestionShown': repeatedQuestionShown,
    'consecutiveIdenticalReply': consecutiveIdenticalReply,
    'implicitMeta': '$implicitMetaDetected/$implicitMetaTotal',
  };
}

const _policy = CounselingStatePolicy();

String? _lastQuestion(String text) {
  final ms = RegExp(r'[^.!?\n]*\?').allMatches(text).toList();
  if (ms.isEmpty) return null;
  return ms.last.group(0)!.replaceAll(RegExp(r'[\s.,!?“”"‘’]'), '');
}

void _score(_Scenario s, List<_Step> steps, _Metrics m) {
  final asked = <String>{
    for (final msg in s.seed)
      if (!msg.isUser && msg.dialogueGoalId != null) msg.dialogueGoalId!,
  };
  String? prevGoal;
  GoalExhaustionRecovery? prevRecovery;
  var goalRun = 0;
  var recoveryRun = 0;

  for (final step in steps) {
    final reply = step.reply;
    if (step.error != null || reply == null) {
      m.validatorOrMaterializerFailure++;
      continue;
    }

    final goal = reply.dialogueGoalId;
    if (goal != null && asked.contains(goal)) m.immediateSameGoalRepeat++;
    if (goal != null) asked.add(goal);
    goalRun = goal != null && goal == prevGoal ? goalRun + 1 : (goal == null ? 0 : 1);
    if (goalRun > m.maximumConsecutiveSameGoal) m.maximumConsecutiveSameGoal = goalRun;
    prevGoal = goal;

    final rec = reply.goalExhaustionRecovery;
    if (rec != null && rec == prevRecovery) m.repeatedRecoveryLoop++;
    recoveryRun = rec != null && rec == prevRecovery ? recoveryRun + 1 : (rec == null ? 0 : 1);
    if (recoveryRun > m.maximumConsecutiveSameRecovery) {
      m.maximumConsecutiveSameRecovery = recoveryRun;
    }
    prevRecovery = rec;

    final repaired = reply.interactionRepairReason != null;
    if (step.turn.isMeta && !repaired) {
      if (step.before == CounselingState.closing) {
        m.metaInClosingUnhandled++;
      } else if (step.turn.kind == _Kind.metaSeen) {
        m.ignoredMetaFeedbackSeen++;
      } else {
        m.ignoredMetaFeedbackUnseen++;
        m.missedUnseen.add(step.turn.text);
      }
    }
    if (step.turn.isImplicitMeta) {
      m.implicitMetaTotal++;
      if (repaired) m.implicitMetaDetected++;
    } else if (!step.turn.isMeta && repaired) {
      m.metaFalsePositive++;
    }
    final i = steps.indexOf(step);
    final previousReply = i > 0 ? steps[i - 1].reply : null;
    final q = _lastQuestion(reply.text);
    if (previousReply != null && q != null && q == _lastQuestion(previousReply.text)) {
      m.repeatedQuestionShown++;
    }
    if (previousReply != null && previousReply.text == reply.text) {
      m.consecutiveIdenticalReply++;
    }

    // A repair/recovery turn may only move state when the ordinary budget
    // would have moved it anyway.
    if (step.isRepairOrRecovery && step.after != step.before) {
      final budgetDone =
          step.turnsInStateBefore + 1 >= _policy.budgetFor(step.before);
      if (!budgetDone) m.abnormalEarlyTransition++;
    }

    if (reply.referencedCbtIds.isNotEmpty &&
        step.before != CounselingState.intervention) {
      m.unauthorizedCbtDecision++;
    }

    if (step.before == CounselingState.intervention ||
        step.before == CounselingState.closing) {
      for (final prior in steps.take(steps.indexOf(step) + 1)) {
        if (prior.turn.kind == _Kind.content) continue;
        final quoted = prior.turn.text.replaceFirst(RegExp(r'[.!?]+$'), '');
        if (!reply.text.contains('“$quoted')) continue;
        if (prior.turn.isMeta) {
          m.metaTextUsedAsTarget++;
          m.targetedMeta.add('${s.id}: ${prior.turn.text}');
          if (prior.reply?.interactionRepairReason != null) {
            m.metaContentLeakage++;
          } else {
            m.untaggedMetaLeakage++;
          }
        } else {
          m.lowInfoTextUsedAsTarget++;
        }
      }
    }
  }

  // Dead end: after the last repair/recovery turn, at least two more turns
  // happened and none of them asked, advanced state, or picked a goal.
  final lastRepair = steps.lastIndexWhere((s) => s.isRepairOrRecovery);
  if (lastRepair >= 0) {
    final tail = steps.sublist(lastRepair + 1);
    if (tail.length >= 2) {
      final progressed = tail.any(
        (t) =>
            t.asksQuestion ||
            t.after != t.before ||
            t.reply?.dialogueGoalId != null ||
            t.after == CounselingState.closing,
      );
      if (!progressed) m.deadEndConversation++;
    }
  }
}

void main() {
  late LocalCbtKnowledgeRepository repository;
  final traces = <String, List<_Step>>{};
  final metrics = _Metrics();

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: _load);
    await repository.initialize();

    for (final s in [..._scenarios, ..._extensionScenarios]) {
      final harness = s.copyingRealizer
          ? CounselingHarness.remoteGpt(
              llm: MockLlmService(),
              safetyGate: const KeywordSafetyGate(),
              knowledgeRepository: repository,
              responseRealizer: RemoteLlmRealizer(api: _CopyPreviousApi()),
              rolloutConfig: const RolloutConfig(
                enabled: true,
                stage: RolloutStage.internalOnly,
              ),
              isInternalAccount: true,
            )
          : CounselingHarness.deterministic(
              llm: MockLlmService(),
              safetyGate: const KeywordSafetyGate(),
              knowledgeRepository: repository,
            );
      final session = CounselingSessionState(
        sessionId: s.id,
        currentWeek: 4,
        state: s.start,
        messages: [
          CounselingMessage(
            id: '${s.id}_greeting',
            role: 'assistant',
            text: '안녕하세요. 오늘 어떤 이야기를 나누고 싶으신가요?',
            createdAt: DateTime(2026, 9, 1),
          ),
          ...s.seed,
        ],
      );
      final steps = <_Step>[];
      for (final (i, turn) in s.turns.indexed) {
        final before = session.state;
        final turnsBefore = session.turnsInCurrentState;
        CounselingMessage? reply;
        Object? error;
        try {
          final result = await harness.handleTurn(
            session: session,
            userMessage: turn.text,
          );
          reply = result.assistantMessage;
        } catch (e) {
          error = e;
        }
        session.messages.add(
          CounselingMessage(
            id: '${s.id}_u$i',
            role: 'user',
            text: turn.text,
            createdAt: DateTime(2026, 9, 1),
          ),
        );
        if (reply != null) session.messages.add(reply);
        steps.add(_Step(turn, before, session.state, turnsBefore, reply, error));
      }
      traces[s.id] = steps;
      _score(s, steps, metrics);
    }

    final all = [..._scenarios, ..._extensionScenarios];
    final report = {
      'scenarios': all.length,
      'userTurns': all.fold<int>(0, (n, s) => n + s.turns.length),
      'metrics': metrics.toJson(),
      'missedUnseen': metrics.missedUnseen.toList()..sort(),
      'traces': {
        for (final e in traces.entries)
          e.key: [
            for (final t in e.value)
              '${t.before.name}->${t.after.name} '
                  '| goal=${t.reply?.dialogueGoalId} '
                  'rec=${t.reply?.goalExhaustionRecovery?.name} '
                  'repair=${t.reply?.interactionRepairReason?.name} '
                  '| ${t.turn.text} => ${t.reply?.text ?? t.error}',
          ],
      },
    };
    // ignore: avoid_print
    print('PHASE12_REPORT ${const JsonEncoder.withIndent('  ').convert(report)}');
  });

  test('suite covers the 8 base families (+ extension) and all five states', () {
    expect(_scenarios.map((s) => s.family).toSet(), hasLength(8));
    expect(_extensionScenarios.map((s) => s.family).toSet(), hasLength(3));
    final states = {
      for (final steps in traces.values)
        for (final t in steps) ...[t.before, t.after],
    };
    expect(states, CounselingState.values.toSet());
    for (final s in [..._scenarios, ..._extensionScenarios]) {
      expect(s.turns.length, inInclusiveRange(4, 8), reason: s.id);
    }
  });

  test('N2: copying realizer was really exercised, and no repeat reached the user', () {
    expect(_CopyPreviousApi.calls, greaterThanOrEqualTo(4));
    expect(metrics.repeatedQuestionShown, 0);
  });

  test('F6: no assistant reply is shown twice in a row', () {
    expect(metrics.consecutiveIdenticalReply, 0);
  });

  test('invariants that hold today stay at zero', () {
    expect(metrics.immediateSameGoalRepeat, 0);
    expect(metrics.ignoredMetaFeedbackSeen, 0);
    expect(metrics.metaFalsePositive, 0);
    expect(metrics.abnormalEarlyTransition, 0);
    expect(metrics.unauthorizedCbtDecision, 0);
    expect(metrics.validatorOrMaterializerFailure, 0);
    expect(metrics.deadEndConversation, 0);
    expect(metrics.maximumConsecutiveSameGoal, lessThanOrEqualTo(1));
  });

  // Known failures, frozen at their current values (not fixed in 12.2).
  // Each must change deliberately, together with the failure corpus in
  // docs/counseling/phase12_conversation_robustness.md.
  group('frozen known failures', () {
    // Phase 12.2 value was 2 / 2 (M2, M6: summarize -> summarize).
    test('F1 fixed (12.3C): no consecutive identical recovery', () {
      expect(metrics.repeatedRecoveryLoop, 0);
      expect(metrics.maximumConsecutiveSameRecovery, 1);
    });

    test('F2 fixed (12.3B): no unseen meta expression is missed in multi-turn', () {
      expect(metrics.missedUnseen, isEmpty);
      expect(metrics.ignoredMetaFeedbackUnseen, 0);
    });

    // Phase 12.2 value, kept as the before-record:
    //   M3a 아까도 물어봤잖아요. / M3b 우리 이 얘기 아까 하지 않았어요? /
    //   M3c 이거 전에 대답했던 것 같은데 / M7 왜 똑같은 말을 반복하지? /
    //   M8 또 같은 걸 물어보네요. / M8 이런 거 한다고 뭐가 달라질까 싶어요.
    // Phase 12.3A excluded every detected repair utterance; what is left is
    // only undetected meta (F2 misses, F5 closing).
    test('F3 detected repair utterances never become semantic targets', () {
      expect(metrics.metaContentLeakage, 0);
    });

    // 12.3A residue was 3 (M3b, M3c from F2 misses; M8 from closing). With
    // F2 fixed in 12.3B, only the closing case (F5, by design) remains.
    test('F3 residue: only closing meta (F5) still leaks', () {
      expect(metrics.untaggedMetaLeakage, 1);
      expect(metrics.targetedMeta, {
        'M8_repair_then_intervention: 이런 거 한다고 뭐가 달라질까 싶어요.',
      });
    });

    test('F4 low-info reply quoted as the intervention/closing target', () {
      expect(metrics.lowInfoTextUsedAsTarget, 5);
    });

    test('F5 meta feedback in closing is not handled (Hard Guard off by design)', () {
      expect(metrics.metaInClosingUnhandled, 1);
    });
  });

  // Single-turn probe of the Phase 12.1 example expressions (reflect state,
  // empty history). Before 12.3B all 11 were missed. After 12.3B the 9
  // explicit ones are detected; the 2 implicit ones are still missed
  // (frozen), and no worry-repetition sentence is misdetected.
  group('F2b single-turn probe of 12.1 example expressions', () {
    const unseenMeta = [
      '우리 이 얘기 아까 하지 않았어요?',
      '계속 비슷한 것만 묻는 느낌인데요',
      '그 질문 또 하는 거예요?',
      '이거 전에 대답했던 것 같은데',
      '아까랑 질문이 거의 같은데요',
      '계속 같은 데서 맴도는 느낌이에요',
      '또 그 질문이에요?',
      '이제 질문은 좀 안 했으면 좋겠어요',
      '그냥 제 얘기만 들어주면 안 돼요?',
      '더 물어보는 건 지금 부담돼요',
      '굳이 답을 찾기보다 그냥 말하고 싶어요',
    ];
    const worryRepetition = [
      '요즘 같은 생각이 계속 반복돼요',
      '또 그런 실수를 할까 봐 걱정돼요',
      '매일 똑같은 일이 생기는 것 같아요',
      '아까도 그 사람이 비슷하게 말했어요',
      '계속 같은 장면이 떠올라요',
    ];
    InteractionRepairReason? detect(String m) => const PolicyPipelineTurnPlanner()
        .plan(TurnPlanningContext(
          state: CounselingState.reflect,
          userMessage: m,
          knowledge: const [],
        ))
        ?.interactionRepairReason;

    const stillMissedImplicit = {
      '계속 같은 데서 맴도는 느낌이에요',
      '굳이 답을 찾기보다 그냥 말하고 싶어요',
    };
    for (final m in unseenMeta) {
      if (stillMissedImplicit.contains(m)) {
        test('implicit, still missed (frozen): $m', () => expect(detect(m), isNull));
      } else {
        test('detected after 12.3B: $m', () => expect(detect(m), isNotNull));
      }
    }
    for (final m in worryRepetition) {
      test('no false positive: $m', () => expect(detect(m), isNull));
    }
  });
}
