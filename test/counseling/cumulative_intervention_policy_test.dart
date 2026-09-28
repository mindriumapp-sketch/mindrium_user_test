// Phase 13.2: cumulative intervention policy. Approved techniques from any
// week up to the current one can be used (most recent first); future-week
// techniques never are. When nothing fits, the outcome is an explicit,
// normal noEligibleIntervention (DialogueAct.summarize), never `unknown`,
// so the session can progress to closing (N1).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

const _script = [
  '내일 발표가 있어서 불안해요',
  '7점이요',
  '발표하다가 말을 못 하면 어떡하지',
  '예전에 발표하다 말이 막힌 적이 있어요',
  '한 번 막혔다고 매번 그런 건 아닐 수도 있겠네요',
  '준비한 만큼은 할 수 있을 것 같아요',
  '고마워요',
  '네',
];

class _Run {
  final List<CounselingState> before = [];
  final List<CounselingMessage> replies = [];
  CounselingState finalState = CounselingState.checkIn;
}

void main() {
  late LocalCbtKnowledgeRepository repo;
  setUpAll(() async {
    repo = LocalCbtKnowledgeRepository(loadAsset: (p) => File(p).readAsString());
    await repo.initialize();
  });

  Future<_Run> run(int week) async {
    final h = CounselingHarness.deterministic(
      llm: MockLlmService(),
      safetyGate: const KeywordSafetyGate(),
      knowledgeRepository: repo,
    );
    final s = CounselingSessionState(sessionId: 'w$week', currentWeek: week);
    final out = _Run();
    for (final (i, t) in _script.indexed) {
      out.before.add(s.state);
      final r = await h.handleTurn(session: s, userMessage: t);
      s.messages
        ..add(CounselingMessage(id: 'u$i', role: 'user', text: t, createdAt: DateTime(2026)))
        ..add(r.assistantMessage);
      out.replies.add(r.assistantMessage);
    }
    out.finalState = s.state;
    return out;
  }

  group('N1: every week reaches closing', () {
    for (var week = 1; week <= 8; week++) {
      test('week $week', () async {
        final r = await run(week);
        expect(r.finalState, CounselingState.closing);
        final interventionTurns = [
          for (final (i, st) in r.before.indexed)
            if (st == CounselingState.intervention) r.replies[i],
        ];
        expect(interventionTurns, isNotEmpty);
        for (final m in interventionTurns) {
          expect(m.dialogueAct, isNot(DialogueAct.unknown), reason: m.text);
        }
      });
    }
  });

  group('weeks 1-3 have no approved technique: explicit noEligible, no CBT', () {
    for (var week = 1; week <= 3; week++) {
      test('week $week', () async {
        final r = await run(week);
        final i = r.before.indexOf(CounselingState.intervention);
        expect(r.replies[i].dialogueAct, DialogueAct.summarize);
        expect(r.replies[i].referencedCbtIds, isEmpty);
        expect(r.replies[i].text.contains('?'), isFalse);
      });
    }
  });

  group('techniques are cumulative, never from a future week', () {
    const registry = ApprovedInterventionRegistry();

    test('policiesUpTo is ordered most recent first and excludes future weeks', () {
      expect(registry.policiesUpTo(3), isEmpty);
      expect(registry.policiesUpTo(4).map((p) => p.week), [4]);
      expect(registry.policiesUpTo(7).map((p) => p.week), [7, 6, 5, 4]);
    });

    for (var week = 4; week <= 8; week++) {
      test('week $week uses only weeks <= $week', () async {
        final r = await run(week);
        final approvedUpTo = {
          for (final p in registry.policiesUpTo(week)) p.requiredId,
        };
        final allApproved = {for (final p in registry.policies) p.requiredId};
        for (final m in r.replies) {
          for (final id in m.referencedCbtIds.where(allApproved.contains)) {
            expect(approvedUpTo, contains(id), reason: 'future-week technique $id');
          }
        }
      });
    }

    test('week 7 ordinary worry (avoidance gate fails) falls back to an earlier approved technique', () async {
      final r = await run(7);
      final i = r.before.indexOf(CounselingState.intervention);
      expect(r.replies[i].dialogueAct, DialogueAct.socraticQuestion);
    });
  });
}
