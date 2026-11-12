part of 'llm_led_contract.dart';

/// The model's answer (backend `output`).
class LlmLedOutput {
  final String domain;
  final List<String> moves;
  final String? interventionId;
  final String? interventionStep;
  final List<String> usedUserFactIds;
  final List<String> usedAppFactIds;
  final String? definitionId;
  final String sessionAction;
  final String statement;
  final String? question;

  /// What the user sees: the statement, then the one question if any.
  String get text => question == null ? statement : '$statement $question';

  const LlmLedOutput({
    required this.domain,
    required this.moves,
    required this.interventionId,
    required this.interventionStep,
    required this.usedUserFactIds,
    required this.usedAppFactIds,
    this.definitionId,
    required this.sessionAction,
    required this.statement,
    required this.question,
  });

  /// Null when the shape or an enum is off (respond_v2 shape: statement +
  /// optional single question; intervention as one {id, step} object).
  static LlmLedOutput? tryParse(Object? json) {
    if (json is! Map) return null;
    final moves = json['dialogue_moves'];
    final userIds = json['used_user_fact_ids'];
    final appIds = json['used_app_fact_ids'];
    final statement = json['statement'];
    final question = json['question'];
    final iv = json['intervention'];
    if (!_domains.contains(json['domain']) ||
        !_sessionActions.contains(json['session_action']) ||
        moves is! List ||
        moves.isEmpty ||
        !moves.every(_moves.contains) ||
        userIds is! List ||
        appIds is! List ||
        statement is! String ||
        statement.trim().isEmpty ||
        (question != null && question is! String) ||
        (iv != null &&
            (iv is! Map ||
                iv['id'] is! String ||
                (iv['step'] != 'prompt' && iv['step'] != 'integration')))) {
      return null;
    }
    final q = (question as String?)?.trim();
    return LlmLedOutput(
      domain: json['domain'] as String,
      moves: moves.cast<String>(),
      interventionId: iv == null ? null : (iv as Map)['id'] as String,
      interventionStep: iv == null ? null : (iv as Map)['step'] as String,
      usedUserFactIds: userIds.whereType<String>().toList(),
      usedAppFactIds: appIds.whereType<String>().toList(),
      definitionId:
          json['definition_id'] is String
              ? json['definition_id'] as String
              : null,
      sessionAction: json['session_action'] as String,
      statement: statement.trim(),
      question: q == null || q.isEmpty ? null : q,
    );
  }
}
