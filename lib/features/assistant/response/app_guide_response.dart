/// App Guide 응답의 상태 분류.
enum AppGuideAnswerStatus {
  /// 실제 KB에 근거한 정보로 답할 수 있음.
  grounded,

  /// 질문은 앱 기능에 대한 것(intent)이지만 KB에 해당 정보가 없음.
  /// (예: "영상 통화 상담 어디서 해?" → appGuide intent, but no knowledge).
  noKnowledge,

  /// KB 로드 실패 등의 이유로 degraded 상태.
  degraded,
}

/// App Guide 응답 생성의 결과.
///
/// 모든 정보는 [AppGuideKnowledgeResult]에서만 생성되므로
/// sourceRefs를 통한 provenance가 보장된다.
class AppGuideResponse {
  final String text;
  final AppGuideAnswerStatus status;
  final List<String> sourceRefs;

  const AppGuideResponse({
    required this.text,
    required this.status,
    this.sourceRefs = const [],
  });
}
