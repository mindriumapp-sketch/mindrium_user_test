# Phase 8: PolicyBoundary Design

## Overview

Phase 8 introduces an Agent layer that generates counseling dialogue while respecting a **PolicyBoundary** contract. The boundary defines what decisions the agent can make given the current counseling state and history.

This document describes:
1. Current (Phase 1-7) architecture
2. Phase 8 proposed architecture with PolicyBoundary
3. PolicyBoundary contract specification
4. Sub-planner boundary examples
5. Fallback to deterministic planners

---

## Part 1: Current Architecture (Phase 1-7)

```
┌─────────────────────────────────────────┐
│  CounselingHarness                      │
│  - State machine (check-in → closing)   │
│  - LLM orchestration (call/validate)    │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  DeterministicCounselingTurnPlanner     │
│  Runs 7 sequential sub-planners:        │
│  1. InputGuard    (hard guard)          │
│  2. ProcessSignal (hard guard)          │
│  3. CheckIn       (state-specific)      │
│  4. Explore       (state-specific)      │
│  5. Reflect       (state-specific)      │
│  6. Intervention  (state-specific)      │
│  7. Closing       (state-specific)      │
└────────────────┬────────────────────────┘
                 │
                 ▼
         CounselingTurnPlan
         - requiredAct (DialogueAct)
         - reflectionTarget (String)
         - questionGoal (String)
         - constraints (List<TurnConstraint>)
         - forbidden (String list for model)
         - allowedActsForTurn (adaptive policy)
         - progressGoalId (for goal tracking)
                 │
                 ▼
      ┌──────────────────────┐
      │  ResponseRealizer    │
      │  (LLM call: GPT-4)   │
      └──────────────────────┘
```

**Key Characteristics**:
- All planning is code-based (Dart functions)
- Policies embedded in conditional logic
- Deterministic: Same input → Same plan (no randomness in planners)
- Constraints communicated via `TurnConstraint` enum
- Acts selected by planners, not by model
- Model only realizes the plan into natural language

**Design Principle**: Harness decides WHAT to do. Model decides HOW to say it.

---

## Part 2: Phase 8 Architecture with Agent

```
┌──────────────────────────────────────────┐
│  CounselingHarness                       │
│  - State machine (check-in → closing)    │
│  - LLM orchestration (agent/fallback)    │
└─────────────────┬──────────────────────┬─┘
                  │                      │
         (Primary)│                      │(Fallback)
                  ▼                      ▼
    ┌──────────────────────┐  ┌─────────────────────────────┐
    │  Agent Layer         │  │ DeterministicTurnPlanner    │
    │  (Claude 3.5+)       │  │ (Current code)              │
    │                      │  │                             │
    │  Generates multiple  │  │ Produces fixed plan         │
    │  candidates:         │  │ within constraints          │
    │  - Act choice        │  │                             │
    │  - Target selection  │  │                             │
    │  - Goal picking      │  └─────────────────────────────┘
    │                      │
    │  Validates against   │
    │  PolicyBoundary      │
    └──────────────┬───────┘
                   │
                   ▼
         CounselingTurnPlan
         - requiredAct (from agent/fallback)
         - reflectionTarget (from agent/fallback)
         - questionGoal (from agent/fallback)
         - constraints (from PolicyBoundary)
         - allowedActsForTurn (from PolicyBoundary)
                   │
                   ▼
        ┌──────────────────────┐
        │  ResponseRealizer    │
        │  (LLM call: GPT-4)   │
        └──────────────────────┘
```

**New Layer: PolicyBoundary**

The agent does not plan in isolation. It receives a `PolicyBoundary` that defines:
- Which acts it can choose
- Which goals it can pursue (reflect only)
- Which interventions are available
- What user facts it can reference
- What hard constraints apply

**Agent Flow**:
1. Receive `PolicyBoundaryRequest` (state, message, context, etc.)
2. Build `PolicyBoundary` (or use cached)
3. Generate one or more `CounselingTurnPlan` candidates
4. Validate candidates against boundary
5. Return best plan, or fall back to deterministic if none valid

