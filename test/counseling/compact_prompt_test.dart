import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/counseling/compact_prompt_builder.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/output_parser.dart';
import 'package:gad_app_team/features/counseling/prompt_builder.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

Future<String> loadFromDisk(String path) => File(path).readAsString();

MindriumCounselingContext contextWithDiary() {
  return MindriumCounselingContext(
    currentWeek: 4,
    relevantItems: [
      UserContextItem(
        id: 'diary:abc123',
        type: UserContextType.diary,
        text: '상황: 내일 발표 / 생각: 질문에 답하지 못하면 사람들이 나를 무능하게 볼 것 같다',
        occurredAt: DateTime(2026, 9, 1),
        sud: 8,
      ),
      UserContextItem(
        id: 'diary:zzz999',
        type: UserContextType.diary,
        text: '상황: 산책 / 생각: 별일 아니다',
        occurredAt: DateTime(2026, 8, 20),
        sud: 2,
      ),
    ],
    recentSud: const SudContext(
      latest: 8,
      weeklyAverage: 7.0,
      trend: 'increasing',
    ),
  );
}

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  group('C1 프롬프트 압축', () {
    // Phase 10.7B: 예전에는 이 헬퍼가 harness.handleTurn()을 실제로 돌려서
    // (bare CounselingHarness — turnPlanner 없음 — 이 관례상 raw LLM 경로로
    // 빠지던) 모델에 보낼 LlmRequest를 가로채 검사했다. 그 raw LLM 경로
    // (`turnPlanner == null` 분기)는 두 production factory 어디서도 도달하지
    // 않는다는 게 확인되어 harness에서 제거됐다 — `CompactPromptBuilder` 자체는
    // 여전히 살아있는 production 코드(`TurnPlanPromptBuilder`가 planner 실패
    // 시 이걸로 물러선다)라서, 여기서는 harness를 거치지 않고 그 클래스를
    // 직접 검증한다.
    PromptBundle bundleFor({
      CounselingState state = CounselingState.reflect,
      MindriumCounselingContext? userContext,
      List<CbtKnowledgeItem> knowledge = const [],
    }) {
      return const CompactPromptBuilder().build(
        PromptContext(
          state: state,
          userMessage: '질문에 답을 못하면 사람들이 저를 무능하게 볼 것 같아요.',
          knowledge: knowledge,
          allowedDialogueActs: state.allowedActs,
          userContext: userContext,
        ),
      );
    }

    test('C1 harness 기본값이 압축 프로파일이다', () {
      final harness = CounselingHarness(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      );
      expect(harness.promptBuilder.promptVersion, 'counsel_v2_compact');
    });

    test('C1 시스템 프롬프트가 짧고 안전 정책을 반복하지 않는다', () {
      final bundle = bundleFor();

      // SafetyGate 가 LLM 앞에서 이미 걸러낸다. 위기 절차를 프롬프트에 넣어도
      // 모델이 할 일은 늘지 않고 지시만 길어진다.
      expect(bundle.systemPrompt, isNot(contains('109')));
      expect(bundle.systemPrompt, isNot(contains('자살')));
      expect(bundle.systemPrompt.length, lessThan(300));
    });

    test('C1 상태 머신을 설명하지 않고 이번 턴 할 일만 준다', () {
      final bundle = bundleFor(state: CounselingState.reflect);

      expect(bundle.userPrompt, contains('CURRENT_TASK:'));
      expect(bundle.userPrompt, contains(CounselingState.reflect.currentTask));

      // 다음 단계가 무엇인지는 harness 가 정한다. 모델에게 줄 이유가 없다.
      expect(bundle.userPrompt, isNot(contains('intervention')));
      expect(bundle.userPrompt, isNot(contains('ALLOWED_DIALOGUE_ACTS')));
    });

    test('C1 CBT 근거와 사용자 기록을 각각 하나만 준다', () {
      final bundle = bundleFor(
        userContext: contextWithDiary(),
        knowledge: const [
          CbtKnowledgeItem(
            id: 'week4_thought_check_01',
            week: 4,
            type: 'technique',
            title: '생각 점검',
            paragraphs: ['질문에 답을 못하면 무능해 보일 것이라는 생각을 점검해봅니다.'],
            tags: [],
            source: 'week4.json',
          ),
        ],
      );

      // OUTPUT 이후에는 스키마 예시와 주의문이 있어 id 표기가 다시 등장한다.
      // 실제로 제공한 근거만 세려면 컨텍스트 영역만 본다.
      final contextPart = bundle.userPrompt.substring(
        0,
        bundle.userPrompt.indexOf('OUTPUT:'),
      );
      final cbtIds = RegExp(r'\[id=week').allMatches(contextPart).length;
      final userIds = RegExp(r'\[id=diary:').allMatches(contextPart).length;

      expect(cbtIds, 1);
      expect(userIds, 1);
      // 가장 관련 높은 기록(목록의 첫 항목)이 남아야 한다 —
      // `CompactPromptBuilder`는 `context.knowledge`/`relevantItems`가 이미
      // 관련도순으로 온다고 가정하고 앞에서 `maxUserContextItems`개만 자른다.
      expect(bundle.userPrompt, contains('diary:abc123'));
      expect(bundle.userPrompt, isNot(contains('diary:zzz999')));
    });

    test('C1 id 표기를 그대로 베끼지 말라고 지시한다', () {
      final bundle = bundleFor(userContext: contextWithDiary());

      expect(bundle.userPrompt, contains('"id=" 또는 "[id="를 포함하지 마세요'));
      expect(bundle.userPrompt, contains('OUTPUT:'));
    });

    test('C1 출력 스키마에 dialogue_act 를 요구하지 않는다', () {
      final bundle = bundleFor();

      // 모델은 문장만 쓴다. 행위 분류는 harness 가 붙인다.
      expect(bundle.userPrompt, contains('"reply"'));
      expect(bundle.userPrompt, isNot(contains('"dialogue_act"')));
    });

    test('C1 verbose 프로파일보다 짧다', () async {
      const context = PromptContext(
        state: CounselingState.reflect,
        userMessage: '발표가 걱정돼요.',
        knowledge: [],
        allowedDialogueActs: [DialogueAct.reflect],
      );

      final verbose = const PromptBuilder().build(context);
      final compact = const CompactPromptBuilder().build(context);

      final verboseLength =
          verbose.systemPrompt.length + verbose.userPrompt.length;
      final compactLength =
          compact.systemPrompt.length + compact.userPrompt.length;

      expect(compactLength, lessThan(verboseLength ~/ 2));
    });
  });

  group('C2 harness 가 발화 행위를 정한다', () {
    test('C2 압축 프로파일은 요구 행위를 bundle 에 담는다', () {
      const context = PromptContext(
        state: CounselingState.intervention,
        userMessage: '생각을 바꾸기 어려워요.',
        knowledge: [],
        allowedDialogueActs: [DialogueAct.socraticQuestion],
      );

      final bundle = const CompactPromptBuilder().build(context);

      expect(bundle.requiredDialogueAct, DialogueAct.socraticQuestion);
    });

    test('C2 verbose 프로파일은 요구 행위를 두지 않는다', () {
      const context = PromptContext(
        state: CounselingState.intervention,
        userMessage: '생각을 바꾸기 어려워요.',
        knowledge: [],
        allowedDialogueActs: [DialogueAct.socraticQuestion],
      );

      expect(const PromptBuilder().build(context).requiredDialogueAct, isNull);
    });

    // Phase 10.7B: "모델이 엉뚱한 행위를 내도 harness 값이 이긴다"와 "파싱에
    // 실패한 턴에는 요구 행위를 붙이지 않는다"는 raw LLM 경로(JSON
    // dialogue_act 직접 주입)로만 이 속성을 검사했다. 그 경로는 제거됐고,
    // 같은 속성(realizer가 고른 행위가 허용 범위 밖이면 무효화/deterministic
    // 복귀)은 이제 `test/counseling/adaptive_dialogue_policy_test.dart`와
    // `test/counseling/hybrid_turn_router_gating_test.dart`가 실제 도달
    // 가능한 Remote 경로 기준으로 검증한다.
  });

  group('id 표기 정리', () {
    const parser = CounselingOutputParser();

    test('모델이 프롬프트 표기를 베껴도 id 를 살려낸다', () {
      final output = parser.parse('''
{
  "reply": "네",
  "referenced_cbt_ids": ["id=week4_thought_check_01", "[id=week3_practice_01]"],
  "referenced_user_context_ids": ["[id=diary:abc123]"]
}
''');

      expect(output.referencedCbtIds, [
        'week4_thought_check_01',
        'week3_practice_01',
      ]);
      expect(output.referencedUserContextIds, ['diary:abc123']);
    });

    test('정상 id 는 그대로 둔다', () {
      final output = parser.parse(
        '{"reply": "네", "referenced_cbt_ids": ["week4_thought_check_01"]}',
      );

      expect(output.referencedCbtIds, ['week4_thought_check_01']);
    });
  });
}
