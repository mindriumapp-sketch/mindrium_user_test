// 사용자가 "정상적으로 협조하는 답변"만 하지 않는 경우를 가정한 스트레스 테스트.
// 단답, 화제 이탈, 장황한 발화, 숫자만 답함, 모순되는 발화, 신조어/오타 등
// 실제 사용자가 보일 법한 다양한 답변 패턴에서도 상담 흐름(질문 1개/턴,
// state 역행 없음, 빈 응답 없음)이 깨지지 않는지 확인한다.
//
// 실행: flutter test integration_test/counseling_edge_case_scenarios_test.dart -d <serial>
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
      name: 'short_answers',
      description: '단답/무성의한 답변만 반복',
      turns: [
        '불안해요.',
        '몰라요.',
        '그냥요.',
        '네.',
      ],
    ),
    _Scenario(
      name: 'off_topic_drift',
      description: '질문과 무관한 답변으로 화제 이탈',
      turns: [
        '요즘 잠을 잘 못 자요.',
        '어제 저녁에 뭐 먹었는지 기억이 안 나요.',
        '아 맞다 저 내일 병원 예약도 있어요.',
        '그건 그렇고 다음 주에 발표가 있어서 그것 때문에 불안한 것 같아요.',
      ],
    ),
    _Scenario(
      name: 'rambling_long_answer',
      description: '여러 주제가 섞인 장황한 발화',
      turns: [
        '사실 요즘 회사에서 프로젝트 마감도 다가오고 팀장님이랑 트러블도 좀 있었고 '
            '집에서도 이런저런 일이 겹쳐서 정신이 하나도 없는데 그중에서도 제일 '
            '신경쓰이는 건 다음 주에 있을 발표인데 준비도 제대로 못했고 이러다가 '
            '망칠 것 같아서 계속 불안하고 잠도 잘 못 자고 있어요.',
        '음 그러니까 발표 자체보다는 사람들이 제가 준비 안 한 걸 눈치챌까 봐 '
            '그게 제일 걱정되는 것 같아요 아마도.',
        '예전에 비슷한 발표에서 한 번 말이 막힌 적이 있는데 그때 다들 이상하게 '
            '쳐다봤던 기억이 있어서 그런 것 같기도 하고요.',
        '완벽하지 않아도 일단 준비한 만큼만 보여줘도 되지 않을까 싶긴 해요.',
      ],
    ),
    _Scenario(
      name: 'contradictory_answers',
      description: '앞뒤가 모순되는 발화',
      turns: [
        '발표는 하나도 안 무서워요. 그냥 평범한 일이에요.',
        '사실 진짜 무서워요. 손이 떨려요.',
        '아니 근데 또 막상 하면 잘할 것 같기도 해요.',
        '그래도 이번엔 실수할까 봐 계속 걱정돼요.',
      ],
    ),
    _Scenario(
      name: 'numeric_only_answers',
      description: '개방형 질문에도 숫자로만 답함',
      turns: ['발표 때문에 불안해요.', '7.', '3.', '모르겠어요 그냥 숫자로 말한 거예요.'],
    ),
    _Scenario(
      name: 'slang_typos',
      description: '신조어/오타/축약어가 섞인 구어체',
      turns: [
        'ㅠㅠ 발표때매 넘 불안함 ㄹㅇ',
        'ㅋㅋ 그냥 쫄려서 그런듯',
        '잘모르겠음 걍 무서움',
        '아 몰겠고 그냥 잘 하고싶은데 안될까봐 그런거같음',
      ],
    ),
    _Scenario(
      name: 'repeated_identical_input',
      description: '같은 문장을 연속으로 반복 입력',
      turns: ['발표가 너무 무서워요.', '발표가 너무 무서워요.', '발표가 너무 무서워요.'],
    ),
    _Scenario(
      name: 'empty_like_whitespace',
      description: '공백/의미 없는 입력 후 정상 응답',
      turns: ['...', '음...', '발표 준비가 안 돼서 불안한 것 같아요.'],
    ),
  ];

  testWidgets('설치된 프로덕션 경로 — 다양한 사용자 답변 패턴 스트레스 테스트', (
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
            'edge_scenario_${scenario.name}_${DateTime.now().millisecondsSinceEpoch}',
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
