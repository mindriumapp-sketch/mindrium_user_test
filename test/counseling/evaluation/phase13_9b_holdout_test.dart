// Phase 13.9B — frozen adversarial holdout. See
// docs/counseling/phase13_status_and_plan.md.
//
// Every user utterance comes from fixtures/phase13_9b_holdout.json, written
// by an agent without access to the code and committed before the first
// run. The utterances are never edited and never used to tune detectors:
// a holdout failure is recorded, and any fix is developed on a new dev
// set.
//
// Gate: the 15 session-flow metrics are 0 — whatever the user says, the
// session doesn't stall, credit a non-answer, quote a meta turn, or send a
// repair to the model. Detector coverage on unseen surfaces (metaIgnored,
// metaFalsePositive, the single-turn probe) is measured and reported, not
// gated.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/production_turn_planner.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

import 'support/session_flow_metrics.dart';

class _EchoApi implements CounselingRealizeApi {
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
  }) async => {
    'request_id': requestId,
    'reply': deterministicDraft,
    'chosen_act': requiredAct,
    'model': 'echo',
    'prompt_version': promptVersion,
    'latency_ms': 1,
  };
}

typedef _Turn = (String, Intent);
typedef _Driver = _Turn Function(List<FlowStep> steps);

enum _Asked { proposal, technique, question }

_Asked _asked(List<FlowStep> steps) {
  if (steps.last.reply.closingStep == ClosingStep.proposed) return _Asked.proposal;
  for (final s in steps.reversed) {
    if (s.reply.interactionRepairReason != null && s.reply.closingStep == null) continue;
    return s.reply.interventionStep == InterventionStep.prompt
        ? _Asked.technique
        : _Asked.question;
  }
  return _Asked.question;
}

/// Cycles through a holdout list.
class _Pool {
  final List<String> items;
  var _i = 0;
  _Pool(this.items, [int offset = 0]) : _i = offset;
  String next() => items[_i++ % items.length];
}

const _ratings = ['6', '8점', '7 정도', '9'];

