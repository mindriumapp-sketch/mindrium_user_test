import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';

/// Thrown by [RemoteCounselorResponse.fromJson] on any malformed/unexpected
/// input. Parsing is **fail-closed**: no guessing, no lenient fallback — an
/// unparseable response must never silently become a plausible-looking
/// [CounselorDecision]. Callers (`RemoteCounselorAgent`) catch this and treat
/// it exactly like a network failure (fall back to the deterministic agent).
class RemoteCounselorParseException implements Exception {
  final String reason;

  const RemoteCounselorParseException(this.reason);

  @override
  String toString() => 'RemoteCounselorParseException: $reason';
}

/// Wire-shape mirror of [ReflectionTarget]. Parsed strictly: `type` must be
/// exactly `text` (with a non-null `text` field) or exactly `none` — any
/// other value, or a missing `type`, is a parse failure.
sealed class RemoteReflectionTarget {
  const RemoteReflectionTarget();

  static RemoteReflectionTarget fromJson(Object? json) {
    if (json is! Map) {
      throw const RemoteCounselorParseException(
        'reflectionTarget must be an object',
      );
    }
    final type = json['type'];
    if (type == 'text') {
      final text = json['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const RemoteCounselorParseException(
          'reflectionTarget.text must be a non-empty string when type=text',
        );
      }
      return RemoteReflectionTargetText(text);
    }
    if (type == 'none') {
      return const RemoteReflectionTargetNone();
    }
    throw RemoteCounselorParseException(
      'reflectionTarget.type must be "text" or "none", got: $type',
    );
  }
}

final class RemoteReflectionTargetText extends RemoteReflectionTarget {
  final String text;
  const RemoteReflectionTargetText(this.text);
}

final class RemoteReflectionTargetNone extends RemoteReflectionTarget {
  const RemoteReflectionTargetNone();
}

/// Parsed, strictly-validated response from `POST /counseling/decide`.
///
/// Expected wire shape:
/// ```json
/// {
///   "selectedAction": "openQuestion",
///   "selectedGoalId": "alternative_perspective",
///   "selectedInterventionId": null,
///   "reflectionTarget": { "type": "text", "text": "..." }
/// }
/// ```
/// `reflectionTarget` may be omitted entirely (or explicitly `null`) to mean
/// "this turn is entirely unavailable" — mapped to
/// [CounselorDecision.reflectionTarget] `null` / `isUnavailable: true`.
class RemoteCounselorResponse {
  /// Phase 9.2D (`decide_v2`): explicit outcome discriminator, closing the
  /// gap the real `phase9_2b_frozen_v1`/`decide_v1` evaluation run found —
  /// when `policy.allowedActions` is empty, no `DialogueAct` selection is
  /// possible at all, and `decide_v1` had no way for the model to say so
  /// (it invented `"selectedAction": "none"`, which fail-closed parsing
  /// correctly rejected as unknown). `status` defaults to `true` (selected)
  /// when absent, for backward compatibility with pre-v2 response shapes
  /// that never set it.
  final bool isUnavailableOutcome;

  final DialogueAct selectedAction;
  final String? selectedGoalId;
  final String? selectedInterventionId;

  /// Null means "turn unavailable" (see class doc). Non-null distinguishes
  /// [RemoteReflectionTargetText] from [RemoteReflectionTargetNone].
  final RemoteReflectionTarget? reflectionTarget;

  /// Phase 9.2A.1: reproducibility metadata, not part of the decision
  /// contract — always optional, never fail-closed. The backend fills
  /// [modelIdentifier]/[promptVersion] whenever it can reach the point of
  /// returning a decision at all; token counts are best-effort and may be
  /// absent even on success.
  final String? modelIdentifier;
  final String? promptVersion;
  final int? inputTokens;
  final int? outputTokens;

  const RemoteCounselorResponse({
    required this.selectedAction,
    required this.selectedGoalId,
    required this.selectedInterventionId,
    required this.reflectionTarget,
    this.isUnavailableOutcome = false,
    this.modelIdentifier,
    this.promptVersion,
    this.inputTokens,
    this.outputTokens,
  });

  /// Phase 9.2D: the `status: "unavailable"` outcome — no [DialogueAct] was
  /// selectable at all (mirrors `policy.allowedActions.isEmpty`). Carries no
  /// action/goal/intervention/reflectionTarget; those fields are
  /// meaningless for this outcome and [toCounselorDecision] ignores them.
  const RemoteCounselorResponse.unavailable({
    this.modelIdentifier,
    this.promptVersion,
    this.inputTokens,
    this.outputTokens,
  }) : isUnavailableOutcome = true,
       selectedAction = DialogueAct.unknown,
       selectedGoalId = null,
       selectedInterventionId = null,
       reflectionTarget = null;

