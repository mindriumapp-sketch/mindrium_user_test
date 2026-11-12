part of 'counseling_harness.dart';

/// Phase 14.X: outcome of one LLM-led attempt. [status]: success | safety |
/// timeout | http_error | schema_reject | rejected (validator).
class LlmLedTurn {
  final CounselingTurnResult? result;
  final String status;
  final int? latencyMs;
  final LlmLedOutput? output;
  final List<String> violations;

  /// Error detail for http_error (status code / backend reason; no user text).
  final String? detail;

  /// The classified transport/API failure, when the call did not answer.
  final CounselingRespondFailure? failure;

  /// success | the failure's request status | 'success' also for a reply the
  /// validator rejected (the request itself succeeded).
  String get requestStatus => failure?.requestStatus ?? 'success';

  /// direct (B shown) | content_fallback (B answered, rejected) |
  /// transport_fallback (no usable answer) | safety.
  String get group => switch (status) {
        'success' => 'direct',
        'safety' => 'safety',
        'rejected' || 'schema_reject' => 'content_fallback',
        _ => 'transport_fallback',
      };

  /// The most serious validator reason (grounding and safety first).
  String? get primaryRejection {
    if (violations.isEmpty) return null;
    for (final r in _rejectionPriority) {
      if (violations.contains(r)) return r;
    }
    return violations.first;
  }

  static const _rejectionPriority = [
    'definition_mismatch', 'unknown_term_defined', 'definition_without_request', 'recall_not_stated',
    'unauthorized_intervention', 'prompt_without_intervention', 'integration_without_prompt',
    'unsupported_user_fact', 'unsupported_app_fact', 'app_claim_without_fact',
    'diagnosis', 'outcome_guarantee', 'directive', 'advice', 'premature_example', 'finalize_without_proposal',
    'question_after_no_question_promise', 'too_many_questions', 'question_shape',
    'repeated_question', 'repeated_reply', 'exploring_after_closed', 'banmal_reply', 'second_person', 'too_long',
  ];

  const LlmLedTurn({
    this.result,
    required this.status,
    this.latencyMs,
    this.output,
    this.violations = const [],
    this.detail,
    this.failure,
    this.timing = const {},
  });

  /// Latency breakdown (ms): context build, request (network + model), model
  /// alone (backend-reported), validation; plus prompt tokens.
  final Map<String, int?> timing;
}
