// Phase 13.6 — Week × multi-turn progression evaluation. See
// docs/counseling/chatbot_system.md.
//
// Every scenario family runs in every week 1–8 through the real
// deterministic `CounselingHarness`. The simulated user is adaptive: it
// answers a closing proposal, a technique question, or a reflective
// question according to the family, the way a person would on device.
// Metrics are computed from the turn trace. Phase 13 gate: all zero.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

// Q1: was 56 (every session) before the fix: the answer to reflect's last
// question reached intervention unacknowledged. Now acknowledged.
const _frozenQ1 = 0;
// Q2: was 36 before the fix: behavior techniques quoted any message as "the
// behavior", balanced thought quoted the evidence answer as "the thought".
// Now the target is the reflect round's worry (or a described behavior).
const _frozenQ2 = 0;

const _registry = ApprovedInterventionRegistry();
const _policy = CounselingStatePolicy();

/// Upper bound on user turns per session. Below the policy's 20-turn cap,
/// so reaching it means the flow itself failed to finish.
const _maxTurns = 18;

enum _Family {
  /// Ordinary worry, cooperative answers.
  normalWorry,

  /// "모르겠어요" to the technique question.
  lowInfo,

  /// A week without an eligible technique (weeks 1–3 by construction; in
  /// other weeks this family still runs and must behave normally).
  noEligible,

  /// Ordinary worry in weeks whose own technique is gated (7, 8): an
  /// earlier approved technique must be used.
  earlierWeek,

  /// The entry message satisfies the current week's gate, so the current
  /// week's technique is used.
  currentWeek,

  /// Meta feedback right after the technique question, then the answer.
  metaDuringIntervention,

  /// "조금 더 이야기하고 싶어요" at the closing proposal.
  continueAtClosing,
}

const _opening = [
  '내일 발표가 있어서 불안해요',
  '7점이요',
  '발표하다가 말을 못 하면 어떡하지',
];

const _reflectAnswers = [
  '예전에 발표하다 말이 막힌 적이 있어요',
  '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
  '준비를 꽤 했으니까 아주 망치지는 않을 것 같아요',
  '사람들이 생각보다 제 실수를 오래 기억하진 않을 것 같아요',
];

const _continueTopic = [
  '사실 교수님 반응이 제일 걱정돼요',
  '교수님이 실망하실 것 같아요',
  '그래도 한 번 실망하신다고 끝나는 건 아니겠죠',
  '조금은 마음이 가벼워졌어요',
];

const _ordinaryEntry = '그래도 긴장되는 건 어쩔 수 없네요';

/// Entry message that satisfies the current week's gate. Weeks 5–6 have no
/// gate; there it describes a behavior, so the technique examines that
/// behavior instead of asking about behavior around the worry.
String _gatedEntry(int week) => switch (week) {
  5 || 6 => '그래서 발표 자료만 계속 확인하게 돼요',
  7 => '그래서 발표 연습을 자꾸 미루고 피하게 돼요',
  8 => '요즘 호흡 연습을 계속했더니 도움이 됐어요',
  _ => _ordinaryEntry,
};

/// What a technique question may legitimately be about: a worry thought,
/// or a message shaped for a gated technique.
final _appropriateTargets = {
  _opening[2],
  _continueTopic[0],
  _continueTopic[1],
  _gatedEntry(5),
  _gatedEntry(7),
  _gatedEntry(8),
};

/// Openings with which intervention acknowledges the answer to reflect's
/// last question (Q1 fix).
const _reflectAnswerAcks = [
  '그 걱정이 어디서 오는지 조금 더 알 것 같아요',
  '말씀해 주신 생각도 함께 담아 둘게요',
  '말씀해 주신 느낌도 함께 담아 둘게요',
  '바로 떠오르지 않아도 괜찮아요',
];

const _techniqueAnswer = '긴장해도 준비한 만큼은 할 수 있을 것 같아요';

class _Step {
  final String user;
  final CounselingState before;
  final CounselingState after;
  final int turnsInStateBefore;
  final CounselingMessage reply;

  /// This user turn answered a technique question.
  final bool answersPrompt;

  /// This user turn asked to keep talking at a closing proposal.
  final bool asksToContinue;
  _Step(
    this.user,
    this.before,
    this.after,
    this.turnsInStateBefore,
    this.reply, {
    required this.answersPrompt,
    required this.asksToContinue,
  });
}

