import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'counseling_state.dart';
import 'turn_plan.dart';

/// 프롬프트를 만드는 데 필요한 입력. 문자열을 여기저기서 이어 붙이지 않기 위해 객체로 둔다.
class PromptContext {
  final CounselingState state;
  final String userMessage;
  final List<CbtKnowledgeItem> knowledge;
  final List<DialogueAct> allowedDialogueActs;

  /// 이번 세션의 사용자 컨텍스트. 없으면 개인화 없이 진행한다.
  final MindriumCounselingContext? userContext;

  /// 오래된 대화를 압축한 요약. Step 1 에서는 아직 채우지 않는다.
  final String? sessionSummary;

  /// 최근 대화. 전체를 넣지 않고 harness 가 잘라서 준다.
  final List<CounselingMessage> recentMessages;

  /// TurnPlanner가 만든 결정론적 행동 계획. null이면 기존 prompt 경로다.
  final CounselingTurnPlan? turnPlan;

  const PromptContext({
    required this.state,
    required this.userMessage,
    required this.knowledge,
    required this.allowedDialogueActs,
    this.userContext,
    this.sessionSummary,
    this.recentMessages = const [],
    this.turnPlan,
  });
}

/// 모델에 실제로 보낼 프롬프트 한 쌍.
class PromptBundle {
  final String systemPrompt;
  final String userPrompt;
  final String promptVersion;

  /// 이 턴에 모델이 근거로 쓸 수 있는 CBT id. harness 가 출력 검증에 쓴다.
  final Set<String> offeredCbtIds;

  /// 이 턴에 모델이 참조해도 되는 사용자 데이터 id.
  final Set<String> offeredUserContextIds;

  /// harness 가 이번 턴에 요구하는 발화 행위.
  ///
  /// null 이 아니면 모델에게 행위 분류를 시키지 않고 harness 가 값을 붙인다.
  /// 작은 모델에게 "좋은 상담 문장을 쓰라" 와 "그 문장이 무슨 행위인지 분류하라" 를
  /// 동시에 시키면 정작 중요한 문장 생성에 쓸 capacity 가 줄어든다.
  final DialogueAct? requiredDialogueAct;

  /// JSON이 아닌 사용자 표시용 평문을 의도한 프로파일인지 여부.
  final bool acceptsPlainText;

  const PromptBundle({
    required this.systemPrompt,
    required this.userPrompt,
    required this.promptVersion,
    required this.offeredCbtIds,
    required this.offeredUserContextIds,
    this.requiredDialogueAct,
    this.acceptsPlainText = false,
  });
}

/// 프롬프트 생성 계약.
///
/// 같은 harness 에 서로 다른 프롬프트 전략을 꽂아 비교하기 위해 인터페이스로 둔다.
/// 모델을 바꾸지 않고 프롬프트만 바꿔가며 재는 것이 온디바이스 실험의 핵심이다.
abstract class CounselingPromptBuilder {
  String get promptVersion;

  PromptBundle build(PromptContext context);
}

/// 규칙과 근거를 모두 풀어 쓰는 초기 프롬프트.
///
/// 큰 모델에서는 문제가 없지만, 1.7B 급에서는 지시가 길어질수록 정작 사용자의
/// 핵심 생각을 놓친다. 비교 대상으로 남겨 둔다. CompactPromptBuilder 를 참고.
class PromptBuilder implements CounselingPromptBuilder {
  /// 프롬프트를 고칠 때마다 올린다. 모델 비교 실험에서 조건을 식별하는 값이다.
  static const String promptVersionValue = 'counsel_v1_verbose';

  /// 최근 대화에서 프롬프트에 넣을 메시지 수.
  static const int recentMessageWindow = 6;

  const PromptBuilder();

  @override
  String get promptVersion => promptVersionValue;

  @override
  PromptBundle build(PromptContext context) {
    return PromptBundle(
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(context),
      promptVersion: promptVersionValue,
      offeredCbtIds: context.knowledge.map((item) => item.id).toSet(),
      offeredUserContextIds: context.userContext?.offeredIds ?? const {},
    );
  }

  static const String _systemPrompt = '''
당신은 Mindrium Counselor 입니다. 불안과 걱정을 다루는 CBT 프로그램을 사용 중인
성인 사용자와 한국어로 대화합니다.

역할
- 사용자가 자신의 생각과 행동을 스스로 살펴보도록 돕습니다.
- Mindrium 이 제공한 CBT 기법만 사용합니다.
- 당신은 의사, 심리학자, 의료 전문가가 아닙니다.
- 진단하지 않고, 약물을 권하지 않으며, 전문 치료를 대체하지 않습니다.

근거
- USER_MESSAGE, USER_CONTEXT, CBT_CONTEXT, RECENT_MESSAGES 에 있는 내용만 사용합니다.
- 사용자의 과거 경험을 지어내지 않습니다. USER_CONTEXT 에 없는 기록을 사용자가
  적었다고 말하지 않습니다.
- 과거 기록을 언급했다면 그 id 를 referenced_user_context_ids 에 넣습니다.
- CBT_CONTEXT 에 없는 치료 기법을 소개하지 않습니다.

대화
- 한 번에 주된 질문은 하나만 합니다.
- 두세 문장으로 짧게 답합니다.
- 자연스러운 한국어를 씁니다.
- 기법을 권하기 전에 먼저 되비춥니다.
- 같은 위로 문구를 반복하지 않습니다.

상태
- CURRENT_STATE 를 따릅니다.
- ALLOWED_DIALOGUE_ACTS 안에 있는 행위만 합니다.
- 상담 단계를 스스로 바꾸지 않습니다.
- 앱 기능 실행을 직접 결정하지 않습니다.

출력 형식
아래 JSON 객체 하나만 출력합니다. 다른 문장이나 코드펜스를 덧붙이지 않습니다.
{
  "reply": "사용자에게 보여줄 한국어 문장",
  "dialogue_act": "ALLOWED_DIALOGUE_ACTS 중 하나",
  "referenced_cbt_ids": ["CBT_CONTEXT 에 제시된 id 만"],
  "referenced_user_context_ids": ["USER_CONTEXT 에 제시된 id 만"]
}
''';

