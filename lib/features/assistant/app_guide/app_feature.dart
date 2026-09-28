/// 사용자가 "MindRium에서 무엇을 할 수 있는가?"를 물었을 때 참고할 기능 단위.
///
/// 모든 필드는 실제 production Flutter 코드에서 확인한 값이다 —
/// [sourceRefs]가 그 근거(파일 경로, 필요하면 `#메서드명`)를 남긴다. 존재를
/// 확인하지 못한 기능은 이 목록에 추가하지 않는다(Phase 6 핵심 원칙).
class AppFeature {
  final String featureId;
  final String name;
  final List<String> aliases;
  final String description;
  final bool available;
  final List<String> relatedScreens;
  final List<String> sourceRefs;

  const AppFeature({
    required this.featureId,
    required this.name,
    this.aliases = const [],
    required this.description,
    this.available = true,
    this.relatedScreens = const [],
    this.sourceRefs = const [],
  });

  factory AppFeature.fromJson(Map<String, dynamic> json) {
    return AppFeature(
      featureId: json['feature_id'] as String,
      name: json['name'] as String,
      aliases: (json['aliases'] as List? ?? const []).cast<String>(),
      description: json['description'] as String? ?? '',
      available: json['available'] as bool? ?? true,
      relatedScreens:
          (json['related_screens'] as List? ?? const []).cast<String>(),
      sourceRefs: (json['source_refs'] as List? ?? const []).cast<String>(),
    );
  }
}
