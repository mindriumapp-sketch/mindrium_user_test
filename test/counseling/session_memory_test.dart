import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/counseling_session_summary.dart';

UserContextItem _diary() => UserContextItem(
  id: 'diary:abc123',
  type: UserContextType.diary,
  text: '[발표 전 긴장] 상황: 연구 발표 / 생각: 무능해 보일 것이다 / 감정: 불안 / 행동: 준비를 미룸',
  occurredAt: DateTime(2026, 9, 1),
  sud: 8,
);

void main() {
  group('턴 단위 누적', () {
    test('일기에서 A/B/C 를 채운다', () {
      final memory = CounselingSessionMemory(sessionId: 's1');

      memory.record(
        SessionTurnRecord.fromDiary(
          userMessage: '내일 발표가 걱정돼요.',
          diary: _diary(),
          theme: '발표 전 긴장',
          automaticThought: '무능해 보일 것이다',
          sud: 8,
          provenanceIds: const ['diary:abc123'],
        ),
      );

      final summary = memory.summary;
      expect(summary.concern, '발표 전 긴장');
      expect(summary.activatingEvent, '연구 발표');
      expect(summary.automaticThought, '무능해 보일 것이다');
      expect(summary.emotion, '불안');
      expect(summary.behavior, '준비를 미룸');
      expect(summary.endingSud, 8);
      expect(summary.provenanceIds, ['diary:abc123']);
      expect(summary.turnCount, 1);
    });

    test('먼저 확인된 값을 나중 턴이 덮어쓰지 않는다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(
          const SessionTurnRecord(
            userMessage: '첫 걱정',
            theme: '발표 전 긴장',
            automaticThought: '무능해 보일 것이다',
          ),
        )
        ..record(
          const SessionTurnRecord(
            userMessage: '다른 이야기',
            theme: '건강 걱정',
            automaticThought: '아플 것 같다',
          ),
        );

      expect(memory.summary.concern, '발표 전 긴장');
      expect(memory.summary.automaticThought, '무능해 보일 것이다');
    });

    test('SUD 는 마지막 값이 남는다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(const SessionTurnRecord(userMessage: 'a', sud: 8))
        ..record(const SessionTurnRecord(userMessage: 'b', sud: 5));

      expect(memory.summary.endingSud, 5);
    });
  });

  group('질문에 대한 답을 이어 붙인다', () {
    test('근거 질문 다음 발화를 explored_evidence 로 본다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(
          const SessionTurnRecord(userMessage: '무능해 보일 것 같아요.', askedEvidence: true),
        )
        ..record(const SessionTurnRecord(userMessage: '예전에 한 번 막힌 적이 있어요.'));

      expect(memory.summary.exploredEvidence, '예전에 한 번 막힌 적이 있어요.');
    });

    test('개입 다음 발화를 대안적 생각으로 본다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(
          const SessionTurnRecord(
            userMessage: '바꾸기 어려워요.',
            interventionCbtId: 'week4_alternative_thought_01',
            activity: 'openAlternativeThought',
          ),
        )
        ..record(
          const SessionTurnRecord(userMessage: '완벽하지 않아도 설명할 수 있어요.'),
        );

      final summary = memory.summary;
      expect(summary.interventionUsed, 'week4_alternative_thought_01');
      expect(summary.activityRecommended, 'openAlternativeThought');
      expect(summary.alternativeThought, '완벽하지 않아도 설명할 수 있어요.');
      expect(summary.userResponse, '완벽하지 않아도 설명할 수 있어요.');
    });

    test('질문하지 않은 턴의 발화는 답으로 보지 않는다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(const SessionTurnRecord(userMessage: '그냥 힘들어요.'))
        ..record(const SessionTurnRecord(userMessage: '네.'));

      expect(memory.summary.exploredEvidence, isNull);
      expect(memory.summary.alternativeThought, isNull);
    });
  });

  group('미해결 주제', () {
    test('개입까지 가지 못하면 다루던 생각을 남긴다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(
          const SessionTurnRecord(
            userMessage: '무능해 보일 것 같아요.',
            automaticThought: '무능해 보일 것이다',
          ),
        )
        ..close();

      expect(memory.summary.unfinishedTopic, '무능해 보일 것이다');
    });

    test('대안적 생각을 찾았으면 미해결로 남기지 않는다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(
          const SessionTurnRecord(
            userMessage: '바꾸기 어려워요.',
            automaticThought: '무능해 보일 것이다',
            interventionCbtId: 'week4_alternative_thought_01',
          ),
        )
        ..record(const SessionTurnRecord(userMessage: '설명은 할 수 있어요.'))
        ..close();

      expect(memory.summary.unfinishedTopic, isNull);
      expect(memory.summary.alternativeThought, '설명은 할 수 있어요.');
    });
  });

  group('지어내지 않는다', () {
    test('아무것도 없으면 전부 null 이다', () {
      final summary = CounselingSessionMemory(sessionId: 's1').summary;

      expect(summary.hasContent, isFalse);
      expect(summary.concern, isNull);
      expect(summary.automaticThought, isNull);
      expect(summary.endingSud, isNull);
      expect(summary.provenanceIds, isEmpty);
    });

    test('provenance 는 중복 없이 정렬된다', () {
      final memory = CounselingSessionMemory(sessionId: 's1')
        ..record(
          const SessionTurnRecord(
            userMessage: 'a',
            provenanceIds: ['diary:b', 'diary:a'],
          ),
        )
        ..record(
          const SessionTurnRecord(
            userMessage: 'b',
            provenanceIds: ['diary:a', 'relax:r1'],
          ),
        );

      expect(memory.summary.provenanceIds, ['diary:a', 'diary:b', 'relax:r1']);
    });

    test('JSON 계약을 유지한다', () {
      final json = CounselingSessionMemory(sessionId: 's1').summary.toJson();

      expect(json.keys, containsAll(<String>[
        'session_id',
        'concern',
        'activating_event',
        'automatic_thought',
        'emotion',
        'behavior',
        'explored_evidence',
        'alternative_thought',
        'intervention_used',
        'activity_recommended',
        'user_response',
        'ending_sud',
        'unfinished_topic',
        'provenance_ids',
      ]));
    });
  });
}
