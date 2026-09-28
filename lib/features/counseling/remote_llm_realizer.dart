import 'package:uuid/uuid.dart';

import 'package:gad_app_team/data/api/counseling_realize_api.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'response_realizer.dart';

/// `POST /counseling/realize`(GPT)로 TurnPlan 초안을 자연스럽게 다듬는다.
///
/// 상담 전략(무엇을 반영·질문할지)은 여전히 Harness의 `CounselingTurnPlan`이
/// 정한다. 이 클래스는 그 계획을 벗어난 문장이 오면 항상 `isValid: false`를
/// 돌려주고, `CounselingHarness`가 이미 갖고 있는 fallback 로직이
/// `deterministicDraft`로 되돌아가게 한다.
///
/// **절대 예외를 던지지 않는다.** 네트워크 오류·timeout·4xx/5xx·형식 오류는
/// 모두 여기서 잡아 invalid `RealizationResult`로 바꾼다. 자세한 계약은
/// docs/counseling/remote_gpt_realizer_integration.md 참고.
class RemoteLlmRealizer implements ResponseRealizer {
  final CounselingRealizeApi api;
  final Uuid _uuid;

  /// 백엔드로 보내는 최근 대화는 최소한만 유지한다(개인정보 최소화 원칙).
  final int recentConversationWindow;
  final int maxCbtFacts;

  RemoteLlmRealizer({
    required this.api,
    Uuid? uuid,
    this.recentConversationWindow = 2,
    this.maxCbtFacts = 1,
  }) : _uuid = uuid ?? const Uuid();

  static final RegExp _advicePattern = RegExp(
    r'(해보세요|하세요|도움이 될|권합니다|추천|연습해|준비해)',
  );

  static final RegExp _formatLeakPattern = RegExp(
    r'(<\|im_start\|>|<\|im_end\|>|</?[A-Za-z_][\w-]*>|^\s*(사용자|상담사|user|assistant)\s*:|\{"|```)',
    caseSensitive: false,
  );

  /// 질문을 반드시 포함해야 하는 행위. 질문 개수 검증 기준이 된다.
  /// docs/counseling/adaptive_dialogue_policy.md 4절.
  static const Set<DialogueAct> _questionBearingActs = {
    DialogueAct.explore,
    DialogueAct.socraticQuestion,
  };

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final recent = request.recentConversation;
      final window =
          recent.length > recentConversationWindow
              ? recent.sublist(recent.length - recentConversationWindow)
              : recent;

      final data = await api.realize(
        requestId: _uuid.v4(),
        deterministicDraft: request.deterministicDraft,
        reflectionTarget: request.reflectionTarget,
        questionGoal: request.questionGoal,
        requiredAct: request.requiredAct.wireName,
        allowedActs: request.allowedActs.map((act) => act.wireName).toList(),
        affect: request.affect,
        tone: request.tone,
        recentConversation:
            window
                .map(
                  (message) => {
                    'role': message.isUser ? 'user' : 'assistant',
                    'text': message.text,
                  },
                )
                .toList(),
        allowedCbtFacts:
            request.allowedCbtFacts
                .take(maxCbtFacts)
                .map(
                  (item) =>
                      item.paragraphs.isNotEmpty
                          ? item.paragraphs.first
                          : item.title,
                )
                .toList(),
        forbiddenBehaviors: request.forbiddenBehaviors,
        sudRatingValue: request.realizationSpec?.sudRatingValue,
      );
      stopwatch.stop();

