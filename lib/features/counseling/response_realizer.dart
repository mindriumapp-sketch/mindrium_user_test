import 'package:gad_app_team/data/counseling/counseling_models.dart';

import 'turn_plan.dart';

enum RealizationSource { deterministic, localLlm, remoteLlm }

/// Planner와 문장 생성 구현 사이의 고정 계약.
///
/// Remote API가 추가되더라도 상담 정책은 이 객체 이전에서 이미 확정되어야 한다.
/// Realizer는 허용된 사실과 문장을 표현할 뿐, CBT 기법이나 다음 질문을 고르지 않는다.
class RealizationRequest {
  final String deterministicDraft;
  final String reflectionTarget;
  final String questionGoal;
  final DialogueAct requiredAct;

  /// [requiredAct] 대신 realizer가 골라도 되는 후보. 비어 있으면 선택권이
  /// 없다는 뜻이고, realizer는 항상 [requiredAct]로만 응답해야 한다.
  /// docs/counseling/chatbot_system.md 4절 참고.
  final List<DialogueAct> allowedActs;
  final String? affect;
  final String tone;
  final RetrievalSummary retrievalSummary;
  final List<CounselingMessage> recentConversation;
  final List<CbtKnowledgeItem> allowedCbtFacts;
  final List<String> forbiddenBehaviors;

  /// Phase 10.3: the two legacy per-sentence strings `deterministicDraft`
  /// is concatenated from (`CounselingTurnPlan.reflectionSentence` /
  /// `.questionSentence`), kept available separately so a realizer can
  /// reuse the (unchanged, already-approved) question wording on its own
  /// without having to re-split `deterministicDraft`.
  final String reflectionSentenceRaw;
  final String questionSentenceRaw;

  /// Phase 10.2's semantic realization contract for this turn, when the
  /// plan is one `TurnPlanMaterializer` built (`null` for plans from the
  /// legacy `Deterministic*TurnPlanner` classes). A realizer that doesn't
  /// understand this field can and should ignore it and fall back to
  /// [deterministicDraft] — see `DeterministicResponseRealizer` (always
  /// does) and `SemanticDeterministicResponseRealizer` (does so only when
  /// this is `null`).
  final CounselingRealizationSpec? realizationSpec;

  const RealizationRequest({
    required this.deterministicDraft,
    required this.reflectionTarget,
    required this.questionGoal,
    required this.requiredAct,
    required this.retrievalSummary,
    this.allowedActs = const [],
    this.affect,
    this.tone = 'warm, calm, concise',
    this.recentConversation = const [],
    this.allowedCbtFacts = const [],
    this.forbiddenBehaviors = const [],
    this.reflectionSentenceRaw = '',
    this.questionSentenceRaw = '',
    this.realizationSpec,
  });

  factory RealizationRequest.fromPlan({
    required CounselingTurnPlan plan,
    required RetrievalSummary retrievalSummary,
    List<CounselingMessage> recentConversation = const [],
    List<CbtKnowledgeItem> allowedCbtFacts = const [],
    String? affect,
    String tone = 'warm, calm, concise',
  }) {
    return RealizationRequest(
      deterministicDraft: plan.deterministicReply,
      reflectionTarget: plan.reflectionTarget,
      questionGoal: plan.questionGoal,
      requiredAct: plan.requiredAct,
      allowedActs: plan.allowedActsForTurn,
      affect: affect,
      tone: tone,
      retrievalSummary: retrievalSummary,
      recentConversation: recentConversation,
      allowedCbtFacts: allowedCbtFacts,
      forbiddenBehaviors: plan.forbidden,
      reflectionSentenceRaw: plan.reflectionSentence,
      questionSentenceRaw: plan.questionSentence,
      realizationSpec: plan.realizationSpec,
    );
  }
}

class RealizationValidationResult {
  final bool isValid;
  final List<String> violations;

  const RealizationValidationResult({
    required this.isValid,
    this.violations = const [],
  });

  static const valid = RealizationValidationResult(isValid: true);
}

class RealizationResult {
  final String reply;
  final RealizationSource source;
  final Duration latency;
  final RealizationValidationResult validationResult;

  /// realizer가 실제로 표현한 발화 행위. [RealizationRequest.allowedActs]가
  /// 비어 있었다면 항상 [RealizationRequest.requiredAct]와 같다.
  final DialogueAct chosenAct;

  /// Phase 10.6B: which model/prompt version actually produced [reply],
  /// when [source] is `remoteLlm` and the backend reported one — `null`
  /// for `deterministic`/`localLlm`, and `null` whenever the realizer
  /// failed before getting a response body. Additive telemetry field only;
  /// no existing caller reads this yet.
  final String? modelIdentifier;
  final String? promptVersion;

  const RealizationResult({
    required this.reply,
    required this.source,
    required this.latency,
    required this.validationResult,
    required this.chosenAct,
    this.modelIdentifier,
    this.promptVersion,
  });
}

abstract interface class ResponseRealizer {
  Future<RealizationResult> realize(RealizationRequest request);
}

/// 현재 제품 기본값. Planner가 완성한 문장을 그대로 사용한다.
class DeterministicResponseRealizer implements ResponseRealizer {
  const DeterministicResponseRealizer();

  @override
  Future<RealizationResult> realize(RealizationRequest request) async {
    return RealizationResult(
      reply: request.deterministicDraft,
      source: RealizationSource.deterministic,
      latency: Duration.zero,
      validationResult: RealizationValidationResult.valid,
      chosenAct: request.requiredAct,
    );
  }
}
