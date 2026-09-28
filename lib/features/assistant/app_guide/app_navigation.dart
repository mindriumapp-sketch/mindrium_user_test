/// "어디서 찾나요?" 질문에 답할 실제 내비게이션 경로 하나.
///
/// `steps`는 실제 코드에서 확인되지 않은 메뉴 경로를 추측해 넣지 않는다 —
/// 코드에서 확인한 탭/카드/버튼 이름의 나열이어야 한다.
class AppNavigationPath {
  final String from;
  final String to;
  final List<String> steps;
  final List<String> sourceRefs;

  const AppNavigationPath({
    required this.from,
    required this.to,
    this.steps = const [],
    this.sourceRefs = const [],
  });

  factory AppNavigationPath.fromJson(Map<String, dynamic> json) {
    return AppNavigationPath(
      from: json['from'] as String,
      to: json['to'] as String,
      steps: (json['steps'] as List? ?? const []).cast<String>(),
      sourceRefs: (json['source_refs'] as List? ?? const []).cast<String>(),
    );
  }
}

/// 설명이 필요한 기능을 위한 매뉴얼/FAQ 항목.
///
/// `content`는 앱에 실제로 있는 텍스트(예: 튜토리얼 다이얼로그 문구)를
/// 그대로 옮긴 것이거나, 그런 원문이 없다면 이 목록에 넣지 않는다 — 상담사가
/// 지어낸 설명을 사용자 가이드로 제공하지 않는다.
class AppManualEntry {
  final String knowledgeId;
  final String title;
  final String content;
  final List<String> relatedFeatures;
  final List<String> sourceRefs;

  const AppManualEntry({
    required this.knowledgeId,
    required this.title,
    required this.content,
    this.relatedFeatures = const [],
    this.sourceRefs = const [],
  });

  factory AppManualEntry.fromJson(Map<String, dynamic> json) {
    return AppManualEntry(
      knowledgeId: json['knowledge_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      relatedFeatures:
          (json['related_features'] as List? ?? const []).cast<String>(),
      sourceRefs: (json['source_refs'] as List? ?? const []).cast<String>(),
    );
  }
}
