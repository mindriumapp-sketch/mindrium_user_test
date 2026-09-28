import '../../../../data/counseling/counseling_models.dart';
import '../../../../data/counseling/retrieval_summary.dart';
import '../../counseling_state.dart';
import '../../intervention_registry.dart';
import '../policy_boundary_request.dart';

/// Phase 9.2B: shared construction helpers for `frozen_scenarios_*.dart`.
///
/// Reuses the same fixture-building patterns as
/// `test/counseling/counselor_decision_materializer_invariant_test.dart`
/// (`_cbtItem`, `_diaryContext`) and the phase8 equivalence tests, rather
/// than inventing new shapes for `CbtKnowledgeItem` / `MindriumCounselingContext`
/// / `CounselingMessage`.
CbtKnowledgeItem cbtItem({
  required String id,
  int week = 4,
  String type = 'technique',
  List<String> tags = const ['alternative_thought', 'cognitive_restructuring'],
  bool guidance = true,
}) => CbtKnowledgeItem(
  id: id,
  week: week,
  type: type,
  title: id,
  paragraphs: const ['검증용 문단'],
  tags: tags,
  source: 'test',
  conversationalGuidanceAvailable: guidance,
);

MindriumCounselingContext diaryContext({
  required String text,
  int week = 4,
  int sud = 7,
  String diaryId = 'diary:abc123',
}) => MindriumCounselingContext(
  currentWeek: week,
  relevantItems: [
    UserContextItem(
      id: diaryId,
      type: UserContextType.diary,
      text: text,
      occurredAt: DateTime(2026, 9, 1),
      sud: sud,
    ),
  ],
);

MindriumCounselingContext effectiveInterventionContext({
  required String label,
  int week = 8,
  int preSud = 8,
  int postSud = 3,
  String id = 'intervention:eff1',
}) => MindriumCounselingContext(
  currentWeek: week,
  relevantItems: const [],
  effectiveInterventions: [
    EffectiveIntervention(
      id: id,
      type: 'relaxation',
      label: label,
      preSud: preSud,
      postSud: postSud,
    ),
  ],
);

CounselingMessage assistantGoalMessage(String goalName, {String? id}) =>
    CounselingMessage(
      id: id ?? 'a_$goalName',
      role: 'assistant',
      text: 'goal:$goalName',
      createdAt: DateTime(2026, 9, 1),
      dialogueGoalId: goalName,
    );

CounselingMessage userMessage(String text, {required String id}) =>
    CounselingMessage(
      id: id,
      role: 'user',
      text: text,
      createdAt: DateTime(2026, 9, 1),
    );

CounselingMessage assistantMessage(String text, {required String id}) =>
    CounselingMessage(
      id: id,
      role: 'assistant',
      text: text,
      createdAt: DateTime(2026, 9, 1),
    );

const ApprovedInterventionRegistry defaultRegistry =
    ApprovedInterventionRegistry();

PolicyBoundaryRequest boundaryRequest({
  required CounselingState state,
  required String userMessage,
  MindriumCounselingContext? userContext,
  List<CounselingMessage> recentMessages = const [],
  int currentWeek = 4,
  ApprovedInterventionRegistry registry = defaultRegistry,
  List<CbtKnowledgeItem> knowledge = const [],
}) => PolicyBoundaryRequest(
  currentState: state,
  userMessage: userMessage,
  userContext: userContext,
  recentMessages: recentMessages,
  currentWeek: currentWeek,
  interventionRegistry: registry,
  knowledge: knowledge,
  retrievalSummary: RetrievalSummary.empty,
);