class _Run {
  final _Family family;
  final int week;
  final steps = <_Step>[];
  _Run(this.family, this.week);
  String get id => '${family.name}/w$week';
}

class _Metrics {
  final counts = <String, int>{
    'interventionDeadlock': 0,
    'prematureClosing': 0,
    'interventionResponseDropped': 0,
    'futureWeekTechniqueLeakage': 0,
    'unauthorizedCbt': 0,
    'noEligibleInterventionDeadlock': 0,
    'closingContinuationIgnored': 0,
    'sessionCompletedTooEarly': 0,
    'stateLoop': 0,
    // Not in the directive's list; a session that never finalizes would
    // otherwise pass every other metric vacuously.
    'sessionNotFinalized': 0,
  };

  /// Found in the 13.6 traces and fixed in 13.6b; not in the gate list (see
  /// docs/counseling/chatbot_system.md, Q1/Q2).
  final quality = <String, int>{
    // Q1: reflect's last question is sent in the turn that completes
    // reflect; the user's answer then lands in intervention and is
    // treated as the technique's entry (or, with no technique, summarized
    // over), not as that answer.
    'reflectQuestionDroppedAtTransition': 0,
    // Q2: the technique question quotes a user turn that is neither the
    // worry thought nor a gate-shaped (avoidance/maintenance) message.
    'interventionTargetMismatch': 0,
  };
  final failures = <String, List<String>>{};

  void hit(String metric, _Run run, String detail) {
    counts[metric] = counts[metric]! + 1;
    (failures[metric] ??= []).add('${run.id}: $detail');
  }
}

/// The last non-repair assistant reply before [i], if any.
CounselingMessage? _previousSubstantive(List<_Step> steps, int i) {
  for (var j = i - 1; j >= 0; j--) {
    if (steps[j].reply.interactionRepairReason == null) return steps[j].reply;
  }
  return null;
}

