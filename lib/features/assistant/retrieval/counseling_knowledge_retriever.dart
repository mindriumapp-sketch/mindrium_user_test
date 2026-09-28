import 'package:gad_app_team/data/counseling/cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';

/// [CounselingKnowledgeRetriever]에 넘기는 입력.
class CounselingKnowledgeRequest {
  final String query;
  final int? week;
  final Set<String>? tags;
  final int limit;

  const CounselingKnowledgeRequest({
    required this.query,
    this.week,
    this.tags,
    this.limit = 3,
  });
}

/// [CounselingKnowledgeRetriever]의 결과.
///
/// `ids`는 harness의 provenance 검증(제공하지 않은 id는 인용 취소)에 쓸 수
/// 있는 CBT id 목록이다. `degraded`는 이번 phase에서는 항상 false다 —
/// 현재 `CbtKnowledgeRepository.search()`는 실패를 던지지 않고 빈 결과를
/// 돌려주므로 구분할 성공/실패 신호가 아직 없다.
class CounselingKnowledgeResult {
  final List<CbtKnowledgeItem> items;
  final List<String> ids;
  final bool degraded;

  const CounselingKnowledgeResult({
    this.items = const [],
    this.ids = const [],
    this.degraded = false,
  });

  static const empty = CounselingKnowledgeResult();
}

/// "이 상황에서 어떤 CBT 지식을 쓸 수 있는가?"를 답하는 경계.
///
/// embedding/vector 검색은 이번 phase의 범위가 아니다 — 지금은 기존
/// `CbtKnowledgeRepository.search()`(키워드/태그 기반, 변경 없음) 앞에
/// interface만 씌운다.
abstract interface class CounselingKnowledgeRetriever {
  Future<CounselingKnowledgeResult> retrieve(
    CounselingKnowledgeRequest request,
  );
}

/// 현재 production이 쓰는 유일한 구현. `CbtKnowledgeRepository`(기존 코드,
/// 변경 없음)를 그대로 감싼다.
class LocalCbtKnowledgeAdapter implements CounselingKnowledgeRetriever {
  final CbtKnowledgeRepository repository;

  const LocalCbtKnowledgeAdapter({required this.repository});

  @override
  Future<CounselingKnowledgeResult> retrieve(
    CounselingKnowledgeRequest request,
  ) async {
    final items = repository.search(
      query: request.query,
      week: request.week,
      tags: request.tags,
      limit: request.limit,
    );

    return CounselingKnowledgeResult(
      items: items,
      ids: items.map((item) => item.id).toList(),
    );
  }
}
