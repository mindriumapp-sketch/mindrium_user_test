import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';

UserContextItem _diary({required String id, required String text, int? sud}) =>
    UserContextItem(
      id: id,
      type: UserContextType.diary,
      text: text,
      occurredAt: DateTime(2026, 9, 1),
      sud: sud,
    );

UserContextItem _alt({required String id, required String text}) =>
    UserContextItem(
      id: id,
      type: UserContextType.alternativeThought,
      text: text,
      occurredAt: DateTime(2026, 9, 1),
    );

void main() {
  const builder = RetrievalSummaryBuilder();

  group('현재 생각', () {
    test('이번 발화의 평가 형태 생각을 쓴다', () {
      final summary = builder.build(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');

      expect(summary.currentThought, '사람들이 저를 무능하게 볼 것 같아요.');
    });

    test('이번 발화에 없으면 최근 발화에서 찾는다', () {
      final summary = builder.build(
        userMessage: '내일 발표가 있어요.',
        recentMessages: [
          CounselingMessage(
            id: 'u1',
            role: 'user',
            text: '제가 준비를 안 한 사람처럼 보일 것 같아요.',
            createdAt: DateTime(2026, 9, 3),
          ),
        ],
      );

      expect(summary.currentThought, '제가 준비를 안 한 사람처럼 보일 것 같아요.');
    });

    test('상황 서술만 있으면 생각을 만들어내지 않는다', () {
      final summary = builder.build(userMessage: '내일 발표가 있어요.');

      expect(summary.currentThought, isNull);
    });
  });

  group('과거 근거', () {
    MindriumCounselingContext context() => MindriumCounselingContext(
      currentWeek: 4,
      relevantItems: [
        _diary(
          id: 'diary:abc123',
          text: '[발표 전 긴장] 상황: 연구 발표 / 생각: 실수하면 준비를 안 한 사람처럼 보일 것이다 / 감정: 불안',
          sud: 8,
        ),
        _alt(
          id: 'alt:zzz999',
          text: '이전에 찾은 도움이 되는 생각: 완벽히 답하지 않아도 준비한 내용은 설명할 수 있다',
        ),
      ],
      recentSud: const SudContext(
        latest: 8,
        weeklyAverage: 7.1,
        trend: 'increasing',
      ),
      effectiveInterventions: const [
        EffectiveIntervention(
          id: 'relax:r1',
          type: 'relaxation',
          label: '복식호흡',
          preSud: 8,
          postSud: 5,
        ),
      ],
    );

    test('주제·유사 과거 생각·대안·SUD·도움된 활동을 모은다', () {
      final summary = builder.build(
        userMessage: '질문에 답하지 못하면 사람들이 저를 무능하게 볼 것 같아요.',
        context: context(),
      );

      expect(summary.currentTheme, '발표 전 긴장');
      expect(summary.similarPastThought, '실수하면 준비를 안 한 사람처럼 보일 것이다');
      expect(
        summary.previousAlternativeThought,
        '완벽히 답하지 않아도 준비한 내용은 설명할 수 있다',
      );
      expect(summary.recentSud, 8);
      expect(summary.sudTrend, 'increasing');
      expect(summary.previouslyHelpfulActivity?.label, '복식호흡');
      expect(summary.hasPastReference, isTrue);
    });

    test('사용한 기록만 provenance 에 남고 정렬된다', () {
      final summary = builder.build(
        userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
        context: context(),
      );

      expect(summary.provenanceIds, ['alt:zzz999', 'diary:abc123', 'relax:r1']);
    });

    test('지금 한 말을 과거 생각으로 되돌려주지 않는다', () {
      final summary = builder.build(
        userMessage: '실수하면 준비를 안 한 사람처럼 보일 것 같다고 생각해요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(
              id: 'diary:same',
              text: '상황: 발표 / 생각: 실수하면 준비를 안 한 사람처럼 보일 것 같다',
              sud: 6,
            ),
          ],
        ),
      );

      // 같은 생각을 "예전에도 그러셨죠"로 돌려주면 대화가 이상해진다.
      expect(summary.similarPastThought, isNull);
      expect(summary.provenanceIds, isEmpty);
    });
  });

  group('현재 주제는 관련 있는 일기에서만 가져온다', () {
    test('첫 후보 일기가 이번 발화와 무관하면 그 그룹을 쓰지 않는다', () {
      // 실기기 회귀: 세션 시작 시 고른 diary 후보 목록의 첫 항목이 "학업"
      // 그룹이었는데, 인간관계를 이야기하는 turn 에서도 concern 이 "학업"으로
      // 고정되어 나왔다. diaries 는 이번 발화와 무관한 순서로 올 수 있으므로
      // 첫 항목을 그냥 쓰면 안 된다.
      final summary = builder.build(
        userMessage: '친한 친구가 요즘 제 연락을 피하는 것 같아서 속상해요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(
              id: 'diary:unrelated',
              text: '[학업] 상황: 과제 마감 / 생각: 시간 안에 못 끝낼 것 같다',
              sud: 4,
            ),
            _diary(
              id: 'diary:related',
              text: '[친구 관계] 상황: 단체 채팅 / 생각: 나만 빼고 이야기하는 것 같다',
              sud: 5,
            ),
          ],
        ),
      );

      expect(summary.currentTheme, '친구 관계');
      expect(summary.currentTheme, isNot('학업'));
    });

    test('관련 있는 일기가 하나도 없으면 주제를 지어내지 않는다', () {
      final summary = builder.build(
        userMessage: '앞으로 취업이 안 될까 봐 계속 불안해요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(
              id: 'diary:unrelated',
              text: '[학업] 상황: 과제 마감 / 생각: 시간 안에 못 끝낼 것 같다',
              sud: 4,
            ),
          ],
        ),
      );

      expect(summary.currentTheme, isNull);
    });

    test('관련 있는 diary 가 여럿이면 더 관련 있는 순서를 따른다', () {
      final summary = builder.build(
        userMessage: '발표에서 질문 받을 때가 제일 걱정돼요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(
              id: 'diary:other',
              text: '[학업] 상황: 과제 마감 / 생각: 시간 안에 못 끝낼 것 같다',
              sud: 4,
            ),
            _diary(
              id: 'diary:match',
              text: '[발표 전 긴장] 상황: 발표 질문 / 생각: 답을 못할 것 같다',
              sud: 6,
            ),
          ],
        ),
      );

      expect(summary.currentTheme, '발표 전 긴장');
    });
  });

  group('미해결 과제', () {
    test('SUD 가 높고 대안이 없는 기록을 고른다', () {
      final summary = builder.build(
        userMessage: '요즘 계속 걱정돼요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(
              id: 'diary:open',
              text: '상황: 회의 / 생각: 내 의견이 무시당할 것이다',
              sud: 9,
            ),
          ],
        ),
      );

      expect(summary.unfinishedIssue, '내 의견이 무시당할 것이다');
      expect(summary.provenanceIds, contains('diary:open'));
    });

    test('대안적 생각이 있으면 미해결로 보지 않는다', () {
      final summary = builder.build(
        userMessage: '요즘 계속 걱정돼요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(
              id: 'diary:done',
              text: '상황: 회의 / 생각: 내 의견이 무시당할 것이다',
              sud: 9,
            ),
            _alt(id: 'alt:done', text: '이전에 찾은 도움이 되는 생각: 의견은 참고될 수 있다'),
          ],
        ),
      );

      expect(summary.unfinishedIssue, isNull);
    });

    test('SUD 가 낮으면 미해결로 보지 않는다', () {
      final summary = builder.build(
        userMessage: '요즘 계속 걱정돼요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            _diary(id: 'diary:low', text: '상황: 산책 / 생각: 별일 아니다', sud: 2),
          ],
        ),
      );

      expect(summary.unfinishedIssue, isNull);
    });
  });

  group('없는 것은 만들지 않는다', () {
    test('관련 일기가 없으면 전역 반복 주제를 현재 주제로 쓰지 않는다', () {
      const context = MindriumCounselingContext(
        currentWeek: 4,
        relevantItems: [],
        recurringThemes: ['발표'],
      );

      final summary = const RetrievalSummaryBuilder().build(
        userMessage: '친구가 연락에 답하지 않아서 속상해요.',
        context: context,
      );

      expect(summary.currentTheme, isNull);
      expect(summary.provenanceIds, isEmpty);
    });

    test('컨텍스트가 없으면 과거 참조가 없다', () {
      final summary = builder.build(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');

      expect(summary.hasPastReference, isFalse);
      expect(summary.provenanceIds, isEmpty);
      expect(summary.currentTheme, isNull);
      expect(summary.recentSud, isNull);
    });

    test('빈 컨텍스트면 isEmpty 다', () {
      final summary = builder.build(
        userMessage: '음.',
        context: const MindriumCounselingContext(currentWeek: 1),
      );

      expect(summary.isEmpty, isTrue);
      expect(summary.hasPastReference, isFalse);
    });

    test('같은 입력은 같은 요약을 만든다', () {
      final context = MindriumCounselingContext(
        currentWeek: 4,
        relevantItems: [
          _diary(id: 'diary:a', text: '상황: 발표 / 생각: 망칠 것 같다', sud: 8),
        ],
      );

      final first = builder.build(userMessage: '걱정돼요.', context: context);
      final second = builder.build(userMessage: '걱정돼요.', context: context);

      expect(first.provenanceIds, second.provenanceIds);
      expect(first.unfinishedIssue, second.unfinishedIssue);
    });
  });
}