void _score(_Run run, _Metrics m) {
  final steps = run.steps;
  final approved = {for (final p in _registry.policies) p.requiredId: p.week};

  var interventionRun = 0;
  var sameStateRun = 0;
  var reopenCount = 0;
  var outcomeSeen = false;
  var noEligibleSinceReopen = 0;

  for (final (i, s) in steps.indexed) {
    final r = s.reply;
    final prev = i > 0 ? steps[i - 1].reply : null;

    // futureWeekTechniqueLeakage / unauthorizedCbt
    for (final id in r.referencedCbtIds) {
      final week = approved[id];
      if (week == null) {
        m.hit('unauthorizedCbt', run, 'unapproved $id');
      } else if (week > run.week) {
        m.hit('futureWeekTechniqueLeakage', run, '$id (week $week)');
      }
    }
    if (r.referencedCbtIds.isNotEmpty &&
        s.before != CounselingState.intervention) {
      m.hit('unauthorizedCbt', run, 'CBT id in ${s.before.name}');
    }

    // interventionDeadlock: intervention must progress within its cap and
    // never produce an act StatePolicy can't count.
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

    // interventionResponseDropped: an answer to a technique question must be
    // integrated (a repair turn in between is allowed, then the answer
    // still has to be integrated).
    if (s.answersPrompt &&
        r.interactionRepairReason == null &&
        r.interventionStep != InterventionStep.integration) {
      m.hit('interventionResponseDropped', run, '"${s.user}" -> ${r.text}');
    }

    if (r.interventionStep == InterventionStep.integration ||
        r.interventionStep == InterventionStep.noEligible) {
      outcomeSeen = true;
    }

    // noEligibleInterventionDeadlock
    if (r.interventionStep == InterventionStep.noEligible) {
      noEligibleSinceReopen++;
      if (s.after != CounselingState.closing) {
        m.hit('noEligibleInterventionDeadlock', run, 'stayed in ${s.after.name}');
      }
      if (noEligibleSinceReopen > 1) {
        m.hit('noEligibleInterventionDeadlock', run, 'repeated noEligible');
      }
    }

    // prematureClosing: closing is entered only through a proposal that
    // follows an intervention outcome.
    if (s.before != CounselingState.closing &&
        s.after == CounselingState.closing) {
      if (r.closingStep != ClosingStep.proposed || !outcomeSeen) {
        m.hit('prematureClosing', run,
            '${s.before.name}->closing, closingStep=${r.closingStep?.name}');
      }
    }

    // closingContinuationIgnored
    if (s.asksToContinue && reopenCount == 0) {
      if (r.closingStep != ClosingStep.continued ||
          s.after != CounselingState.reflect) {
        m.hit('closingContinuationIgnored', run,
            '"${s.user}" -> ${r.closingStep?.name}, ${s.after.name}');
      }
    }
    if (r.closingStep == ClosingStep.continued) {
      reopenCount++;
      noEligibleSinceReopen = 0;
    }

    // sessionCompletedTooEarly: finalizing needs an intervention outcome
    // and the user's reply to a proposal.
    if (r.closingStep == ClosingStep.finalized) {
      if (!outcomeSeen || prev?.closingStep != ClosingStep.proposed) {
        m.hit('sessionCompletedTooEarly', run,
            'finalized after ${prev?.closingStep?.name}, outcome=$outcomeSeen');
      }
    }

    // stateLoop: no stage outstays its cap; closing reopens at most once;
    // nothing after the session is finalized.
    final sameAsPrevious = i > 0 && steps[i - 1].before == s.before;
    sameStateRun = sameAsPrevious ? sameStateRun + 1 : 1;
    if (s.before != CounselingState.closing &&
        sameStateRun > _policy.budgetFor(s.before)) {
      m.hit('stateLoop', run, '${s.before.name} x$sameStateRun');
    }
    if (s.before == CounselingState.closing && sameStateRun > 2) {
      m.hit('stateLoop', run, 'closing x$sameStateRun');
    }
    if (reopenCount > 1 && r.closingStep == ClosingStep.continued) {
      m.hit('stateLoop', run, 'closing reopened $reopenCount times');
    }
    if (prev?.closingStep == ClosingStep.finalized) {
      m.hit('stateLoop', run, 'turn after finalize');
    }
  }

  for (final (i, s) in steps.indexed) {
    if (s.before == CounselingState.reflect &&
        s.after == CounselingState.intervention &&
        s.reply.text.trim().endsWith('?') &&
        i + 1 < steps.length &&
        (steps[i + 1].reply.interventionStep == InterventionStep.prompt ||
            steps[i + 1].reply.interventionStep == InterventionStep.noEligible) &&
        !_reflectAnswerAcks.any(steps[i + 1].reply.text.startsWith)) {
      m.quality.update('reflectQuestionDroppedAtTransition', (v) => v + 1);
    }
    if (s.reply.interventionStep == InterventionStep.prompt) {
      final quoted = RegExp(r'“([^”]+)”').firstMatch(s.reply.text)?.group(1);
      if (quoted != null && !_appropriateTargets.contains(quoted)) {
        m.quality.update('interventionTargetMismatch', (v) => v + 1);
        (m.failures['interventionTargetMismatch'] ??= [])
            .add('${run.id}: “$quoted”');
      }
    }
  }

  if (steps.isEmpty || steps.last.reply.closingStep != ClosingStep.finalized) {
    m.hit('sessionNotFinalized', run,
        'ended in ${steps.last.after.name} after ${steps.length} turns');
  }
}