  String _userPrompt(PromptContext context) {
    final buffer =
        StringBuffer()
          ..writeln('CURRENT_STATE: ${context.state.wireName}')
          ..writeln('STATE_GOAL: ${context.state.goal}')
          ..writeln(
            'ALLOWED_DIALOGUE_ACTS: '
            '${context.allowedDialogueActs.map((a) => a.wireName).join(', ')}',
          )
          ..writeln();

    if (context.sessionSummary != null &&
        context.sessionSummary!.trim().isNotEmpty) {
      buffer
        ..writeln('SESSION_SUMMARY:')
        ..writeln(context.sessionSummary!.trim())
        ..writeln();
    }

    if (context.recentMessages.isNotEmpty) {
      buffer.writeln('RECENT_MESSAGES:');
      for (final message in context.recentMessages) {
        buffer.writeln('${message.isUser ? '사용자' : '상담자'}: ${message.text}');
      }
      buffer.writeln();
    }

    _writeUserContext(buffer, context.userContext);

    buffer.writeln('CBT_CONTEXT:');
    if (context.knowledge.isEmpty) {
      buffer.writeln('(이번 턴에 제공된 CBT 근거가 없습니다. 기법을 언급하지 마세요.)');
    } else {
      for (final item in context.knowledge) {
        // source 경로는 내부 검수용이므로 프롬프트에 넣지 않는다. id 만 노출한다.
        buffer
          ..writeln('[id=${item.id}] ${item.title}')
          ..writeln(_summarise(item));
        if (!item.conversationalGuidanceAvailable) {
          buffer.writeln('(주의: 이 내용은 단계별로 안내하지 말고 앱에서 실행하도록만 제안하세요.)');
        }
        buffer.writeln();
      }
    }

    buffer
      ..writeln('USER_MESSAGE:')
      ..writeln(context.userMessage.trim());

    return buffer.toString();
  }

  /// 사용자 기록 블록. 좌표·주소 같은 값은 ContextBuilder 단계에서 이미 걸러져 있다.
  void _writeUserContext(StringBuffer buffer, MindriumCounselingContext? ctx) {
    if (ctx == null || ctx.isEmpty) {
      buffer
        ..writeln('USER_CONTEXT:')
        ..writeln('(참조할 사용자 기록이 없습니다. 과거 기록을 언급하지 마세요.)')
        ..writeln();
      return;
    }

    buffer.writeln('USER_CONTEXT:');
    buffer.writeln('현재 주차: ${ctx.currentWeek}');

    final sud = ctx.recentSud;
    if (sud != null) {
      final parts = <String>[
        if (sud.latest != null) '최근 ${sud.latest}',
        if (sud.weeklyAverage != null) '평균 ${sud.weeklyAverage}',
        '추이 ${sud.trend}',
      ];
      buffer.writeln('불안 점수(SUD): ${parts.join(', ')}');
    }

    if (ctx.recurringThemes.isNotEmpty) {
      buffer.writeln('반복되는 표현: ${ctx.recurringThemes.join(', ')}');
    }

    for (final item in ctx.relevantItems) {
      buffer.writeln('[id=${item.id}] ${item.text}');
    }

    for (final item in ctx.effectiveInterventions) {
      buffer.writeln(
        '[id=${item.id}] 지난 ${item.label} 후 불안이 '
        '${item.preSud}에서 ${item.postSud}로 낮아졌습니다.',
      );
    }

    buffer.writeln();
  }

  /// 항목 하나를 프롬프트에 넣을 만큼만 줄인다. 이완 원고처럼 긴 항목이 창을 잡아먹지 않게 한다.
  static const int _maxParagraphs = 4;
  static const int _maxExamples = 4;

  String _summarise(CbtKnowledgeItem item) {
    final buffer = StringBuffer();
    for (final paragraph in item.paragraphs.take(_maxParagraphs)) {
      buffer.writeln('- $paragraph');
    }
    if (item.paragraphs.length > _maxParagraphs) {
      buffer.writeln('- (이하 생략)');
    }
    for (final example in item.examples.take(_maxExamples)) {
      buffer.writeln('- 예시(${example.label}): ${example.text}');
    }
    if (item.examples.length > _maxExamples) {
      buffer.writeln('- (예시 이하 생략)');
    }
    return buffer.toString().trimRight();
  }
}