---

## Part 3: PolicyBoundary Contract

### 3.1 Data Model

```dart
class PolicyBoundary {
  // ═══════════════════════════════════════════════════════
  // Core decision space
  // ═══════════════════════════════════════════════════════

  /// What counseling state are we in?
  final CounselingState currentState;

  /// Which dialogue acts can the agent choose?
  /// Example: [explore, reflect] for explore state
  final List<DialogueAct> allowedActions;

  /// Which question goals can the agent pursue (reflect only)?
  /// Ordered by intended sequence: [evidence, alternative, probability]
  /// After each is used, remove from this list.
  final List<String> candidateGoalIds;

  /// Which interventions are available (intervention state only)?
  /// Filtered by: week policy + knowledge coverage + not-already-used
  final List<String> eligibleInterventionIds;

  /// Which user context items can be referenced?
  /// IDs of diary entries, extracted thoughts, etc.
  final List<String> allowedFactIds;

  /// Dialogue hard constraints this turn.
  /// Override allowedActions for safety (e.g., forbidAdvice).
  final List<TurnConstraint> forbiddenConstraints;

  /// Progress info: goals asked, interventions used, recent topics.
  /// Used by target selection logic (avoid repetition).
  final DialogueProgressInfo progressInfo;

  /// If not null, this turn has no valid plan.
  /// Example: "No eligible interventions for week 2"
  /// Harness uses deterministic planner as fallback.
  final String? unavailabilityReason;
}

class DialogueProgressInfo {
  /// Which question goals have been asked this reflect phase?
  /// Example: {evidence, alternative} → Next offer: probability
  final Set<String> askedGoalIds;

  /// Which interventions have been proposed/started recently?
  /// Used to avoid re-proposing the same intervention.
  final Set<String> usedInterventionIds;

  /// User thoughts extracted from recent messages.
  /// Used as fallback targets if current message is vague.
  final List<String> recentUserThoughts;

  /// Keywords/topics from the last few turns.
  /// Used to ensure new target matches conversation flow.
  final Set<String> conversationTopics;

  /// Is this the first reflect turn in this phase?
  /// If true: may need clarification before structured goals.
  final bool isFirstReflectTurn;
}
```

### 3.2 Semantics

**allowedActions**:
- State determines the default (e.g., explore state → [explore, reflect])
- Adaptive Dialogue Policy may expand (e.g., add reflect to explore-heavy turns)
- Agent chooses from this set
- Constraints further restrict (forbidAdvice overrides any exploratory act)

**candidateGoalIds**:
- Non-empty only in reflect state
- Ordered by intended sequence
- Agent picks one from this list (or uses default)
- After used, planner removes it (so next reflect turn picks next goal)

**eligibleInterventionIds**:
- Non-empty only in intervention state
- Filtered by:
  1. `ApprovedInterventionRegistry.policyForWeek(currentWeek)` (is this type approved?)
  2. Knowledge base coverage (do we have CBT material for this type?)
  3. Recency (has this type been used recently?)
