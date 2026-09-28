import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/remote_llm_realizer.dart';
import 'package:gad_app_team/features/counseling/response_realizer.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

class _FakeRealizeApi implements CounselingRealizeApi {
  final Object? Function()? onCall;
  final String? fixedReply;
  final String? chosenAct;

  _FakeRealizeApi({this.onCall, this.fixedReply, this.chosenAct});

  @override
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs = const [],
    String? affect,
    String tone = 'warm, calm, concise',
    List<Map<String, String>> recentConversation = const [],
    List<String> allowedCbtFacts = const [],
    List<String> forbiddenBehaviors = const [],
    String promptVersion = 'remote-realizer-v1',
    Duration timeout = const Duration(seconds: 8),
    int? sudRatingValue,
  }) async {
    final override = onCall?.call();
    if (override is Exception) throw override;
    return {
      'request_id': requestId,
      'reply': fixedReply ?? '',
      'chosen_act': chosenAct ?? requiredAct,
      'model': 'gpt-4o-mini',
      'prompt_version': promptVersion,
      'latency_ms': 10,
    };
  }
}

RealizationRequest _request({
  String draft = '마음이 많이 쓰이셨겠어요. 어떤 점이 가장 걱정되나요?',
  List<DialogueAct> allowedActs = const [],
}) {
  return RealizationRequest(
    deterministicDraft: draft,
    reflectionTarget: '마음이 쓰인다',
    questionGoal: '핵심 걱정을 확인한다',
    requiredAct: DialogueAct.explore,
    allowedActs: allowedActs,
    retrievalSummary: RetrievalSummary.empty,
    forbiddenBehaviors: const ['조언하지 않는다'],
  );
}

