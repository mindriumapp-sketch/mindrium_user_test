// Phase 13.9A — known-failure regression on uncooperative users. See
// docs/counseling/phase13_status_and_plan.md.
//
// The 13.6 simulated user answers every question as asked. Device users
// didn't: they got confused, gave non-answers, complained, got angry, and
// typed without spaces. Each family below plays one of those users in
// every week 1–8, plus the four device sessions replayed verbatim. The
// phrasings are the dev set: taken from dogfood (D/E/P) and used while
// fixing. The frozen holdout (13.9B) must use different surfaces.
//
// Runs on the remote-GPT harness with an API that echoes the
// deterministic draft, so the flow equals the deterministic one while the
// router's remote decision is observable (remoteOnRepair).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/rollout/rollout_config.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

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

/// What the counselor is waiting for, read from reply metadata.
enum _Asked { proposal, technique, question }

_Asked _asked(List<FlowStep> steps) {
  final last = steps.last.reply;
  if (last.closingStep == ClosingStep.proposed) return _Asked.proposal;
  for (final s in steps.reversed) {
    if (s.reply.interactionRepairReason != null && s.reply.closingStep == null) continue;
    return s.reply.interventionStep == InterventionStep.prompt
        ? _Asked.technique
        : _Asked.question;
  }
  return _Asked.question;
}

const _opening = <_Turn>[
  ('내일 발표가 있어서 불안해요', Intent.content),
  ('7점이요', Intent.content),
  ('발표하다가 말을 못 하면 어떡하지', Intent.content),
];
const _answers = [
  '예전에 발표하다 말이 막힌 적이 있어요',
  '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
  '준비를 꽤 했으니까 아주 망치지는 않을 것 같아요',
  '사람들이 생각보다 제 실수를 오래 기억하진 않을 것 같아요',
];
const _techniqueAnswer = '긴장해도 준비한 만큼은 할 수 있을 것 같아요';
const _confusions = [
  '무슨 말이야',
  '너가 무슨말 하는지 모르겠어',
  '지금 무슨 이야기를 하는거야?',
  '뭐라는거야',
  '그게 무슨 뜻이야?',
  '방금 한 말이 이해가 안 돼요',
];
const _nonAnswers = ['몰라', '잘 모르겠어', '모르겠어', '모르겠다니까', '글쎄요', '응'];

/// An adaptive user: given the transcript so far, the next turn.
typedef _Driver = _Turn Function(List<FlowStep> steps);

_Driver _cooperative() {
  var a = 0;
  return (steps) {
    if (steps.length < _opening.length) return _opening[steps.length];
    return switch (_asked(steps)) {
      _Asked.proposal => ('네, 좋아요', Intent.wrapUp),
      _Asked.technique => (_techniqueAnswer, Intent.content),
      _Asked.question => (_answers[a++ % _answers.length], Intent.content),
    };
  };
}

/// Confused once at each kind of question, then answers.
_Driver _confused() {
  final base = _cooperative();
  final confusedAt = <_Asked>{};
  var c = 0;
  return (steps) {
    if (steps.length < 2) return base(steps);
    final asked = _asked(steps);
    if (confusedAt.add(asked)) return (_confusions[c++ % _confusions.length], Intent.meta);
    return base(steps);
  };
}

/// Only non-answers after the opening worry and the rating.
_Driver _nonAnswering() {
  var n = 0;
  return (steps) {
    if (steps.length < 2) return _opening[steps.length];
    return (_nonAnswers[n++ % _nonAnswers.length], Intent.nonAnswer);
  };
}

/// Complains about repetition at reflect and right after the technique
/// question, then answers.
_Driver _complaining() {
  final base = _cooperative();
  final complainedAt = <_Asked>{};
  return (steps) {
    if (steps.length < 3) return base(steps);
    final asked = _asked(steps);
    if (asked != _Asked.proposal && complainedAt.add(asked)) {
      return (asked == _Asked.technique ? '아까도 물어봤잖아요' : '왜 같은 말을 해?', Intent.meta);
    }
    return base(steps);
  };
}

/// Non-answers, then the angry complaint from session 4, then non-answers.
_Driver _angry() {
  var n = 0;
  return (steps) {
    if (steps.length < 2) return _opening[steps.length];
    n++;
    if (n == 3) return ('모르겠다고, 왜 계속 같은말해 짜증나게', Intent.meta);
    if (n == 5) return ('짜증나게 왜 계속 물어봐', Intent.meta);
    return (_nonAnswers[n % _nonAnswers.length], Intent.nonAnswer);
  };
}

/// No spaces, 반말, several sentences.
_Driver _variants() {
  const script = <_Turn>[
    ('내일발표있는데 너무떨려. 망칠것같아', Intent.content),
    ('8점', Intent.content),
  ];
  const answers = ['저번에도발표하다가 말이막혔어', '그렇다고 매번 그런건아닐수도있어', '준비는 해놨으니까 괜찮을것같기도해'];
  var a = 0;
  return (steps) {
    if (steps.length < script.length) return script[steps.length];
    return switch (_asked(steps)) {
      _Asked.proposal => ('정리하자', Intent.wrapUp),
      _Asked.technique => ('떨려도 준비한만큼은 할수있을것같아', Intent.content),
      _Asked.question => (answers[a++ % answers.length], Intent.content),
    };
  };
}

/// Meta and worry content in the same session, sometimes the same turn.
_Driver _mixed() {
  final base = _cooperative();
  var q = 0;
  return (steps) {
    if (steps.length < 3) return base(steps);
    if (_asked(steps) == _Asked.question) {
      q++;
      if (q == 1) return ('잘 모르겠어 그냥 발표 망칠까봐 걱정돼', Intent.content);
      if (q == 2) return ('근데 아까도 이거 물어본 것 같은데', Intent.meta);
    }
    return base(steps);
  };
}