- Agent chooses one from this list
- After used, planner adds to `usedInterventionIds` (for next turn's boundary)

**forbiddenConstraints**:
- Hard requirements that override policy in special situations
- Example: `forbidNewIntervention` during closing phase
- If boundary says "act=explore but forbidAdvice=true", agent must avoid giving suggestions

---

## Part 4: Deterministic PolicyBoundaryBuilder

In Phase 8.2, a builder extracts the decision space from current deterministic planners:

```dart
class DeterministicPolicyBoundaryBuilder implements PolicyBoundaryBuilder {
  PolicyBoundary? build(PolicyBoundaryRequest request) {
    // 1. Check if any hard guard (InputGuard, ProcessSignal) applies
    if (inputGuard.blocks(request)) {
      return null; // No boundary; harness uses inputGuard's plan
    }

    // 2. Check which state-specific planner will run
    if (request.state == CounselingState.checkIn) {
      return _buildCheckInBoundary(request);
    }
    if (request.state == CounselingState.explore) {
      return _buildExploreBoundary(request);
    }
    if (request.state == CounselingState.reflect) {
      return _buildReflectBoundary(request);
    }
    if (request.state == CounselingState.intervention) {
      return _buildInterventionBoundary(request);
    }
    if (request.state == CounselingState.closing) {
      return _buildClosingBoundary(request);
    }
    throw StateError('Unknown state: ${request.state}');
  }

  PolicyBoundary _buildCheckInBoundary(PolicyBoundaryRequest req) {
    return PolicyBoundary(
      currentState: req.state,
      allowedActions: req.state.allowedActs,
      candidateGoalIds: const [], // No goals; SUD question only
      eligibleInterventionIds: const [],
      allowedFactIds: const [],
      forbiddenConstraints: const [
        TurnConstraint.forbidAdvice,
        TurnConstraint.forbidNewUserFacts,
        TurnConstraint.forbidNewIntervention,
      ],
      progressInfo: _buildProgressInfo(req.recentMessages),
    );
  }

  PolicyBoundary _buildReflectBoundary(PolicyBoundaryRequest req) {
    final goals = _selectCandidateGoals(req.recentMessages);
    return PolicyBoundary(
      currentState: req.state,
      allowedActions: req.state.allowedActs,
      candidateGoalIds: goals,
      eligibleInterventionIds: const [],
      allowedFactIds: _extractDiaryIds(req.userContext),
      forbiddenConstraints: const [TurnConstraint.forbidAdvice],
      progressInfo: _buildProgressInfo(req.recentMessages),
    );
  }

  PolicyBoundary? _buildInterventionBoundary(PolicyBoundaryRequest req) {
    final policy = req.interventionRegistry.policyForWeek(req.currentWeek);
    if (policy == null || _alreadyUsed(req.recentMessages, policy)) {
      return PolicyBoundary(
        currentState: req.state,
        allowedActions: const [],
        candidateGoalIds: const [],
        eligibleInterventionIds: const [],
        allowedFactIds: const [],
        forbiddenConstraints: const [],
        progressInfo: _buildProgressInfo(req.recentMessages),
        unavailabilityReason: 'No eligible interventions for week ${req.currentWeek}',
      );
    }

    final candidates = _matchKnowledge(req.knowledge, policy);
    if (candidates.isEmpty) {
      return PolicyBoundary(
        unavailabilityReason: 'No knowledge items match policy',
        // ...
      );
    }

    return PolicyBoundary(
      currentState: req.state,
      allowedActions: const [DialogueAct.socraticQuestion],
      candidateGoalIds: const [],
      eligibleInterventionIds: candidates.map((item) => item.id).toList(),
      allowedFactIds: _extractContextIds(req.userContext),
      forbiddenConstraints: const [
        TurnConstraint.forbidNewIntervention,
        TurnConstraint.forbidStageAdvance,
      ],
      progressInfo: _buildProgressInfo(req.recentMessages),
    );
  }
  // ... similar for other states
}
```

This builder validates that:
1. **PolicyBoundary captures the decision space** of deterministic planners
2. **Agent-generated plans fit within the boundary**
3. **Fallback to deterministic works** if agent plan is invalid

---

## Part 5: Sub-Planner Boundary Examples

### Example 1: Explore State

**Request**:
```dart
PolicyBoundaryRequest(
  currentState: CounselingState.explore,
  userMessage: '발표할 때 질문을 받으면 대답을 못할까봐 걱정돼요.',
  recentMessages: [...], // Empty except bot's last question
  currentWeek: 1,
)
```

**Resulting Boundary**:
```dart
PolicyBoundary(
  currentState: CounselingState.explore,
  allowedActions: [DialogueAct.explore, DialogueAct.reflect],
  candidateGoalIds: [],     // Not in reflect yet
  eligibleInterventionIds: [],  // Not in intervention yet
  allowedFactIds: [],       // No user context relevant
  forbiddenConstraints: [
    TurnConstraint.forbidAdvice,
    TurnConstraint.forbidNewUserFacts,
    TurnConstraint.forbidStageAdvance,
  ],
  progressInfo: DialogueProgressInfo(...),
  unavailabilityReason: null,
)
```

**Agent Decision Space**:
- Can choose: explore question OR brief reflection
- Cannot offer advice ("try practicing")
- Cannot add new user facts ("So you have social anxiety")
- Cannot move to next state

**Deterministic Planner Comparison**:
```dart
DeterministicExploreTurnPlanner.plan(context) {
  // Picks reflection: "발표에서 질문을 받는 건 신경 쓰이시는군요"
  // OR one of 4 alternatives via surface variation
  
  // Picks question: one of 3 context-aware variants
  // - "발표에서 가장 걱정되는 순간은?"
  // - Or specific to "moment" if already asked
  
  // Always explore act (unless Adaptive Policy allows reflect)
  requiredAct: DialogueAct.explore,
  allowedActsForTurn: state.allowedActs,  // [explore, reflect]
}
```

Agent should produce similar decisions within the boundary.

---

### Example 2: Reflect State (First Turn)

**Request**:
```dart
PolicyBoundaryRequest(
  currentState: CounselingState.reflect,
  userMessage: '네, 맞아요.',
  recentMessages: [...5 messages...], // Previous explore turns
  currentWeek: 2,
)
```

**Resulting Boundary**:
```dart
PolicyBoundary(
  currentState: CounselingState.reflect,
  allowedActions: [
    DialogueAct.reflect,
    DialogueAct.summarize,
    DialogueAct.socraticQuestion,
  ],
  candidateGoalIds: [
    'evidence',     // What makes you believe this?
    'alternative',  // How else could you see it?
    'probability',  // How likely is it?
  ],
  eligibleInterventionIds: [],
  allowedFactIds: ['diary_001', 'diary_003'],  // From userContext
  forbiddenConstraints: [TurnConstraint.forbidAdvice],
  progressInfo: DialogueProgressInfo(
    askedGoalIds: {},          // No goals asked yet
    usedInterventionIds: {},
    recentUserThoughts: ['질문에 답을 못하면 무능해 보일 것 같다'],
    conversationTopics: {'발표', '질문'},
    isFirstReflectTurn: true,
  ),
  unavailabilityReason: null,
)
```

**Agent Decision Space**:
- Can choose act: reflect/summarize/socraticQuestion
- Can choose goal: evidence/alternative/probability (not all at once, just pick one)
- Can reference diary entries 001, 003
- Must eventually pick one goal; first turn may skip if clarification needed

**Deterministic Planner Comparison**:
```dart
DeterministicReflectTurnPlanner.plan(context) {
  // If current message is low-info ("네"), may return clarification plan
  // Otherwise:
  
  // Picks target: recent explicit thought, diary thought, etc.
  reflectionTarget: '질문에 답을 못하면 무능해 보일 것 같다',
  
  // Picks goal: evidence (first in sequence)
  questionGoal: 'evidence',
  progressGoalId: 'evidence',
  
  // Picks reflection sentence: "질문에 답을 못하면 무능해 보일 것 같다는 생각이
  // 특히 걱정되는군요." (from 3 candidates, rotated)
  
  // Fixed question for evidence goal
  questionSentence: "그 생각을 사실이라고 느끼게 하는 근거나 경험이 무엇인지
  하나 떠올려볼까요?",
  
  requiredAct: DialogueAct.socraticQuestion,
  allowedActsForTurn: state.allowedActs,  // Allows reflect/summarize too
  
  userContextIds: ['diary_001'],  // If diary was used
}
```

**Agent Validation**:
1. Selected goal must be in `candidateGoalIds`
2. Selected act must be in `allowedActions`
3. Referenced diary IDs must be in `allowedFactIds`

---

### Example 3: Intervention State (Available)

**Request**:
```dart
PolicyBoundaryRequest(
  currentState: CounselingState.intervention,
  userMessage: '이 생각이 맞다고 생각해요. 하지만 준비를 못 하면...',
  recentMessages: [...],
  currentWeek: 4,
  interventionRegistry: ApprovedInterventionRegistry(),
  knowledge: [
    CbtKnowledgeItem(id: 'week4_alternative_thought_01', ...),
    CbtKnowledgeItem(id: 'week4_behavior_pattern_01', ...),
    // ... more week 4 items
  ],
)
```

**Resulting Boundary**:
```dart
PolicyBoundary(
  currentState: CounselingState.intervention,
  allowedActions: [DialogueAct.socraticQuestion],
  candidateGoalIds: [],
  eligibleInterventionIds: [
    'week4_alternative_thought_01',  // Policy approved + knowledge exists
    // + not already used in recent messages
  ],
  allowedFactIds: ['thought_extract_123'],  // From userContext
  forbiddenConstraints: [
    TurnConstraint.forbidNewIntervention,
    TurnConstraint.forbidStageAdvance,
  ],
  progressInfo: DialogueProgressInfo(
    usedInterventionIds: {...},  // Already proposed/completed
    // ...
  ),
  unavailabilityReason: null,
)
```

**Agent Decision Space**:
- Must choose socraticQuestion act (fixed)
- Must choose from eligible interventions (only 'week4_alternative_thought_01')
- Can reference extracted thought 123
- Cannot propose new intervention types or move to closing

---

### Example 4: Intervention State (Unavailable)

**Request** (Week 2, when only Week 4 is approved):
```dart
PolicyBoundaryRequest(
  currentState: CounselingState.intervention,
  userMessage: '...',
  currentWeek: 2,  // No approved policy for week 2
)
```

**Resulting Boundary**:
```dart
PolicyBoundary(
  // ... same fields as above but:
  eligibleInterventionIds: [],
  unavailabilityReason: 'No eligible interventions for week 2',
)
```

**Harness Action**:
- Detect `unavailabilityReason != null`
- Use `InterventionPlanner._unavailablePlan(...)` instead
- Hold current state; ask for more information
- Next turn, try again with new input

---

### Example 5: Closing State

**Request**:
```dart
PolicyBoundaryRequest(
  currentState: CounselingState.closing,
  userMessage: '감사합니다.',
  recentMessages: [...],
)
```

**Resulting Boundary**:
```dart
PolicyBoundary(
  currentState: CounselingState.closing,
  allowedActions: [DialogueAct.closing, DialogueAct.summarize],
  candidateGoalIds: [],
  eligibleInterventionIds: [],
  allowedFactIds: [],
  forbiddenConstraints: [
    TurnConstraint.requireNoQuestion,
    TurnConstraint.forbidAdvice,
    TurnConstraint.forbidNewIntervention,
    TurnConstraint.forbidStageAdvance,
  ],
  progressInfo: DialogueProgressInfo.empty(),
  unavailabilityReason: null,
)
```

**Agent Decision Space**:
- Can choose: closing or summarize act
- Must produce NO question (enforced by constraint)
- Cannot introduce new interventions
- Cannot move to next state (already at end)

---

## Part 6: Agent Validation Loop

```
┌──────────────────────────┐
│  PolicyBoundaryRequest   │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  DeterministicBuilder    │
│  .build(request)         │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  PolicyBoundary          │
│  allowedActions: [...]   │
│  candidateGoals: [...]   │
│  constraints: [...]      │
└────────────┬─────────────┘
             │
             ▼ (Phase 8.2)
┌──────────────────────────────────────────┐
│  Agent (Claude 3.5+)                     │
│                                          │
│  Generate CounselingTurnPlan candidate   │
│  - requiredAct                           │
│  - reflectionTarget                      │
│  - questionGoal                          │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│  Validation                              │
│                                          │
│  ✓ Is act in allowedActions?             │
│  ✓ Is goal in candidateGoals?            │
│  ✓ Are facts in allowedFactIds?          │
│  ✓ Does it violate constraints?          │
└────────────┬─────────────────────────────┘
         │         │
    Valid│         │Invalid
         │         │
         ▼         ▼
    ┌────────┐ ┌────────────────────┐
    │ Use    │ │ Fallback to        │
    │Agent's │ │ Deterministic      │
    │Plan    │ │ Planner's Plan     │
    └────────┘ └────────────────────┘
         │              │
         └──────┬───────┘
                ▼
        CounselingTurnPlan
                │
                ▼
        ResponseRealizer
```

---

## Part 7: Implementation Timeline

### Phase 8.1 (Current): Design & Specification
- [x] Inventory 7 sub-planners
- [x] Design PolicyBoundary contract
- [x] Define PolicyBoundaryRequest input
- [x] Write test structure
- [ ] Validate 401 tests green

### Phase 8.2: Deterministic Builder
- [ ] Implement DeterministicPolicyBoundaryBuilder
- [ ] Extract decision logic from each planner
- [ ] Build boundary for each state
- [ ] Validate boundary matches planner decisions
- [ ] 401 tests green

### Phase 8.3: Agent Integration (Out of Scope)
- Agent layer will use DeterministicBuilder as reference
- Agent generates candidate plans
- Validation loop checks against boundary
- Fallback to deterministic if agent invalid

### Phase 9+: Adaptive Dialogue Policy
- Extend allowedActions based on recent turns
- Expand candidateGoals based on model confidence
- Phase 8 boundary layer stays unchanged

---

## Part 8: Fallback Mechanism

If agent is unavailable, unhealthy, or timeout:

```dart
CounselingTurnPlan? plan(TurnPlanningContext context) {
  // Try agent
  final boundary = builder.build(request);
  if (boundary?.isAvailable == false) {
    return deterministicPlanner.plan(context);
  }

  try {
    final agentPlan = await agent.generatePlan(boundary, context);
    if (isValidAgainstBoundary(agentPlan, boundary)) {
      return agentPlan;  // Use agent's plan
    }
  } on Exception catch (e) {
    logger.warn('Agent failed: $e');
  }

  // Fallback: deterministic planner
  return deterministicPlanner.plan(context);
}
```

**Guarantees**:
- If agent unavailable → Use deterministic (no UX change)
- If agent valid → Use agent (better naturalness/variation)
- If agent invalid → Use deterministic + log for debugging
- Boundary design ensures deterministic is always valid

---

## Summary

| Aspect | Phase 1-7 | Phase 8+ |
|--------|-----------|---------|
| Planning | Code-based (7 planners) | Agent + Boundary + Fallback |
| Decision space | Implicit in planner code | Explicit in PolicyBoundary |
| Act selection | Planners → fixed | Agent chooses from allowedActions |
| Fallback | None (only deterministic exists) | Deterministic if agent fails |
| Variation | Surface variation only | Act/goal/target choices |
| Policy layer | Embedded in code | Extracted to PolicyBoundary |
| Testability | Behavior tests only | Contract + behavior tests |

---

## Next Steps (Phase 8.2)

1. Implement DeterministicPolicyBoundaryBuilder
2. Extract decision space from each planner
3. Write builder tests matching planner outputs
4. Validate 401 tests green
5. Document builder-planner mapping

---

## Files

- `lib/features/counseling/PHASE8_PLANNER_INVENTORY.md` - Detailed planner inventory
- `lib/features/counseling/policy/policy_boundary.dart` - PolicyBoundary contract
- `lib/features/counseling/policy/policy_boundary_request.dart` - Request spec
- `test/counseling/phase8_planning_test.dart` - Contract validation tests
- `docs/counseling/phase8_boundary_design.md` - This document
