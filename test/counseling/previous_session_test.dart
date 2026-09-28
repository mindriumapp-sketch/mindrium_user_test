import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/previous_session.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';

PreviousSession _session({
  String id = 's1',
  String status = 'completed',
  String? concern = '발표 전 긴장',
  String? thought = '질문에 답하지 못하면 무능해 보일 것이다',
  String? alternative = '완벽하지 않아도 준비한 내용은 설명할 수 있다',
  String? unfinished,
  List<String> provenance = const [],
  DateTime? endedAt,
}) => PreviousSession(
  sessionId: id,
  week: 4,
  completionStatus: status,
  mainConcern: concern,
  coreThought: thought,
  alternativeThought: alternative,
  unfinishedIssue: unfinished,
  provenanceIds: provenance,
  endedAt: endedAt ?? DateTime(2026, 9, 1),
);

void main() {
  const selector = PreviousSessionSelector();
  const builder = RetrievalSummaryBuilder();

  group('세션 선택 정책', () {
    test('완료 세션을 우선한다', () {
      final picked = selector.selectPrimary([
        _session(id: 'a', status: 'interrupted', endedAt: DateTime(2026, 9, 3)),
        _session(id: 'b', endedAt: DateTime(2026, 9, 1)),
      ]);

      // 중단 세션이 더 최근이어도 완료 세션을 쓴다.
      expect(picked!.sessionId, 'b');
    });

    test('완료 세션이 여럿이면 가장 최근을 쓴다', () {
      final picked = selector.selectPrimary([
        _session(id: 'old', endedAt: DateTime(2026, 8, 20)),
        _session(id: 'new', endedAt: DateTime(2026, 9, 2)),
      ]);

      expect(picked!.sessionId, 'new');
    });

    test('완료 세션이 없으면 null 이다', () {
      final picked = selector.selectPrimary([
        _session(status: 'interrupted'),
      ]);

      // 중단 세션을 주 참고 대상으로 쓰지 않는다.
      expect(picked, isNull);
    });
  });

  group('미해결 주제', () {
    test('완료 세션의 미해결 주제가 우선이다', () {
      final primary = _session(unfinished: '실제 상황에서 적용해보기');
      final issue = selector.selectUnfinishedIssue([
        primary,
        _session(id: 'x', status: 'interrupted', unfinished: '다른 미해결'),
      ], primary: primary);

      expect(issue, '실제 상황에서 적용해보기');
    });

    test('완료 세션에 없으면 더 최근 중단 세션에서 가져온다', () {
      final primary = _session(endedAt: DateTime(2026, 9, 1));
      final issue = selector.selectUnfinishedIssue([
        primary,
        _session(
          id: 'x',
          status: 'interrupted',
          unfinished: '회의에서 의견 말하기',
          endedAt: DateTime(2026, 9, 3),
        ),
      ], primary: primary);

      expect(issue, '회의에서 의견 말하기');
    });

    test('완료 세션보다 오래된 중단 기록은 쓰지 않는다', () {
      final primary = _session(endedAt: DateTime(2026, 9, 3));
      final issue = selector.selectUnfinishedIssue([
        primary,
        _session(
          id: 'x',
          status: 'interrupted',
          unfinished: '지난 이야기',
          endedAt: DateTime(2026, 8, 20),
        ),
      ], primary: primary);

      expect(issue, isNull);
    });
  });

  group('관련성 판단', () {
    test('주제가 겹치면 지난 상담을 꺼낸다', () {
      final summary = builder.build(
        userMessage: '또 발표가 있는데 걱정돼요.',
        previousSession: _session(),
      );

      expect(summary.hasPreviousSessionReference, isTrue);
      expect(summary.previousSessionThought, contains('무능해 보일'));
      expect(summary.provenanceIds, contains('session:s1'));
    });

    test('주제가 다르면 지난 상담을 꺼내지 않는다', () {
      final summary = builder.build(
        userMessage: '요즘 친구랑 사이가 어색해요.',
        previousSession: _session(),
      );

      // 지난 세션이 발표였는데 이번엔 인간관계다.
      // "지난번 발표 이야기를 했었죠"를 꺼내면 안 된다.
      expect(summary.hasPreviousSessionReference, isFalse);
      expect(summary.previousSessionThought, isNull);
      expect(summary.provenanceIds, isNot(contains('session:s1')));
    });

    test('"걱정"/"불안" 같은 감정어만 겹쳐도 지난 상담을 꺼내지 않는다', () {
      final summary = builder.build(
        userMessage: '요즘 몸에 이상한 증상이 있어서 큰 병일까봐 계속 걱정되고 불안해요.',
        previousSession: _session(),
      );

      // 지난 세션은 발표 걱정이었고 이번엔 건강 걱정이다. "걱정"이라는
      // 감정어 하나만 겹친다고 같은 주제로 보면 안 된다.
      expect(summary.hasPreviousSessionReference, isFalse);
      expect(summary.previousSessionThought, isNull);
    });

    test('같은 일기를 근거로 썼으면 관련 있다고 본다', () {
      final summary = builder.build(
        userMessage: '그냥 마음이 무거워요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            UserContextItem(
              id: 'diary:abc123',
              type: UserContextType.diary,
              text: '상황: 회의 / 생각: 내 의견이 무시당할 것이다',
              occurredAt: DateTime(2026, 9, 1),
            ),
          ],
        ),
        previousSession: _session(
          concern: '전혀 다른 주제',
          thought: '전혀 다른 생각',
          provenance: const ['diary:abc123'],
        ),
      );

      expect(summary.hasPreviousSessionReference, isTrue);
    });

    test('지난 세션이 없으면 아무 영향이 없다', () {
      final summary = builder.build(userMessage: '발표가 걱정돼요.');

      expect(summary.hasPreviousSessionReference, isFalse);
      expect(summary.provenanceIds, isEmpty);
    });
  });

  group('이어받은 미해결 주제', () {
    test('이번 기록에 미해결이 없으면 지난 것을 쓴다', () {
      final summary = builder.build(
        userMessage: '발표가 걱정돼요.',
        carriedUnfinishedIssue: '실제 상황에서 적용해보기',
      );

      expect(summary.unfinishedIssue, '실제 상황에서 적용해보기');
    });

    test('이번 기록의 미해결이 우선이다', () {
      final summary = builder.build(
        userMessage: '요즘 계속 걱정돼요.',
        context: MindriumCounselingContext(
          currentWeek: 4,
          relevantItems: [
            UserContextItem(
              id: 'diary:open',
              type: UserContextType.diary,
              text: '상황: 회의 / 생각: 내 의견이 무시당할 것이다',
              occurredAt: DateTime(2026, 9, 1),
              sud: 9,
            ),
          ],
        ),
        carriedUnfinishedIssue: '지난 세션 미해결',
      );

      expect(summary.unfinishedIssue, '내 의견이 무시당할 것이다');
    });
  });
}
