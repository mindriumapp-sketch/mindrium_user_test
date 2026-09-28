// Phase 12.3A (F3): a user message the system answered with an
// interaction-repair turn is about the conversation, not the worry. It
// stays in history, but must never be picked as reflection, intervention
// or closing content.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/closing_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/explore_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/intervention_decision_selector.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/reflect_decision_selector.dart';

CounselingMessage _user(String text, int i) => CounselingMessage(
  id: 'u$i',
  role: 'user',
  text: text,
  createdAt: DateTime(2026, 9, 1),
);

CounselingMessage _assistant(
  int i, {
  InteractionRepairReason? repair,
  String? goal,
}) => CounselingMessage(
  id: 'a$i',
  role: 'assistant',
  text: repair != null ? '맞아요, 비슷한 질문을 반복해서 드렸네요.' : '그렇군요.',
  createdAt: DateTime(2026, 9, 1),
  dialogueAct: repair != null ? DialogueAct.reflect : DialogueAct.socraticQuestion,
  interactionRepairReason: repair,
  dialogueGoalId: goal,
);

const _worry = '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.';

List<CounselingMessage> _historyWith(String meta, InteractionRepairReason r) => [
  _user(_worry, 0),
  _assistant(0, goal: 'evidence'),
  _user(meta, 1),
  _assistant(1, repair: r),
];

String? _text(ReflectionTarget? t) =>
    t is ReflectionTargetText ? t.value : null;

CbtKnowledgeItem _cbt() => CbtKnowledgeItem(
  id: 'week4_alternative_thought_01',
  week: 4,
  type: 'technique',
  title: 'week4_alternative_thought_01',
  paragraphs: const ['검증용'],
  tags: const ['alternative_thought', 'cognitive_restructuring'],
  source: 'test',
  conversationalGuidanceAvailable: true,
);

void main() {
  const repairs = {
    InteractionRepairReason.repeatedQuestion: '아까도 물어봤잖아요.',
    InteractionRepairReason.stopQuestioning: '질문 그만하고 그냥 들어주세요.',
    InteractionRepairReason.processFrustration: '이런 거 한다고 뭐가 달라질까 싶어요.',
  };

  for (final entry in repairs.entries) {
    group('${entry.key.name} utterance is excluded from semantic targets', () {
      final history = _historyWith(entry.value, entry.key);

      test('A. intervention target skips it', () {
        final d = const InterventionDecisionSelector().select(
          currentWeek: 4,
          userMessage: '네, 그냥 계속 걱정되긴 해요.',
          recentMessages: history,
          knowledge: [_cbt()],
          userContext: null,
          registry: const ApprovedInterventionRegistry(),
        );
        expect(_text(d.reflectionTarget), isNot(entry.value));
        expect(_text(d.reflectionTarget), _worry);
      });

      test('B. closing summary skips it', () {
        final d = const ClosingDecisionSelector().select(
          userMessage: '고마워요',
          recentMessages: history,
        );
        expect(_text(d.reflectionTarget), _worry);
      });

      test('reflect follow-up target skips it', () {
        final d = const ReflectDecisionSelector().select(
          userMessage: '네.',
          recentMessages: history,
          userContext: null,
        );
        expect(_text(d.reflectionTarget), isNot(entry.value));
      });

      test('explore SUD fallback skips it', () {
        final d = const ExploreDecisionSelector().select(
          userMessage: '7점이에요.',
          recentMessages: history,
        );
        expect(_text(d.reflectionTarget), _worry);
      });

      test('history itself is unchanged (message kept, metadata kept)', () {
        expect(history, hasLength(4));
        expect(history[2].text, entry.value);
        expect(history[3].interactionRepairReason, entry.key);
      });
    });
  }

  group('D. normal content selection is unchanged', () {
    final plain = [_user(_worry, 0), _assistant(0, goal: 'evidence')];

    test('eligible view of a repair-free history is identical', () {
      expect(UserThoughtExtractor.semanticContent(plain), plain);
    });

    test('intervention still uses the latest user message', () {
      final d = const InterventionDecisionSelector().select(
        currentWeek: 4,
        userMessage: '네.',
        recentMessages: plain,
        knowledge: [_cbt()],
        userContext: null,
        registry: const ApprovedInterventionRegistry(),
      );
      expect(_text(d.reflectionTarget), _worry);
    });

    test('a turn is excluded by the reply that closes it, not the first one', () {
      // Instant-empathy history: user, empathy bubble, then the real reply.
      final withEmpathy = [
        _user('아까도 물어봤잖아요.', 1),
        _assistant(9),
        _assistant(1, repair: InteractionRepairReason.repeatedQuestion),
      ];
      expect(
        UserThoughtExtractor.semanticContent(withEmpathy).where((m) => m.isUser),
        isEmpty,
      );
    });

    test('unanswered last user message stays eligible', () {
      final pending = [..._historyWith('아까도 물어봤잖아요.', InteractionRepairReason.repeatedQuestion), _user(_worry, 2)];
      expect(UserThoughtExtractor.semanticContent(pending).last.text, _worry);
    });
  });
}
