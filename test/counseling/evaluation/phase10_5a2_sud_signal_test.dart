// Phase 10.5A.2 Track B: the explicit SUD-rating semantic signal added to
// CounselingRealizationSpec. Verifies the value-extraction helper handles
// the phrasings actually found in the Phase 10.5A holdout_v1 fixtures
// (including "한 8점 정도요", which the pre-existing `_isSudResponse`
// wording-branch check does NOT match — that's untouched by design, this
// signal is purely additive) and that TurnPlanMaterializer.explore() wires
// the extracted value onto the plan's realizationSpec.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';

void main() {
  const materializer = TurnPlanMaterializer();

  group('sudRatingValue extraction via TurnPlanMaterializer.explore', () {
    test('"7점이요." -> 7', () {
      final plan = materializer.explore(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('7점이요'),
        ),
        userMessage: '7점이요.',
        recentMessages: const [],
        allowedActsForTurn: const [],
      );
      expect(plan.realizationSpec!.sudRatingValue, 7);
    });

    test('"한 8점 정도요." -> 8 (a phrasing _isSudResponse itself does not match)', () {
      final plan = materializer.explore(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('한 8점 정도요'),
        ),
        userMessage: '한 8점 정도요.',
        recentMessages: const [],
        allowedActsForTurn: const [],
      );
      expect(plan.realizationSpec!.sudRatingValue, 8);
    });

    test('"6점이에요." -> 6', () {
      final plan = materializer.explore(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('6점이에요'),
        ),
        userMessage: '6점이에요.',
        recentMessages: const [],
        allowedActsForTurn: const [],
      );
      expect(plan.realizationSpec!.sudRatingValue, 6);
    });

    test('ordinary (non-numeric) worry message -> null', () {
      final plan = materializer.explore(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('면접이 다가오니까 계속 초조해요'),
        ),
        userMessage: '면접이 다가오니까 계속 초조해요.',
        recentMessages: const [],
        allowedActsForTurn: const [],
      );
      expect(plan.realizationSpec!.sudRatingValue, isNull);
    });

    test('out-of-range number is not treated as a SUD rating', () {
      final plan = materializer.explore(
        const CounselorDecision(
          selectedAction: DialogueAct.explore,
          reflectionTarget: ReflectionTarget.text('회의 3번째 안건이 걱정이에요'),
        ),
        userMessage: '회의 3번째 안건이 걱정이에요.',
        recentMessages: const [],
        allowedActsForTurn: const [],
      );
      // No "N점" pattern at all here — must stay null, not misfire on "3".
      expect(plan.realizationSpec!.sudRatingValue, isNull);
    });
  });
}
