// Phase 9.1: RemoteCounselorResponse fail-closed parsing + CounselorDecision
// mapping, and compatibility with the existing CounselorDecisionValidator.
import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision.dart';
import 'package:gad_app_team/features/counseling/policy/counselor_decision_validator.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/_archive_phase9_decision_agent/remote_counselor_response.dart';

void main() {
  group('RemoteCounselorResponse.fromJson — success cases', () {
    test('parses a normal action + goal, intervention null, ReflectionTargetText', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'socratic_question',
        'selectedGoalId': 'alternative',
        'selectedInterventionId': null,
        'reflectionTarget': {'type': 'text', 'text': '발표에서 실수할 것 같다는 생각'},
      });

      expect(response.selectedAction, DialogueAct.socraticQuestion);
      expect(response.selectedGoalId, 'alternative');
      expect(response.selectedInterventionId, isNull);
      final decision = response.toCounselorDecision();
      expect(decision.isUnavailable, isFalse);
      expect(decision.reflectionTarget, isA<ReflectionTargetText>());
      expect(
        (decision.reflectionTarget as ReflectionTargetText).value,
        '발표에서 실수할 것 같다는 생각',
      );
    });

    test('parses intervention id when present', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'socratic_question',
        'selectedGoalId': null,
        'selectedInterventionId': 'cbt-1',
        'reflectionTarget': {'type': 'none'},
      });

      expect(response.selectedInterventionId, 'cbt-1');
      final decision = response.toCounselorDecision();
      expect(decision.selectedInterventionId, 'cbt-1');
      expect(decision.reflectionTarget, isA<ReflectionTargetNone>());
    });

    test('reflectionTarget type=none maps to ReflectionTargetNone, not null', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'closing',
        'selectedGoalId': null,
        'selectedInterventionId': null,
        'reflectionTarget': {'type': 'none'},
      });
      final decision = response.toCounselorDecision();
      expect(decision.reflectionTarget, isA<ReflectionTargetNone>());
      expect(decision.isUnavailable, isFalse);
    });

    test('missing reflectionTarget field maps to null (turn entirely unavailable)', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'closing',
        'selectedGoalId': null,
        'selectedInterventionId': null,
      });
      expect(response.reflectionTarget, isNull);
      final decision = response.toCounselorDecision();
      expect(decision.reflectionTarget, isNull);
      expect(decision.isUnavailable, isTrue);
    });

    test('explicit reflectionTarget: null also maps to unavailable', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'closing',
        'selectedGoalId': null,
        'selectedInterventionId': null,
        'reflectionTarget': null,
      });
      expect(response.reflectionTarget, isNull);
      expect(response.toCounselorDecision().isUnavailable, isTrue);
    });
  });

  group('RemoteCounselorResponse.fromJson — fail-closed rejection', () {
    test('rejects malformed JSON shape (array instead of object)', () {
      expect(
        () => RemoteCounselorResponse.fromJson([1, 2, 3]),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });

    test('rejects unknown action string', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'selectedAction': 'totally_made_up_action',
          'reflectionTarget': {'type': 'none'},
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });

    test('rejects missing selectedAction field', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'reflectionTarget': {'type': 'none'},
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });

    test('rejects reflectionTarget with unknown type', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'selectedAction': 'closing',
          'reflectionTarget': {'type': 'maybe'},
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });

    test('rejects reflectionTarget type=text with missing text field', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'selectedAction': 'socratic_question',
          'reflectionTarget': {'type': 'text'},
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });

    test('rejects selectedGoalId that is not a string or null', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'selectedAction': 'socratic_question',
          'selectedGoalId': 42,
          'reflectionTarget': {'type': 'none'},
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });

    test('rejects reflectionTarget that is not an object', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'selectedAction': 'closing',
          'reflectionTarget': 'none',
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });
  });

  group('CounselorDecisionValidator compatibility (reuse, no new validator)', () {
    const validator = CounselorDecisionValidator();

    final policy = PolicyBoundary(
      currentState: CounselingState.reflect,
      allowedActions: const [DialogueAct.socraticQuestion],
      candidateGoalIds: const ['evidence', 'alternative'],
      eligibleInterventionIds: const [],
      allowedFactIds: const [],
      forbiddenConstraints: const [],
      progressInfo: DialogueProgressInfo.empty(),
    );

    test('a parsed decision with allowed action/goal validates OK', () {
      final decision = RemoteCounselorResponse.fromJson({
        'selectedAction': 'socratic_question',
        'selectedGoalId': 'evidence',
        'reflectionTarget': {'type': 'text', 'text': 'x'},
      }).toCounselorDecision();

      expect(validator.validate(decision: decision, policy: policy), isNull);
      expect(validator.isValid(decision: decision, policy: policy), isTrue);
    });

    test('a parsed decision with out-of-policy goal fails validation', () {
      final decision = RemoteCounselorResponse.fromJson({
        'selectedAction': 'socratic_question',
        'selectedGoalId': 'not_a_real_goal',
        'reflectionTarget': {'type': 'text', 'text': 'x'},
      }).toCounselorDecision();

      final violation = validator.validate(decision: decision, policy: policy);
      expect(violation, isNotNull);
      expect(violation, contains('not_a_real_goal'));
    });

    test('a parsed decision with out-of-policy action fails validation', () {
      final decision = RemoteCounselorResponse.fromJson({
        'selectedAction': 'closing',
        'reflectionTarget': {'type': 'none'},
      }).toCounselorDecision();

      expect(validator.validate(decision: decision, policy: policy), isNotNull);
    });
  });

  group('Phase 9.2A.1: reproducibility metadata (lenient, non-fail-closed)', () {
    test('modelIdentifier/promptVersion/token fields are parsed when present', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'socratic_question',
        'reflectionTarget': {'type': 'none'},
        'modelIdentifier': 'gpt-4o-2024-08-06',
        'promptVersion': 'decide_v1',
        'inputTokens': 321,
        'outputTokens': 42,
      });

      expect(response.modelIdentifier, 'gpt-4o-2024-08-06');
      expect(response.promptVersion, 'decide_v1');
      expect(response.inputTokens, 321);
      expect(response.outputTokens, 42);
    });

    test('missing/wrong-typed metadata becomes null, never a parse failure', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'socratic_question',
        'reflectionTarget': {'type': 'none'},
        'inputTokens': 'not-a-number',
      });

      expect(response.modelIdentifier, isNull);
      expect(response.promptVersion, isNull);
      expect(response.inputTokens, isNull);
      expect(response.outputTokens, isNull);
    });
  });

  group('Phase 9.2D: status="unavailable" (decide_v2)', () {
    test('parses to an isUnavailable CounselorDecision', () {
      final response = RemoteCounselorResponse.fromJson({
        'status': 'unavailable',
        'modelIdentifier': 'gpt-4o-mini',
        'promptVersion': 'decide_v2',
      });

      expect(response.isUnavailableOutcome, isTrue);
      final decision = response.toCounselorDecision();
      expect(decision.isUnavailable, isTrue);
      expect(decision.selectedAction, DialogueAct.unknown);
    });

    test('status="selected" (explicit) parses the normal shape', () {
      final response = RemoteCounselorResponse.fromJson({
        'status': 'selected',
        'selectedAction': 'closing',
        'reflectionTarget': {'type': 'none'},
      });

      expect(response.isUnavailableOutcome, isFalse);
      expect(response.selectedAction, DialogueAct.closing);
    });

    test('missing status defaults to "selected" (backward compatible '
        'with pre-v2/decide_v1 response shapes)', () {
      final response = RemoteCounselorResponse.fromJson({
        'selectedAction': 'explore',
        'reflectionTarget': {'type': 'text', 'text': 'x'},
      });

      expect(response.isUnavailableOutcome, isFalse);
    });

    test('unknown status value is a parse failure, not silently ignored', () {
      expect(
        () => RemoteCounselorResponse.fromJson({
          'status': 'something_else',
          'selectedAction': 'explore',
        }),
        throwsA(isA<RemoteCounselorParseException>()),
      );
    });
  });
}
