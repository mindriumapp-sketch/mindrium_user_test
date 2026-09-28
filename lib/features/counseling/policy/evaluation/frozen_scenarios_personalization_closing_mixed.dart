import '../../../../data/counseling/counseling_models.dart';
import '../../../assistant/retrieval/personal_context_summary.dart';
import '../../counseling_state.dart';
import 'frozen_scenarios_common.dart';
import 'scenario_fixture.dart';

/// Phase 9.2B: personalization-sensitive, closing, and mixed-counseling-
/// portion scenarios.
///
/// Personalization scenarios reuse the explore state (always multi-option)
/// purely as a vehicle to carry a [PersonalContextSummary] signal — the
/// personalization fields themselves are NOT part of [PolicyBoundary] (see
/// `PolicyBoundaryRequest` — it has no personalization field at all), so
/// they cannot change `multiOption`. They exist so `AggregateReport` can
/// break out a "personalization-sensitive subset" and compare how agents
/// behave when a [PersonalContextSummary] signal is present vs. absent.
List<ScenarioFixture> buildPersonalizationClosingMixedScenarios() {
  final fixtures = <ScenarioFixture>[];

  const previousSimilarIssueMessages = ['또 비슷한 걱정이 생겼어요.', '이번에도 발표가 걱정돼요.', '전에도 이런 기분이었어요.'];
  for (var i = 0; i < previousSimilarIssueMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'personalization_previousSimilarIssue_${i + 1}',
        label: 'Personalization previousSimilarIssue: ${previousSimilarIssueMessages[i]}',
        category: 'personalization_previousSimilarIssue',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: previousSimilarIssueMessages[i],
        ),
        personalContext: PersonalContextSummary(
          previousSimilarIssue: '예전에도 발표 상황에서 비슷한 걱정을 했던 기록',
          evidenceIds: const ['diary:prev_sim'],
        ),
        multiOption: true,
      ),
    );
  }

  const previousAltThoughtMessages = ['다시 그런 생각이 들어요.', '예전에 찾은 생각이 도움이 될까요.', '그때처럼 다르게 볼 수 있을까요.'];
  for (var i = 0; i < previousAltThoughtMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'personalization_previousAlternativeThought_${i + 1}',
        label: 'Personalization previousAlternativeThought: ${previousAltThoughtMessages[i]}',
        category: 'personalization_previousAlternativeThought',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: previousAltThoughtMessages[i],
        ),
        personalContext: PersonalContextSummary(
          previousAlternativeThought: '완벽하지 않아도 괜찮다는 생각',
          evidenceIds: const ['alt:prev_alt'],
        ),
        multiOption: true,
      ),
    );
  }

  const helpfulActivityMessages = ['뭘 해야 좀 나아질지 모르겠어요.', '전에 했던 게 도움이 됐던 것 같아요.', '마음을 가라앉히고 싶어요.'];
  for (var i = 0; i < helpfulActivityMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'personalization_helpfulActivity_${i + 1}',
        label: 'Personalization helpfulActivity: ${helpfulActivityMessages[i]}',
        category: 'personalization_helpfulActivity',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: helpfulActivityMessages[i],
        ),
        personalContext: PersonalContextSummary(
          previousHelpfulActivity: const EffectiveIntervention(
            id: 'intervention:helpful1',
            type: 'relaxation',
            label: '호흡 이완 연습',
            preSud: 8,
            postSud: 3,
          ),
          evidenceIds: const ['intervention:helpful1'],
        ),
        multiOption: true,
      ),
    );
  }

  const unfinishedIssueMessages = ['그 일은 아직도 마음에 걸려요.', '해결이 안 된 것 같아요.', '계속 신경 쓰여요.'];
  for (var i = 0; i < unfinishedIssueMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'personalization_unfinishedIssue_${i + 1}',
        label: 'Personalization unfinishedIssue: ${unfinishedIssueMessages[i]}',
        category: 'personalization_unfinishedIssue',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: unfinishedIssueMessages[i],
        ),
        personalContext: PersonalContextSummary(
          unfinishedIssue: '건강검진 결과에 대한 걱정이 해결되지 않음',
          evidenceIds: const ['diary:unfinished1'],
        ),
        multiOption: true,
      ),
    );
  }

  // ── closing: summary target present (4) — substantial prior message.
  const closingPresentMessages = [
    '발표 준비에 대해 이야기했어요.',
    '오늘은 건강 걱정에 대해 많이 나눴어요.',
    '업무 마감 스트레스를 이야기했습니다.',
    '가족 문제로 힘들었던 걸 이야기했어요.',
  ];
  for (var i = 0; i < closingPresentMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'closing_summary_target_present_${i + 1}',
        label: 'Closing summary present: ${closingPresentMessages[i]}',
        category: 'closing_summary_target_present',
        request: boundaryRequest(
          state: CounselingState.closing,
          userMessage: closingPresentMessages[i],
        ),
        multiOption: false,
      ),
    );
  }

  // ── closing: summary target absent (3) — closing-only acknowledgements.
  const closingAbsentMessages = ['네.', '고마워요.', '알겠어요.'];
  for (var i = 0; i < closingAbsentMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'closing_summary_target_absent_${i + 1}',
        label: 'Closing summary absent: ${closingAbsentMessages[i]}',
        category: 'closing_summary_target_absent',
        request: boundaryRequest(
          state: CounselingState.closing,
          userMessage: closingAbsentMessages[i],
        ),
        multiOption: false,
      ),
    );
  }

  // ── mixed counseling portion (4): pure PolicyBoundaryRequest level only,
  // no intent routing — just the counseling-relevant half of what would be
  // a mixed (counseling + app-guidance) user turn in production.
  const mixedMessages = [
    '발표 걱정도 있고 앱 사용법도 궁금해요.',
    '요즘 불안한데 알림 설정은 어떻게 하나요.',
    '마음이 힘든데 기록은 어디서 보나요.',
    '가족 문제로 힘든데 앱을 어떻게 써야 할지도 모르겠어요.',
  ];
  for (var i = 0; i < mixedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'mixed_counseling_portion_${i + 1}',
        label: 'Mixed counseling portion: ${mixedMessages[i]}',
        category: 'mixed_counseling_portion',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: mixedMessages[i],
        ),
        multiOption: true,
      ),
    );
  }

  return fixtures;
}
