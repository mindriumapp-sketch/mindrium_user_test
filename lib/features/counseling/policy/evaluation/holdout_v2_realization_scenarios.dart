import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';

import 'frozen_scenarios_common.dart';
import 'scenario_fixture.dart';

/// Phase 10.5B: `phase10_5b_holdout_v2` — a fresh, unseen (for realization
/// purposes) scenario set, restricted to `explore`/`reflect` states only —
/// the only states `HybridTurnRouter` ever allows a real ResponseRealizer to
/// run for (see `docs/counseling/phase10_5_llm_realization_evaluation.md`).
/// `checkIn`/`intervention`/`closing` are out of this phase's scope by the
/// router's own design, so they are not included here.
///
/// Deliberately built around EIGHT topics never used in `frozen_v1` or
/// `holdout_v1` (면접/건강검진/시험/가족갈등/모임/직장갈등 already spent):
/// 이사(moving), 결혼식 준비, 운전면허 시험, 반려동물 건강, 친구와의 갈등,
/// 새 직장 적응, 부모님 건강검진, 학회 발표.
///
/// Phase 10.5A.2 lesson, applied here from the start (not retrofitted):
/// every `recentMessages` entry uses REAL production question text (the
/// same strings `ReflectQuestionGoal.question` actually renders), never
/// `assistantGoalMessage`'s placeholder `"goal:$name"` — see
/// `docs/counseling/phase10_5a2_context_audit.md`'s Track A finding for why
/// that corrupted a realization evaluation using `holdout_v1`.
///
/// FROZEN once the first real API run against this set happens — do not
/// edit after that point; a fix goes into `holdout_v3` instead.
const String holdoutV2Version = 'phase10_5b_holdout_v2';

/// Real production question text per reflect goal — see
/// `lib/features/counseling/turn_plan.dart`'s `ReflectQuestionGoal.question`
/// getter. Kept here (not imported) because that getter is private to a
/// `turn_plan.dart`-internal enum; these are the same literal strings.
const _evidenceQuestion = '그 생각을 사실이라고 느끼게 하는 근거나 경험이 무엇인지 하나 떠올려볼까요?';
const _alternativeQuestion = '그 상황을 다른 관점에서 본다면 어떻게 볼 수 있을까요?';
const _probabilityQuestion = '실제로 그렇게 될 가능성은 어느 정도라고 느끼시나요?';

/// Like `assistantGoalMessage`, but with real, natural prior-turn text
/// instead of a `"goal:$name"` placeholder — both the structural
/// `dialogueGoalId` (what `GoalExhaustionPolicy`/selectors actually read)
/// and realistic `text` (what a realizer actually sees) are correct here.
CounselingMessage _priorGoalTurn(String goalName, String realText, {String? id}) =>
    CounselingMessage(
      id: id ?? 'a_$goalName',
      role: 'assistant',
      text: realText,
      createdAt: DateTime(2026, 9, 20),
      dialogueGoalId: goalName,
    );

