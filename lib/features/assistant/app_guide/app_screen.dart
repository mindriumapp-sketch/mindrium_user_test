/// 실제 사용자에게 보이는 화면 하나.
///
/// `displayName`은 Dart 클래스 이름이 아니라 **화면에 실제로 표시되는
/// 한국어 이름**이다(예: 클래스는 `AlternativeThoughtArchivePage`여도 화면
/// 제목은 "지난 걱정 보기"일 수 있다) — Phase 6 조사 시 AppBar/타이틀 텍스트를
/// 직접 확인한 것만 담는다.
class AppScreen {
  final String screenId;
  final String displayName;
  final String description;
  final List<String> entryPoints;
  final List<String> availableActions;
  final List<String> sourceRefs;

  const AppScreen({
    required this.screenId,
    required this.displayName,
    this.description = '',
    this.entryPoints = const [],
    this.availableActions = const [],
    this.sourceRefs = const [],
  });

  factory AppScreen.fromJson(Map<String, dynamic> json) {
    return AppScreen(
      screenId: json['screen_id'] as String,
      displayName: json['display_name'] as String,
      description: json['description'] as String? ?? '',
      entryPoints: (json['entry_points'] as List? ?? const []).cast<String>(),
      availableActions:
          (json['available_actions'] as List? ?? const []).cast<String>(),
      sourceRefs: (json['source_refs'] as List? ?? const []).cast<String>(),
    );
  }
}
