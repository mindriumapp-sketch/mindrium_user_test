// 설치된 프로덕션 경로(결정론 harness + 실제 로그인 계정의 서버 데이터)로
// 여러 상담 시나리오를 멀티턴 실행한다. 실기기에서 앱과 같은 패키지로 돌아가므로
// 로그인 토큰을 그대로 읽어 실제 개인화 컨텍스트가 반영되는지도 함께 본다.
//
// 실행: flutter test integration_test/counseling_production_scenarios_test.dart -d <serial>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/counseling_sessions_api.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/llm_service.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

/// 프로덕션 fallback(설치된 앱의 기본 경로)에서 모델이 실제로 불리지 않는지
/// 세는 용도. 결정론 경로면 항상 0이어야 한다.
class _CountingLlm implements LlmService {
  int calls = 0;
  final LlmService _inner = MockLlmService();

  @override
  Future<LlmResponse> generate(LlmRequest request) {
    calls++;
    return _inner.generate(request);
  }
}

class _Scenario {
  final String name;
  final List<String> turns;

  const _Scenario({required this.name, required this.turns});
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenarios = <_Scenario>[
    _Scenario(
      name: 'presentation_anxiety',
      turns: [
        '내일 발표가 있어서 계속 불안해요.',
        '질문에 답을 못할까 봐 걱정돼요.',
        '사람들이 저를 무능하게 볼 것 같아요.',
        '한 번 막히면 준비를 안 했다고 생각할 것 같아요.',
        '완벽하게 답하지 못해도 준비한 내용은 설명할 수 있어요.',
      ],
    ),
    _Scenario(
      name: 'relationship_worry',
      turns: [
        '친한 친구가 요즘 제 연락을 피하는 것 같아서 속상해요.',
        '제가 뭔가 실수한 게 있을까 봐 계속 신경 쓰여요.',
        '친구가 저를 이제 안 좋아하는 것 같다는 생각이 들어요.',
        '먼저 연락해서 무슨 일인지 물어보면 어떨까 하는 생각도 들어요.',
      ],
    ),
    _Scenario(
      name: 'future_failure_worry',
      turns: [
        '앞으로 취업이 안 될까 봐 계속 불안해요.',
        '이대로 가면 아무 데도 못 갈 것 같다는 생각이 들어요.',
        '남들은 다 잘하고 있는데 저만 뒤처지는 것 같아요.',
        '아직 일어나지 않은 일인데 벌써부터 걱정하고 있는 것 같기도 해요.',
      ],
    ),
    _Scenario(
      name: 'avoidance_behavior',
      turns: [
        '요즘 사람 많은 모임에 나가는 게 너무 힘들어요.',
        '초대를 받으면 항상 핑계를 대고 안 나가게 돼요.',
        '안 나가면 편하긴 한데 나중에 후회가 돼요.',
        '조금씩이라도 나가보는 게 나을지 고민돼요.',
      ],
    ),
    _Scenario(
      name: 'already_has_alternative',
      turns: [
        '오늘 회의에서 실수할까 봐 걱정했는데 막상 잘 끝났어요.',
        '전에는 실수하면 다 끝났다고 생각했는데, 이번엔 그렇지 않다는 걸 알았어요.',
        '완벽하지 않아도 괜찮다는 걸 조금씩 느끼고 있어요.',
      ],
    ),
    _Scenario(
      name: 'safety_bypass_check',
      turns: ['요즘 정말 힘들어서 죽고 싶다는 생각이 들어요.', '그래도 발표 준비는 계속해야 하는데 손이 안 가요.'],
    ),
  ];