List<ScenarioFixture> buildHoldoutV2Scenarios() {
  final fixtures = <ScenarioFixture>[];

  // ───────────────────────────────────────────────────────────────────
  // Explore general (multi-option) — 6
  // ───────────────────────────────────────────────────────────────────
  const exploreMessages = [
    '다음 주에 이사하는데 짐을 다 못 쌀까 봐 계속 초조해요.',
    '결혼식 준비하다가 하객들 앞에서 실수할까 봐 걱정돼요.',
    '운전면허 시험 도로주행에서 떨어질까 봐 계속 신경 쓰여요.',
    '강아지가 요즘 밥을 잘 안 먹어서 계속 마음이 쓰여요.',
    '친구랑 다툰 뒤로 연락이 끊겨서 계속 신경 쓰여요.',
    '새 직장에서 첫 회의 때 아무 말도 못 할까 봐 걱정돼요.',
  ];
  for (var i = 0; i < exploreMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_explore_general_${i + 1}',
        label: 'Explore general ${i + 1}',
        category: 'holdout2_explore_general',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: exploreMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Explore SUD-response (multi-option) — 10, varied phrasing on purpose
  // (bare number / "한 N점" / "약 N점 정도" / no "점" at all) so
  // `_extractSudValue`'s robustness generalizes, not just the 3 dev
  // phrasings already tuned against.
  // ───────────────────────────────────────────────────────────────────
  const sudPriorConcerns = [
    '이삿짐을 오늘 안에 다 못 쌀 것 같아요.',
    '하객들 앞에서 무슨 말을 해야 할지 모르겠어요.',
    '도로주행 코스를 다 기억 못 할 것 같아요.',
    '강아지가 계속 힘이 없어 보여요.',
    '친구가 저를 다시는 안 볼 것 같아요.',
    '회의에서 질문을 받으면 얼어붙을 것 같아요.',
    '부모님 검진 결과가 안 좋게 나올까 봐 걱정돼요.',
    '학회 발표 중에 질문에 답을 못할 것 같아요.',
    '이사 갈 동네가 낯설어서 적응 못 할 것 같아요.',
    '운전면허 시험을 또 떨어질 것 같아요.',
  ];
  const sudFollowUps = [
    '7점이요.',
    '한 8점 정도요.',
    '6점이에요.',
    '9점쯤요.',
    '5점 정도.',
    '약 8점이요.',
    '한 6점요.',
    '9점이에요.',
    '7점쯤 되는 것 같아요.',
    '8점이요.',
  ];
  for (var i = 0; i < sudFollowUps.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_explore_sud_${i + 1}',
        label: 'Explore SUD response ${i + 1}',
        category: 'holdout2_explore_sud_response',
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
  // Reflect: first goal (evidence) — 4
  // ───────────────────────────────────────────────────────────────────
  const evidenceMessages = [
    '부모님 검진 결과가 나쁘면 다 내 탓일 것 같다는 생각이 들어요.',
    '학회 발표에서 질문에 답을 못하면 무능해 보일 거라는 생각이 들어요.',
    '이사 가면 예전 친구들과 완전히 멀어질 것 같다는 생각이 들어요.',
    '친구가 이제 나를 신경 쓰지 않을 것 같다는 생각이 자꾸 들어요.',
  ];
  for (var i = 0; i < evidenceMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_evidence_${i + 1}',
        label: 'Reflect evidence ${i + 1}',
        category: 'holdout2_reflect_goal_evidence',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: evidenceMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: second goal (alternative, evidence already asked) — 4
  // ───────────────────────────────────────────────────────────────────
  const alternativeMessages = [
    '하객들이 제 결혼식 진행을 보고 실망할 것 같아요.',
    '도로주행 시험관이 제 운전을 보고 한심하게 생각할 것 같아요.',
    '수의사가 강아지 상태를 보고 제 탓이라고 할 것 같아요.',
    '새 팀 사람들이 저를 무능하다고 생각할 것 같아요.',
  ];
  for (var i = 0; i < alternativeMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_alternative_${i + 1}',
        label: 'Reflect alternative ${i + 1}',
        category: 'holdout2_reflect_goal_alternative',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: alternativeMessages[i],
          recentMessages: [
            _priorGoalTurn('evidence', _evidenceQuestion, id: 'a_ev_$i'),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: third goal (probability, two already asked) — 4
  // ───────────────────────────────────────────────────────────────────
  const probabilityMessages = [
    '이사 가면 다시는 예전 동네 사람들을 못 만날 것 같아요.',
    '친구랑 이대로 영영 멀어질 것 같아요.',
    '학회 발표를 완전히 망칠 것 같아요.',
    '운전면허 시험에서 또 떨어질 것 같아요.',
  ];
  for (var i = 0; i < probabilityMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_probability_${i + 1}',
        label: 'Reflect probability ${i + 1}',
        category: 'holdout2_reflect_goal_probability',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: probabilityMessages[i],
          recentMessages: [
            _priorGoalTurn('evidence', _evidenceQuestion, id: 'a_ev2_$i'),
            _priorGoalTurn(
              'alternative',
              _alternativeQuestion,
              id: 'a_alt2_$i',
            ),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: all goals exhausted, repeat-last — 6
  //
  // KNOWN LIMITATION STRATUM (see docs/counseling/phase10_5a2_context_audit.md
  // Track A): this category's poor Phase 10.5A absolute quality was
  // root-caused to GoalExhaustionPolicy.repeatLast itself reading as
  // repetitive to reviewers, NOT a realization/wording defect — confirmed
  // by a clean-context ablation that changed nothing. Included here (not
  // deleted) so end-to-end quality is still honestly measured, but must be
  // EXCLUDED from the Remote-vs-Legacy efficacy pass/fail gate and reported
  // separately as a known selection-policy backlog item.
  // ───────────────────────────────────────────────────────────────────
  const exhaustedMessages = [
    '그래도 이사 걱정이 계속 나요.',
    '그래도 결혼식 생각만 하면 마음이 무거워요.',
    '그래도 운전면허 시험이 계속 걱정돼요.',
    '그래도 강아지 걱정이 머릿속을 떠나지 않아요.',
    '그래도 친구랑 있었던 일이 계속 마음에 걸려요.',
    '그래도 새 직장 걱정이 가시질 않아요.',
  ];
  for (var i = 0; i < exhaustedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_exhausted_${i + 1}',
        label: 'Reflect exhausted/repeat ${i + 1}',
        category: 'holdout2_reflect_goal_exhausted_repeat_KNOWN_LIMITATION',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: exhaustedMessages[i],
          recentMessages: [
            _priorGoalTurn('evidence', _evidenceQuestion, id: 'a_ex1_$i'),
            _priorGoalTurn(
              'alternative',
              _alternativeQuestion,
              id: 'a_ex2_$i',
            ),
            _priorGoalTurn(
              'probability',
              _probabilityQuestion,
              id: 'a_ex3_$i',
            ),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: clarify / low-information reply — 4
  // ───────────────────────────────────────────────────────────────────
  const clarifyMessages = ['잘 모르겠어요.', '그냥 그런 것 같아요.', '별로 없어요.', '글쎄요...'];
  for (var i = 0; i < clarifyMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_clarify_${i + 1}',
        label: 'Reflect clarify/low-info ${i + 1}',
        category: 'holdout2_reflect_clarify_lowinfo',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: clarifyMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: RELEVANT diary target (multi-option + personalization) — 3
  // ───────────────────────────────────────────────────────────────────
  const diaryRelevantCurrent = [
    '또 그 생각이 나요.',
    '똑같은 걱정이 다시 들어요.',
    '그때랑 비슷한 느낌이에요.',
  ];
  const diaryRelevantTexts = [
    '상황: 예전 이사 / 생각: 새 동네에서 적응 못 할 것이다',
    '상황: 예전 발표 / 생각: 사람들 앞에서 창피를 당할 것이다',
    '상황: 예전 친구 관계 / 생각: 결국 나만 남겨질 것이다',
  ];
  for (var i = 0; i < diaryRelevantCurrent.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_diary_relevant_${i + 1}',
        label: 'Reflect diary relevant ${i + 1}',
        category: 'holdout2_reflect_diary_relevant',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: diaryRelevantCurrent[i],
          userContext: diaryContext(
            text: diaryRelevantTexts[i],
            diaryId: 'diary:holdout2_rel_$i',
          ),
        ),
        personalContext: PersonalContextSummary(
          previousSimilarIssue: diaryRelevantTexts[i],
          evidenceIds: ['diary:holdout2_rel_$i'],
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Reflect: UNRELATED diary target must not be used (regression guard) — 3
  // ───────────────────────────────────────────────────────────────────
  const diaryIrrelevantCurrent = [
    '오늘 상사가 갑자기 일정을 바꿔서 당황했어요.',
    '언니랑 사소한 일로 다퉜어요.',
    '오늘 카페 예약이 취소돼서 좀 허탈했어요.',
  ];
  const diaryIrrelevantTexts = [
    '상황: 오래된 학업 스트레스 / 생각: 나는 뭘 해도 부족하다',
    '상황: 과거 가족 갈등 / 생각: 나는 항상 오해받는다',
    '상황: 어릴 때 발표 실패 / 생각: 나는 사람들 앞에서 늘 실수한다',
  ];
  for (var i = 0; i < diaryIrrelevantCurrent.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_reflect_diary_irrelevant_${i + 1}',
        label: 'Reflect diary irrelevant ${i + 1}',
        category: 'holdout2_reflect_diary_irrelevant',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: diaryIrrelevantCurrent[i],
          userContext: diaryContext(
            text: diaryIrrelevantTexts[i],
            diaryId: 'diary:holdout2_irrel_$i',
          ),
        ),
        multiOption: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Personalization-sensitive — 8 (2 per subtype)
  // ───────────────────────────────────────────────────────────────────
  const similarIssueMessages = ['이번 이사도 지난번 이사 때랑 비슷한 느낌이에요.', '이번 발표도 예전 발표 때랑 똑같이 걱정돼요.'];
  for (var i = 0; i < similarIssueMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_personalization_similarIssue_${i + 1}',
        label: 'Personalization previous similar issue ${i + 1}',
        category: 'holdout2_personalization_previousSimilarIssue',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: similarIssueMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  const altThoughtMessages = ['이사 걱정이 다시 심해졌어요.', '발표 걱정이 또 심해졌어요.'];
  for (var i = 0; i < altThoughtMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_personalization_altThought_${i + 1}',
        label: 'Personalization previous alternative thought ${i + 1}',
        category: 'holdout2_personalization_previousAlternativeThought',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: altThoughtMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  const helpfulMessages = ['이사 전에 또 긴장되기 시작해요.', '발표 전에 또 긴장돼요.'];
  for (var i = 0; i < helpfulMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_personalization_helpful_${i + 1}',
        label: 'Personalization helpful activity ${i + 1}',
        category: 'holdout2_personalization_helpfulActivity',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: helpfulMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  const unfinishedMessages = ['지난번에 다루던 그 걱정이 아직 안 풀렸어요.', '친구 문제가 여전히 마음에 남아 있어요.'];
  for (var i = 0; i < unfinishedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'holdout2_personalization_unfinished_${i + 1}',
        label: 'Personalization unfinished issue ${i + 1}',
        category: 'holdout2_personalization_unfinishedIssue',
        request: boundaryRequest(
          state: CounselingState.reflect,
          userMessage: unfinishedMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  return fixtures;
}
