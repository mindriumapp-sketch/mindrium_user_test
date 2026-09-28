import 'app_feature.dart';
import 'app_navigation.dart';
import 'app_screen.dart';

/// MindRium 앱 사용 지식(기능/화면/내비게이션/매뉴얼)의 source of truth.
///
/// `CbtKnowledgeRepository`(상담 지식)와 같은 역할을 앱 가이드 도메인에서
/// 맡는다 — [LocalAppGuideKnowledgeRetriever]가 검색 로직 없이 순수 저장소
/// 접근만 이 인터페이스에 맡긴다.
abstract class AppGuideRepository {
  Future<void> initialize();

  List<AppFeature> get features;
  List<AppScreen> get screens;
  List<AppNavigationPath> get navigationPaths;
  List<AppManualEntry> get manualEntries;
}