  testWidgets('설치된 프로덕션 경로 — 여러 시나리오 멀티턴', (tester) async {
    final repository = LocalCbtKnowledgeRepository();
    await repository.initialize();

    final tokenStorage = TokenStorage();
    final access = await tokenStorage.access;
    // ignore: avoid_print
    print('[AUTH] token_present=${access != null && access.isNotEmpty}');

    final apiClient = ApiClient(tokens: tokenStorage);
    final sessionsApi = CounselingSessionsApi(apiClient);
    final contextBuilder = MindriumContextBuilder(
      dataSource: ApiMindriumDataSource(
        diariesApi: DiariesApi(apiClient),
        worryGroupsApi: WorryGroupsApi(apiClient),
        relaxationApi: RelaxationApi(apiClient),
      ),
    );

    for (final scenario in scenarios) {
      final countingLlm = _CountingLlm();
      final harness = CounselingHarness.deterministic(
        llm: countingLlm,
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      );

      final provider = CounselingProvider(
        harness: harness,
        knowledgeRepository: repository,
        currentWeek: 4,
        contextBuilder: contextBuilder,
        sessionsApi: sessionsApi,
        sessionId: 'prod_scenario_${scenario.name}_${DateTime.now().millisecondsSinceEpoch}',
      );

      await provider.initialize();
      // ignore: avoid_print
      print(
        '[SCENARIO_START] scenario=${scenario.name} '
        'previous_session=${provider.previousSession != null} '
        'carried_unfinished=${provider.carriedUnfinishedIssue != null}',
      );

      CounselingState? previousState;
      String? previousNonSafetyReply;

      for (var index = 0; index < scenario.turns.length; index++) {
        final userMessage = scenario.turns[index];
        await provider.sendMessage(userMessage);

        final reply = provider.messages.last;
        final questionCount = '?'.allMatches(reply.text).length;
        final stateOk = previousState == null || _isForwardOrSame(previousState, provider.state);

        // ignore: avoid_print
        print(
          '[SCENARIO_TURN] scenario=${scenario.name} turn=${index + 1} '
          'state=${previousState?.wireName}->${provider.state.wireName} '
          'act=${reply.dialogueAct?.wireName} '
          'question_count=$questionCount '
          'cbt_ids=${reply.referencedCbtIds} '
          'user_ids=${reply.referencedUserContextIds} '
          'construction_ids=${provider.sessionSummary.provenanceIds} '
          'safety=${provider.lastSafetyLevel.name} '
          'llm_calls_total=${countingLlm.calls} '
          'reply=${reply.text}',
        );

        expect(reply.text.trim(), isNotEmpty, reason: '${scenario.name} turn ${index + 1}');
        expect(questionCount, lessThanOrEqualTo(1), reason: '${scenario.name} turn ${index + 1}: 한 턴 한 질문');
        expect(stateOk, isTrue, reason: '${scenario.name} turn ${index + 1}: state가 역행함');
        // 안전 응답은 임상 검수된 고정 문구라 반복돼도 정상이다. 그 외 턴에서
        // 직전과 완전히 같은 응답이 나오면 대화가 제자리에 머문 것이다.
        final isNormalTurn = provider.lastSafetyLevel == SafetyLevel.normal;
        if (isNormalTurn && previousNonSafetyReply != null) {
          expect(
            reply.text,
            isNot(equals(previousNonSafetyReply)),
            reason: '${scenario.name} turn ${index + 1}: 직전과 동일한 응답',
          );
        }

        previousState = provider.state;
        if (isNormalTurn) previousNonSafetyReply = reply.text;
      }

      // 프로덕션 기본 구성은 결정론 경로이므로 모델 호출이 없어야 한다.
      expect(countingLlm.calls, 0, reason: '${scenario.name}: 결정론 경로에서 LLM이 호출됨');

      // ignore: avoid_print
      print(
        '[SCENARIO_END] scenario=${scenario.name} '
        'final_state=${provider.state.wireName} '
        'concern=${provider.sessionSummary.concern} '
        'core_thought=${provider.sessionSummary.automaticThought} '
        'alternative=${provider.sessionSummary.alternativeThought} '
        'intervention=${provider.sessionSummary.interventionUsed} '
        'activity=${provider.sessionSummary.activityRecommended} '
        'unfinished=${provider.sessionSummary.unfinishedTopic} '
        'turn_count=${provider.sessionSummary.turnCount}',
      );

      if (provider.state == CounselingState.closing) {
        await provider.sendMessage('네, 감사합니다.');
      }
      await provider.finalizeIfIncomplete();
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

bool _isForwardOrSame(CounselingState previous, CounselingState current) {
  const order = [
    CounselingState.checkIn,
    CounselingState.explore,
    CounselingState.reflect,
    CounselingState.intervention,
    CounselingState.closing,
  ];
  return order.indexOf(current) >= order.indexOf(previous);
}
