import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'compact_prompt_builder.dart';
import 'prompt_builder.dart';

/// TurnPlan을 상담 전략이 아닌 자연어 realization 문제로 바꾸는 프롬프트.
class TurnPlanPromptBuilder implements CounselingPromptBuilder {
  static const String promptVersionValue = 'counsel_v4_sentence_plan_reflect';

  final int maxKnowledge;
  final int maxUserContextItems;
  final int recentMessageWindow;

  const TurnPlanPromptBuilder({
    this.maxKnowledge = 3,
    this.maxUserContextItems = 3,
    this.recentMessageWindow = 6,
  });

  @override
  String get promptVersion => promptVersionValue;

  @override
  PromptBundle build(PromptContext context) {
    final plan = context.turnPlan;
    if (plan == null) return const CompactPromptBuilder().build(context);

    final knowledge =
        context.knowledge
            .where((item) => plan.cbtContextIds.contains(item.id))
            .take(maxKnowledge)
            .toList();
    final userItems =
        (context.userContext?.relevantItems ?? const <UserContextItem>[])
            .where((item) => plan.userContextIds.contains(item.id))
            .take(maxUserContextItems)
            .toList();

    return PromptBundle(
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(context, knowledge, userItems),
      promptVersion: promptVersionValue,
      offeredCbtIds: knowledge.map((item) => item.id).toSet(),
      offeredUserContextIds: userItems.map((item) => item.id).toSet(),
      requiredDialogueAct: plan.requiredAct,
    );
  }

  static const String _systemPrompt = '''
당신은 Mindrium 상담 문장 생성기입니다.
상담 전략이나 내용을 판단하지 마세요.
주어진 두 문장의 의미를 바꾸지 말고 자연스러운 한국어 표현만 최소한으로 다듬으세요.
반드시 {"reply":"..."} JSON 형식으로만 출력하세요.''';

  String _userPrompt(
    PromptContext context,
    List<CbtKnowledgeItem> knowledge,
    List<UserContextItem> userItems,
  ) {
    final plan = context.turnPlan!;
    final buffer =
        StringBuffer()
          ..writeln('REFLECTION:')
          ..writeln(plan.reflectionSentence)
          ..writeln()
          ..writeln('QUESTION:')
          ..writeln(plan.questionSentence)
          ..writeln()
          ..writeln('금지:');
    for (final rule in plan.forbidden) {
      buffer.writeln('- $rule');
    }
    buffer
      ..writeln()
      ..writeln('규칙:')
      ..writeln('1. 반드시 두 문장을 모두 보존하세요.')
      ..writeln('2. 첫 문장은 반영, 두 번째 문장은 질문이어야 합니다.')
      ..writeln('3. 질문은 정확히 하나여야 합니다.')
      ..writeln();

    if (userItems.isNotEmpty) {
      buffer.writeln('USER_CONTEXT:');
      for (final item in userItems) {
        buffer
          ..writeln('[id=${item.id}]')
          ..writeln(item.text);
      }
      buffer.writeln();
    }
    if (knowledge.isNotEmpty) {
      buffer.writeln('CBT_CONTEXT:');
      for (final item in knowledge) {
        buffer
          ..writeln('[id=${item.id}]')
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
      ..writeln('{"reply":"..."}');
    return buffer.toString();
  }
}