void main() {
  late LocalCbtKnowledgeRepository repo;
  late Map<String, List<String>> h;
  final runs = <FlowRun>[];
  final metrics = FlowMetrics();
  final probe = <String, Map<String, Object>>{};

  _Pool pool(String key, int offset) => _Pool(h[key]!, offset);

  /// A holdout user who answers content questions from the holdout pools.
  _Driver cooperative(int seed) {
    final opening = h['worry_opening']![seed % h['worry_opening']!.length];
    final rating = _ratings[seed % _ratings.length];
    final evidence = pool('evidence_answers', seed);
    final alternative = pool('alternative_answers', seed);
    final technique = pool('technique_answers', seed);
    final agree = pool('agree_to_wrap_up', seed);
    var reflectAnswers = 0;
    return (steps) {
      if (steps.isEmpty) return (opening, Intent.content);
      if (steps.length == 1) return (rating, Intent.content);
      switch (_asked(steps)) {
        case _Asked.proposal:
          return (agree.next(), Intent.wrapUp);
        case _Asked.technique:
          return (technique.next(), Intent.content);
        case _Asked.question:
          final answer = reflectAnswers.isEven ? evidence.next() : alternative.next();
          reflectAnswers++;
          return (answer, Intent.content);
      }
    };
  }

  /// Uses [pool] once at each kind of question (not the proposal), then
  /// answers from the cooperative pools.
  _Driver interrupting(int seed, String key, Intent intent, {bool atProposal = false}) {
    final base = cooperative(seed);
    final items = pool(key, seed);
    final done = <_Asked>{};
    return (steps) {
      if (steps.length < 2) return base(steps);
      final asked = _asked(steps);
      if ((atProposal || asked != _Asked.proposal) && done.add(asked)) {
        return (items.next(), intent);
      }
      return base(steps);
    };
  }

  _Driver nonAnswering(int seed) {
    final base = cooperative(seed);
    final items = pool('non_answer', seed);
    return (steps) => steps.length < 2 ? base(steps) : (items.next(), Intent.nonAnswer);
  }

  _Driver continueThenNonAnswer(int seed) {
    final base = cooperative(seed);
    final more = pool('want_to_continue', seed);
    final items = pool('non_answer', seed);
    var continued = false;
    return (steps) {
      if (!continued && steps.length > 1 && _asked(steps) == _Asked.proposal) {
        continued = true;
        return (more.next(), Intent.continueTalking);
      }
      if (continued) return (items.next(), Intent.nonAnswer);
      return base(steps);
    };
  }

  _Driver continueThenCooperate(int seed) {
    final base = cooperative(seed);
    final more = pool('want_to_continue', seed);
    var continued = false;
    return (steps) {
      if (!continued && steps.length > 1 && _asked(steps) == _Asked.proposal) {
        continued = true;
        return (more.next(), Intent.continueTalking);
      }
      return base(steps);
    };
  }

  final families = <String, _Driver Function(int)>{
    'cooperative': cooperative,
    'notUnderstood': (s) => interrupting(s, 'not_understood', Intent.meta, atProposal: true),
    'repetitionComplaint': (s) => interrupting(s, 'repetition_complaint', Intent.meta),
    'stopOrFrustration': (s) => interrupting(s, 'stop_or_frustration', Intent.meta),
    'nonAnswering': nonAnswering,
    'mixed': (s) => interrupting(s, 'mixed_meta_and_worry', Intent.mixed),
    'worryLooksMeta': (s) => interrupting(s, 'worry_that_looks_meta', Intent.content),
    'continueThenNonAnswer': continueThenNonAnswer,
    'continueThenCooperate': continueThenCooperate,
  };

  Future<FlowRun> simulate(String id, int week, _Driver next) async {
    final harness = CounselingHarness.remoteGpt(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repo,
      responseRealizer: RemoteLlmRealizer(api: _EchoApi()),
      rolloutConfig: const RolloutConfig(enabled: true, stage: RolloutStage.internalOnly),
      isInternalAccount: true,
    );
    final session = CounselingSessionState(sessionId: id, currentWeek: week);
    final steps = <FlowStep>[];
    for (var t = 0; t < 18; t++) {
      final (text, intent) = next(steps);
      final before = session.state;
      final r = await harness.handleTurn(session: session, userMessage: text);
      session.messages
        ..add(CounselingMessage(id: 'u$t', role: 'user', text: text, createdAt: DateTime(2026)))
        ..add(r.assistantMessage);
      steps.add(FlowStep(
        user: text,
        intent: intent,
        before: before,
        after: session.state,
        reply: r.assistantMessage,
        remoteAllowed: r.routing?.allowLlm ?? false,
      ));
      if (r.assistantMessage.closingStep == ClosingStep.finalized) break;
    }
    return FlowRun(id, week, steps);
  }

  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
    final raw = jsonDecode(
      File('test/counseling/evaluation/fixtures/phase13_9b_holdout.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    h = {
      for (final e in raw.entries)
        if (!e.key.startsWith('_')) e.key: (e.value as List).cast<String>(),
    };

    var seed = 0;
    for (final MapEntry(key: name, value: make) in families.entries) {
      for (var week = 1; week <= 8; week++) {
        runs.add(await simulate('$name/w$week', week, make(seed++)));
      }
    }
    for (final r in runs) {
      scoreFlow(r, metrics);
    }

    // Single-turn probe in reflect, empty history: does each category land
    // where its label says?
    InteractionRepairReason? detect(String m) => const PolicyPipelineTurnPlanner()
        .plan(TurnPlanningContext(state: CounselingState.reflect, userMessage: m, knowledge: const []))
        ?.interactionRepairReason;
    for (final key in ['not_understood', 'repetition_complaint', 'stop_or_frustration', 'mixed_meta_and_worry']) {
      final missed = [for (final u in h[key]!) if (detect(u) == null) u];
      probe[key] = {'detected': h[key]!.length - missed.length, 'of': h[key]!.length, 'missed': missed};
    }
    final falsePositives = [for (final u in h['worry_that_looks_meta']!) if (detect(u) != null) '$u -> ${detect(u)!.name}'];
    probe['worry_that_looks_meta'] = {
      'falsePositives': falsePositives.length,
      'of': h['worry_that_looks_meta']!.length,
      'list': falsePositives,
    };
    final lowInfoMissed = [for (final u in h['non_answer']!) if (!UserThoughtExtractor.isLowInformation(u)) u];
    probe['non_answer'] = {
      'recognized': h['non_answer']!.length - lowInfoMissed.length,
      'of': h['non_answer']!.length,
      'missed': lowInfoMissed,
    };

    // ignore: avoid_print
    print('PHASE13_9B_REPORT ${const JsonEncoder.withIndent('  ').convert({
      'sessions': runs.length,
      'userTurns': runs.fold<int>(0, (n, r) => n + r.steps.length),
      'metrics': metrics.counts,
      'failures': metrics.failures,
      'probe': probe,
      'traces': {
        for (final r in runs)
          r.id: [
            for (final s in r.steps)
              '${s.before.name}->${s.after.name} [${s.intent.name}] '
                  'rep=${s.reply.interactionRepairReason?.name} '
                  'iv=${s.reply.interventionStep?.name} cl=${s.reply.closingStep?.name} '
                  'wrap=${s.reply.earlyWrapUp?.name} remote=${s.remoteAllowed} '
                  '| ${s.user} => ${s.reply.text}',
          ],
      },
    })}');
  });

  test('covers every holdout family in weeks 1–8', () {
    expect(runs, hasLength(families.length * 8));
  });

  // Holdout v1 FAILED on its first run (2026-09-30). The result is frozen
  // here as a record, not as a target: the holdout has now been seen, so it
  // can no longer certify a fix. Fixes are developed on a new dev set and
  // the gate moves to a fresh blind holdout (v2). See
  // docs/counseling/phase13_status_and_plan.md, "13.9B holdout v1".
  //
  // First run (3f9f3d4): stateLoop 2, nonAnswerCredited 17, metaAsTarget 54,
  // repeatedClarifyRun 30. The values below are the re-run after the 13.9C
  // safety nets and dev-v2 widening, on a set that is no longer blind:
  // informational only, never a pass. Remaining v1 misses are not fixed
  // from v1.
  const seenSetRerun = {'metaAsTarget': 3};
  group('holdout v1 (seen set): re-run recorded, not a pass', () {
    for (final metric in flowGateMetrics) {
      test(metric, () {
        expect(metrics.counts[metric], seenSetRerun[metric] ?? 0,
            reason: 'holdout v1 changed; update the record deliberately.\n'
                '${metrics.failures[metric]?.join('\n')}');
      });
    }
  });
}
