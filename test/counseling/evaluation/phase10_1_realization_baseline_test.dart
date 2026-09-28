// Phase 10.1: locks in TODAY's TurnPlanMaterializer output as a baseline
// snapshot, BEFORE any Phase 10.2 wording/structure change. This test is
// deliberately not "should" — it records what current production actually
// says, including the verbatim-quoting and abrupt-transition patterns named
// in docs/counseling/phase10_1_failure_taxonomy.md (R1/R3/R8). A failing
// assertion here after Phase 10.2 work starts is expected and desired: it
// means behavior intentionally changed, and this file's expectations should
// be updated deliberately (not silently) to describe the new baseline.
//
// Phase 10.1 makes zero production changes, so every assertion below must
// pass unmodified against current `main`/`2027_demo` code.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';

CbtKnowledgeItem _cbtItem({required String id, int week = 4}) =>
    CbtKnowledgeItem(
      id: id,
      week: week,
      type: 'technique',
      title: id,
      paragraphs: const ['검증용 문단'],
      tags: const ['alternative_thought', 'cognitive_restructuring'],
      source: 'test',
      conversationalGuidanceAvailable: true,
    );

void main() {
  const materializer = TurnPlanMaterializer();

  test('R1: checkIn quotes user input verbatim in the reflection sentence', () {
    final plan = materializer.checkIn(
      const CounselorDecision(
        selectedAction: DialogueAct.explore,
        reflectionTarget: ReflectionTarget.text('오늘은 좀 힘들었어요'),
      ),
    );
    expect(plan.reflectionSentence, '“오늘은 좀 힘들었어요”라고 말씀해 주셨군요.');
    expect(
      plan.questionSentence,
      '지금 느끼는 불안을 0에서 10 사이로 표현하면 어느 정도인가요?',
    );
    // R3: no transition between the two — a plain space join.
    expect(plan.deterministicReply, '${plan.reflectionSentence} ${plan.questionSentence}');
  });

  test('R8: intervention reflection is a single fixed template per type, always quoting verbatim', () {
    final knowledge = [_cbtItem(id: 'cbt:balanced:1')];
    final plan = materializer.intervention(
      CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        selectedInterventionId: 'cbt:balanced:1',
        reflectionTarget: const ReflectionTarget.text(
          '시험에서 떨어지면 인생이 끝날 것 같다',
        ),
      ),
      currentWeek: 4,
      knowledge: knowledge,
    );
    expect(
      plan.reflectionSentence,
      '“시험에서 떨어지면 인생이 끝날 것 같다”라는 생각을 함께 살펴보겠습니다.',
    );
    expect(
      plan.questionSentence,
      '이 생각을 조금 더 균형 있게 바꾼다면 어떤 문장이 될 수 있을까요?',
    );
    // R8: rerunning with a different target produces the same skeleton,
    // only the quoted span differs — proving zero rotation/variation exists
    // for this state today.
    final plan2 = materializer.intervention(
      CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        selectedInterventionId: 'cbt:balanced:1',
        reflectionTarget: const ReflectionTarget.text('다른 걱정거리'),
      ),
      currentWeek: 4,
      knowledge: knowledge,
    );
    expect(plan2.questionSentence, plan.questionSentence);
    expect(
      plan2.reflectionSentence,
      '“다른 걱정거리”라는 생각을 함께 살펴보겠습니다.',
    );
  });

  test('closing quotes the target verbatim when present, and asks no question', () {
    final plan = materializer.closing(
      const CounselorDecision(
        selectedAction: DialogueAct.closing,
        reflectionTarget: ReflectionTarget.text(
          '가족 모임에서 오빠와 다시 부딪힐까 봐 걱정된다',
        ),
      ),
    );
    expect(
      plan.reflectionSentence,
      '오늘은 “가족 모임에서 오빠와 다시 부딪힐까 봐 걱정된다”라는 이야기를 나눴습니다. '
      '여기까지 이야기해 주셔서 감사합니다.',
    );
    expect(plan.questionSentence, '');
  });

  test('reflect (evidence goal) paraphrases target rather than quoting it verbatim', () {
    final plan = materializer.reflect(
      const CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        selectedGoalId: 'evidence',
        reflectionTarget: ReflectionTarget.text(
          '질문에 답을 못하면 무능해 보일 것 같다는 생각이 들어요',
        ),
      ),
      recentMessages: const [],
      allowedActsForTurn: const [],
    );
    // Unlike every other state's reflection, this branch does not wrap the
    // raw target in "" — it rewrites it into a noun phrase first.
    expect(plan.reflectionSentence.contains('“'), isFalse);
    expect(
      plan.questionSentence,
      '그 생각을 사실이라고 느끼게 하는 근거나 경험이 무엇인지 하나 떠올려볼까요?',
    );
  });
}
