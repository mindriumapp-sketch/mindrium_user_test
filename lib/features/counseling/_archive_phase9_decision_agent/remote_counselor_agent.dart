import 'package:dio/dio.dart';
import 'package:gad_app_team/features/assistant/retrieval/personal_context_summary.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_agent.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';

import 'counseling_decide_api.dart';
import 'remote_counselor_request.dart';
import 'remote_counselor_response.dart';

/// Distinguishes exactly why a remote decide call failed, so callers/tests
/// can tell timeout apart from a 5xx apart from a malformed body — mirrors
/// the categories `RemoteLlmRealizer` folds into `request_failed`, but kept
/// separate here since nothing in this phase silently swallows them into a
/// deterministic fallback yet (that wiring is Phase 9.2's job).
enum RemoteCounselorFailureKind {
  timeout,
  networkError,
  httpError,
  emptyResponse,
  malformedResponse,
}

class RemoteCounselorFailure implements Exception {
  final RemoteCounselorFailureKind kind;
  final String message;

  const RemoteCounselorFailure(this.kind, this.message);

  @override
  String toString() => 'RemoteCounselorFailure(${kind.name}): $message';
}

/// Phase 9.2A.1: [RemoteCounselorAgent.decideAsync]'s successful result,
/// pairing the actual [decision] with reproducibility metadata
/// (model/prompt/token counts) the backend returned alongside it. The
/// metadata is never part of the decision's selection semantics — it exists
/// so shadow-evaluation logs can be replayed/interpreted later.
class RemoteCounselorDecisionOutcome {
  final CounselorDecision decision;
  final String? modelIdentifier;
  final String? promptVersion;
  final int? inputTokens;
  final int? outputTokens;

  const RemoteCounselorDecisionOutcome({
    required this.decision,
    this.modelIdentifier,
    this.promptVersion,
    this.inputTokens,
    this.outputTokens,
  });
}

/// Phase 9.1: a [CounselorAgent] backed by `POST /counseling/decide`.
///
/// **Not wired into production or shadow evaluation this phase.** Nothing in
/// `PolicyPipelineTurnPlanner`/`CounselingHarness` constructs or calls this
/// class — it exists purely as a contract/parser/backend-boundary
/// implementation so Phase 9.2 can wire it in without redesigning the
/// request/response shape.
///
/// This agent only SELECTS (action/goal/intervention/reflection target). It
/// never drafts reply text and must never be combined with
/// `ResponseRealizer`/`RemoteLlmRealizer`.
///
/// [CounselorAgent.decide] stays synchronous per the shared interface, but a
/// real network call cannot be synchronous in Dart — so [decide] is not the
/// entry point for actual remote calls in this phase. It throws
/// [UnsupportedError] to make that explicit rather than silently doing
/// nothing useful. The real, testable behavior lives in [decideAsync].
/// (Widening [CounselorAgent.decide] itself to `Future<CounselorDecision>`
/// would cascade into `CounselingTurnPlanner.plan()` and therefore
/// `CounselingHarness` — out of scope while this agent isn't wired to any
/// caller yet; Phase 9.2, which actually invokes this agent, is the right
/// place to make that interface decision.)
class RemoteCounselorAgent implements CounselorAgent {
  final CounselingDecideApi api;
  final int recentConversationWindow;
  final int maxKnowledgeItems;

  const RemoteCounselorAgent({
    required this.api,
    this.recentConversationWindow = 2,
    this.maxKnowledgeItems = 5,
  });

  @override
  CounselorDecision decide({
    required PolicyBoundaryRequest context,
    required PolicyBoundary policy,
  }) {
    throw UnsupportedError(
      'RemoteCounselorAgent.decide() is not usable synchronously — use '
      'decideAsync(). This agent is not wired into any production/sync '
      'call path in Phase 9.1.',
    );
  }

  /// The real (async) entry point. Builds a privacy-minimized
  /// [RemoteCounselorRequest] from [personalContext] (never raw diary/
  /// transcript data), calls `POST /counseling/decide`, and fail-closed
  /// parses the result into a [CounselorDecision].
  ///
  /// Throws [RemoteCounselorFailure] for every failure mode — timeout,
  /// network error, 4xx/5xx, empty body, or malformed/unexpected JSON. Never
  /// returns a guessed decision.
  Future<RemoteCounselorDecisionOutcome> decideAsync({
    required PolicyBoundaryRequest context,
    required PolicyBoundary policy,
    required PersonalContextSummary personalContext,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final request = buildRemoteCounselorRequest(
      context: context,
      policy: policy,
      personalContext: personalContext,
      recentConversationWindow: recentConversationWindow,
      maxKnowledgeItems: maxKnowledgeItems,
    );

    Map<String, dynamic> data;
    try {
      data = await api.decide(
        requestBody: request.toJson(),
        timeout: timeout,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw RemoteCounselorFailure(
          RemoteCounselorFailureKind.timeout,
          e.message ?? 'timeout',
        );
      }
      final status = e.response?.statusCode;
      if (status != null) {
        throw RemoteCounselorFailure(
          RemoteCounselorFailureKind.httpError,
          'status=$status',
        );
      }
      throw RemoteCounselorFailure(
        RemoteCounselorFailureKind.networkError,
        e.message ?? 'network error',
      );
    }

    if (data.isEmpty) {
      throw const RemoteCounselorFailure(
        RemoteCounselorFailureKind.emptyResponse,
        'empty /counseling/decide response body',
      );
    }

    try {
      final response = RemoteCounselorResponse.fromJson(data);
      return RemoteCounselorDecisionOutcome(
        decision: response.toCounselorDecision(),
        modelIdentifier: response.modelIdentifier,
        promptVersion: response.promptVersion,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
      );
    } on RemoteCounselorParseException catch (e) {
      throw RemoteCounselorFailure(
        RemoteCounselorFailureKind.malformedResponse,
        e.reason,
      );
    }
  }
}
