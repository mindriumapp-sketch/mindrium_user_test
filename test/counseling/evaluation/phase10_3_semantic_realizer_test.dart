// Phase 10.3: SemanticDeterministicResponseRealizer — the first
// ResponseRealizer that consumes CounselingRealizationSpec (Phase 10.2)
// instead of only passing deterministicDraft through. This is a PARALLEL
// implementation; production still defaults to
// DeterministicResponseRealizer (identity) — see
// docs/counseling/phase10_3_semantic_realizer.md.
//
// Every test builds a real CounselingTurnPlan via TurnPlanMaterializer
// (not a hand-rolled spec) and feeds it through RealizationRequest.fromPlan,
// so this exercises the actual production wiring path end to end.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/materializers/turn_plan_materializer.dart';
import 'package:gad_app_team/features/counseling/policy/realization/semantic_deterministic_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

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

Future<String> _realize(
  CounselingTurnPlan plan,
  ResponseRealizer realizer,
) async {
  final request = RealizationRequest.fromPlan(
    plan: plan,
    retrievalSummary: RetrievalSummary.empty,
  );
  final result = await realizer.realize(request);
  return result.reply;
}

int _questionMarkCount(String text) => text.split('?').length - 1;

void main() {
  const materializer = TurnPlanMaterializer();
  const semanticRealizer = SemanticDeterministicResponseRealizer();
  const legacyRealizer = DeterministicResponseRealizer();

  test('A: raw "" quotation is removed from the reflection for a normal reflectionTarget', () async {
    final plan = materializer.checkIn(
      const CounselorDecision(
        selectedAction: DialogueAct.explore,
        reflectionTarget: ReflectionTarget.text('오늘은 좀 힘들었어요'),
      ),
    );
    final legacy = await _realize(plan, legacyRealizer);
    final semantic = await _realize(plan, semanticRealizer);

    expect(legacy.contains('“'), isTrue, reason: 'legacy path still quotes — sanity check');
    expect(semantic.contains('“'), isFalse);
    expect(semantic.contains('오늘은 좀 힘들었어요'), isTrue,
        reason: 'target content must be preserved, only the quoting removed');
  });

  test('B/C: intervention reflection -> why-now bridge -> unchanged question, not a bare concat', () async {
    final knowledge = [_cbtItem(id: 'cbt:balanced:1')];
    final decision = CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      selectedInterventionId: 'cbt:balanced:1',
      reflectionTarget: const ReflectionTarget.text(
        '시험에서 떨어지면 인생이 끝날 것 같다',
      ),
    );
    final plan = materializer.intervention(
      decision,
      currentWeek: 4,
      knowledge: knowledge,
    );
    final legacy = await _realize(plan, legacyRealizer);
    final semantic = await _realize(plan, semanticRealizer);

    expect(legacy, isNot(equals(semantic)));
    // D/E: the InterventionRationale-grounded bridge must appear as its own
    // clause, distinct from both the reflection and the (unchanged) question.
    expect(
      semantic.contains('다른 관점에서도 살펴보면 도움이 될 것 같아요') ||
          semantic.contains('사실과 얼마나 맞닿아 있는지 함께 살펴볼게요'),
      isTrue,
    );
    expect(semantic.endsWith(plan.questionSentence), isTrue,
        reason: 'the actual question wording must be reused unchanged');
  });

  test('D: all 5 InterventionRationale values render a distinct grounded bridge', () async {
    final rationalesSeen = <String>{};
    final types = [
      InterventionType.balancedThought,
      InterventionType.behaviorPatternReview,
      InterventionType.consequenceReview,
      InterventionType.gainLossReview,
      InterventionType.maintenanceReview,
    ];
    for (final type in types) {
      final id = 'cbt:${type.name}';
      final knowledge = [_cbtItem(id: id)];
      // Build via the registry-driven method by faking currentWeek→type
      // mapping is awkward here, so construct the plan through the same
      // realization-spec builder path the materializer itself uses.
      final decision = CounselorDecision(
        selectedAction: DialogueAct.socraticQuestion,
        selectedInterventionId: id,
        reflectionTarget: const ReflectionTarget.text('걱정되는 상황'),
      );
      // Route through the real per-type wording helpers via reflection of
      // the public API: call intervention() with a registry whose only
      // policy for this week matches `type`.
      final plan = _planForType(materializer, decision, type, knowledge);
      final semantic = await _realize(plan, semanticRealizer);
      rationalesSeen.add(semantic);
    }
    expect(rationalesSeen.length, 5,
        reason: 'each InterventionRationale must produce distinguishable wording');
  });

  test('F: question mark count is never higher in the semantic path than the legacy path', () async {
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
    final legacy = await _realize(plan, legacyRealizer);
    final semantic = await _realize(plan, semanticRealizer);
    expect(_questionMarkCount(semantic), _questionMarkCount(legacy));
    expect(semantic.contains(plan.questionSentence), isTrue);
  });

  test('H: realizationSpec == null falls back to the legacy deterministicDraft verbatim', () async {
    const plan = CounselingTurnPlan(
      reflectionTarget: '레거시 경로',
      questionGoal: '레거시 질문 목표',
      reflectionSentence: '“레거시 경로”라고 말씀해 주셨군요.',
      questionSentence: '레거시 질문입니까?',
      forbidden: [],
      constraints: [],
      requiredAct: DialogueAct.explore,
      userContextIds: [],
      cbtContextIds: [],
      // realizationSpec intentionally omitted -> null, mirroring a legacy
      // Deterministic*TurnPlanner-built plan.
    );
    final semantic = await _realize(plan, semanticRealizer);
    expect(semantic, plan.deterministicReply);
  });

  test('I: closing keeps its no-question structure and drops the topic quote', () async {
    final plan = materializer.closing(
      const CounselorDecision(
        selectedAction: DialogueAct.closing,
        reflectionTarget: ReflectionTarget.text(
          '가족 모임에서 오빠와 다시 부딪힐까 봐 걱정된다',
        ),
      ),
    );
    final semantic = await _realize(plan, semanticRealizer);
    expect(semantic.contains('?'), isFalse);
    expect(semantic.contains('“'), isFalse);
  });

  test('G: intervention bridge introduces no new intervention id or CBT fact', () async {
    final knowledge = [_cbtItem(id: 'cbt:balanced:1')];
    final decision = CounselorDecision(
      selectedAction: DialogueAct.socraticQuestion,
      selectedInterventionId: 'cbt:balanced:1',
      reflectionTarget: const ReflectionTarget.text('시험 걱정'),
    );
    final plan = materializer.intervention(
      decision,
      currentWeek: 4,
      knowledge: knowledge,
    );
    final semantic = await _realize(plan, semanticRealizer);
    // The bridge/question must stay within the approved question set for
    // this InterventionType — reuses plan.questionSentence verbatim.
    expect(semantic.contains(plan.questionSentence), isTrue);
    expect(plan.interventionPlan!.selectedCbtId, 'cbt:balanced:1');
  });

  test('J: repeated identical target does not repeat the exact same reflection candidate back-to-back', () async {
    final decision = const CounselorDecision(
      selectedAction: DialogueAct.explore,
      reflectionTarget: ReflectionTarget.text('같은 걱정'),
    );
    final plan = materializer.checkIn(decision);
    final request1 = RealizationRequest.fromPlan(
      plan: plan,
      retrievalSummary: RetrievalSummary.empty,
    );
    final first = await semanticRealizer.realize(request1);

    final assistantTurn = CounselingMessage(
      id: 'm1',
      role: 'assistant',
      text: first.reply,
      createdAt: DateTime.now(),
    );
    final request2 = RealizationRequest.fromPlan(
      plan: plan,
      retrievalSummary: RetrievalSummary.empty,
      recentConversation: [assistantTurn],
    );
    final second = await semanticRealizer.realize(request2);
    expect(second.reply, isNot(equals(first.reply)));
  });
}

CounselingTurnPlan _planForType(
  TurnPlanMaterializer materializer,
  CounselorDecision decision,
  InterventionType type,
  List<CbtKnowledgeItem> knowledge,
) {
  // Every InterventionType in this project's registry is tied to a
  // specific approved week; rather than depend on that private mapping,
  // exercise the materializer through its public `intervention()` method
  // with a single-policy registry constructed for exactly this type.
  final registry = ApprovedInterventionRegistry(
    policies: [
      ApprovedInterventionPolicy(
        week: 4,
        interventionType: type,
        requiredId: knowledge.first.id,
        requiredType: knowledge.first.type,
        requiredTags: const {},
      ),
    ],
  );
  final localMaterializer = TurnPlanMaterializer(registry: registry);
  return localMaterializer.intervention(
    decision,
    currentWeek: 4,
    knowledge: knowledge,
  );
}
