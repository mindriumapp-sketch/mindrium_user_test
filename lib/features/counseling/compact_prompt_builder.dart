import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'counseling_state.dart';
import 'prompt_builder.dart';

/// 작은 온디바이스 모델을 위한 압축 프롬프트.
///
/// 1.7B 급에서 지시가 길어질수록 정작 사용자의 핵심 생각을 놓치는 현상을 겨냥한다.
/// 이번 턴에 모델이 실제로 해야 하는 일은 네 가지뿐이다.
///
///   1. 사용자의 핵심 걱정을 반영한다
///   2. 지금 단계에 맞는 질문을 하나 한다
///   3. 주어진 근거 밖의 사실을 만들지 않는다
///   4. 정해진 JSON 으로 답한다
///
/// 나머지는 모델에게 줄 이유가 없다.
///
/// - **안전 정책**: SafetyGate 가 LLM 앞에서 이미 걸러낸다. 위기 대응 절차를
///   프롬프트에 반복해 넣어도 모델이 할 일이 늘지 않는다.
/// - **상태 머신 설명**: 다음 단계는 harness 가 정한다. 모델에게는 지금 할 일만 준다.
/// - **발화 행위 분류**: harness 가 요구값을 정해 붙인다. 모델은 분류하지 않는다.
class CompactPromptBuilder implements CounselingPromptBuilder {
  static const String promptVersionValue = 'counsel_v2_compact';

  /// 프롬프트에 넣을 CBT 근거 수. 작은 모델에는 가장 관련 높은 하나가 낫다.
  final int maxKnowledge;

  /// 프롬프트에 넣을 사용자 기록 수.
  final int maxUserContextItems;

  /// 최근 대화에서 넣을 메시지 수.
  final int recentMessageWindow;

  /// CURRENT_TASK 문구를 바꿔 끼우는 자리.
  ///
  /// 같은 데이터·같은 스키마에서 행동 지시만 바꿔 비교하기 위한 실험용 seam 이다.
  /// 기본값은 상태가 갖고 있는 문구를 쓴다.
  final String Function(CounselingState state)? taskResolver;

  const CompactPromptBuilder({
    this.maxKnowledge = 1,
    this.maxUserContextItems = 1,
    this.recentMessageWindow = 2,
    this.taskResolver,
  });

  @override
  String get promptVersion => promptVersionValue;

  @override
  PromptBundle build(PromptContext context) {
    final knowledge = context.knowledge.take(maxKnowledge).toList();
    final userItems =
        context.userContext?.relevantItems.take(maxUserContextItems).toList() ??
        const <UserContextItem>[];

    return PromptBundle(
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(context, knowledge, userItems),
      promptVersion: promptVersionValue,
      offeredCbtIds: knowledge.map((item) => item.id).toSet(),
      offeredUserContextIds: userItems.map((item) => item.id).toSet(),
      // 모델에게 분류를 시키지 않는다.
      requiredDialogueAct: context.state.requiredAct,
    );
  }

  static const String _systemPrompt = '''
/no_think

당신은 Mindrium의 CBT 기반 상담 문장 생성기입니다.

이번 턴의 목표:
- 앱이 이미 사용자의 감정을 짧게 공감했습니다. 같은 말을 반복하지 마세요.
- CURRENT_TASK와 방금 한 말에 맞는 자연스러운 후속 질문을 하나만 하세요.
- USER_CONTEXT와 CBT_CONTEXT에 없는 사실은 만들지 마세요.
- 자연스러운 한국어 한 문장으로 답하세요.

반드시 지정된 JSON 형식으로만 출력하세요.''';

  String _userPrompt(
    PromptContext context,
    List<CbtKnowledgeItem> knowledge,
    List<UserContextItem> userItems,
  ) {
    final buffer =
        StringBuffer()
          ..writeln('CURRENT_TASK:')
          ..writeln(
            taskResolver?.call(context.state) ?? context.state.currentTask,
          )
          ..writeln();

    if (userItems.isNotEmpty || context.userContext?.recentSud != null) {
      buffer.writeln('USER_CONTEXT:');
      for (final item in userItems) {
        buffer
          ..writeln('[id=${item.id}]')
          ..writeln(item.text);
      }
      final sud = context.userContext?.recentSud?.latest;
      if (sud != null) buffer.writeln('SUD: $sud');
      buffer.writeln();
    }

    if (knowledge.isNotEmpty) {
      buffer.writeln('CBT_CONTEXT:');
      for (final item in knowledge) {
        buffer
          ..writeln('[id=${item.id}]')
          // 압축 프로파일에서는 첫 문단만 준다. 길게 주면 모델이 그걸 읊는다.
          ..writeln(item.paragraphs.first);
      }
      buffer.writeln();
    }

    final recent =
        context.recentMessages.length > recentMessageWindow
            ? context.recentMessages.sublist(
              context.recentMessages.length - recentMessageWindow,
            )
            : context.recentMessages;
    if (recent.isNotEmpty) {
      buffer.writeln('RECENT_MESSAGES:');
      for (final message in recent) {
        buffer.writeln('${message.isUser ? '사용자' : '상담자'}: ${message.text}');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('USER_MESSAGE:')
      ..writeln(context.userMessage.trim())
      ..writeln()
      ..writeln('OUTPUT:')
      ..writeln('{')
      ..writeln('  "reply": "...",')
      ..writeln(
        '  "referenced_cbt_ids": [${_idExample(knowledge.map((e) => e.id))}],',
      )
      ..writeln(
        '  "referenced_user_context_ids": [${_idExample(userItems.map((e) => e.id))}]',
      )
      ..writeln('}')
      ..writeln()
      // 모델이 프롬프트 표기를 그대로 베껴 "id=week4_..." 를 내보내는 일이 있다.
      ..writeln('주의:')
      ..writeln('본문에서는 [id=diary:abc123]처럼 표시하지만,')
      ..writeln('JSON에서는 "diary:abc123"만 반환하세요.')
      ..writeln('"id=" 또는 "[id="를 포함하지 마세요.');

    return buffer.toString();
  }

  String _idExample(Iterable<String> ids) =>
      ids.isEmpty ? '' : '"${ids.first}"';
}
