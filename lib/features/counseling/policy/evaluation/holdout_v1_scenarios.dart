import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';

import 'frozen_scenarios_common.dart';
import 'scenario_fixture.dart';

/// Phase 9.2E: `phase9_2e_holdout_v1` — 60 scenarios never seen by
/// `decide_v1` or `decide_v2` during Phase 9.2B/9.2D. Deliberately built
/// around SIX DIFFERENT situational topics (job interview, health/medical
/// anxiety, exam anxiety, family conflict, social gathering anxiety,
/// workplace conflict) rather than paraphrasing `frozen_v1`'s presentation-
/// anxiety scenarios — the goal is structurally distinct situations
/// (different response patterns, different personalization mixes, different
/// goal-progression states), not a find-and-replace of the topic noun.
///
/// FROZEN once the first real API run against this set happens (see
/// `docs/counseling/phase9_2_activation_criteria.md`) — do not edit after
/// that point; a fix goes into `holdout_v2` instead.
const String holdoutV1Version = 'phase9_2e_holdout_v1';

List<ScenarioFixture> buildHoldoutV1Scenarios() {
  final fixtures = <ScenarioFixture>[];

  // ───────────────────────────────────────────────────────────────────
  // CheckIn (single-option control) — 3
  // ───────────────────────────────────────────────────────────────────
  const checkInMessages = [
    '면접이 다가오니까 계속 초조해요.',
    '건강검진 결과를 기다리는 게 너무 불안해요.',
    '가족들이랑 또 다퉜어요. 마음이 복잡해요.',
  ];
  for (var i = 0; i < checkInMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_checkIn_${i + 1}',
        label: 'CheckIn ${i + 1}',
        category: 'holdout_checkIn',
        request: boundaryRequest(
          state: CounselingState.checkIn,
          userMessage: checkInMessages[i],
        ),
        multiOption: false,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Explore general (multi-option: explore state allows [explore, reflect]) — 5
  // ───────────────────────────────────────────────────────────────────
  const exploreMessages = [
    '면접에서 예상 못한 질문이 나올까 봐 계속 신경 쓰여요.',
    '검진 결과가 안 좋게 나올 것 같아서 잠도 잘 못 자요.',
    '시험 전날인데 하나도 준비가 안 된 것 같은 느낌이에요.',
    '모임에 가면 사람들이 저를 이상하게 볼 것 같아요.',
    '팀장님이랑 또 부딪힐까 봐 회의 들어가는 게 무서워요.',
  ];
  for (var i = 0; i < exploreMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_explore_general_${i + 1}',
        label: 'Explore general ${i + 1}',
        category: 'holdout_explore_general',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: exploreMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Explore SUD-response edge case (multi-option) — 3
  // ───────────────────────────────────────────────────────────────────
  const sudFollowUps = ['7점이요.', '한 8점 정도요.', '6점이에요.'];
  const sudPriorConcerns = [
    '면접에서 말이 막힐까 봐 걱정돼요.',
    '검진 결과 듣는 순간이 제일 두려워요.',
    '시험 날 아침에 배가 아플까 봐 걱정돼요.',
  ];
  for (var i = 0; i < sudFollowUps.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_explore_sud_${i + 1}',
        label: 'Explore SUD response ${i + 1}',
        category: 'holdout_explore_sud_response',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: sudFollowUps[i],
          recentMessages: [
            userMessage(sudPriorConcerns[i], id: 'u_prior_$i'),
            assistantMessage(
              '지금 느끼는 불안을 0에서 10 사이로 표현하면 어느 정도인가요?',
              id: 'a_sud_ask_$i',
            ),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: first goal (evidence) — multi-option — 4
  // ───────────────────────────────────────────────────────────────────
  const reflectFirstMessages = [
    '면접관이 제 대답을 듣고 실망할 것 같다는 생각이 계속 들어요.',
    '검진 결과가 나쁘게 나오면 인생이 끝날 것 같다는 생각이 들어요.',
    '이번 시험을 망치면 앞으로도 계속 실패할 것 같다는 생각이 들어요.',
    '모임에서 아무도 저한테 말을 안 걸 것 같다는 생각이 들어요.',
  ];
  for (var i = 0; i < reflectFirstMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_evidence_${i + 1}',
        label: 'Reflect evidence ${i + 1}',
        category: 'holdout_reflect_goal_evidence',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: reflectFirstMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: second goal (alternative, evidence already asked) — 4
  // ───────────────────────────────────────────────────────────────────
  const reflectSecondMessages = [
    '팀장님이 제 의견을 무시할 거라는 생각이 자꾸 들어요.',
    '가족들이 저를 실망스러운 자식으로 볼 것 같아요.',
    '면접에서 질문에 답을 못하면 그걸로 다 끝났다고 생각해요.',
    '검진 결과를 받으면 의사가 심각한 표정을 지을 것 같아요.',
  ];
  for (var i = 0; i < reflectSecondMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_alternative_${i + 1}',
        label: 'Reflect alternative ${i + 1}',
        category: 'holdout_reflect_goal_alternative',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: reflectSecondMessages[i],
          recentMessages: [assistantGoalMessage('evidence', id: 'a_ev_$i')],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: third goal (probability, two already asked) — 3
  // ───────────────────────────────────────────────────────────────────
  const reflectThirdMessages = [
    '시험 결과가 나쁘면 다시는 도전할 수 없을 것 같아요.',
    '모임에서 실수하면 다들 저를 멀리할 것 같아요.',
    '팀장님한테 한 번 혼나면 계속 무능하다고 생각할 것 같아요.',
  ];
  for (var i = 0; i < reflectThirdMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_probability_${i + 1}',
        label: 'Reflect probability ${i + 1}',
        category: 'holdout_reflect_goal_probability',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: reflectThirdMessages[i],
          recentMessages: [
            assistantGoalMessage('evidence', id: 'a_ev2_$i'),
            assistantGoalMessage('alternative', id: 'a_alt2_$i'),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: all goals exhausted, repeat-last (repetition/exhaustion) — 5
  // ───────────────────────────────────────────────────────────────────
  const exhaustedMessages = [
    '그래도 여전히 면접이 걱정돼요.',
    '그래도 검진 결과 생각을 멈출 수가 없어요.',
    '그래도 시험 걱정이 계속 나요.',
    '그래도 모임 생각만 하면 마음이 무거워요.',
    '그래도 팀장님 얼굴이 계속 떠올라요.',
    '그래도 가족 문제가 계속 마음에 걸려요.',
  ];
  for (var i = 0; i < exhaustedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_exhausted_${i + 1}',
        label: 'Reflect exhausted/repeat ${i + 1}',
        category: 'holdout_reflect_goal_exhausted_repeat',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: exhaustedMessages[i],
          recentMessages: [
            assistantGoalMessage('evidence', id: 'a_ex1_$i'),
            assistantGoalMessage('alternative', id: 'a_ex2_$i'),
            assistantGoalMessage('probability', id: 'a_ex3_$i'),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: clarify / low-information reply (multi-option, boundary widens
  // to include explore) — 4
  // ───────────────────────────────────────────────────────────────────
  const clarifyMessages = ['모르겠어요.', '그냥 그래요.', '딱히 없어요.', '음...'];
  for (var i = 0; i < clarifyMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_clarify_${i + 1}',
        label: 'Reflect clarify/low-info ${i + 1}',
        category: 'holdout_reflect_clarify_lowinfo',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: clarifyMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: relevant diary target (multi-option + personalization) — 4
  // ───────────────────────────────────────────────────────────────────
  const diaryRelevantCurrent = [
    '또 그 생각이 나요.',
    '똑같은 걱정이 다시 들어요.',
    '그때랑 비슷한 느낌이에요.',
    '또 그 순간이 자꾸 떠올라요.',
  ];
  const diaryRelevantTexts = [
    '상황: 면접 / 생각: 대답을 못하면 무능해 보일 것이다',
    '상황: 건강검진 / 생각: 결과가 나쁘면 인생이 끝날 것이다',
    '상황: 시험 / 생각: 떨어지면 다시는 기회가 없을 것이다',
    '상황: 회사 회의 / 생각: 의견을 내면 팀장님이 무시할 것이다',
  ];
  for (var i = 0; i < diaryRelevantCurrent.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_diary_relevant_${i + 1}',
        label: 'Reflect diary relevant ${i + 1}',
        category: 'holdout_reflect_diary_relevant',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: diaryRelevantCurrent[i],
          userContext: diaryContext(
            text: diaryRelevantTexts[i],
            diaryId: 'diary:holdout_rel_$i',
          ),
        ),
        personalContext: PersonalContextSummary(
          previousSimilarIssue: diaryRelevantTexts[i],
          evidenceIds: ['diary:holdout_rel_$i'],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: UNRELATED diary target must not be used (regression guard,
  // multi-option + personalization) — 3
  // ───────────────────────────────────────────────────────────────────
  const diaryIrrelevantCurrent = [
    '오늘 회의에서 발표 순서가 바뀌어서 당황했어요.',
    '동생이랑 사소한 일로 다퉜어요.',
    '오늘 점심 약속이 취소돼서 좀 허탈했어요.',
  ];
  const diaryIrrelevantTexts = [
    '상황: 오래된 취업 스트레스 / 생각: 나는 뭘 해도 안 될 것이다',
    '상황: 과거 연애 문제 / 생각: 나는 사랑받을 자격이 없다',
    '상황: 어릴 때 시험 실패 / 생각: 나는 원래 능력이 부족하다',
  ];
  for (var i = 0; i < diaryIrrelevantCurrent.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_reflect_diary_irrelevant_${i + 1}',
        label: 'Reflect diary irrelevant ${i + 1}',
        category: 'holdout_reflect_diary_irrelevant',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: diaryIrrelevantCurrent[i],
          userContext: diaryContext(
            text: diaryIrrelevantTexts[i],
            diaryId: 'diary:holdout_irrel_$i',
          ),
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Intervention: balancedThought success (single-option, intervention-sensitive) — 4
  // ───────────────────────────────────────────────────────────────────
  const balancedMessages = [
    '면접 생각을 균형 있게 바꿔보려 해도 잘 안 돼요.',
    '검진 결과에 대한 생각을 다르게 보려 해도 어려워요.',
    '시험에 대한 생각을 좀 더 균형 있게 보고 싶은데 잘 안 돼요.',
    '모임에 대한 생각을 조금 더 현실적으로 보고 싶어요.',
  ];
  for (var i = 0; i < balancedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_intervention_balanced_${i + 1}',
        label: 'Intervention balancedThought ${i + 1}',
        category: 'holdout_intervention_balancedThought_success',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: balancedMessages[i],
          knowledge: [cbtItem(id: 'week4_alternative_thought_01')],
        ),
        multiOption: false,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Intervention: gainLoss/avoidance success (single-option, intervention-sensitive) — 3
  // ───────────────────────────────────────────────────────────────────
  const avoidanceMessages = [
    '면접 준비를 계속 미루고 피하고 있어요.',
    '검진 예약 잡는 걸 계속 미루고 있어요.',
    '시험 공부를 피하고 다른 일만 하고 있어요.',
  ];
  for (var i = 0; i < avoidanceMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_intervention_gainloss_${i + 1}',
        label: 'Intervention gainLoss/avoidance ${i + 1}',
        category: 'holdout_intervention_gainLossOrAvoidance_success',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: avoidanceMessages[i],
          currentWeek: 7,
          knowledge: [
            cbtItem(
              id: 'week7_gain_lose_01',
              week: 7,
              tags: const ['habit', 'behavior', 'avoidance', 'planning'],
            ),
          ],
        ),
        multiOption: false,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Intervention: maintenanceReview success (single-option, intervention +
  // personalization) — 3
  // ───────────────────────────────────────────────────────────────────
  const maintenanceMessages = [
    '면접 전에 했던 호흡 연습이 도움이 됐어요.',
    '검진 전에 했던 이완 연습이 좀 편안하게 해줬어요.',
    '시험 전에 했던 방법이 실제로 효과가 있었어요.',
  ];
  for (var i = 0; i < maintenanceMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_intervention_maintenance_${i + 1}',
        label: 'Intervention maintenanceReview ${i + 1}',
        category: 'holdout_intervention_maintenanceReview_success',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: maintenanceMessages[i],
          currentWeek: 8,
          userContext: effectiveInterventionContext(
            label: '점진적 이완 연습',
            id: 'intervention:holdout_eff_$i',
          ),
          knowledge: [
            cbtItem(
              id: 'week8_maintenance_01',
              week: 8,
              tags: const [
                'maintenance',
                'relapse_prevention',
                'habit',
                'values',
              ],
            ),
          ],
        ),
        personalContext: PersonalContextSummary(
          previousHelpfulActivity: const EffectiveIntervention(
            id: 'intervention:holdout_eff_ctx',
            type: 'relaxation',
            label: '점진적 이완 연습',
            preSud: 8,
            postSud: 3,
          ),
          evidenceIds: const ['intervention:holdout_eff_ctx'],
        ),
        multiOption: false,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Intervention unavailable (single-option controls, allowedActions=[]) — 6
  // ───────────────────────────────────────────────────────────────────
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_intervention_already_used_1',
      label: 'Intervention already-used unavailable 1',
      category: 'holdout_intervention_already_used_unavailable',
      request: boundaryRequest(
        state: CounselingState.intervention,
        userMessage: '생각을 또 바꿔볼까요.',
        recentMessages: [
          assistantMessage('이전에 나눈 균형 잡힌 생각 이야기입니다.', id: 'a_prevbal1'),
        ],
      ),
      multiOption: false,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_intervention_already_used_2',
      label: 'Intervention already-used unavailable 2',
      category: 'holdout_intervention_already_used_unavailable',
      request: boundaryRequest(
        state: CounselingState.intervention,
        userMessage: '또 그 이야기를 해볼까요.',
        recentMessages: [
          assistantMessage('이전에 나눈 균형 잡힌 생각 이야기입니다.', id: 'a_prevbal2'),
        ],
      ),
      multiOption: false,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_intervention_week_not_approved_1',
      label: 'Intervention week-not-approved unavailable 1',
      category: 'holdout_intervention_week_not_approved_unavailable',
      request: boundaryRequest(
        state: CounselingState.intervention,
        userMessage: '뭐라도 해보고 싶어요.',
        currentWeek: 99,
      ),
      multiOption: false,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_intervention_week_not_approved_2',
      label: 'Intervention week-not-approved unavailable 2',
      category: 'holdout_intervention_week_not_approved_unavailable',
      request: boundaryRequest(
        state: CounselingState.intervention,
        userMessage: '방법이 있을까요.',
        currentWeek: 1,
      ),
      multiOption: false,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_intervention_knowledge_not_matched_1',
      label: 'Intervention knowledge-not-matched unavailable 1',
      category: 'holdout_intervention_knowledge_not_matched_unavailable',
      request: boundaryRequest(
        state: CounselingState.intervention,
        userMessage: '생각을 바꾸는 걸 도와주세요.',
        currentWeek: 4,
        knowledge: const [],
      ),
      multiOption: false,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_intervention_knowledge_not_matched_2',
      label: 'Intervention knowledge-not-matched unavailable 2',
      category: 'holdout_intervention_knowledge_not_matched_unavailable',
      request: boundaryRequest(
        state: CounselingState.intervention,
        userMessage: '균형 잡힌 생각을 만들어볼 수 있을까요.',
        currentWeek: 4,
        knowledge: [
          cbtItem(id: 'unrelated_item_01', week: 2, type: 'education'),
        ],
      ),
      multiOption: false,
    ),
  );

  // ───────────────────────────────────────────────────────────────────
  // Personalization-sensitive (multi-option via reflect state) — 8
  // ───────────────────────────────────────────────────────────────────
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_similarIssue_1',
      label: 'Personalization previousSimilarIssue 1',
      category: 'holdout_personalization_previousSimilarIssue',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '이번 면접도 지난번 면접 때랑 비슷한 느낌이에요.',
      ),
      personalContext: const PersonalContextSummary(
        previousSimilarIssue: '지난 면접에서도 대답을 못하면 끝이라고 생각했다',
        evidenceIds: ['diary:holdout_sim1'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_similarIssue_2',
      label: 'Personalization previousSimilarIssue 2',
      category: 'holdout_personalization_previousSimilarIssue',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '이번 검진도 예전 검진 때랑 똑같이 걱정돼요.',
      ),
      personalContext: const PersonalContextSummary(
        previousSimilarIssue: '예전 검진 때도 결과가 나쁠 거라 생각했다',
        evidenceIds: ['diary:holdout_sim2'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_altThought_1',
      label: 'Personalization previousAlternativeThought 1',
      category: 'holdout_personalization_previousAlternativeThought',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '면접 걱정이 다시 심해졌어요.',
      ),
      personalContext: const PersonalContextSummary(
        previousAlternativeThought: '완벽하지 않아도 준비한 만큼은 보여줄 수 있다',
        evidenceIds: ['session:holdout_alt1'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_altThought_2',
      label: 'Personalization previousAlternativeThought 2',
      category: 'holdout_personalization_previousAlternativeThought',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '시험 걱정이 또 심해졌어요.',
      ),
      personalContext: const PersonalContextSummary(
        previousAlternativeThought: '한 번의 시험이 전체 미래를 결정하지는 않는다',
        evidenceIds: ['session:holdout_alt2'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_helpful_1',
      label: 'Personalization helpfulActivity 1',
      category: 'holdout_personalization_helpfulActivity',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '면접 전에 또 긴장되기 시작해요.',
      ),
      personalContext: const PersonalContextSummary(
        previousHelpfulActivity: EffectiveIntervention(
          id: 'intervention:holdout_helpful1',
          type: 'relaxation',
          label: '호흡 연습',
          preSud: 8,
          postSud: 3,
        ),
        evidenceIds: ['intervention:holdout_helpful1'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_helpful_2',
      label: 'Personalization helpfulActivity 2',
      category: 'holdout_personalization_helpfulActivity',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '회의 들어가기 전에 또 긴장돼요.',
      ),
      personalContext: const PersonalContextSummary(
        previousHelpfulActivity: EffectiveIntervention(
          id: 'intervention:holdout_helpful2',
          type: 'relaxation',
          label: '점진적 이완',
          preSud: 7,
          postSud: 2,
        ),
        evidenceIds: ['intervention:holdout_helpful2'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_unfinished_1',
      label: 'Personalization unfinishedIssue 1',
      category: 'holdout_personalization_unfinishedIssue',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '지난번에 다루던 그 걱정이 아직 안 풀렸어요.',
      ),
      personalContext: const PersonalContextSummary(
        unfinishedIssue: '면접에서 압박 질문을 받으면 얼어붙을 것 같다는 생각',
        evidenceIds: ['diary:holdout_unf1'],
      ),
      multiOption: true,
    ),
  );
  fixtures.add(
    ScenarioFixture(
      id: 'holdout_personalization_unfinished_2',
      label: 'Personalization unfinishedIssue 2',
      category: 'holdout_personalization_unfinishedIssue',
      request: boundaryRequest(
        state: CounselingState.reflect,
        userMessage: '가족 문제가 여전히 마음에 남아 있어요.',
      ),
      personalContext: const PersonalContextSummary(
        unfinishedIssue: '가족이 나를 실망스럽게 볼 것이라는 생각',
        evidenceIds: ['diary:holdout_unf2'],
      ),
      multiOption: true,
    ),
  );

  // ───────────────────────────────────────────────────────────────────
  // Closing (single-option) — 5
  // ───────────────────────────────────────────────────────────────────
  const closingWithTarget = [
    '오늘은 면접 걱정에 대해 이야기했어요.',
    '오늘은 검진 결과에 대한 걱정을 나눴어요.',
    '오늘은 시험 스트레스에 대해 이야기했어요.',
  ];
  for (var i = 0; i < closingWithTarget.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_closing_present_${i + 1}',
        label: 'Closing summary target present ${i + 1}',
        category: 'holdout_closing_summary_target_present',
        request: boundaryRequest(
          state: CounselingState.closing,
          userMessage: closingWithTarget[i],
        ),
        multiOption: false,
      ),
    );
  }
  const closingWithoutTarget = ['네.', '알겠어요.'];
  for (var i = 0; i < closingWithoutTarget.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_closing_absent_${i + 1}',
        label: 'Closing summary target absent ${i + 1}',
        category: 'holdout_closing_summary_target_absent',
        request: boundaryRequest(
          state: CounselingState.closing,
          userMessage: closingWithoutTarget[i],
        ),
        multiOption: false,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Mixed-intent counseling portion (multi-option) — 4
  // ───────────────────────────────────────────────────────────────────
  const mixedMessages = [
    '요즘 다시 면접 걱정이 심해졌는데 예전에 적어둔 기록은 어디서 볼 수 있어요?',
    '검진 걱정이 심한데 이완 활동은 어디서 할 수 있어요?',
    '시험 걱정이 다시 커졌는데 지난 걱정 기록은 어디서 봐요?',
    '회의 걱정이 심한데 알림 설정은 어떻게 바꿔요?',
  ];
  for (var i = 0; i < mixedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout_mixed_portion_${i + 1}',
        label: 'Mixed counseling portion ${i + 1}',
        category: 'holdout_mixed_counseling_portion',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: mixedMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  return fixtures;
}
