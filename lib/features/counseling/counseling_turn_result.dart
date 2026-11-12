part of 'counseling_harness.dart';

/// `handleTurn()`이 CBT 검색과 `RetrievalSummary` 계산을 다시 하지 않도록
/// 미리 계산해 넘기는 값. `MindRiumAssistantHarness`가 이미 같은 조회를
/// 끝냈을 때만 채운다 — Phase 5(Personal Context v2 + Precomputed Context
/// Bridge)에서 두 경로(assistant 계층/harness 내부)가 같은 retrieval을
/// 중복 계산하던 문제를 없애기 위한 다리다.
///
/// `null`이면(기존 `CounselingHarness`를 직접 생성해 쓰는 모든 호출부·
/// 테스트) 이전과 완전히 동일하게 harness가 직접 조회한다 — 이 필드가
/// 생기기 전의 동작을 그대로 보존한다.
class PrecomputedTurnContext {
  final List<CbtKnowledgeItem> knowledge;
  final RetrievalSummary retrievalSummary;

  const PrecomputedTurnContext({
    required this.knowledge,
    required this.retrievalSummary,
  });
}

/// 한 턴을 처리한 결과.
class CounselingTurnResult {
  final CounselingMessage assistantMessage;

  /// 이번 턴에 planner가 확정한 행동 계획. planning 미적용/안전 턴이면 null이다.
  final CounselingTurnPlan? turnPlan;

  /// 이번 턴을 어떻게 실현하기로 했는지.
  final TurnRoutingDecision? routing;

  /// 최종 사용자 문장을 만든 구현. 향후 D/local/remote 비교의 기준이다.
  final RealizationSource realizationSource;

  /// 이번 턴의 응답을 구성하는 데 실제로 사용한 사용자 기록 id.
  ///
  /// 모델이 "인용했다고 신고한" id(`referencedUserContextIds`)와 다르다.
  /// 이쪽은 harness 가 무엇을 근거로 문장을 만들었는지의 기록이다.
  final List<String> retrievalProvenanceIds;

  /// 턴이 끝난 뒤의 상태.
  final CounselingState state;
  final SafetyResult safety;

  /// 안전 관문에 걸려 모델을 호출하지 않았는지.
  final bool handledBySafety;

  /// harness 가 사용자에게 제안하는 앱 동작. 모델이 정하지 않는다.
  final CounselingUiAction? uiAction;

  final String promptVersion;

  /// 턴 시작 시점의 상태. 전이가 일어났는지 보려면 [state] 와 비교한다.
  final CounselingState stateBefore;

  /// 이번 턴에 프롬프트로 제공한 근거 id 수.
  ///
  /// 모델이 실제로 인용한 수(assistantMessage.referenced*)와 함께 보면
  /// 문제가 retrieval 인지, 프롬프트인지, 모델이 근거를 무시한 것인지 구분된다.
  final int offeredCbtIdCount;
  final int offeredUserContextIdCount;

  /// GPT가 [turnPlan]의 requiredAct 대신 allowedActsForTurn 안의 다른 행위를
  /// 선택했고, 그 선택이 실제로 채택됐는지. Adaptive Dialogue Policy Phase 1
  /// 선택 분포를 벤치마크로 확인하기 위한 필드다.
  final bool actChosenByModel;

  const CounselingTurnResult({
    required this.assistantMessage,
    required this.state,
    required this.stateBefore,
    required this.safety,
    required this.handledBySafety,
    required this.promptVersion,
    this.turnPlan,
    this.uiAction,
    this.offeredCbtIdCount = 0,
    this.offeredUserContextIdCount = 0,
    this.retrievalProvenanceIds = const [],
    this.routing,
    this.realizationSource = RealizationSource.deterministic,
    this.actChosenByModel = false,
  });
}

/// 앱 동작 제안. LLM 출력이 아니라 harness 정책에서 나온다.
/// 이번 턴에 **추천**하는 앱 활동.
///
/// 화면 이동 명령이 아니다. 상담은 활동을 알려줄 뿐이고, 수행 여부와 시점은
/// 사용자가 앱에서 스스로 정한다. **추천했다는 사실이 수행했다는 뜻은 아니다.**
/// 수행 여부는 서버 기록에 실제로 남았을 때만 인정한다.
typedef CounselingUiAction = CounselingActivity;
