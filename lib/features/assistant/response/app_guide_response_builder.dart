import '../retrieval/app_guide_knowledge_retriever.dart';
import 'app_guide_response.dart';

/// App Guide Knowledge에서 사용자-friendly한 응답을 생성한다.
///
/// 모든 내용은 [AppGuideKnowledgeResult]의 데이터에만 근거한다 —
/// 존재하지 않는 화면이나 경로를 만들어내지 않는다.
abstract interface class AppGuideResponseBuilder {
  AppGuideResponse build(
    String userMessage,
    AppGuideKnowledgeResult knowledge,
  );
}

/// Deterministic implementation. GPT 없이 KB 구조만 사용.
class DeterministicAppGuideResponseBuilder implements AppGuideResponseBuilder {
  const DeterministicAppGuideResponseBuilder();

  @override
  AppGuideResponse build(
    String userMessage,
    AppGuideKnowledgeResult knowledge,
  ) {
    if (knowledge.degraded) {
      return AppGuideResponse(
        text: 'MindRium 기능 정보를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.',
        status: AppGuideAnswerStatus.degraded,
      );
    }

    if (!knowledge.hasMatch) {
      return AppGuideResponse(
        text:
            '현재 확인 가능한 MindRium 기능 정보에서는 해당 내용을 찾을 수 없어요.',
        status: AppGuideAnswerStatus.noKnowledge,
        sourceRefs: knowledge.sourceRefs,
      );
    }

    // 응답 생성: navigation path가 있으면 그것을 최우선으로 사용한다.
    // 없으면 feature description이나 manual을 사용한다.
    if (knowledge.navigationSteps.isNotEmpty) {
      return _buildNavigationGuide(knowledge);
    }

    if (knowledge.manualKnowledge.isNotEmpty) {
      return _buildManualExplanation(knowledge);
    }

    if (knowledge.matchedFeatures.isNotEmpty) {
      return _buildFeatureDescription(knowledge);
    }

    // 여기 도달하면 hasMatch는 true지만 사실상 표시할 정보가 없는 경우 —
    // 설계상 일어나면 안 되지만 defensive fallback.
    return AppGuideResponse(
      text: '해당 정보를 표시할 수 없습니다.',
      status: AppGuideAnswerStatus.noKnowledge,
      sourceRefs: knowledge.sourceRefs,
    );
  }

  AppGuideResponse _buildNavigationGuide(AppGuideKnowledgeResult knowledge) {
    final steps = knowledge.navigationSteps;
    if (steps.isEmpty) {
      return AppGuideResponse(
        text: '찾으신 화면이 있지만 경로를 알려드릴 수 없습니다.',
        status: AppGuideAnswerStatus.noKnowledge,
        sourceRefs: knowledge.sourceRefs,
      );
    }

    final path = steps.first;
    final stepsText = path.steps.join(' → ');

    final buffer = StringBuffer();
    if (knowledge.matchedFeatures.isNotEmpty) {
      final name = knowledge.matchedFeatures.first.name;
      buffer.write('$name${_topicParticle(name)} ');
    }
    buffer.write(stepsText);
    buffer.write('에서 확인할 수 있어요.');

    return AppGuideResponse(
      text: buffer.toString(),
      status: AppGuideAnswerStatus.grounded,
      sourceRefs: knowledge.sourceRefs,
    );
  }

  AppGuideResponse _buildFeatureDescription(AppGuideKnowledgeResult knowledge) {
    final feature = knowledge.matchedFeatures.first;
    return AppGuideResponse(
      text: '${feature.name}: ${feature.description}',
      status: AppGuideAnswerStatus.grounded,
      sourceRefs: knowledge.sourceRefs,
    );
  }

  AppGuideResponse _buildManualExplanation(AppGuideKnowledgeResult knowledge) {
    final manual = knowledge.manualKnowledge.first;
    return AppGuideResponse(
      text: manual.content,
      status: AppGuideAnswerStatus.grounded,
      sourceRefs: knowledge.sourceRefs,
    );
  }

  /// 은/는 by the final syllable's batchim ("걱정 기록은", "위젯은", "알림은",
  /// "리포트는"). Non-Hangul endings default to 는.
  static String _topicParticle(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return '는';
    final code = trimmed.codeUnitAt(trimmed.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return '는';
    return (code - 0xAC00) % 28 == 0 ? '는' : '은';
  }
}