/// Continues at the proposal, then only non-answers (sessions 3–4).
_Driver _continueThenNonAnswers() {
  final base = _cooperative();
  var continued = false;
  var n = 0;
  return (steps) {
    if (!continued && steps.isNotEmpty && _asked(steps) == _Asked.proposal) {
      continued = true;
      return ('더 이야기하자', Intent.continueTalking);
    }
    if (continued) return (_nonAnswers[n++ % _nonAnswers.length], Intent.nonAnswer);
    return base(steps);
  };
}

/// A device session verbatim, then a cooperative tail if it hasn't ended.
_Driver _replay(List<_Turn> script) {
  final tail = _cooperative();
  return (steps) => steps.length < script.length ? script[steps.length] : tail(steps);
}

const _c = Intent.content, _n = Intent.nonAnswer, _m = Intent.meta;
final _deviceSessions = <String, List<_Turn>>{
  'device_s1': [
    ('내일 시험이 있는데 걱정돼', _c), ('7', _c), ('내일 시험을 못봐서 혼날것같아', _c),
    ('선생님한테 혼날 것 같아', _c), ('저번 중간고사때 시험을 못봐서 혼났어', _c),
    ('앞으로 더 열심히 준비해야겠다는 생각이 들어', _c),
    ('선생님한테 혼나도 괜찮아, 다음에 더 열심히 하면 돼', _c), ('정리해보자', Intent.wrapUp),
  ],
  'device_s2': [
    ('내일 발표시험이 있어', _c), ('8', _c),
    ('처음 해보는 발표 시험이라 너무 긴장되고 떨려. 실수할까봐 걱정돼', _c),
    ('내가 사람들한테 집중당하는걸 무서워해서 발표를 잘 못해. 그런데 이런 발표로 시험까지 봐야하니까 너무 걱정돼', _c),
    ('몰라', _n), ('모르겠어', _n), ('정리하자', Intent.wrapUp),
  ],
  'device_s3': [
    ('오늘 시험을 봤는데 잘 못본 것 같아', _c), ('9', _c), ('모르는 문제가 너무 많아서 못풀었어', _c),
    ('내가 찍은 문제가 다 틀려서 망할까봐 걱정돼', _c), ('딱히 없어. 그냥 불안해', _c),
    ('공부를 열심히 했으면 잘 봤겠지만 그렇지 못해서 망한 것 같아', _c),
    ('문제를 다 틀려도 망한 것은 아니야. 다음에도 기회가 있어', _c),
    ('더 이야기하자', Intent.continueTalking), ('내일 시험은 잘 볼 수 있을까', _c),
    ('잘 모르겠어', _n), ('네?', _n), ('정리하자', Intent.wrapUp),
  ],
  'device_s4': [
    ('오늘 시험을 못본것 같아', _c), ('7', _c), ('문제를 많이 못풀었어', _c),
    ('왜 같은 말을 해?', _m), ('무슨 말이야', _m), ('너가 무슨말 하는지 모르겠어', _m),
    ('지금 무슨 이야기를 하는거야?', _m), ('뭐라는거야', _m),
    ('더 이야기 하자', Intent.continueTalking), ('잘 모르겠어', _n), ('모르겠어', _n),
    ('모르겠다니까', _n), ('모르겠다고, 왜 계속 같은말해 짜증나게', _m), ('응', _n),
    ('정리하자', Intent.wrapUp),
  ],
};

final _families = <String, _Driver Function()>{
  'cooperative': _cooperative,
  'confused': _confused,
  'nonAnswering': _nonAnswering,
  'complaining': _complaining,
  'angry': _angry,
  'variants': _variants,
  'mixed': _mixed,
  'continueThenNonAnswers': _continueThenNonAnswers,
};

const _maxTurns = 18;

void main() {
  late LocalCbtKnowledgeRepository repo;
  final runs = <FlowRun>[];
  final metrics = FlowMetrics();

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
    for (var t = 0; t < _maxTurns; t++) {
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
    for (final MapEntry(key: name, value: make) in _families.entries) {
      for (var week = 1; week <= 8; week++) {
        runs.add(await simulate('$name/w$week', week, make()));
      }
    }
    for (final MapEntry(key: name, value: script) in _deviceSessions.entries) {
      runs.add(await simulate(name, 4, _replay(script)));
    }
    for (final r in runs) {
      scoreFlow(r, metrics);
    }
    // ignore: avoid_print
    print('PHASE13_9A_REPORT ${const JsonEncoder.withIndent('  ').convert({
      'sessions': runs.length,
      'userTurns': runs.fold<int>(0, (n, r) => n + r.steps.length),
      'metrics': metrics.counts,
      'failures': metrics.failures,
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

  test('covers every family in weeks 1–8 plus the four device sessions', () {
    expect(runs, hasLength(_families.length * 8 + _deviceSessions.length));
  });

  group('Phase 13 gate on uncooperative users: all zero', () {
    for (final metric in flowGateMetrics) {
      test(metric, () {
        expect(metrics.counts[metric], 0, reason: metrics.failures[metric]?.join('\n'));
      });
    }
  });

  test('dev-set meta phrasings are all detected (outside closing)', () {
    expect(metrics.counts['metaIgnored'], 0, reason: metrics.failures['metaIgnored']?.join('\n'));
  });

  test('dev-set worry content is never taken for meta', () {
    expect(metrics.counts['metaFalsePositive'], 0,
        reason: metrics.failures['metaFalsePositive']?.join('\n'));
  });
}