void main() {
  test('정상 응답은 remoteLlm으로 채택된다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(
        fixedReply: '내일 발표가 계속 마음에 걸리시는군요. 어떤 순간이 가장 걱정되나요?',
      ),
    );

    final result = await realizer.realize(_request());

    expect(result.source, RealizationSource.remoteLlm);
    expect(result.validationResult.isValid, isTrue);
    expect(result.reply, isNotEmpty);
  });

  test('빈 응답은 invalid로 fallback 대상이 된다', () async {
    final realizer = RemoteLlmRealizer(api: _FakeRealizeApi(fixedReply: ''));

    final result = await realizer.realize(_request());

    expect(result.validationResult.isValid, isFalse);
    expect(result.validationResult.violations, contains('empty_reply'));
  });

  test('질문 개수가 초안과 다르면 invalid다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(fixedReply: '그 마음이 계속 걸리시는군요.'), // 질문 0개, 초안은 1개
    );

    final result = await realizer.realize(_request());

    expect(result.validationResult.isValid, isFalse);
    expect(
      result.validationResult.violations,
      contains('question_count_mismatch'),
    );
  });

  test('조언성 표현이 섞이면 invalid다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(
        fixedReply: '마음이 쓰이시는군요. 천천히 심호흡을 해보세요. 어떤 점이 가장 걱정되나요?',
      ),
    );

    final result = await realizer.realize(_request());

    expect(result.validationResult.isValid, isFalse);
    expect(result.validationResult.violations, contains('advice_language'));
  });

  test('프롬프트/역할 표기가 새면 invalid다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(fixedReply: '상담사: 마음이 쓰이시는군요. 어떤 점이 가장 걱정되나요?'),
    );

    final result = await realizer.realize(_request());

    expect(result.validationResult.isValid, isFalse);
    expect(result.validationResult.violations, contains('format_leak'));
  });

  test('API 호출이 예외를 던져도 harness로 예외가 전파되지 않는다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(onCall: () => Exception('network down')),
    );

    final result = await realizer.realize(_request());

    expect(result.validationResult.isValid, isFalse);
    expect(result.validationResult.violations, contains('request_failed'));
    expect(result.reply, isEmpty);
  });

  test('allowedActs 안에서 고른 다른 행위는 그 행위 기준으로 검증한다', () async {
    // explore 상태: 초안은 질문 1개(explore)지만, GPT가 반영만 하는 reflect를
    // 고르면 질문 0개여야 유효하다. docs/counseling/adaptive_dialogue_policy.md
    // 4절 Phase 1.
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(
        fixedReply: '오늘은 그냥 지친 마음을 그대로 두고 싶으신 것 같아요.',
        chosenAct: 'reflect',
      ),
    );

    final request = _request(
      draft: '마음이 많이 쓰이셨겠어요. 어떤 점이 가장 걱정되나요?',
      allowedActs: [DialogueAct.explore, DialogueAct.reflect],
    );
    final result = await realizer.realize(request);

    expect(result.validationResult.isValid, isTrue);
    expect(result.chosenAct, DialogueAct.reflect);
  });

  test('allowedActs 밖의 행위를 고르면 invalid다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(
        fixedReply: 'CBT 기법을 하나 설명해 드릴게요.',
        chosenAct: 'psychoeducation',
      ),
    );

    final request = _request(
      allowedActs: [DialogueAct.explore, DialogueAct.reflect],
    );
    final result = await realizer.realize(request);

    expect(result.validationResult.isValid, isFalse);
    expect(result.validationResult.violations, contains('act_not_allowed'));
  });

  test('allowedActs가 비어 있으면 requiredAct 외의 선택은 invalid다', () async {
    final realizer = RemoteLlmRealizer(
      api: _FakeRealizeApi(
        fixedReply: '오늘은 그냥 지친 마음을 그대로 두고 싶으신 것 같아요.',
        chosenAct: 'reflect', // requiredAct=explore인데 임의로 바꿔 응답
      ),
    );

    final result = await realizer.realize(_request());

    expect(result.validationResult.isValid, isFalse);
    expect(result.validationResult.violations, contains('act_not_allowed'));
  });

  test('최근 대화는 window 크기만큼만 API로 보낸다', () async {
    Map<String, dynamic>? captured;
    final realizer = RemoteLlmRealizer(
      api: _CapturingRealizeApi((args) => captured = args),
      recentConversationWindow: 1,
    );

    final now = DateTime(2026, 1, 1);
    final request = RealizationRequest(
      deterministicDraft: '그 마음이 계속 걸리시는군요. 어떤 순간이 가장 걱정되나요?',
      reflectionTarget: '마음이 쓰인다',
      questionGoal: '핵심 걱정을 확인한다',
      requiredAct: DialogueAct.explore,
      retrievalSummary: RetrievalSummary.empty,
      recentConversation: [
        CounselingMessage(
          id: 'm1',
          role: 'user',
          text: '첫 번째 발화',
          createdAt: now,
        ),
        CounselingMessage(
          id: 'm2',
          role: 'assistant',
          text: '두 번째 발화',
          createdAt: now,
        ),
      ],
    );

    await realizer.realize(request);

    final sent = captured!['recentConversation'] as List;
    expect(sent, hasLength(1));
    expect(sent.single['text'], '두 번째 발화');
  });

  test('Phase 10.5A.2 Track B: realizationSpec의 sudRatingValue가 API 요청까지 전달된다', () async {
    Map<String, dynamic>? captured;
    final realizer = RemoteLlmRealizer(
      api: _CapturingRealizeApi((args) => captured = args),
    );

    final request = RealizationRequest(
      deterministicDraft: '“7점이요”라고 느끼고 계시는군요. 그 상황에서 가장 걱정되는 순간은 언제인가요?',
      reflectionTarget: '7점이요',
      questionGoal: '핵심 걱정을 확인한다',
      requiredAct: DialogueAct.explore,
      retrievalSummary: RetrievalSummary.empty,
      realizationSpec: const CounselingRealizationSpec(
        reflectionTarget: ReflectionTarget.text('7점이요'),
        transitionIntent: TransitionIntent.exploreTrigger,
        questionGoal: '핵심 걱정을 확인한다',
        sudRatingValue: 7,
      ),
    );

    await realizer.realize(request);

    expect(captured!['sudRatingValue'], 7);
  });

  test('sudRatingValue가 없는 turn은 null을 그대로 API로 보낸다', () async {
    Map<String, dynamic>? captured;
    final realizer = RemoteLlmRealizer(
      api: _CapturingRealizeApi((args) => captured = args),
    );

    await realizer.realize(_request());

    expect(captured!['sudRatingValue'], isNull);
  });
}

class _CapturingRealizeApi implements CounselingRealizeApi {
  final void Function(Map<String, dynamic> args) onCapture;
  _CapturingRealizeApi(this.onCapture);

  @override
  Future<Map<String, dynamic>> realize({
    required String requestId,
    required String deterministicDraft,
    required String reflectionTarget,
    required String questionGoal,
    required String requiredAct,
    List<String> allowedActs = const [],
    String? affect,
    String tone = 'warm, calm, concise',
    List<Map<String, String>> recentConversation = const [],
    List<String> allowedCbtFacts = const [],
    List<String> forbiddenBehaviors = const [],
    String promptVersion = 'remote-realizer-v1',
    Duration timeout = const Duration(seconds: 8),
    int? sudRatingValue,
  }) async {
    onCapture({
      'recentConversation': recentConversation,
      'sudRatingValue': sudRatingValue,
    });
    return {
      'reply': '그 마음이 계속 걸리시는군요. 어떤 순간이 가장 걱정되나요?',
      'chosen_act': requiredAct,
    };
  }
}
