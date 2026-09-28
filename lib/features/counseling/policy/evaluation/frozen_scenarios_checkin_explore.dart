import '../../counseling_state.dart';
import 'frozen_scenarios_common.dart';
import 'scenario_fixture.dart';

/// Phase 9.2B: checkIn (single-option turns) and explore (always
/// multi-option — `CounselingState.explore.allowedActs` has 2 entries)
/// scenarios.
List<ScenarioFixture> buildCheckInAndExploreScenarios() {
  final fixtures = <ScenarioFixture>[];

  // ── checkIn: 4 scenarios, always single-option (allowedActions == [explore]).
  const checkInMessages = [
    '오늘은 좀 힘들었어요.',
    '괜찮은 하루였어요.',
    '요즘 계속 불안해요.',
    '별일 없었어요.',
  ];
  for (var i = 0; i < checkInMessages.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'checkIn_${i + 1}',
        label: 'CheckIn: ${checkInMessages[i]}',
        category: 'checkIn',
        request: boundaryRequest(
          state: CounselingState.checkIn,
          userMessage: checkInMessages[i],
        ),
        multiOption: false,
      ),
    );
  }

  // ── explore general: 6 scenarios, varied topics. Always multi-option
  // (allowedActs = [explore, reflect]).
  const exploreTopics = [
    '발표 중에 실수할까 봐 걱정돼요.',
    '건강 검진 결과가 나쁠까 봐 계속 신경 쓰여요.',
    '업무 마감이 다가오는데 못 끝낼 것 같아요.',
    '친구와의 관계가 예전 같지 않아서 속상해요.',
    '면접이 다음 주인데 떨어질까 봐 불안해요.',
    '가족 문제로 계속 마음이 무거워요.',
  ];
  for (var i = 0; i < exploreTopics.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'explore_general_${i + 1}',
        label: 'Explore: ${exploreTopics[i]}',
        category: 'explore_general',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: exploreTopics[i],
        ),
        multiOption: true,
      ),
    );
  }

  // ── explore SUD response path: 4 scenarios — current message is a bare
  // SUD rating following an assistant question about "어떤 순간".
  const sudResponses = ['7점이에요', '5정도요', '8이에요', '3점입니다'];
  for (var i = 0; i < sudResponses.length; i++) {
    fixtures.add(
      ScenarioFixture(
        id: 'explore_sud_response_${i + 1}',
        label: 'Explore SUD response: ${sudResponses[i]}',
        category: 'explore_sud_response',
        request: boundaryRequest(
          state: CounselingState.explore,
          userMessage: sudResponses[i],
          recentMessages: [
            assistantMessage(
              '발표에서 가장 걱정되는 순간은 언제인가요?',
              id: 'a_sud_$i',
            ),
          ],
        ),
        multiOption: true,
      ),
    );
  }

  return fixtures;
}
