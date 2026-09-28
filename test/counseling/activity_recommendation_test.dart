import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/activity_recommendation.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';

CbtKnowledgeItem _item({
  String id = 'week4_alternative_thought_01',
  List<String> paragraphs = const [
    '정답을 찾기보다, 지금 생각보다 조금 더 균형 잡힌 문장을 한 문장 적어보는 것이 목표입니다. 두 번째 문장은 쓰지 않는다.',
  ],
}) => CbtKnowledgeItem(
  id: id,
  week: 4,
  type: 'technique',
  title: id,
  paragraphs: paragraphs,
  tags: const ['alternative_thought'],
  source: 'test',
);

void main() {
  const policy = ActivityRecommendationPolicy();

  group('개입 → 앱 활동 매핑', () {
    test('대안적 생각 개입은 해당 화면으로 잇는다', () {
      final rec = policy.recommend(
        type: InterventionType.balancedThought,
        source: _item(),
      );

      expect(rec.activity, CounselingActivity.alternativeThought);
    });

    test('행동/결과 검토는 걱정 일기로 잇는다', () {
      for (final type in [
        InterventionType.behaviorPatternReview,
        InterventionType.consequenceReview,
      ]) {
        expect(
          policy.recommend(type: type, source: _item()).activity,
          CounselingActivity.abcDiary,
          reason: type.name,
        );
      }
    });

    test('대응 화면이 없는 개입은 활동을 만들지 않는다', () {
      // 없는 화면을 억지로 붙이면 승인되지 않은 개입을 실행시키는 것과 같다.
      for (final type in [
        InterventionType.gainLossReview,
        InterventionType.valueBasedChoice,
        InterventionType.maintenanceReview,
      ]) {
        expect(
          policy.recommend(type: type, source: _item()).activity,
          isNull,
          reason: type.name,
        );
      }
    });

    test('모든 개입 종류를 빠짐없이 다룬다', () {
      for (final type in InterventionType.values) {
        // 예외를 던지지 않아야 한다.
        expect(() => policy.recommend(type: type), returnsNormally);
      }
    });
  });

  group('교육 문구', () {
    test('승인된 CBT 원문의 첫 문장만 쓴다', () {
      final rec = policy.recommend(
        type: InterventionType.balancedThought,
        source: _item(),
      );

      expect(
        rec.microcontent,
        '정답을 찾기보다, 지금 생각보다 조금 더 균형 잡힌 문장을 한 문장 적어보는 것이 목표입니다.',
      );
      expect(rec.microcontent, isNot(contains('두 번째 문장')));
      expect(rec.microcontentCbtId, 'week4_alternative_thought_01');
    });

    test('긴 문장은 잘라낸다', () {
      final rec = policy.recommend(
        type: InterventionType.balancedThought,
        source: _item(paragraphs: ['가' * 200]),
      );

      expect(
        rec.microcontent!.length,
        lessThanOrEqualTo(
          ActivityRecommendationPolicy.microcontentMaxLength + 1,
        ),
      );
      expect(rec.microcontent, endsWith('…'));
    });

    test('출처가 없으면 문구를 만들지 않는다', () {
      final rec = policy.recommend(type: InterventionType.balancedThought);

      expect(rec.microcontent, isNull);
      expect(rec.microcontentCbtId, isNull);
      // 활동은 여전히 있을 수 있다.
      expect(rec.activity, CounselingActivity.alternativeThought);
    });

    test('빈 문단이면 문구를 만들지 않는다', () {
      final rec = policy.recommend(
        type: InterventionType.balancedThought,
        source: _item(paragraphs: const ['   ']),
      );

      expect(rec.microcontent, isNull);
    });
  });

  group('세 갈래 분리', () {
    test('상담 문장과 교육 문구와 활동이 각각 따로 남는다', () {
      final rec = policy.recommend(
        type: InterventionType.balancedThought,
        source: _item(),
      );

      // 교육 문구가 질문을 포함하면 한 턴에 질문이 둘이 된다.
      expect(rec.microcontent, isNot(contains('?')));
      expect(rec.activity, isNotNull);
      expect(rec.isEmpty, isFalse);
    });

    test('둘 다 없으면 none 이다', () {
      final rec = policy.recommend(type: InterventionType.maintenanceReview);

      expect(rec.isEmpty, isTrue);
    });
  });
}
