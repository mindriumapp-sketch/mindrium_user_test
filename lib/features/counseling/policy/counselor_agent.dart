import 'counselor_decision.dart';
import 'policy_boundary.dart';
import 'policy_boundary_request.dart';

/// Phase 8.3: an agent that SELECTS within a [PolicyBoundary].
///
/// Reuses [PolicyBoundaryRequest] as the context type rather than inventing
/// a new one — it already carries userMessage, recentMessages, userContext,
/// knowledge, currentWeek, interventionRegistry and retrievalSummary, which
/// is everything the deterministic legacy selection logic needs.
abstract interface class CounselorAgent {
  CounselorDecision decide({
    required PolicyBoundaryRequest context,
    required PolicyBoundary policy,
  });
}
