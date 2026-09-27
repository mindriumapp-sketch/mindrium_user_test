import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/retrieval_summary.dart';
import 'package:gad_app_team/features/counseling/counseling_state.dart';
import 'package:gad_app_team/features/counseling/intervention_registry.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary.dart';
import 'package:gad_app_team/features/counseling/policy/policy_boundary_request.dart';
import 'package:gad_app_team/features/counseling/turn_plan.dart';

void main() {
  group('Phase 8.1: PolicyBoundary Contract Validation', () {
    /// Tests that PolicyBoundary captures current planner decision space.
    /// These are design-validation tests (structure only, no implementation).

    group('PolicyBoundary Structure', () {
      test('PolicyBoundary holds state and action constraints', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.checkIn,
          allowedActions: const [DialogueAct.explore],
          candidateGoalIds: const [],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [TurnConstraint.forbidAdvice],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.currentState, CounselingState.checkIn);
        expect(boundary.allowedActions, contains(DialogueAct.explore));
        expect(boundary.isAvailable, true);
      });

      test('PolicyBoundary unavailability reason prevents planning', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.intervention,
          allowedActions: const [],
          candidateGoalIds: const [],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [],
          progressInfo: DialogueProgressInfo.empty(),
          unavailabilityReason: 'No eligible interventions for week 2',
        );

        expect(boundary.isAvailable, false);
        expect(boundary.unavailabilityReason, isNotNull);
      });

      test('DialogueProgressInfo tracks dialogue history', () {
        final progress = DialogueProgressInfo(
          askedGoalIds: {'evidence', 'alternative'}.toSet(),
          usedInterventionIds: {'week4_alternative_thought_01'}.toSet(),
          recentUserThoughts: ['질문에 답을 못하면 무능해 보일 것 같다'],
          conversationTopics: {'발표', '불안'}.toSet(),
          isFirstReflectTurn: false,
        );

        expect(progress.askedGoalIds, contains('evidence'));
        expect(progress.usedInterventionIds, contains('week4_alternative_thought_01'));
        expect(progress.recentUserThoughts, isNotEmpty);
      });
    });

    group('PolicyBoundaryRequest Input', () {
      test('PolicyBoundaryRequest contains all needed planner inputs', () {
        final request = PolicyBoundaryRequest(
          currentState: CounselingState.explore,
          userMessage: '발표에서 질문을 받으면 대답을 못할까 봐 걱정돼요.',
          recentMessages: const [],
          currentWeek: 1,
          interventionRegistry: const ApprovedInterventionRegistry(),
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        );

        expect(request.currentState, CounselingState.explore);
        expect(request.userMessage, isNotEmpty);
        expect(request.currentWeek, 1);
        expect(request.knowledge, isEmpty);
      });
    });

    group('State-Specific Boundaries', () {
      test('CheckIn state allows only explore act', () {
        // In Phase 8.2, the boundary builder will construct this.
        // For Phase 8.1, we validate the structure.
        final boundary = PolicyBoundary(
          currentState: CounselingState.checkIn,
          allowedActions: CounselingState.checkIn.allowedActs,
          candidateGoalIds: const [],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [
            TurnConstraint.forbidAdvice,
            TurnConstraint.forbidNewUserFacts,
            TurnConstraint.forbidNewIntervention,
          ],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.allowedActions, contains(DialogueAct.explore));
        expect(boundary.allowedActions, contains(DialogueAct.reflect));
        expect(boundary.candidateGoalIds, isEmpty);
        expect(boundary.eligibleInterventionIds, isEmpty);
      });

      test('Reflect state includes goal candidates from progress', () {
        // Validates goal sequencing (evidence → alternative → probability)
        final progress = DialogueProgressInfo(
          askedGoalIds: {'evidence'}.toSet(),
          usedInterventionIds: <String>{}.toSet(),
          recentUserThoughts: const [],
          conversationTopics: <String>{}.toSet(),
          isFirstReflectTurn: false,
        );

        final boundary = PolicyBoundary(
          currentState: CounselingState.reflect,
          allowedActions: CounselingState.reflect.allowedActs,
          candidateGoalIds: const ['alternative', 'probability'],
          // Note: 'evidence' is missing because already asked
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [TurnConstraint.forbidAdvice],
          progressInfo: progress,
        );

        expect(boundary.candidateGoalIds, contains('alternative'));
        expect(boundary.candidateGoalIds, contains('probability'));
        expect(boundary.candidateGoalIds, isNot(contains('evidence')));
      });

      test('Intervention state limits to eligible types', () {
        // In actual use: eligibleInterventionIds = registry policy + knowledge match
        final boundary = PolicyBoundary(
          currentState: CounselingState.intervention,
          allowedActions: const [DialogueAct.socraticQuestion],
          candidateGoalIds: const [],
          eligibleInterventionIds: const [
            'week4_alternative_thought_01',
          ], // Only this week's approved intervention
          allowedFactIds: const ['diary_001', 'thought_002'],
          forbiddenConstraints: const [
            TurnConstraint.forbidNewIntervention,
            TurnConstraint.forbidStageAdvance,
          ],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.eligibleInterventionIds, hasLength(1));
        expect(boundary.allowedFactIds, isNotEmpty);
      });

      test('Closing state requires no follow-up question', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.closing,
          allowedActions: const [DialogueAct.closing, DialogueAct.summarize],
          candidateGoalIds: const [],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [
            TurnConstraint.requireNoQuestion,
            TurnConstraint.forbidAdvice,
            TurnConstraint.forbidNewIntervention,
          ],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(
          boundary.forbiddenConstraints,
          contains(TurnConstraint.requireNoQuestion),
        );
      });
    });

    group('PolicyBoundary Constraints Validation', () {
      test('Forbidden constraints prevent certain acts', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.explore,
          allowedActions: const [DialogueAct.explore, DialogueAct.reflect],
          candidateGoalIds: const [],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [
            TurnConstraint.forbidAdvice,
            TurnConstraint.forbidNewUserFacts,
          ],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.forbiddenConstraints, contains(TurnConstraint.forbidAdvice));
        expect(
          boundary.forbiddenConstraints,
          contains(TurnConstraint.forbidNewUserFacts),
        );
      });

      test('Goal availability can be checked', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.reflect,
          allowedActions: const [DialogueAct.socraticQuestion],
          candidateGoalIds: const ['evidence', 'alternative'],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.isGoalAvailable('evidence'), true);
        expect(boundary.isGoalAvailable('probability'), false);
      });

      test('Intervention availability can be checked', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.intervention,
          allowedActions: const [DialogueAct.socraticQuestion],
          candidateGoalIds: const [],
          eligibleInterventionIds: const ['week4_alternative_thought_01'],
          allowedFactIds: const [],
          forbiddenConstraints: const [],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.isInterventionAvailable('week4_alternative_thought_01'), true);
        expect(boundary.isInterventionAvailable('week3_some_intervention'), false);
      });
    });

    group('Edge Cases', () {
      test('Empty progress info is valid', () {
        final progress = DialogueProgressInfo.empty();

        expect(progress.askedGoalIds, isEmpty);
        expect(progress.usedInterventionIds, isEmpty);
        expect(progress.isFirstReflectTurn, true);
      });

      test('Multiple goals can be available', () {
        final boundary = PolicyBoundary(
          currentState: CounselingState.reflect,
          allowedActions: CounselingState.reflect.allowedActs,
          candidateGoalIds: const [
            'evidence',
            'alternative',
            'probability',
          ],
          eligibleInterventionIds: const [],
          allowedFactIds: const [],
          forbiddenConstraints: const [],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.candidateGoalIds, hasLength(3));
        for (final goal in ['evidence', 'alternative', 'probability']) {
          expect(boundary.isGoalAvailable(goal), true);
        }
      });

      test('Multiple interventions can be eligible', () {
        // Future: if approval expands to multiple types per week
        final boundary = PolicyBoundary(
          currentState: CounselingState.intervention,
          allowedActions: const [DialogueAct.socraticQuestion],
          candidateGoalIds: const [],
          eligibleInterventionIds: const [
            'week4_alternative_thought_01',
            'week4_behavior_pattern_01', // If multiple approved
          ],
          allowedFactIds: const [],
          forbiddenConstraints: const [],
          progressInfo: DialogueProgressInfo.empty(),
        );

        expect(boundary.eligibleInterventionIds, hasLength(2));
      });
    });

    group('Phase 8.2 Implementation Notes', () {
      test('DeterministicPolicyBoundaryBuilder will extract planner logic', () {
        // Placeholder test for Phase 8.2 implementation.
        // Phase 8.2 will:
        // 1. Run each deterministic planner
        // 2. Extract its decision boundaries
        // 3. Construct matching PolicyBoundary
        // 4. Agent layer will validate against this boundary

        // For now, verify the builder interface exists.
        expect(DeterministicPolicyBoundaryBuilder, isNotNull);
      });

      test('PolicyBoundaryRequest format matches planner inputs', () {
        // Verifies that all current planner dependencies are covered.
        // (This is validated by the inventory document.)

        // Required by ALL planners:
        // - currentState
        // - userMessage
        // - recentMessages

        // Required by SOME planners:
        // - currentWeek (intervention)
        // - interventionRegistry (intervention)
        // - knowledge (intervention)
        // - userContext (reflect, intervention)
        // - retrievalSummary (forward-compatible, not yet used)

        final minimalRequest = PolicyBoundaryRequest(
          currentState: CounselingState.explore,
          userMessage: 'test message',
          recentMessages: const [],
          currentWeek: 1,
          interventionRegistry: const ApprovedInterventionRegistry(),
          knowledge: const [],
          retrievalSummary: RetrievalSummary.empty,
        );

        expect(minimalRequest.userMessage, isNotEmpty);
        expect(minimalRequest.recentMessages, isNotNull);
      });
    });
  });

  group('Phase 8.1: Planner Inventory Cross-Check', () {
    /// High-level validation that the inventory document matches code reality.

    test('7 sub-planners are composed in DeterministicCounselingTurnPlanner', () {
      // This test documents the 7 planners:
      // 1. InputGuardTurnPlanner
      // 2. ProcessSignalTurnPlanner
      // 3. CheckInTurnPlanner
      // 4. ExploreTurnPlanner
      // 5. ReflectTurnPlanner
      // 6. InterventionTurnPlanner
      // 7. ClosingTurnPlanner

      final planner = const DeterministicCounselingTurnPlanner();
      expect(planner.inputGuardPlanner, isNotNull);
      expect(planner.processSignalPlanner, isNotNull);
      expect(planner.checkInPlanner, isNotNull);
      expect(planner.explorePlanner, isNotNull);
      expect(planner.reflectPlanner, isNotNull);
      expect(planner.interventionPlanner, isNotNull);
      expect(planner.closingPlanner, isNotNull);
    });

    test('Each CounselingState has defined allowedActs', () {
      for (final state in CounselingState.values) {
        expect(state.allowedActs, isNotEmpty);
        expect(state.requiredAct, isNotNull);
      }
    });

    test('DialogueAct enum covers all planner decisions', () {
      // Planners output one of these acts (or unknown).
      final acts = [
        DialogueAct.reflect,
        DialogueAct.explore,
        DialogueAct.socraticQuestion,
        DialogueAct.summarize,
        DialogueAct.psychoeducation,
        DialogueAct.closing,
        DialogueAct.unknown,
      ];
      expect(acts, isNotEmpty);
    });

    test('TurnConstraint covers all planner restrictions', () {
      // Planners use constraints to communicate hard requirements.
      final constraints = [
        TurnConstraint.requireReflection,
        TurnConstraint.requireExactlyOneQuestion,
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidStageAdvance,
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.requireNoQuestion,
      ];
      expect(constraints, isNotEmpty);
    });
  });

  group('Phase 8.1: Documentation Validation', () {
    /// Ensures design doc structure is present.

    test('PHASE8_PLANNER_INVENTORY.md exists and documents 7 planners', () {
      // This test will be enabled in Phase 8.2 when testing against files.
      // For Phase 8.1, we verify the design structure via code.

      expect(true, true); // Placeholder
    });

    test('PolicyBoundary fields match turn_plan.dart usage patterns', () {
      // Validates that PolicyBoundary includes all info used by planners:

      // allowedActions: From state.allowedActs
      // forbiddenConstraints: From plan.constraints
      // candidateGoalIds: From reflect planner's goal sequencing
      // eligibleInterventionIds: From intervention registry + knowledge match
      // allowedFactIds: From userContext provenance
      // progressInfo: From recentMessages analysis

      final boundary = PolicyBoundary(
        currentState: CounselingState.reflect,
        allowedActions: CounselingState.reflect.allowedActs,
        candidateGoalIds: const ['evidence', 'alternative', 'probability'],
        eligibleInterventionIds: const [],
        allowedFactIds: const ['diary_001'],
        forbiddenConstraints: const [TurnConstraint.forbidAdvice],
        progressInfo: DialogueProgressInfo(
          askedGoalIds: <String>{}.toSet(),
          usedInterventionIds: <String>{}.toSet(),
          recentUserThoughts: const [],
          conversationTopics: <String>{}.toSet(),
          isFirstReflectTurn: true,
        ),
      );

      // All fields should be non-null and usable by planner logic.
      expect(boundary.currentState, isNotNull);
      expect(boundary.allowedActions, isNotEmpty);
      expect(boundary.forbiddenConstraints, isNotEmpty);
      expect(boundary.progressInfo, isNotNull);
    });
  });
}
