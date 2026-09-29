// Phase 13.9: session-flow scoring shared by the known-failure regression
// suite (13.9A) and the frozen adversarial holdout (13.9B). A scenario
// driver records what the simulated user *meant* by each turn ([Intent]);
// the scorer compares that with what the counselor did. See
// docs/counseling/phase13_status_and_plan.md.
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';

/// What the simulated user meant by a turn. Ground truth for scoring; the
/// counselor never sees it.
enum Intent {
  /// Worry content or an attempt to answer.
  content,

  /// No content: "몰라", "응", "잘 모르겠어".
  nonAnswer,

  /// About the conversation itself: repetition complaints, "I don't
  /// understand you", "stop asking".
  meta,

  /// Wants to keep talking at a closing proposal.
  continueTalking,

  /// Agrees to wrap up at a closing proposal.
  wrapUp,

  /// Meta and worry content in one utterance ("그 질문 이해 안 가요 근데
  /// 면접날 머리 하얘질까 봐 걱정돼요"). Either repairing it or taking the
  /// content is acceptable, so detector metrics skip it.
  mixed,
}

class FlowStep {
  final String user;
  final Intent intent;
  final CounselingState before;
  final CounselingState after;
  final CounselingMessage reply;

  /// Whether the router let this turn reach the remote realizer.
  final bool remoteAllowed;

  const FlowStep({
    required this.user,
    required this.intent,
    required this.before,
    required this.after,
    required this.reply,
    required this.remoteAllowed,
  });
}

class FlowRun {
  final String id;
  final int week;
  final List<FlowStep> steps;
  const FlowRun(this.id, this.week, this.steps);
}

/// The Phase 13 gate metrics. All must be 0.
const flowGateMetrics = [
  // 13.6
  'interventionDeadlock',
  'prematureClosing',
  'interventionResponseDropped',
  'futureWeekTechniqueLeakage',
  'unauthorizedCbt',
  'noEligibleInterventionDeadlock',
  'closingContinuationIgnored',
  'sessionCompletedTooEarly',
  'stateLoop',
  'sessionNotFinalized',
  // 13.9
  'nonAnswerCredited',
  'metaAsTarget',
  'remoteOnRepair',
  'repeatedClarifyRun',
  'deadTurnStatement',
];

/// Reported separately, as detector coverage: a meta turn outside closing
/// that got no repair (metaIgnored), and a content turn outside closing
/// that got one (metaFalsePositive). Both must be 0 on the 13.9A dev set;
/// on the holdout they are measured, not gated.
const flowDetectorMetrics = ['metaIgnored', 'metaFalsePositive'];

class FlowMetrics {
  final counts = <String, int>{
    for (final m in [...flowGateMetrics, ...flowDetectorMetrics]) m: 0,
  };
  final failures = <String, List<String>>{};

  void hit(String metric, FlowRun run, String detail) {
    counts[metric] = counts[metric]! + 1;
    (failures[metric] ??= []).add('${run.id}: $detail');
  }
}

const _policy = CounselingStatePolicy();
const _registry = ApprovedInterventionRegistry();
/// Integration openings that claim no technique outcome.
const _lowInfoAcks = [
  '바로 떠오르지 않아도 괜찮아요',
  '지금 바로 답하기 어려우셔도 괜찮아요',
  '말씀해 주셔서 고마워요. 이렇게 함께 살펴본 것만으로도',
];

/// Asks something: a question, or an explicit invitation to speak ("편하게
/// 말씀해 주세요").
bool _asks(CounselingMessage m) {
  final t = m.text.trim();
  return t.endsWith('?') ||
      RegExp(r'(말씀해|이야기해|얘기해|적어)\s*주세요[.!]?$').hasMatch(t);
}

/// Repairs that deliberately don't ask: they acknowledge and wait.
bool _intentionalListen(CounselingMessage m) =>
    const {
      InteractionRepairReason.stopQuestioning,
      InteractionRepairReason.repeatedQuestion,
      InteractionRepairReason.processFrustration,
    }.contains(m.interactionRepairReason) ||
    m.goalExhaustionRecovery == GoalExhaustionRecovery.listenWithoutQuestion;

