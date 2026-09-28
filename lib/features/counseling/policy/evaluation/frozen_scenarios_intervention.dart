import '../../../../data/counseling/counseling_models.dart';
import '../../counseling_state.dart';
import 'frozen_scenarios_common.dart';
import 'scenario_fixture.dart';

/// Phase 9.2B: intervention-state scenarios. Success scenarios use exactly
/// one matching knowledge item, so `eligibleInterventionIds.length == 1` ->
/// single-option (`multiOption: false`); unavailable scenarios have an
/// empty boundary (`allowedActions == []`) -> also single-option by
/// definition (no legal choice at all).
List<ScenarioFixture> buildInterventionScenarios() {
  final fixtures = <ScenarioFixture>[];

  // ── balancedThought success (week 4): 5 scenarios.
  const balancedThoughtMessages = [
    '생각을 바꾸는 게 잘 안 돼요.',
    '이 생각이 맞는 건지 계속 의심돼요.',
    '조금 더 균형 잡힌 시각을 갖고 싶어요.',
    '극단적으로 생각하는 것 같긴 해요.',
    '다르게 생각해보고 싶은데 잘 안 돼요.',
  ];
  for (var i = 0; i < balancedThoughtMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'intervention_balancedThought_success_${i + 1}',
        label: 'Intervention balancedThought: ${balancedThoughtMessages[i]}',
        category: 'intervention_balancedThought_success',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: balancedThoughtMessages[i],
          currentWeek: 4,
          userContext: diaryContext(
            text: '상황: 발표 준비 / 생각: 질문에 답을 못하면 무능해 보일 것이다',
            diaryId: 'diary:bt_$i',
          ),
          knowledge: [cbtItem(id: 'week4_alternative_thought_01')],
        ),
        multiOption: false,
      ),
    );
  }

  // ── gainLossReview / avoidance success (week 7): 4 scenarios.
  const avoidanceMessages = [
    '발표 자리를 피하고 싶어요.',
    '그 모임에 가기 싫어서 피하고 있어요.',
    '건강검진을 계속 미루고 피하고 있어요.',
    '어려운 대화를 자꾸 피하게 돼요.',
  ];
  for (var i = 0; i < avoidanceMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'intervention_gainLossOrAvoidance_success_${i + 1}',
        label: 'Intervention gainLossReview: ${avoidanceMessages[i]}',
        category: 'intervention_gainLossOrAvoidance_success',
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

  // ── maintenanceReview success (week 8): 4 scenarios, via an effective
  // intervention on record (rather than an explicit-thought message).
  const maintenanceLabels = ['호흡 이완 연습', '점진적 근육 이완', '짧은 산책', '일기 쓰기'];
  for (var i = 0; i < maintenanceLabels.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'intervention_maintenanceReview_success_${i + 1}',
        label: 'Intervention maintenanceReview: ${maintenanceLabels[i]}',
        category: 'intervention_maintenanceReview_success',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: '이 방법이 도움이 됐던 것 같아요.',
          currentWeek: 8,
          userContext: effectiveInterventionContext(
            label: maintenanceLabels[i],
            id: 'intervention:eff_$i',
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
        multiOption: false,
      ),
    );
  }

  // ── already used -> unavailable (week 4, policy already referenced): 3.
  const alreadyUsedMessages = ['생각을 또 바꿔볼까요.', '다시 해볼게요.', '한 번 더 해보고 싶어요.'];
  for (var i = 0; i < alreadyUsedMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'intervention_already_used_unavailable_${i + 1}',
        label: 'Intervention already used: ${alreadyUsedMessages[i]}',
        category: 'intervention_already_used_unavailable',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: alreadyUsedMessages[i],
          currentWeek: 4,
          knowledge: [cbtItem(id: 'week4_alternative_thought_01')],
          recentMessages: [
            CounselingMessage(
              id: 'a_used_$i',
              role: 'assistant',
              text: '이전에 나눈 균형 잡힌 생각 이야기입니다.',
              createdAt: DateTime(2026, 9, 1),
              referencedCbtIds: const ['week4_alternative_thought_01'],
            ),
          ],
        ),
        multiOption: false,
      ),
    );
  }

  // ── week has no approved policy -> unavailable: 3.
  const unapprovedWeeks = [1, 2, 99];
  for (var i = 0; i < unapprovedWeeks.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'intervention_week_not_approved_unavailable_${i + 1}',
        label: 'Intervention week ${unapprovedWeeks[i]} not approved',
        category: 'intervention_week_not_approved_unavailable',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: '아무거나요.',
          currentWeek: unapprovedWeeks[i],
        ),
        multiOption: false,
      ),
    );
  }

  // ── policy exists but no knowledge item matches -> unavailable: 2.
  for (var i = 0; i < 2; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'intervention_knowledge_not_matched_unavailable_${i + 1}',
        label: 'Intervention knowledge not matched ($i)',
        category: 'intervention_knowledge_not_matched_unavailable',
        request: boundaryRequest(
          state: CounselingState.intervention,
          userMessage: '생각을 바꿔볼까요.',
          currentWeek: 4,
          // No knowledge items at all, or items that don't match week 4's
          // required id/type/tags — either way, matchedKnowledge is empty.
          knowledge:
              i == 0
                  ? const []
                  : [
                    cbtItem(
                      id: 'unrelated_item',
                      week: 4,
                      type: 'education',
                      tags: const ['unrelated'],
                    ),
                  ],
        ),
        multiOption: false,
      ),
    );
  }

  return fixtures;
}