      final reply = (data['reply'] as String?)?.trim() ?? '';
      final parsedChosenAct = DialogueAct.fromWire(
        data['chosen_act'] as String?,
      );
      // 백엔드가 chosen_act를 안 주거나 알 수 없는 값을 주면 항상
      // requiredAct로 취급한다 — allowedActs가 비어 있던 요청과 동일하게.
      final chosenAct =
          parsedChosenAct == DialogueAct.unknown
              ? request.requiredAct
              : parsedChosenAct;
      return RealizationResult(
        reply: reply,
        source: RealizationSource.remoteLlm,
        latency: stopwatch.elapsed,
        validationResult: _validate(reply, chosenAct, request),
        chosenAct: chosenAct,
        modelIdentifier: data['model'] as String?,
        promptVersion: data['prompt_version'] as String?,
      );
    } on Object {
      stopwatch.stop();
      // 네트워크 오류, timeout, 4xx/5xx, 형식 오류를 모두 fallback 대상으로
      // 묶는다. 원인은 backend 로그에서 구분하고, 클라이언트는 사용자에게
      // 오류를 보이는 대신 조용히 deterministic draft로 되돌아간다.
      return RealizationResult(
        reply: '',
        source: RealizationSource.remoteLlm,
        latency: stopwatch.elapsed,
        validationResult: const RealizationValidationResult(
          isValid: false,
          violations: ['request_failed'],
        ),
        chosenAct: request.requiredAct,
      );
    }
  }

  RealizationValidationResult _validate(
    String reply,
    DialogueAct chosenAct,
    RealizationRequest request,
  ) {
    if (reply.isEmpty) {
      return const RealizationValidationResult(
        isValid: false,
        violations: ['empty_reply'],
      );
    }

    final violations = <String>[];

    // 선택권을 준 적이 없으면(allowedActs 비어 있음) 기존과 동일하게
    // requiredAct 하나로만 응답해야 하고, 질문 개수는 초안과 정확히 같아야
    // 한다. 선택권을 줬다면 GPT가 고른 행위가 그 후보 안에 있는지, 그리고
    // 그 행위에 맞는 질문 개수인지를 본다.
    final replyQuestionCount = '?'.allMatches(reply).length;
    if (request.allowedActs.isEmpty) {
      if (chosenAct != request.requiredAct) {
        violations.add('act_not_allowed');
      }
      final draftQuestionCount =
          '?'.allMatches(request.deterministicDraft).length;
      if (replyQuestionCount != draftQuestionCount) {
        violations.add('question_count_mismatch');
      }
    } else {
      if (!request.allowedActs.contains(chosenAct)) {
        violations.add('act_not_allowed');
      }
      final expectedQuestionCount =
          _questionBearingActs.contains(chosenAct) ? 1 : 0;
      if (replyQuestionCount != expectedQuestionCount) {
        violations.add('question_count_mismatch');
      }
    }

    if (_advicePattern.hasMatch(reply)) violations.add('advice_language');
    if (_formatLeakPattern.hasMatch(reply)) violations.add('format_leak');
    // 상담사 두세 문장을 크게 벗어나면 새 내용을 지어냈을 가능성이 높다.
    if (reply.length > 400) violations.add('too_long');

    // Phase 12.3 (N2): real dogfood showed the model ignoring the plan's
    // question and copying the previous assistant turn's question, which
    // is what triggered users' "왜 똑같은 말을 해?" complaints. Rejecting it
    // falls back to the deterministic draft. Only flagged when the plan
    // itself asked something new — following the plan is never rejected.
    if (_repeatsPreviousQuestion(reply, request)) {
      violations.add('repeats_previous_question');
    }

    return RealizationValidationResult(
      isValid: violations.isEmpty,
      violations: violations,
    );
  }

  bool _repeatsPreviousQuestion(String reply, RealizationRequest request) {
    final previous = request.recentConversation.lastWhere(
      (m) => !m.isUser,
      orElse: () => CounselingMessage(
        id: '',
        role: 'user',
        text: '',
        createdAt: DateTime(0),
      ),
    );
    if (previous.isUser) return false;
    final previousQuestion = _lastQuestion(previous.text);
    final replyQuestion = _lastQuestion(reply);
    if (previousQuestion == null || replyQuestion == null) return false;
    if (replyQuestion != previousQuestion) return false;
    final draftQuestion = _lastQuestion(request.deterministicDraft);
    return draftQuestion != previousQuestion;
  }

  static String? _lastQuestion(String text) {
    final matches = RegExp(r'[^.!?\n]*\?').allMatches(text).toList();
    if (matches.isEmpty) return null;
    final normalized = matches.last
        .group(0)!
        .replaceAll(RegExp(r'[\s.,!?“”"‘’]'), '');
    return normalized.isEmpty ? null : normalized;
  }
}
