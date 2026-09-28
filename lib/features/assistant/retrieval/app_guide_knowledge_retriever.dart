import '../app_guide/app_feature.dart';
import '../app_guide/app_guide_repository.dart';
import '../app_guide/app_navigation.dart';
import '../app_guide/app_screen.dart';

export '../app_guide/app_feature.dart';
export '../app_guide/app_navigation.dart';
export '../app_guide/app_screen.dart';

/// [AppGuideKnowledgeRetriever]에 넘기는 입력.
class AppGuideKnowledgeRequest {
  final String query;

  const AppGuideKnowledgeRequest({required this.query});
}

/// [AppGuideKnowledgeRetriever]의 결과.
///
/// `sourceRefs`는 나중에 App Guide Agent가 만든 문장이 실제 이 근거에서
/// 나온 것인지 validator가 확인할 수 있게 한다. `confidence`는 이번
/// phase에서는 "무엇이든 매칭됐는가"만 보는 단순한 값이다(0.0 또는 1.0) —
/// 정교한 순위화는 이후 phase의 일이다.
class AppGuideKnowledgeResult {
  final List<AppFeature> matchedFeatures;
  final List<AppScreen> matchedScreens;
  final List<AppNavigationPath> navigationSteps;
  final List<AppManualEntry> manualKnowledge;
  final List<String> sourceRefs;
  final double confidence;
  final bool degraded;

  const AppGuideKnowledgeResult({
    this.matchedFeatures = const [],
    this.matchedScreens = const [],
    this.navigationSteps = const [],
    this.manualKnowledge = const [],
    this.sourceRefs = const [],
    this.confidence = 0.0,
    this.degraded = false,
  });

  static const empty = AppGuideKnowledgeResult();

  /// 앱에 실제로 있는 것을 하나라도 찾았는지. false면 App Guide Agent는
  /// (도입되면) 반드시 "모른다"고 답해야 한다 — 화면/기능을 지어내면 안
  /// 된다.
  bool get hasMatch =>
      matchedFeatures.isNotEmpty ||
      matchedScreens.isNotEmpty ||
      navigationSteps.isNotEmpty ||
      manualKnowledge.isNotEmpty;
}

/// "MindRium에서 이 기능을 어떻게 쓰는가?"를 답할 경계.
abstract interface class AppGuideKnowledgeRetriever {
  Future<AppGuideKnowledgeResult> retrieve(AppGuideKnowledgeRequest request);
}

/// Phase 6 이전 기본값. 항상 빈 결과를 돌려준다 — App Guide Knowledge
/// Base가 없던 시절과 동일하게 동작해야 하는 테스트/fallback 용도로 계속
/// 남겨 둔다.
class NoOpAppGuideKnowledgeRetriever implements AppGuideKnowledgeRetriever {
  const NoOpAppGuideKnowledgeRetriever();

  @override
  Future<AppGuideKnowledgeResult> retrieve(
    AppGuideKnowledgeRequest request,
  ) async => AppGuideKnowledgeResult.empty;
}

/// Phase 6 production 구현. [AppGuideRepository](현재는
/// [LocalAppGuideRepository])에 이미 있는 기능/화면/내비게이션/매뉴얼만
/// 키워드로 찾는다 — 없는 것을 만들어내지 않는다. embedding/vector 검색은
/// 쓰지 않는다.
class LocalAppGuideKnowledgeRetriever implements AppGuideKnowledgeRetriever {
  final AppGuideRepository repository;

  const LocalAppGuideKnowledgeRetriever({required this.repository});

  static const Set<String> _genericQueryWords = {
    '어디', '어떻게', '뭐', '뭔가', '있어', '있나', '해줘', '알려줘', '궁금',
  };

  Set<String> _keywords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^0-9a-z가-힣]+'))
        .where((word) => word.length >= 2)
        .toSet();
  }

  bool _overlaps(Set<String> queryWords, String text) {
    final wordSet = _keywords(text);
    return queryWords.any(wordSet.contains) || wordSet.any(queryWords.contains);
  }

  @override
  Future<AppGuideKnowledgeResult> retrieve(
    AppGuideKnowledgeRequest request,
  ) async {
    final allWords = _keywords(request.query);
    final queryWords = allWords.difference(_genericQueryWords);
    // 일반적인 질문 어미만 있는 경우("이거 어떻게 해?")는 아무것도 특정
    // 하지 않으므로 매칭을 시도하지 않는다 — 애매한 질문에 아무 기능이나
    // 끌어오지 않기 위함이다.
    if (queryWords.isEmpty) return AppGuideKnowledgeResult.empty;

    bool matchesNames(Iterable<String> names) =>
        names.any((name) => _overlaps(queryWords, name));

    final matchedFeatures = repository.features
        .where((feature) => matchesNames([feature.name, ...feature.aliases]))
        .toList();
    final matchedScreens = repository.screens
        .where((screen) => matchesNames([screen.displayName]))
        .toList();

    final matchedFeatureIds = matchedFeatures.map((f) => f.featureId).toSet();
    final matchedScreenIds = matchedScreens.map((s) => s.screenId).toSet();
    final navigationSteps = repository.navigationPaths
        .where(
          (path) =>
              matchedFeatureIds.contains(path.to) ||
              matchedScreenIds.contains(path.to),
        )
        .toList();

    final manualKnowledge = repository.manualEntries
        .where(
          (entry) =>
              matchesNames([entry.title]) ||
              entry.relatedFeatures.any(matchedFeatureIds.contains),
        )
        .toList();

    final result = AppGuideKnowledgeResult(
      matchedFeatures: matchedFeatures,
      matchedScreens: matchedScreens,
      navigationSteps: navigationSteps,
      manualKnowledge: manualKnowledge,
      sourceRefs: {
        for (final f in matchedFeatures) ...f.sourceRefs,
        for (final s in matchedScreens) ...s.sourceRefs,
        for (final n in navigationSteps) ...n.sourceRefs,
        for (final m in manualKnowledge) ...m.sourceRefs,
      }.toList(),
      confidence: 0.0,
    );

    // 매칭이 하나도 없으면 confidence 0인 빈 결과 — "존재하지 않는 기능"
    // 질문에 가짜 화면/경로를 만들어내지 않는다(Phase 6 핵심 요구사항).
    if (!result.hasMatch) return AppGuideKnowledgeResult.empty;

    return AppGuideKnowledgeResult(
      matchedFeatures: result.matchedFeatures,
      matchedScreens: result.matchedScreens,
      navigationSteps: result.navigationSteps,
      manualKnowledge: result.manualKnowledge,
      sourceRefs: result.sourceRefs,
      confidence: 1.0,
    );
  }
}
