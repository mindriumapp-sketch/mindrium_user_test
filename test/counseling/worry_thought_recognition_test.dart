// Phase 12.3 (N3): reflect didn't recognize common worry-thought forms, so
// both reflect turns went to the clarify branch and no evidence/alternative
// question was ever asked. Consecutive near-identical clarify questions were
// also the trigger for the Remote Realizer copying its previous sentence
// (N2 root-cause analysis). Dogfood sessions 2, 3 and 4.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/user_thought_extractor.dart';
import 'package:gad_app_team/features/counseling/policy/selectors/reflect_decision_selector.dart';

CounselingMessage _m(String role, String text, int i, {String? goal}) =>
    CounselingMessage(
      id: '$role$i',
      role: role,
      text: text,
      createdAt: DateTime(2026, 9, 28),
      dialogueGoalId: goal,
    );

void main() {
  const positives = [
    '재밌게 놀아야하는데 어색해서 서로 조금 불편하게 놀까봐 걱정돼', // dogfood s2
    '내일 시험을 잘 못보면 어떡하지?', // dogfood s3
    '미팅준비가 가장 마음에 걸려', // dogfood s4
    '발표하다가 말을 못 하면 어떡하지',
    '거절당할까 봐 신경 쓰여',
    '늦으면 혼날까 봐 불안해',
    '교수님이 실망하실 것 같아서 불안해',
  ];
  const negatives = [
    '발표가 내일이라 걱정돼',
    '요즘 좀 불안해',
    '그냥 걱정돼요',
    '시험이 있어서 신경 쓰여',
    '그냥 한번 해볼까 봐요',
    '몰라요',
    '네',
  ];

  group('worry-thought forms are recognized as thoughts', () {
    for (final m in positives) {
      test(m, () => expect(UserThoughtExtractor.thoughtShaped(m), isNotNull));
    }
  });

  group('situations and plain feelings are not', () {
    for (final m in negatives) {
      test(m, () => expect(UserThoughtExtractor.thoughtShaped(m), isNull));
    }
  });

  group('reflect no longer spends both turns on clarify (dogfood replays)', () {
    const selector = ReflectDecisionSelector();

    test('session 3: "잘 못보면 어떡하지?" gets the evidence goal', () {
      final d = selector.select(
        userMessage: '내일 시험을 잘 못보면 어떡하지?',
        recentMessages: [_m('user', '내일 시험이 있어', 0), _m('assistant', '가장 걱정되는 순간은 언제인가요?', 0)],
        userContext: null,
      );
      expect(d.selectedAction, DialogueAct.socraticQuestion);
      expect(d.selectedGoalId, 'evidence');
    });

    test('session 2: "…놀까봐 걱정돼" gets the evidence goal', () {
      final d = selector.select(
        userMessage: '재밌게 놀아야하는데 어색해서 서로 조금 불편하게 놀까봐 걱정돼',
        recentMessages: [_m('user', '6', 0), _m('assistant', '그 상황에서 가장 걱정되는 순간은 언제인가요?', 0)],
        userContext: null,
      );
      expect(d.selectedGoalId, 'evidence');
    });

    test('session 4: second reflect turn "미팅준비가 가장 마음에 걸려" gets the evidence goal', () {
      final d = selector.select(
        userMessage: '미팅준비가 가장 마음에 걸려',
        recentMessages: [
          _m('user', '갑자기 무슨말이야', 0),
          _m('assistant', '지금 여러 가지 일을 동시에 하고 계신 것 같은데, 그 중에서 특히 어떤 부분이 가장 마음에 걸리나요?', 0),
        ],
        userContext: null,
      );
      expect(d.selectedGoalId, 'evidence');
    });

    test('a plain situation still gets clarify', () {
      final d = selector.select(
        userMessage: '발표가 내일이라 걱정돼',
        recentMessages: const [],
        userContext: null,
      );
      expect(d.selectedAction, DialogueAct.explore);
    });
  });
}
