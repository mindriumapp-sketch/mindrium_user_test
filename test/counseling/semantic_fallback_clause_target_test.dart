// Phase 12.3 follow-up (N5): the semantic-deterministic fallback slotted a
// whole verb-final clause into a noun position. Real device output (dogfood
// session 4): "미팅준비가 가장 마음에 걸려 부분이 마음에 걸리시는 것 같아요."
// The N2 guard sends more turns to this fallback, so the defect surfaced
// more often.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';
import 'package:gad_app_team/features/counseling/policy/realization/semantic_deterministic_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';

const _suffixes = ['부분이 마음에 걸리시는', '때문에 마음이 무거우신', '생각이 계속 신경 쓰이시는'];

Future<String> _explore(String target) async {
  final plan = const TurnPlanMaterializer().explore(
    CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text(target),
    ),
    userMessage: target,
    recentMessages: const [],
    allowedActsForTurn: const [],
  );
  final result = await const SemanticDeterministicResponseRealizer().realize(
    RealizationRequest.fromPlan(plan: plan, retrievalSummary: RetrievalSummary.empty),
  );
  return result.reply;
}

void main() {
  group('verb-final clauses are never slotted into a noun position', () {
    const clauses = [
      '미팅준비가 가장 마음에 걸려', // dogfood session 4
      '7점이요', // 12.3D copying-realizer trace
      '다음주에 여행이 계획 되어있는데 같이가는 친구들이랑 어색해', // dogfood session 2
      '내일 시험이 있어', // dogfood session 3
      '면접이 다가오니까 계속 초조해요',
      '준비를 못한게 티가나서 혼날 것 같아',
    ];
    for (final c in clauses) {
      test(c, () async {
        final reply = await _explore(c);
        for (final s in _suffixes) {
          expect(reply.contains('$c $s'), isFalse, reason: reply);
        }
        expect(reply.contains(c), isFalse, reason: 'no verbatim parroting: $reply');
      });
    }
  });

  group('noun phrases keep the specific template', () {
    for (final p in ['시험 걱정', '친구들과의 어색함', '미팅 준비']) {
      test(p, () async {
        final reply = await _explore(p);
        expect(_suffixes.any((s) => reply.contains('$p $s')), isTrue, reason: reply);
      });
    }
  });
}
