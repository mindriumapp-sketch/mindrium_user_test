// 실제 상담을 받는 사용자가 보일 법한, 기존 시나리오(counseling_production_
// scenarios_test.dart / counseling_edge_case_scenarios_test.dart)에 없던
// 발화 패턴을 검증한다: 신체 증상 위주 호소, 과도한 자기비난, 상담 자체에
// 회의적인 태도, 즉각적인 해결책 요구, 세션 중 드러나는 우울감(위기는 아님),
// 타인과의 비교, 질문 자체에 대한 반발, 여러 고민이 섞인 세션.
//
// 실행: flutter test integration_test/counseling_realistic_user_scenarios_test.dart -d <serial>
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
  final String description;
  final List<String> turns;

  const _Scenario({
    required this.name,
    required this.description,
    required this.turns,
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenarios = <_Scenario>[
    _Scenario(
      name: 'somatic_symptoms_only',
      description: '감정 단어 없이 신체 증상만으로 호소',
      turns: [
        '요즘 자꾸 심장이 두근거리고 소화가 안 돼요.',
        '병원 가도 별 이상 없다고 하더라고요.',
        '근데 회사 갈 때만 유독 그래요.',
        '발표가 있는 날은 더 심해지는 것 같아요.',
      ],
    ),
    _Scenario(
      name: 'self_blame_heavy',
      description: '과도한 자기비난',
      turns: [
        '다 제 잘못인 것 같아요.',
        '제가 좀 더 잘했으면 이런 일이 없었을 텐데요.',
        '저는 원래 뭘 해도 부족한 사람인 것 같아요.',
        '그냥 제가 문제인 거죠 뭐.',
      ],
    ),
    _Scenario(
      name: 'skeptical_resistant',
      description: '상담 자체에 회의적인 태도로 시작',
      turns: [
        '이런 거 한다고 뭐가 달라질까 싶어요.',
        '그냥 하라고 해서 하는 거예요.',
        '말한다고 해결되는 것도 아니잖아요.',
        '그래도 한 번 해볼게요, 요즘 발표 때문에 계속 신경 쓰이긴 해요.',
      ],
    ),
    _Scenario(
      name: 'demands_solution_immediately',
      description: '탐색 없이 바로 해결책을 요구',
      turns: [
        '발표가 불안한데 그냥 어떻게 해야 하는지만 알려주세요.',
        '설명 필요 없고 방법만요.',
        '네 알겠어요, 근데 그게 진짜 도움이 될까요?',
      ],
    ),
    _Scenario(
      name: 'depressive_symptoms_surface',
      description: '세션 중 우울감이 드러남 (위기 발화는 아님)',
      turns: [
        '요즘 발표 준비하기가 너무 힘들어요.',
        '사실 요즘 뭘 해도 재미가 없고 밥맛도 없어요.',
        '그냥 다 귀찮고 눕고만 싶어요.',
        '그래도 발표는 해야 하니까 어떻게든 해보려고요.',
      ],
    ),
    _Scenario(
      name: 'comparison_to_others',
      description: '타인과 자신을 비교하며 위축됨',
      turns: [
        '다른 사람들은 발표 잘만 하던데 저만 이런 것 같아요.',
        '동기들은 다 여유로워 보이는데 저만 유난 떠는 거 같고요.',
        '그래서 더 위축되고 자신이 없어졌어요.',
        '잘하는 사람들 보면 저만 부족한 사람처럼 느껴져요.',
      ],
    ),
    _Scenario(
      name: 'pushes_back_on_question',
      description: '챗봇의 질문 자체에 반발',
      turns: [
        '그냥 힘든 얘기 좀 들어주세요.',
        '왜 자꾸 물어보기만 해요, 그냥 공감 좀 해주시면 안 돼요?',
        '네... 발표 때문에 계속 불안한 거 맞아요.',
      ],
    ),
    _Scenario(
      name: 'multi_topic_drift_real',
      description: '여러 실제 고민이 섞여 있다가 하나로 수렴',
      turns: [
        '요즘 회사 일도 너무 많고 힘들어요.',
        '집에서도 부모님이랑 자꾸 부딪히고요.',
        '근데 요즘 제일 스트레스받는 건 다음 주 발표예요.',
        '실수하면 팀장님이 저를 안 좋게 볼까 봐 계속 걱정돼요.',
      ],
    ),
  ];

  testWidgets('설치된 프로덕션 경로 — 실제 사용자 발화 패턴 추가 점검', (
    tester,
  ) async {
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
        sessionId:
            'realistic_${scenario.name}_${DateTime.now().millisecondsSinceEpoch}',
      );

      await provider.initialize();
      // ignore: avoid_print
      print(
        '[SCENARIO_START] scenario=${scenario.name} desc=${scenario.description}',
      );

      CounselingState? previousState;

      for (var index = 0; index < scenario.turns.length; index++) {
        final userMessage = scenario.turns[index];
        await provider.sendMessage(userMessage);

        final reply = provider.messages.last;
        final questionCount = '?'.allMatches(reply.text).length;
        final stateOk =
            previousState == null ||
            _isForwardOrSame(previousState, provider.state);

        // ignore: avoid_print
        print(
          '[SCENARIO_TURN] scenario=${scenario.name} turn=${index + 1} '
          'user="$userMessage" '
          'state=${previousState?.wireName}->${provider.state.wireName} '
          'act=${reply.dialogueAct?.wireName} '
          'question_count=$questionCount '
          'safety=${provider.lastSafetyLevel.name} '
          'llm_calls_total=${countingLlm.calls} '
          'reply=${reply.text}',
        );

        expect(
          reply.text.trim(),
          isNotEmpty,
          reason: '${scenario.name} turn ${index + 1}: 빈 응답',
        );
        expect(
          questionCount,
          lessThanOrEqualTo(1),
          reason: '${scenario.name} turn ${index + 1}: 한 턴 한 질문 위반',
        );
        expect(
          stateOk,
          isTrue,
          reason: '${scenario.name} turn ${index + 1}: state가 역행함',
        );

        previousState = provider.state;
      }

      expect(
        countingLlm.calls,
        0,
        reason: '${scenario.name}: 결정론 경로에서 LLM이 호출됨',
      );

      // ignore: avoid_print
      print(
        '[SCENARIO_END] scenario=${scenario.name} '
        'final_state=${provider.state.wireName} '
        'concern=${provider.sessionSummary.concern} '
        'core_thought=${provider.sessionSummary.automaticThought} '
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