void main() {
  late LocalCbtKnowledgeRepository repository;
  final runs = <_Run>[];
  final metrics = _Metrics();

  Future<_Run> simulate(_Family family, int week) async {
    final harness = CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repository,
    );
    final session = CounselingSessionState(
      sessionId: 'p13_6_${family.name}_w$week',
      currentWeek: week,
      messages: [
        CounselingMessage(
          id: 'greeting',
          role: 'assistant',
          text: '안녕하세요. 오늘 어떤 이야기를 나누고 싶으신가요?',
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
    );
    final run = _Run(family, week);
    var reflectIdx = 0;
    var continueIdx = 0;
    var continued = false;
    var metaSent = false;

    String nextUserTurn() {
      final i = run.steps.length;
      if (i < _opening.length) return _opening[i];
      final last = run.steps.last.reply;
      final pending = _previousSubstantive(run.steps, run.steps.length);

      if (last.closingStep == ClosingStep.proposed) {
        if (family == _Family.continueAtClosing && !continued) {
          continued = true;
          return '아니요, 조금 더 이야기하고 싶어요';
        }
        return '네, 좋아요';
      }
      if (pending?.interventionStep == InterventionStep.prompt) {
        if (family == _Family.metaDuringIntervention && !metaSent) {
          metaSent = true;
          return '왜 똑같은 말을 해요?';
        }
        if (family == _Family.lowInfo) return '모르겠어요';
        return _techniqueAnswer;
      }
      if (session.state == CounselingState.intervention) {
        return family == _Family.currentWeek ? _gatedEntry(week) : _ordinaryEntry;
      }
      if (continued) {
        return _continueTopic[continueIdx++ % _continueTopic.length];
      }
      return _reflectAnswers[reflectIdx++ % _reflectAnswers.length];
    }

    for (var t = 0; t < _maxTurns; t++) {
      final text = nextUserTurn();
      final pending = run.steps.isEmpty
          ? null
          : _previousSubstantive(run.steps, run.steps.length);
      final lastReply = run.steps.isEmpty ? null : run.steps.last.reply;
      final before = session.state;
      final turnsBefore = session.turnsInCurrentState;
      final result = await harness.handleTurn(session: session, userMessage: text);
      session.messages
        ..add(CounselingMessage(
          id: 'u$t',
          role: 'user',
          text: text,
          createdAt: DateTime(2026, 9, 1),
        ))
        ..add(result.assistantMessage);
      run.steps.add(_Step(
        text,
        before,
        session.state,
        turnsBefore,
        result.assistantMessage,
        answersPrompt: pending?.interventionStep == InterventionStep.prompt &&
            text != '왜 똑같은 말을 해요?',
        asksToContinue: lastReply?.closingStep == ClosingStep.proposed &&
            text.contains('더 이야기'),
      ));
      if (result.assistantMessage.closingStep == ClosingStep.finalized) break;
    }
    return run;
  }

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(
      loadAsset: (p) => File(p).readAsString(),
    );
    await repository.initialize();
    for (final family in _Family.values) {
      for (var week = 1; week <= 8; week++) {
        final run = await simulate(family, week);
        runs.add(run);
        _score(run, metrics);
      }
    }
    final report = {
      'sessions': runs.length,
      'userTurns': runs.fold<int>(0, (n, r) => n + r.steps.length),
      'metrics': metrics.counts,
      'quality': metrics.quality,
      'failures': metrics.failures,
      'traces': {
        for (final r in runs)
          r.id: [
            for (final s in r.steps)
              '${s.before.name}->${s.after.name} '
                  '| act=${s.reply.dialogueAct?.name} '
                  'iv=${s.reply.interventionStep?.name} '
                  'cl=${s.reply.closingStep?.name} '
                  'cbt=${s.reply.referencedCbtIds.join(",")} '
                  '| ${s.user} => ${s.reply.text}',
          ],
      },
    };
    // ignore: avoid_print
    print('PHASE13_6_REPORT ${const JsonEncoder.withIndent('  ').convert(report)}');
  });

  test('covers every family in every week 1–8', () {
    expect(runs, hasLength(_Family.values.length * 8));
    expect(runs.map((r) => r.week).toSet(), {1, 2, 3, 4, 5, 6, 7, 8});
  });

  group('Phase 13 gate: all zero', () {
    for (final metric in _Metrics().counts.keys) {
      test(metric, () {
        expect(metrics.counts[metric], 0,
            reason: metrics.failures[metric]?.join('\n'));
      });
    }
  });

  // Found in 13.6, fixed in 13.6b. Kept at 0; see Q1/Q2 in
  // docs/counseling/chatbot_system.md.
  group('quality findings Q1/Q2 (fixed)', () {
    test('Q1 reflect question dropped at reflect->intervention', () {
      expect(metrics.quality['reflectQuestionDroppedAtTransition'], _frozenQ1);
    });
    test('Q2 technique question quotes an unsuitable target', () {
      expect(metrics.quality['interventionTargetMismatch'], _frozenQ2,
          reason: metrics.failures['interventionTargetMismatch']?.join('\n'));
    });
  });

  group('family expectations', () {
    Iterable<CounselingMessage> interventionReplies(_Run r) =>
        r.steps.where((s) => s.before == CounselingState.intervention).map((s) => s.reply);
    String? firstTechnique(_Run r) => interventionReplies(r)
        .where((m) => m.interventionStep == InterventionStep.prompt)
        .map((m) => m.referencedCbtIds.first)
        .firstOrNull;
    _Run find(_Family f, int w) => runs.firstWhere((r) => r.family == f && r.week == w);

    test('weeks 1–3: explicit noEligible, no CBT, then finalize', () {
      for (final f in _Family.values) {
        for (var w = 1; w <= 3; w++) {
          final r = find(f, w);
          expect(
            interventionReplies(r).map((m) => m.interventionStep),
            contains(InterventionStep.noEligible),
            reason: r.id,
          );
          expect(r.steps.expand((s) => s.reply.referencedCbtIds), isEmpty, reason: r.id);
        }
      }
    });

    test('weeks 4–6: the current week technique is asked, then integrated', () {
      for (var w = 4; w <= 6; w++) {
        final r = find(_Family.normalWorry, w);
        expect(firstTechnique(r), _registry.policyForWeek(w)!.requiredId, reason: r.id);
        expect(
          r.steps.map((s) => s.reply.interventionStep),
          containsAllInOrder([InterventionStep.prompt, InterventionStep.integration]),
          reason: r.id,
        );
      }
    });

    test('weeks 7–8 ordinary worry: an earlier approved technique', () {
      for (final w in [7, 8]) {
        final r = find(_Family.earlierWeek, w);
        final id = firstTechnique(r);
        expect(id, isNotNull, reason: r.id);
        expect(_registry.policyForItemId(id!)!.week, lessThan(w), reason: r.id);
      }
    });

    test('weeks 7–8 gate-satisfying entry: the current week technique', () {
      for (final w in [7, 8]) {
        final r = find(_Family.currentWeek, w);
        expect(firstTechnique(r), _registry.policyForWeek(w)!.requiredId, reason: r.id);
      }
    });

    CounselingMessage promptOf(_Run r) => r.steps
        .firstWhere((s) => s.reply.interventionStep == InterventionStep.prompt)
        .reply;

    test('Q2: ordinary worry — the technique is about the worry thought', () {
      for (var w = 4; w <= 8; w++) {
        final r = find(_Family.normalWorry, w);
        expect(promptOf(r).text, contains('“${_opening[2]}”'), reason: r.id);
      }
      // Behavior techniques ask about behavior around the worry.
      expect(promptOf(find(_Family.normalWorry, 5)).text, contains('그 걱정이 들 때 보통 어떻게 하시는지'));
      expect(promptOf(find(_Family.normalWorry, 6)).text, contains('그 걱정이 들 때 주로 하게 되는 행동'));
    });

    test('Q2: a described behavior is what the behavior technique examines', () {
      for (final w in [5, 6]) {
        final r = find(_Family.currentWeek, w);
        final text = promptOf(r).text;
        expect(text, contains('“${_gatedEntry(w)}”'), reason: r.id);
        expect(text.contains('그 걱정이 들 때'), isFalse, reason: r.id);
      }
    });

    test('Q1: intervention opens by acknowledging the reflect answer, without quoting it', () {
      for (final r in runs) {
        final i = r.steps.indexWhere(
          (s) => s.before == CounselingState.intervention,
        );
        final reply = r.steps[i].reply;
        expect(_reflectAnswerAcks.any(reply.text.startsWith), isTrue, reason: '${r.id}: ${reply.text}');
        // Quoting is right only when the answer is itself the technique's
        // target (a described behavior or practice).
        if (!_appropriateTargets.contains(r.steps[i].user)) {
          expect(reply.text.contains('“${r.steps[i].user}”'), isFalse, reason: r.id);
        }
      }
    });

    test('low-info answer gets the no-pressure acknowledgment (weeks 4–8)', () {
      for (var w = 4; w <= 8; w++) {
        final r = find(_Family.lowInfo, w);
        final integration = r.steps.firstWhere(
          (s) => s.reply.interventionStep == InterventionStep.integration,
        );
        expect(integration.reply.text, contains('바로 떠오르지 않아도 괜찮아요'), reason: r.id);
      }
    });

    test('meta during intervention is repaired, then the answer is integrated (weeks 4–8)', () {
      for (var w = 4; w <= 8; w++) {
        final r = find(_Family.metaDuringIntervention, w);
        final meta = r.steps.firstWhere((s) => s.user == '왜 똑같은 말을 해요?');
        expect(meta.reply.interactionRepairReason, isNotNull, reason: r.id);
        expect(meta.after, CounselingState.intervention, reason: r.id);
        expect(
          r.steps.map((s) => s.reply.interventionStep),
          contains(InterventionStep.integration),
          reason: r.id,
        );
      }
    });

    test('continue at closing reopens exactly once and still finalizes', () {
      for (var w = 1; w <= 8; w++) {
        final r = find(_Family.continueAtClosing, w);
        expect(
          r.steps.where((s) => s.reply.closingStep == ClosingStep.continued),
          hasLength(1),
          reason: r.id,
        );
        expect(r.steps.last.reply.closingStep, ClosingStep.finalized, reason: r.id);
      }
    });
  });
}