  /// Fail-closed parse: throws [RemoteCounselorParseException] on anything
  /// that isn't exactly the expected shape. Never guesses a "best effort"
  /// decision from a malformed payload.
  factory RemoteCounselorResponse.fromJson(Object? json) {
    if (json is! Map) {
      throw const RemoteCounselorParseException('response must be a JSON object');
    }

    // Phase 9.2D (decide_v2): explicit "no action is selectable" outcome.
    // `status` defaults to implicit "selected" when absent (backward
    // compatible with the decide_v1 wire shape replayed from the frozen_v1
    // evaluation run) — any value other than "unavailable"/"selected" is a
    // parse failure, not silently ignored.
    final statusRaw = json['status'];
    if (statusRaw != null) {
      if (statusRaw is! String ||
          (statusRaw != 'unavailable' && statusRaw != 'selected')) {
        throw RemoteCounselorParseException('unknown status: $statusRaw');
      }
      if (statusRaw == 'unavailable') {
        final modelIdentifierRaw = json['modelIdentifier'];
        final promptVersionRaw = json['promptVersion'];
        final inputTokensRaw = json['inputTokens'];
        final outputTokensRaw = json['outputTokens'];
        return RemoteCounselorResponse.unavailable(
          modelIdentifier: modelIdentifierRaw is String ? modelIdentifierRaw : null,
          promptVersion: promptVersionRaw is String ? promptVersionRaw : null,
          inputTokens: inputTokensRaw is int ? inputTokensRaw : null,
          outputTokens: outputTokensRaw is int ? outputTokensRaw : null,
        );
      }
    }

    if (!json.containsKey('selectedAction')) {
      throw const RemoteCounselorParseException('missing selectedAction');
    }
    final actionRaw = json['selectedAction'];
    if (actionRaw is! String) {
      throw const RemoteCounselorParseException('selectedAction must be a string');
    }
    final action = DialogueAct.fromWire(actionRaw);
    if (action == DialogueAct.unknown) {
      throw RemoteCounselorParseException(
        'unknown selectedAction: $actionRaw',
      );
    }

    final goalRaw = json['selectedGoalId'];
    if (goalRaw != null && goalRaw is! String) {
      throw const RemoteCounselorParseException(
        'selectedGoalId must be a string or null',
      );
    }

    final interventionRaw = json['selectedInterventionId'];
    if (interventionRaw != null && interventionRaw is! String) {
      throw const RemoteCounselorParseException(
        'selectedInterventionId must be a string or null',
      );
    }

    RemoteReflectionTarget? reflectionTarget;
    if (json.containsKey('reflectionTarget') &&
        json['reflectionTarget'] != null) {
      reflectionTarget = RemoteReflectionTarget.fromJson(
        json['reflectionTarget'],
      );
    }

    // Metadata is deliberately lenient: absent/wrong-typed values become
    // null rather than a parse failure — they're for logging, not selection.
    final modelIdentifierRaw = json['modelIdentifier'];
    final promptVersionRaw = json['promptVersion'];
    final inputTokensRaw = json['inputTokens'];
    final outputTokensRaw = json['outputTokens'];

    return RemoteCounselorResponse(
      selectedAction: action,
      selectedGoalId: goalRaw as String?,
      selectedInterventionId: interventionRaw as String?,
      reflectionTarget: reflectionTarget,
      modelIdentifier: modelIdentifierRaw is String ? modelIdentifierRaw : null,
      promptVersion: promptVersionRaw is String ? promptVersionRaw : null,
      inputTokens: inputTokensRaw is int ? inputTokensRaw : null,
      outputTokens: outputTokensRaw is int ? outputTokensRaw : null,
    );
  }

  /// Maps this wire-level response back onto [CounselorDecision], preserving
  /// the exact null/None/Text tri-state that [ReflectionTarget] models —
  /// this is not reduced back to a magic string anywhere in this mapping.
  CounselorDecision toCounselorDecision() {
    if (isUnavailableOutcome) {
      return const CounselorDecision(
        selectedAction: DialogueAct.unknown,
        isUnavailable: true,
      );
    }

    final target = reflectionTarget;
    final ReflectionTarget? mapped;
    if (target == null) {
      mapped = null;
    } else if (target is RemoteReflectionTargetNone) {
      mapped = const ReflectionTarget.none();
    } else if (target is RemoteReflectionTargetText) {
      mapped = ReflectionTarget.text(target.text);
    } else {
      // Unreachable: sealed class covers exactly the two cases above.
      throw const RemoteCounselorParseException('unhandled reflectionTarget');
    }

    return CounselorDecision(
      selectedAction: selectedAction,
      selectedGoalId: selectedGoalId,
      selectedInterventionId: selectedInterventionId,
      reflectionTarget: mapped,
      isUnavailable: target == null,
    );
  }
}
