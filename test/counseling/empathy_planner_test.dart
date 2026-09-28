import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/empathy_planner.dart';

void main() {
  const planner = EmpathyPlanner();

  group('근거 없는 과거 언급 금지', () {
    test('요약이 비면 과거를 언급하지 않는다', () {
      final plan = planner.plan(userMessage: '내일 발표가 걱정돼요.');

      expect(plan.referencedPast, isFalse);
      expect(plan.provenanceIds, isEmpty);
      expect(plan.sentence, isNot(contains('지난번')));
    });

    test('과거 생각만 있고 현재 생각이 없으면 언급하지 않는다', () {
      final plan = planner.plan(
        userMessage: '내일 발표가 있어요.',
        summary: const RetrievalSummary(
          currentTheme: '발표 전 긴장',
          similarPastThought: '실수하면 무능해 보일 것이다',
          provenanceIds: ['diary:a'],
        ),
      );

      // 이을 현재 생각이 없으면 "지난번에도"가 근거 없는 말이 된다.
      expect(plan.referencedPast, isFalse);
      expect(plan.sentence, isNot(contains('지난번')));
    });

    test('주제가 없으면 언급하지 않는다', () {
      final plan = planner.plan(
        userMessage: '또 사람들이 저를 무능하게 볼 것 같아요.',
        summary: const RetrievalSummary(
          currentThought: '사람들이 저를 무능하게 볼 것 같아요.',
          similarPastThought: '실수하면 무능해 보일 것이다',
          provenanceIds: ['diary:a'],
        ),
      );

      expect(plan.referencedPast, isFalse);
    });
  });

  group('개인화된 공감', () {
    test('주제·과거 생각·현재 생각이 모두 있으면 이어 말한다', () {
      final plan = planner.plan(
        userMessage: '또 사람들이 저를 무능하게 볼 것 같아요.',
        summary: const RetrievalSummary(
          currentTheme: '발표 전 긴장',
          currentThought: '사람들이 저를 무능하게 볼 것 같아요.',
          similarPastThought: '실수하면 준비를 안 한 사람처럼 보일 것이다',
          provenanceIds: ['diary:abc123'],
        ),
      );

      expect(plan.referencedPast, isTrue);
      expect(plan.sentence, contains('지난번에도'));
      expect(plan.sentence, contains('발표 전 긴장'));
      expect(plan.sentence, contains('사람들이 저를 무능하게 볼 것 같아요'));
      expect(plan.provenanceIds, ['diary:abc123']);
    });

    test('비슷한 단어 하나만으로 지난 상담을 먼저 꺼내지 않는다', () {
      final plan = planner.plan(
        userMessage: '친한 친구가 요즘 연락을 피하는 것 같아.',
        summary: const RetrievalSummary(
          previousSessionThought: '친구랑 싸웠어',
          provenanceIds: ['session:s1'],
        ),
      );

      expect(plan.referencedPast, isFalse);
      expect(plan.sentence, isNot(contains('지난 상담')));
      expect(plan.sentence, isNot(contains('친구랑 싸웠어')));
    });
  });

  group('나아지는 중', () {
    const helpful = EffectiveIntervention(
      id: 'relax:r1',
      type: 'relaxation',
      label: '복식호흡',
      preSud: 8,
      postSud: 5,
    );

    test('SUD 추이가 내려가고 도움된 활동이 있으면 그것을 먼저 말한다', () {
      final plan = planner.plan(
        userMessage: '조금 나아진 것 같아요.',
        summary: const RetrievalSummary(
          sudTrend: 'decreasing',
          previouslyHelpfulActivity: helpful,
          currentTheme: '발표 전 긴장',
          currentThought: '제가 잘 해낼 것 같아요.',
          similarPastThought: '망칠 것 같다',
          provenanceIds: ['diary:a', 'relax:r1'],
        ),
      );

      expect(plan.sentence, contains('복식호흡'));
      expect(plan.provenanceIds, ['relax:r1']);
      expect(plan.referencedPast, isTrue);
    });

    test('턴 사이 개선만으로도 인정한다', () {
      final plan = planner.plan(
        userMessage: '아까보다는 괜찮아요.',
        summary: const RetrievalSummary(previouslyHelpfulActivity: helpful),
        change: AffectChange.improved,
      );

      expect(plan.sentence, contains('복식호흡'));
    });

    test('도움된 활동이 없으면 개선을 지어내지 않는다', () {
      final plan = planner.plan(
        userMessage: '조금 나아졌어요.',
        summary: const RetrievalSummary(sudTrend: 'decreasing'),
      );

      expect(plan.referencedPast, isFalse);
      expect(plan.provenanceIds, isEmpty);
    });
  });

  group('지난 상담 연속성', () {
    test('지난번 대안적 생각을 먼저 상기시킨다', () {
      final plan = planner.plan(
        userMessage: '또 발표가 있는데 걱정돼요.',
        summary: const RetrievalSummary(
          previousSessionThought: '무능해 보일 것이다',
          previousSessionAlternativeThought: '준비한 내용은 설명할 수 있다',
          provenanceIds: ['session:s1', 'diary:a'],
        ),
      );

      expect(plan.referencedPast, isTrue);
      expect(plan.sentence, contains('지난 상담'));
      expect(plan.sentence, contains('준비한 내용은 설명할 수 있다'));
      // 세션 근거만 남긴다.
      expect(plan.provenanceIds, ['session:s1']);
    });

    test('대안적 생각이 없으면 핵심 생각을 상기시킨다', () {
      final plan = planner.plan(
        userMessage: '또 발표가 있는데 걱정돼요.',
        summary: const RetrievalSummary(
          previousSessionThought: '무능해 보일 것이다',
          provenanceIds: ['session:s1'],
        ),
      );

      expect(plan.sentence, contains('무능해 보일 것이다'));
      expect(plan.sentence, contains('지난 상담'));
    });

    test('공감 문장에 질문을 넣지 않는다', () {
      final plan = planner.plan(
        userMessage: '또 발표가 있는데 걱정돼요.',
        summary: const RetrievalSummary(
          previousSessionThought: '무능해 보일 것이다',
          previousSessionAlternativeThought: '설명할 수 있다',
          provenanceIds: ['session:s1'],
        ),
      );

      // planner 가 뒤에 질문 하나를 붙인다. 여기서 물으면 한 턴에 질문이 둘이 된다.
      expect(plan.sentence.contains('?'), isFalse);
    });

    test('관련 없는 지난 세션은 언급하지 않는다', () {
      // RetrievalSummary 가 관련 없다고 판단하면 두 필드가 비어 온다.
      final plan = planner.plan(
        userMessage: '친구랑 사이가 어색해요.',
        summary: const RetrievalSummary(provenanceIds: ['session:s1']),
      );

      expect(plan.referencedPast, isFalse);
      expect(plan.sentence, isNot(contains('지난 상담')));
    });

    test('도움된 활동이 있으면 그것이 먼저다', () {
      const helpful = EffectiveIntervention(
        id: 'relax:r1',
        type: 'relaxation',
        label: '복식호흡',
        preSud: 8,
        postSud: 4,
      );

      final plan = planner.plan(
        userMessage: '조금 나아졌어요.',
        summary: const RetrievalSummary(
          sudTrend: 'decreasing',
          previouslyHelpfulActivity: helpful,
          previousSessionThought: '무능해 보일 것이다',
          provenanceIds: ['session:s1', 'relax:r1'],
        ),
      );

      expect(plan.sentence, contains('복식호흡'));
    });
  });

  group('일반 공감', () {
    test('현재 발화 단서로 문장을 고른다', () {
      expect(planner.plan(userMessage: '너무 무서워요.').sentence, contains('두렵게'));
      expect(
        planner.plan(userMessage: '요즘 너무 힘들어요.').sentence,
        contains('지치셨겠어요'),
      );
      expect(
        planner.plan(userMessage: '혼자인 것 같아요.').sentence,
        contains('외로우셨겠어요'),
      );
    });

    test('높은 점수 응답을 알아본다', () {
      expect(planner.plan(userMessage: '8점 정도요.').sentence, contains('꽤 크게'));
    });

    test('단서가 없으면 기본 문장으로 물러선다', () {
      final plan = planner.plan(userMessage: '음 글쎄요.');

      expect(plan.sentence, '말씀하신 일이 마음에 계속 걸리고 계시는군요.');
      expect(plan.referencedPast, isFalse);
    });

    test('같은 입력은 같은 문장을 만든다', () {
      expect(
        planner.plan(userMessage: '불안해요.').sentence,
        planner.plan(userMessage: '불안해요.').sentence,
      );
    });
  });
}
