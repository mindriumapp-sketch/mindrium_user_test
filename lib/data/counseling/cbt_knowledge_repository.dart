import 'counseling_models.dart';

/// 승인된 CBT 지식에 접근하는 유일한 경로.
///
/// Step 1 은 키워드/태그 기반 구현만 둔다. Step 5 에서 임베딩 검색으로 바꾸더라도
/// harness 는 이 인터페이스만 알면 되도록 유지한다.
abstract class CbtKnowledgeRepository {
  /// 코퍼스를 메모리에 올린다. 이미 로드했다면 아무 일도 하지 않는다.
  Future<void> initialize();

  /// 해당 주차의 항목. week 0 은 프로그램 공통 지식이다.
  List<CbtKnowledgeItem> getByWeek(int week);

  /// 질의와 관련된 항목을 점수 순으로 돌려준다.
  List<CbtKnowledgeItem> search({
    required String query,
    int? week,
    Set<String>? tags,
    int limit = 5,
  });

  CbtKnowledgeItem? getById(String id);

  /// 로드된 모든 항목의 id. harness 의 provenance 검증에 쓴다.
  Set<String> get allIds;
}
