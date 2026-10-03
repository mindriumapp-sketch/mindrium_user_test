// Phase 10.3B: Reflection Surface Robustness. Narrow follow-up to Phase
// 10.3 — fixes exactly two target-shape composition defects found via the
// 72-scenario dev comparison export (docs/counseling/chatbot_system.md's
// "Known limitation" section), and nothing else. Not broad style tuning:
// R2/R3(non-intervention)/R5/R8/R11/R12 are explicitly out of scope here.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';
import 'package:gad_app_team/features/counseling/policy/realization/semantic_deterministic_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';

Future<String> _realize(plan, realizer) async {
  final request = RealizationRequest.fromPlan(
    plan: plan,
    retrievalSummary: RetrievalSummary.empty,
  );
  final result = await realizer.realize(request);
  return result.reply as String;
}

void main() {
  const materializer = TurnPlanMaterializer();
  const semanticRealizer = SemanticDeterministicResponseRealizer();

  group('classifyReflectionTargetShape', () {
    test('phrase', () {
      expect(
        classifyReflectionTargetShape('시험'),
        ReflectionTargetShape.phrase,
      );
    });

    test('declarative sentence', () {
      expect(
        classifyReflectionTargetShape('면접이 다가오니까 계속 초조해요'),
        ReflectionTargetShape.declarativeSentence,
      );
    });

    test('question-form sentence (no literal "?", ends in -까요.)', () {
      expect(
        classifyReflectionTargetShape('생각을 또 바꿔볼까요.'),
        ReflectionTargetShape.questionSentence,
      );
    });

    test('multi-sentence target (internal terminal punctuation)', () {
      expect(
        classifyReflectionTargetShape('가족들이랑 또 다퉜어요. 마음이 복잡해요.'),
        ReflectionTargetShape.multiSentence,
      );
    });

    test('trailing punctuation alone does not make a target multiSentence', () {
      expect(
        classifyReflectionTargetShape('오늘은 좀 힘들었어요.'),
        ReflectionTargetShape.declarativeSentence,
      );
    });

    test('bare "-가요" ending is not misclassified as a question', () {
      // "가요" is also the plain conjugation of 가다 ("[I] go") — must not
      // be swept into questionSentence, or ordinary statements would be
      // routed to the generic fallback for no reason. It isn't in either
      // recognized ending list, so it conservatively falls to `phrase` —
      // what matters here is that it's NOT `questionSentence`.
      expect(
        classifyReflectionTargetShape('내일 병원에 가요'),
        isNot(ReflectionTargetShape.questionSentence),
      );
    });
  });

  test(
    'multi-sentence target no longer gets a suffix bolted onto the whole sentence',
    () async {
      final plan = materializer.checkIn(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text(
            '가족들이랑 또 다퉜어요. 마음이 복잡해요.',
          ),
        ),
      );
      final semantic = await _realize(plan, semanticRealizer);
      // The old (Phase 10.3A) defect: "...복잡해요 부분이 마음에 걸리시는 것
      // 같아요." — a suffix concatenated onto a full multi-clause sentence.
      expect(semantic.contains('복잡해요 부분이'), isFalse);
      expect(semantic.contains('“'), isFalse);
      // Must still ask the same (unchanged) question.
      expect(semantic.contains(plan.questionSentence), isTrue);
    },
  );

  test(
    'question-form target no longer gets a declarative suffix bolted on',
    () async {
      final plan = materializer.interventionUnavailable(
        '생각을 또 바꿔볼까요.',
        const [],
      );
      final semantic = await _realize(plan, semanticRealizer);
      // The old (Phase 10.3A) defect: "...바꿔볼까요 부분이 마음에 걸리시는 것
      // 같아요." — a declarative acknowledgment suffix glued onto a
      // question-shaped target.
      expect(semantic.contains('바꿔볼까요 부분이'), isFalse);
      expect(semantic.contains('“'), isFalse);
      expect(semantic.contains(plan.questionSentence), isTrue);
    },
  );

  test(
    'Phase 12.3 (N5): declarative single-clause target gets the generic acknowledgment',
    () async {
      final plan = materializer.checkIn(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('면접이 다가오니까 계속 초조해요'),
        ),
      );
      final semantic = await _realize(plan, semanticRealizer);
      // Reversed from the original 10.3B decision. Slotting a clause into
      // "X 부분이 마음에 걸리시는" is ungrammatical; device dogfood produced
      // exactly that ("미팅준비가 가장 마음에 걸려 부분이…").
      expect(semantic.contains('면접이 다가오니까 계속 초조해요'), isFalse);
      expect(semantic.contains('초조해요 부분이'), isFalse);
    },
  );

  test(
    'phrase-shaped target is unaffected by the 10.3B gate',
    () async {
      final plan = materializer.checkIn(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('시험 걱정'),
        ),
      );
      final semantic = await _realize(plan, semanticRealizer);
      expect(semantic.contains('시험 걱정'), isTrue);
    },
  );

  test(
    'fallback for unsafe shapes introduces no new user fact — generic wording only',
    () async {
      final plan = materializer.checkIn(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text(
            '가족들이랑 또 다퉜어요. 마음이 복잡해요.',
          ),
        ),
      );
      final semantic = await _realize(plan, semanticRealizer);
      // The fallback must not mention specifics ("가족"/"다퉜어요") that
      // would otherwise require paraphrasing the target's actual content —
      // it only uses the fixed generic acknowledgment pool.
      expect(semantic.contains('가족'), isFalse);
      expect(semantic.contains('다퉜'), isFalse);
    },
  );

  test('questionSentence and selectedAction/selectedGoalId/selectedInterventionId stay untouched', () async {
    final decision = const CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text('가족들이랑 또 다퉜어요. 마음이 복잡해요.'),
    );
    final plan = materializer.checkIn(decision);
    final semantic = await _realize(plan, semanticRealizer);
    expect(semantic.endsWith(plan.questionSentence), isTrue);
    expect(decision.selectedAction, DialogueAct.explore);
    expect(decision.selectedGoalId, isNull);
    expect(decision.selectedInterventionId, isNull);
  });
}