bool _isRepairLike(CounselingMessage m) =>
    m.interactionRepairReason != null ||
    m.goalExhaustionRecovery != null ||
    m.earlyWrapUp != null;

CounselingMessage? _previousSubstantive(List<FlowStep> steps, int i) {
  for (var j = i - 1; j >= 0; j--) {
    if (steps[j].reply.interactionRepairReason == null) return steps[j].reply;
  }
  return null;
}

void scoreFlow(FlowRun run, FlowMetrics m) {
  final steps = run.steps;
  final approvedWeek = {for (final p in _registry.policies) p.requiredId: p.week};

  var interventionRun = 0;
  var sameStateRun = 0;
  var reopenCount = 0;
  var outcomeSeen = false;
  var noEligibleSinceReopen = 0;
  var clarifyRun = 0;

  for (final (i, s) in steps.indexed) {
    final r = s.reply;
    final prev = i > 0 ? steps[i - 1].reply : null;

    // ── 13.6 metrics ──────────────────────────────────────────────────
    for (final id in r.referencedCbtIds) {
      final week = approvedWeek[id];
      if (week == null) {
        m.hit('unauthorizedCbt', run, 'unapproved $id');
      } else if (week > run.week) {
        m.hit('futureWeekTechniqueLeakage', run, '$id (week $week)');
      }
    }
    if (r.referencedCbtIds.isNotEmpty && s.before != CounselingState.intervention) {
      m.hit('unauthorizedCbt', run, 'CBT id in ${s.before.name}');
    }

    if (s.before == CounselingState.intervention) {
      interventionRun++;
      if (interventionRun > _policy.budgetFor(CounselingState.intervention)) {
        m.hit('interventionDeadlock', run, 'intervention run $interventionRun');
      }
      if (r.dialogueAct == DialogueAct.unknown) {
        m.hit('interventionDeadlock', run, 'unknown act at turn $i');
      }
    } else {
      interventionRun = 0;
    }

    final pending = _previousSubstantive(steps, i);
    final answersPrompt = pending?.interventionStep == InterventionStep.prompt &&
        s.before == CounselingState.intervention;
    if (answersPrompt &&
        s.intent == Intent.content &&
        r.interactionRepairReason == null &&
        r.interventionStep != InterventionStep.integration) {
      m.hit('interventionResponseDropped', run, '"${s.user}" -> ${r.text}');
    }

    if (r.interventionStep == InterventionStep.integration ||
        r.interventionStep == InterventionStep.noEligible ||
        r.earlyWrapUp != null) {
      outcomeSeen = true;
    }

    if (r.interventionStep == InterventionStep.noEligible) {
      noEligibleSinceReopen++;
      if (s.after != CounselingState.closing) {
        m.hit('noEligibleInterventionDeadlock', run, 'stayed in ${s.after.name}');
      }
      if (noEligibleSinceReopen > 1) {
        m.hit('noEligibleInterventionDeadlock', run, 'repeated noEligible');
      }
    }

    if (s.before != CounselingState.closing && s.after == CounselingState.closing) {
      if (r.closingStep != ClosingStep.proposed || !outcomeSeen) {
        m.hit('prematureClosing', run,
            '${s.before.name}->closing, closingStep=${r.closingStep?.name}');
      }
    }

    if (s.intent == Intent.continueTalking &&
        prev?.closingStep == ClosingStep.proposed &&
        reopenCount == 0) {
      if (r.closingStep != ClosingStep.continued || s.after != CounselingState.reflect) {
        m.hit('closingContinuationIgnored', run,
            '"${s.user}" -> ${r.closingStep?.name}, ${s.after.name}');
      }
    }
    if (r.closingStep == ClosingStep.continued) {
      reopenCount++;
      noEligibleSinceReopen = 0;
    }

    if (r.closingStep == ClosingStep.finalized) {
      if (!outcomeSeen || prev?.closingStep != ClosingStep.proposed) {
        m.hit('sessionCompletedTooEarly', run,
            'finalized after ${prev?.closingStep?.name}, outcome=$outcomeSeen');
      }
    }

    final sameAsPrevious = i > 0 && steps[i - 1].before == s.before;
    sameStateRun = sameAsPrevious ? sameStateRun + 1 : 1;
    if (s.before != CounselingState.closing &&
        sameStateRun > _policy.budgetFor(s.before)) {
      m.hit('stateLoop', run, '${s.before.name} x$sameStateRun');
    }
    if (s.before == CounselingState.closing && sameStateRun > 3) {
      m.hit('stateLoop', run, 'closing x$sameStateRun');
    }
    if (reopenCount > 1 && r.closingStep == ClosingStep.continued) {
      m.hit('stateLoop', run, 'closing reopened $reopenCount times');
    }
    if (prev?.closingStep == ClosingStep.finalized) {
      m.hit('stateLoop', run, 'turn after finalize');
    }

    // ── 13.9 metrics ──────────────────────────────────────────────────
    // nonAnswerCredited: a non-answer or a meta turn integrated as if it
    // answered the technique question (P1: "뭐라는거야" credited).
    // Credited = acknowledged with the technique's outcome sentence; a
    // no-pressure or neutral acknowledgment claims nothing.
    if (r.interventionStep == InterventionStep.integration) {
      final noCreditAck = _lowInfoAcks.any(r.text.contains);
      if ((s.intent == Intent.meta || s.intent == Intent.nonAnswer) && !noCreditAck) {
        m.hit('nonAnswerCredited', run, '"${s.user}" -> ${r.text}');
      }
    }

    // metaAsTarget: a meta or non-answer turn quoted back as content.
    for (final quoted in RegExp(r'“([^”]+)”').allMatches(r.text).map((x) => x.group(1)!)) {
      for (final earlier in steps.take(i + 1)) {
        if (earlier.intent != Intent.meta && earlier.intent != Intent.nonAnswer) continue;
        final said = earlier.user.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
        if (said.isNotEmpty && quoted.trim() == said) {
          m.hit('metaAsTarget', run, '“$quoted” in ${r.text}');
        }
      }
    }

    // remoteOnRepair: repair/recovery/wrap-up turns must not reach the model.
    if (_isRepairLike(r) && s.remoteAllowed) {
      m.hit('remoteOnRepair', run, '${s.before.name}: ${r.text}');
    }

    // repeatedClarifyRun: three questions in a row after non-answers, with
    // no wrap-up offer in between (P4).
    final askedAgain = s.intent == Intent.nonAnswer &&
        _asks(r) &&
        r.earlyWrapUp == null &&
        r.closingStep == null &&
        r.interventionStep == null;
    clarifyRun = askedAgain ? clarifyRun + 1 : 0;
    if (clarifyRun >= 3) {
      m.hit('repeatedClarifyRun', run, 'run $clarifyRun at "${s.user}"');
    }

    // deadTurnStatement: a reply with no question that isn't the end and
    // isn't a deliberate "I'm listening" repair (E3's recovery summary).
    if (!_asks(r) && r.closingStep != ClosingStep.finalized && !_intentionalListen(r)) {
      m.hit('deadTurnStatement', run, '${s.before.name}: ${r.text}');
    }

    // Detector coverage (reported separately). A wrap-up offered for a
    // second non-answer is not a repair of the utterance itself.
    if (s.intent == Intent.meta &&
        s.before != CounselingState.closing &&
        r.interactionRepairReason == null) {
      m.hit('metaIgnored', run, '"${s.user}" -> ${r.text}');
    }
    if (s.intent == Intent.content &&
        s.before != CounselingState.closing &&
        r.interactionRepairReason != null) {
      m.hit('metaFalsePositive', run, '"${s.user}" -> ${r.interactionRepairReason!.name}');
    }
  }

  if (steps.isEmpty || steps.last.reply.closingStep != ClosingStep.finalized) {
    m.hit('sessionNotFinalized', run,
        'ended in ${steps.isEmpty ? '-' : steps.last.after.name} after ${steps.length} turns');
  }
}
