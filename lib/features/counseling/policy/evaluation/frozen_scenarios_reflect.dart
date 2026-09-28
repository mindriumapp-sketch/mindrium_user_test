import '../../counseling_state.dart';
import 'frozen_scenarios_common.dart';
import 'scenario_fixture.dart';

/// Phase 9.2B: reflect-state scenarios. `CounselingState.reflect.allowedActs`
/// always has 3 entries (reflect/summarize/socraticQuestion), so every
/// reflect scenario is multi-option regardless of goal/diary content.
List<ScenarioFixture> buildReflectScenarios() {
  final fixtures = <ScenarioFixture>[];

  const evidenceMessages = [
    '발표 중에 실수하면 사람들이 저를 무능하다고 생각할 것 같아요.',
    '건강검진 결과가 나쁘면 큰일이 날 것 같아요.',
    '마감을 못 지키면 팀에서 신뢰를 잃을 것 같아요.',
    '면접에서 떨어지면 제 능력이 부족하다는 뜻일 것 같아요.',
    '가족과 갈등이 계속되면 관계가 끝날 것 같아요.',
  ];
  for (var i = 0; i < evidenceMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_goal_evidence_${i + 1}',
        label: 'Reflect evidence goal: ${evidenceMessages[i]}',
        category: 'reflect_goal_evidence',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: evidenceMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  const alternativeMessages = [
    '그래도 다르게 생각해볼 수 있을까요?',
    '조금 다른 관점도 있을 것 같긴 해요.',
    '이 생각이 맞는지 모르겠어요.',
    '다른 가능성도 생각은 나요.',
    '꼭 그렇게 될 거라는 확신은 없어요.',
  ];
  for (var i = 0; i < alternativeMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_goal_alternative_${i + 1}',
        label: 'Reflect alternative goal: ${alternativeMessages[i]}',
        category: 'reflect_goal_alternative',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: alternativeMessages[i],
          recentMessages: [assistantGoalMessage('evidence', id: 'a_alt_$i')],
        ),
        multiOption: true,
      ),
    );
  }

  const probabilityMessages = [
    '그럴 확률이 얼마나 될지는 잘 모르겠어요.',
    '실제로 그렇게 될 가능성이 있을까요.',
    '아마 그럴 일은 드물 것 같기도 해요.',
    '확실히는 모르겠지만 걱정은 돼요.',
  ];
  for (var i = 0; i < probabilityMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_goal_probability_${i + 1}',
        label: 'Reflect probability goal: ${probabilityMessages[i]}',
        category: 'reflect_goal_probability',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: probabilityMessages[i],
          recentMessages: [
            assistantGoalMessage('evidence', id: 'a_prob_ev_$i'),
            assistantGoalMessage('alternative', id: 'a_prob_alt_$i'),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  const exhaustedMessages = [
    '그래도 여전히 걱정돼요.',
    '그렇긴 한데 마음이 편해지진 않아요.',
    '알겠는데 계속 신경 쓰여요.',
    '여전히 확신이 안 들어요.',
  ];
  for (var i = 0; i < exhaustedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_goal_exhausted_repeat_${i + 1}',
        label: 'Reflect exhausted repeat-last: ${exhaustedMessages[i]}',
        category: 'reflect_goal_exhausted_repeat',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: exhaustedMessages[i],
          recentMessages: [
            assistantGoalMessage('evidence', id: 'a_ex_ev_$i'),
            assistantGoalMessage('alternative', id: 'a_ex_alt_$i'),
            assistantGoalMessage('probability', id: 'a_ex_prob_$i'),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // Low-info messages that should trigger the "clarify" branch (no usable
  // thought yet, no diary) — reflectSelector.wouldClarify widens
  // allowedActions to include explore, but the scenario is still
  // multi-option regardless (reflect state already has 3 allowed acts).
  const lowInfoMessages = ['네.', '모르겠어요.', '그냥 그래요.', '음...'];
  for (var i = 0; i < lowInfoMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_clarify_lowinfo_${i + 1}',
        label: 'Reflect clarify (low info): ${lowInfoMessages[i]}',
        category: 'reflect_clarify_lowinfo',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: lowInfoMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // Diary relevant: diary text shares topic keywords with the current
  // message.
  const diaryRelevantPairs = [
    ('발표에서 질문에 답을 못할까 봐 걱정돼요.', '상황: 발표 준비 / 생각: 질문에 답을 못하면 무능해 보일 것이다'),
    ('건강검진 결과가 걱정돼요.', '상황: 건강검진 대기 / 생각: 결과가 나쁘게 나올 것 같다'),
    ('마감을 못 지킬까 봐 걱정돼요.', '상황: 업무 마감 / 생각: 마감을 못 지키면 신뢰를 잃을 것이다'),
    ('면접이 걱정돼요.', '상황: 면접 준비 / 생각: 면접에서 떨어질 것 같다'),
    ('가족 문제로 마음이 무거워요.', '상황: 가족 갈등 / 생각: 관계가 끝날 것 같다'),
  ];
  for (var i = 0; i < diaryRelevantPairs.length; i++) {
    final (message, diaryText) = diaryRelevantPairs[i];
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_diary_relevant_${i + 1}',
        label: 'Reflect diary relevant: $message',
        category: 'reflect_diary_relevant',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: message,
          userContext: diaryContext(
            text: diaryText,
            diaryId: 'diary:relevant_$i',
          ),
        ),
        multiOption: true,
      ),
    );
  }

  // Diary irrelevant: diary text is about a completely different topic than
  // the current message — regression guard against wrong cross-referencing
  // in downstream materialization/realization (not enforceable at the
  // boundary level itself, since `firstDiary` is unconditional; this
  // category exists so ScenarioRunner/AggregateReport can flag agents that
  // incorrectly reference the diary's topic in their output).
  const diaryIrrelevantPairs = [
    ('업무 마감이 걱정돼요.', '상황: 친구와의 다툼 / 생각: 우리 관계가 예전 같지 않다'),
    ('면접이 다음 주라 불안해요.', '상황: 건강검진 / 생각: 결과가 나쁠 것 같다'),
    ('가족 문제로 힘들어요.', '상황: 발표 준비 / 생각: 질문에 답을 못할 것 같다'),
    ('친구와 관계가 어색해요.', '상황: 업무 마감 / 생각: 마감을 못 지킬 것 같다'),
  ];
  for (var i = 0; i < diaryIrrelevantPairs.length; i++) {
    final (message, diaryText) = diaryIrrelevantPairs[i];
    fixtures.add(
      ScenarioFixture(
        id: 'reflect_diary_irrelevant_${i + 1}',
        label: 'Reflect diary irrelevant: $message',
        category: 'reflect_diary_irrelevant',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: message,
          userContext: diaryContext(
            text: diaryText,
            diaryId: 'diary:irrelevant_$i',
          ),
        ),
        multiOption: true,
      ),
    );
  }

  return fixtures;
}
