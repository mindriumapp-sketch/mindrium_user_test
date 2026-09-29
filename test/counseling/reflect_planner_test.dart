import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

CounselingMessage _user(String text) => CounselingMessage(
  id: 'u${text.hashCode}',
  role: 'user',
  text: text,
  createdAt: DateTime(2026, 9, 3),
);

CounselingMessage _assistant(String text, {String? goalId}) =>
    CounselingMessage(
      id: 'a${text.hashCode}',
      role: 'assistant',
      text: text,
      createdAt: DateTime(2026, 9, 3),
      dialogueGoalId: goalId,
    );

MindriumCounselingContext _diaryContext() => MindriumCounselingContext(
  currentWeek: 4,
  relevantItems: [
    UserContextItem(
      id: 'diary:abc123',
      type: UserContextType.diary,
      text: '상황: 연구 발표 / 생각: 질문에 답을 못하면 무능해 보일 것이다',
      occurredAt: DateTime(2026, 9, 1),
      sud: 7,
    ),
  ],
);

void main() {
  const planner = DeterministicReflectTurnPlanner();

  CounselingTurnPlan? planWith({
    required String userMessage,
    List<CounselingMessage> recent = const [],
    MindriumCounselingContext? userContext,
  }) => planner.plan(
    TurnPlanningContext(
      state: CounselingState.reflect,
      userMessage: userMessage,
      knowledge: const [],
      userContext: userContext,
      recentMessages: recent,
    ),
  );

  group('P5-D 반영 대상 우선순위', () {
    test('현재 발화의 명시적 생각이 최우선이다', () {
      final plan = planWith(
        userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
        recent: [_user('제가 준비를 못했다고 생각할 것 같아요.')],
        userContext: _diaryContext(),
      );

      expect(plan!.reflectionTarget, '사람들이 저를 무능하게 볼 것 같아요.');
      // 현재 발화에서 얻었으므로 일기를 근거로 기록하지 않는다.
      expect(plan.userContextIds, isEmpty);
    });

    test('현재 발화에 생각이 없으면 최근 사용자 발화를 쓴다', () {
      final plan = planWith(
        userMessage: '내일 발표가 있어요.',
        recent: [_user('사람들이 저를 무능하게 볼 것 같아요.')],
        userContext: _diaryContext(),
      );

      // 방금 한 말보다 과거 일기를 먼저 되비추면 대화가 어긋난다.
      expect(plan!.reflectionTarget, '사람들이 저를 무능하게 볼 것 같아요.');
      expect(plan.userContextIds, isEmpty);
    });

    test('대화에도 없으면 일기 생각을 쓰고 근거로 기록한다', () {
      final plan = planWith(
        userMessage: '내일 발표가 있어요.',
        recent: [_user('좀 긴장돼요.')],
        userContext: _diaryContext(),
      );

      expect(plan!.reflectionTarget, '질문에 답을 못하면 무능해 보일 것이다');
      expect(plan.userContextIds, ['diary:abc123']);
    });

    test('일기에서는 생각만 추출하고 감정과 행동 필드를 포함하지 않는다', () {
      final context = MindriumCounselingContext(
        currentWeek: 4,
        relevantItems: [
          UserContextItem(
            id: 'diary:screen-case',
            type: UserContextType.diary,
            text:
                '상황: 발표 / 생각: 질문에 답하지 못하면 사람들이 나를 무능하다고 볼 것 같다 '
                '/ 감정: 두려움, 불안 / 행동: 호흡 1분 하기',
            occurredAt: DateTime(2026, 9, 4),
          ),
        ],
      );
      final plan =
          planWith(userMessage: '질문을 받을 때가 가장 걱정돼요.', userContext: context)!;

      expect(plan.reflectionTarget, '질문에 답하지 못하면 사람들이 나를 무능하다고 볼 것 같다');
      expect(plan.deterministicReply, isNot(contains('감정:')));
      expect(plan.deterministicReply, isNot(contains('행동:')));
      expect(plan.deterministicReply, isNot(contains('호흡 1분')));
      expect(plan.userContextIds, ['diary:screen-case']);
    });

    test('아무 근거도 없으면 현재 발화로 물러선다', () {
      final plan = planWith(userMessage: '그냥 좀 답답해요.');

      expect(plan!.reflectionTarget, '그냥 좀 답답해요.');
      expect(plan.userContextIds, isEmpty);
    });
  });

  group('P5-D 질문 목표 정책', () {
    test('처음에는 근거 탐색 질문을 쓴다', () {
      final plan = planWith(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');

      expect(plan!.questionSentence, ReflectQuestionGoal.evidence.question);
      expect(plan.questionGoal, ReflectQuestionGoal.evidence.goal);
    });

    test('같은 질문을 이미 했으면 다음 목표로 넘어간다', () {
      final plan = planWith(
        userMessage: '예전에 한 번 막힌 적이 있어요.',
        recent: [
          _assistant(
            '그 생각이 걱정되는군요. ${ReflectQuestionGoal.evidence.question}',
            goalId: ReflectQuestionGoal.evidence.name,
          ),
        ],
      );

      expect(plan!.questionSentence, ReflectQuestionGoal.alternative.question);
      expect(plan.reflectionTarget, '예전에 한 번 막힌 적이 있어요.');
      // Phase 13.9D (b): an experience is reflected without quoting; only a
      // worry thought is quoted.
      expect(plan.reflectionSentence, '그 이야기를 들으니 지금 느끼시는 마음이 더 잘 이해가 돼요.');
      expect(plan.userContextIds, isEmpty);
    });

    test('두 목표를 소진하면 세 번째로 넘어간다', () {
      final plan = planWith(
        userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
        recent: [
          _assistant(
            ReflectQuestionGoal.evidence.question,
            goalId: ReflectQuestionGoal.evidence.name,
          ),
          _user('예전에 막힌 적이 있어요.'),
          _assistant(
            ReflectQuestionGoal.alternative.question,
            goalId: ReflectQuestionGoal.alternative.name,
          ),
          _user('잘 모르겠어요.'),
        ],
      );

      expect(plan!.questionSentence, ReflectQuestionGoal.probability.question);
    });

    test(
      'Phase 11.3: 모두 소진하면 마지막 목표를 반복하지 않고, 대신 명시적 '
      'recovery(질문 없음)로 전환한다 — 예전 repeatLast(마지막 목표 유지) 동작을 대체',
      () {
        final plan = planWith(
          userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
          recent: [
            for (final goal in DeterministicReflectTurnPlanner.goalOrder)
              _assistant(goal.question, goalId: goal.name),
          ],
        );

        expect(plan!.questionSentence, isEmpty);
        expect(plan.progressGoalId, isNull);
        expect(plan.goalExhaustionRecovery, GoalExhaustionRecovery.summarize);
        expect(plan.constraints, contains(TurnConstraint.requireNoQuestion));
        // Never `.summarize` — that would trigger reflect->intervention
        // acceleration via CounselingStatePolicy._acceleratesFrom, which a
        // recovery turn must not cause.
        expect(plan.requiredAct, DialogueAct.reflect);
      },
    );

    test('사용자가 같은 문장을 말해도 질문 소진으로 세지 않는다', () {
      final plan = planWith(
        userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
        recent: [_user(ReflectQuestionGoal.evidence.question)],
      );

      expect(plan!.questionSentence, ReflectQuestionGoal.evidence.question);
    });

    test('GPT가 표현을 바꿔 말해도 goal ID로 이미 물은 목표를 안다', () {
      // 실제로 발견된 버그: 이전엔 assistant 메시지 텍스트에 고정 질문
      // 문구가 그대로 들어있는지로 "이미 물었다"를 판단했다. GPT(Adaptive
      // Dialogue Policy 등)가 다른 말로 바꿔 표현하면 텍스트 일치가 깨져
      // 같은 목표를 다시 고르는 문제가 있었다. dialogueGoalId는 문장과
      // 무관하게 남는다.
      final plan = planWith(
        userMessage: '예전에 한 번 막힌 적이 있어요.',
        recent: [
          _assistant(
            '그 생각이 계속 마음에 걸리시는군요. 그렇게 느끼시게 된 계기가 있었을까요?',
            goalId: ReflectQuestionGoal.evidence.name,
          ),
        ],
      );

      expect(plan!.questionSentence, ReflectQuestionGoal.alternative.question);
    });
  });

  group('P5-D 불변식', () {
    test('질문은 정확히 하나다', () {
      for (final goal in DeterministicReflectTurnPlanner.goalOrder) {
        expect('?'.allMatches(goal.question).length, 1, reason: goal.name);
      }

      final plan = planWith(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');
      expect('?'.allMatches(plan!.deterministicReply).length, 1);
    });

    test('행동 조언과 단계 진행을 금지한다', () {
      final plan = planWith(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');

      expect(plan!.constraints, contains(TurnConstraint.forbidAdvice));
      expect(plan.constraints, contains(TurnConstraint.forbidStageAdvance));
      expect(
        plan.constraints,
        contains(TurnConstraint.requireExactlyOneQuestion),
      );
      expect(plan.forbidden, contains('행동 해결책을 제안하지 않는다.'));
      expect(plan.forbidden, contains('다음 CBT 단계로 넘어가지 않는다.'));
    });

    test('CBT 개입을 미리 끌어오지 않는다', () {
      final plan = planWith(
        userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
        userContext: _diaryContext(),
      );

      expect(plan!.interventionPlan, isNull);
      expect(plan.cbtContextIds, isEmpty);
      expect(plan.requiredAct, DialogueAct.socraticQuestion);
    });

    test('reflect 상태가 아니면 계획하지 않는다', () {
      for (final state in CounselingState.values) {
        if (state == CounselingState.reflect) continue;
        final plan = planner.plan(
          TurnPlanningContext(
            state: state,
            userMessage: '사람들이 저를 무능하게 볼 것 같아요.',
            knowledge: const [],
          ),
        );
        expect(plan, isNull, reason: state.wireName);
      }
    });

    test('같은 입력은 같은 계획을 만든다', () {
      final first = planWith(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');
      final second = planWith(userMessage: '사람들이 저를 무능하게 볼 것 같아요.');

      expect(first!.deterministicReply, second!.deterministicReply);
    });
  });
}
