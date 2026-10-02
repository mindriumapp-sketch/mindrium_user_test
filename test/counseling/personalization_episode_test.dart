// Episodic personalization (2026-10-02): past session summaries change the
// next counseling action, inside the approved/week/gate limits.
//   D1 technique order: credited-before first, tried-but-never-credited last.
//   D2 recall: a similar past worry's own alternative thought is recalled
//      before the balanced-thought question.
//   Outcome: each integration records whether the answer earned the
//      technique's outcome (saved as the episode's intervention_outcome).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/episode_history.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/policy/intervention_eligibility_predicates.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

PreviousSession _episode(
  String id, {
  String? intervention,
  String? outcome,
  String? thought,
  String? alternative,
  String status = 'completed',
  int daysAgo = 1,
}) => PreviousSession(
  sessionId: id,
  week: 6,
  completionStatus: status,
  coreThought: thought,
  alternativeThought: alternative,
  interventionUsed: intervention,
  interventionOutcome: outcome,
  endedAt: DateTime(2026, 9, 30).subtract(Duration(days: daysAgo)),
);

const _w4 = 'week4_alternative_thought_01';
const _w5 = 'week5_confront_avoid_01';
const _w6 = 'week6_short_long_term_01';

void main() {
  group('EpisodeHistory', () {
    final h = EpisodeHistory.fromSessions([
      _episode('a', intervention: _w4, outcome: 'credited', daysAgo: 3),
      _episode('b', intervention: _w6, outcome: 'acknowledged', daysAgo: 2),
      _episode('c', intervention: _w4, outcome: 'credited', daysAgo: 1),
      _episode('d', intervention: _w5, outcome: 'credited', daysAgo: 5),
    ]);

    test('credited techniques, most credited first', () {
      expect(h.effectiveTechniqueIds, [_w4, _w5]);
    });

    test('tried but never credited', () {
      expect(h.ineffectiveTechniqueIds, {_w6});
    });

    test('a similar completed episode with an alternative thought is found', () {
      final past = EpisodeHistory.fromSessions([
        _episode('x', thought: '발표하다가 말이 막히면 어떡하지', alternative: '막혀도 다시 이어가면 된다'),
        _episode('y', thought: '시험을 망칠 것 같아', alternative: '준비한 만큼은 할 수 있다', status: 'interrupted'),
      ]);
      expect(past.similarEpisodeWithAlternative('내일 발표에서 실수할까봐 걱정돼')?.sessionId, 'x');
      // interrupted episodes are not recalled; unrelated worries aren't either.
      expect(past.similarEpisodeWithAlternative('시험이 걱정돼'), isNull);
      expect(past.similarEpisodeWithAlternative('면접에서 떨어질 것 같아'), isNull);
    });
  });

  group('D1: technique order', () {
    const registry = ApprovedInterventionRegistry();
    List<String> order(EpisodeHistory h) => [
      for (final p in InterventionCandidateResolver.personalizedOrder(registry.policiesUpTo(6), h))
        p.requiredId,
    ];

    test('no history keeps most-recent-week-first', () {
      expect(order(EpisodeHistory.empty), [_w6, _w5, _w4]);
    });

    test('credited first, never-credited last', () {
      final h = EpisodeHistory.fromSessions([
        _episode('a', intervention: _w4, outcome: 'credited'),
        _episode('b', intervention: _w6, outcome: 'acknowledged'),
      ]);
      expect(order(h), [_w4, _w5, _w6]);
    });

    test('never a future-week technique, whatever the history', () {
      final h = EpisodeHistory.fromSessions([
        _episode('a', intervention: 'week8_maintenance_01', outcome: 'credited'),
      ]);
      expect(order(h), isNot(contains('week8_maintenance_01')));
    });
  });

  group('in a session', () {
    late LocalCbtKnowledgeRepository repo;
    setUpAll(() async {
      repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
      await repo.initialize();
    });

    Future<List<CounselingMessage>> run(int week, EpisodeHistory h, List<String> turns) async {
      final harness = CounselingHarness.deterministic(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repo,
      );
      final s = CounselingSessionState(
        sessionId: 'pz',
        currentWeek: week,
        userContext: MindriumCounselingContext(currentWeek: week, episodes: h),
      );
      final out = <CounselingMessage>[];
      for (final (i, t) in turns.indexed) {
        final r = await harness.handleTurn(session: s, userMessage: t);
        s.messages
          ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
          ..add(r.assistantMessage);
        out.add(r.assistantMessage);
      }
      return out;
    }

    const turns = [
      '내일 발표가 있어서 불안해요',
      '7점이요',
      '발표하다가 말을 못 하면 어떡하지',
      '예전에 발표하다 말이 막힌 적이 있어요',
      '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
      '긴장해도 준비한 만큼은 할 수 있을 것 같아요',
    ];

    CounselingMessage prompt(List<CounselingMessage> r) =>
        r.firstWhere((m) => m.interventionStep == InterventionStep.prompt);

    test('week 6 without history uses the week 6 technique', () async {
      final r = await run(6, EpisodeHistory.empty, turns);
      expect(prompt(r).referencedCbtIds, [_w6]);
      expect(prompt(r).text.contains('지난번'), isFalse);
    });

    test('week 6 user for whom balanced thought worked before gets it, with the past alternative recalled', () async {
      final h = EpisodeHistory.fromSessions([
        _episode('past1',
            intervention: _w4,
            outcome: 'credited',
            thought: '발표 때 말이 막힐까 봐 걱정돼',
            alternative: '막혀도 잠깐 쉬고 다시 이어가면 된다'),
      ]);
      final r = await run(6, h, turns);
      final p = prompt(r);
      expect(p.referencedCbtIds, [_w4]);
      expect(p.text, contains('지난번 비슷한 걱정에서는 “막혀도 잠깐 쉬고 다시 이어가면 된다”라고 정리해 보셨어요.'));
    });

    test('an integration records whether the answer was credited', () async {
      final credited = await run(4, EpisodeHistory.empty, turns);
      expect(credited.last.interventionCredited, isTrue);
      final ack = await run(4, EpisodeHistory.empty, [...turns.take(5), '모르겠어']);
      expect(ack.last.interventionCredited, isFalse);
    });
  });
}
