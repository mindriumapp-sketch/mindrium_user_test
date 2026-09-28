# Turn Planner Responsibility Inventory (Phase 8.1)

## Overview

This document inventories the 7 sub-planners in `DeterministicCounselingTurnPlanner` and classifies their decision logic into three categories:

1. **Hard Guard**: Decisions that apply before all other planners (no state-dependency)
2. **Policy Boundary**: Decisions that define the allowable range/set for this turn
3. **Deterministic Selection**: Decisions that pick one specific choice within the boundary

---

## 7 Sub-Planner Analysis

### 1. InputGuardTurnPlanner

**Execution Order**: Runs first (before all others)

**Decision Type**: Hard Guard

**Responsibility**:
- Filters gibberish, abusive, inappropriate, and prompt-injection inputs
- Applies same logic across ALL counseling states (including closing)
- Does NOT depend on state, user context, or CBT knowledge

**Deterministic Decisions**:
1. **Text pattern matching** (4 RegExp patterns):
   - `_isolatedJamoOnly`: Detects isolated jamo characters
   - `_keyboardMash`: Detects keyboard mashing patterns
   - `_abusiveTowardBot`: Detects bot-directed abuse
   - `_inappropriateRequest`: Detects sexual/harmful content
   - `_promptInjection`: Detects system instruction attempts

2. **Response selection** (if detected):
   - 4 possible reflection sentences (based on violation type)
   - 1 fixed question sentence per violation type
   - Fixed forbidden list and constraints

**Output**:
- `CounselingTurnPlan` with:
  - `requiredAct: DialogueAct.unknown`
  - `planningStatus: TurnPlanningStatus.unavailable`
  - `constraints`: Reflection + ExactlyOneQuestion + forbid advice/facts/stageadvance
  - Empty `userContextIds`, `cbtContextIds`

**Why It Stays Outside Agent Boundary**:
- This is a safety layer that should run in all contexts
- Not a counseling decision—it's input validation
- Policy Boundary agent cannot override these guards

---

### 2. ProcessSignalTurnPlanner

**Execution Order**: Runs second (after InputGuard, before state-specific planners)

**Decision Type**: Hard Guard + Policy Boundary

**Responsibility**:
- Detects user signals about counseling process itself
- Applies same logic across checkIn/explore/reflect/intervention (NOT closing)
- Two signal types: empathy requests, process resistance

**Hard Guard Decisions**:
1. **Text pattern matching** (2 RegExp patterns):
   - `_requestsEmpathy`: User asks to listen without questioning
   - `_showsProcessResistance`: User expresses doubt about counseling process
   
2. **Signal precedence**:
   - If empathy request detected → use empathy reflection
   - Else if resistance detected → use process reflection
   - Else → no match, return null (pass to next planner)

**Policy Boundary Decision**:
- Skip in closing state (already non-questioning)
- Do NOT produce this plan if user is in mid-thought exploration

**Deterministic Selection**:
- Fix `requiredAct` to maintain state progression:
  - In reflect/intervention: use `DialogueAct.reflect` (not explore, which would accelerate)
  - In checkIn/explore: use `DialogueAct.explore`
- Fixed reflection (empathy vs resistance variant)
- Fixed constraints: Reflection + NoQuestion + forbid advice/facts/stageadvance

**Output**:
- `CounselingTurnPlan` with no question sentence
- No context provenance (no CBT or user context referenced)

---

### 3. CheckInTurnPlanner

**Execution Order**: Runs third

**Decision Type**: Policy Boundary + Deterministic Selection

**Precondition** (Policy Boundary):
- Only runs in `checkIn` state
- Requires non-empty user message

**Hard Guard Decisions**: None (state is the only guard)

**Policy Boundary**:
- Allows only one reflective acknowledgment
- Allows only one specific question: SUD (Subjective Units of Distress 0-10)
- Forbids advice, new facts, new interventions

**Deterministic Selection**:
1. **Reflection target**: Current user message (with punctuation trimmed)
2. **Reflection sentence**: Fixed format `"[message]"라고 말씀해 주셨군요.`
3. **Question sentence**: Fixed SUD question
4. **requiredAct**: Always `DialogueAct.explore`
5. **progressGoalId**: None (SUD is not a goal, it's a state assessment)

**Output**:
- `CounselingTurnPlan` with:
  - Constraints: Reflection + ExactlyOneQuestion + forbid advice/facts/intervention
  - Empty context (no CBT or user item provenance)

---

### 4. ExploreTurnPlanner

**Execution Order**: Runs fourth

**Decision Type**: Policy Boundary + Deterministic Selection

**Precondition** (Policy Boundary):
- Only runs in `explore` state
- Requires non-empty user message

**Hard Guard Decisions**: None

**Policy Boundary**:
1. **Target selection** (handles SUD response edge case):
   - If current message is SUD response (e.g., "6점"), skip it
   - Use previous substantial user concern instead
   - Otherwise use current message

2. **Question selection** (context-aware):
   - If asked about "moment" before → ask about worry consequence
   - If "발표" (presentation) detected → ask about presentation moment
   - Default: Ask about worry moment

3. **Allowed acts**: State's allowedActs (explore/reflect)
   - Lets model choose reflection vs question within boundary

**Deterministic Selection**:
1. **Reflection target**: Current message or previous concern (if SUD response)
2. **Reflection sentence**: Selected from 4 candidates (rotation avoids repetition)
3. **Question sentence**: One of 3 options (based on prior context)
4. **requiredAct**: `DialogueAct.explore` (though allowedActsForTurn may allow reflect)
5. **progressGoalId**: None

**Output**:
- `CounselingTurnPlan` with:
  - Constraints: Reflection + ExactlyOneQuestion + forbid advice/facts/stageadvance
  - Empty context (no CBT or user item referenced)
  - `allowedActsForTurn`: State's allowedActs for adaptive policy

---

### 5. ReflectTurnPlanner

**Execution Order**: Runs fifth

**Decision Type**: Highly Structured Policy Boundary + Deterministic Selection

**Precondition** (Policy Boundary):
- Only runs in `reflect` state
- Requires non-empty user message

**Hard Guard Decisions**: None

**Policy Boundary**:
1. **Target selection** (6-step priority):
   - (1st) Explicit evaluative thought from current message
   - (2nd) Recent message's evaluative thought (if follow-up question)
   - (3rd) Diary thought (if current is low-info or topic-matching)
   - (4th) Current message if substantial (topic matching via shared words)
   - (5th) Latest user message from recent
   - (6th) Current message as fallback

2. **Clarification decision**:
   - If first reflect turn AND no real thought found → ask clarification
   - If follow-up AND current is substantial → use current as target
   - Else use priority-ordered selection above

3. **Question goal selection** (deterministic sequence):
   - Track asked goals via `CounselingMessage.dialogueGoalId`
   - Order: evidence → alternative → probability → (repeat last)
   - Skip any goal already asked

4. **Allowed acts**: State's allowedActs (reflect/summarize/socraticQuestion)
   - Except clarification branch (fixed to explore)

**Deterministic Selection**:
1. **Reflection sentence**: 
   - Clarify branch: From 2 candidates (rotation)
   - Normal branch: From 3 candidates (rotation)
   - Normalizes target (fixes "것이다" → "것 같다는 생각")

2. **Question sentence**:
   - Fixed per goal (evidence/alternative/probability)
   - Clarify branch: From 2 candidates (rotation)

3. **requiredAct**:
   - Clarify branch: `DialogueAct.explore`
   - Normal branch: `DialogueAct.socraticQuestion`

4. **userContextIds**:
   - Only if diary used as target: [selectedUserItem.id]
   - Otherwise empty

5. **progressGoalId**: goal.name (for next turn to detect repetition)

**Output**:
- `CounselingTurnPlan` with:
  - Constraints: Reflection + ExactlyOneQuestion + forbid advice/facts/stageadvance
  - Provenance: userContextIds only if diary used
  - `allowedActsForTurn`: State's allowedActs (not for clarify)

---

### 6. InterventionTurnPlanner

**Execution Order**: Runs sixth

**Decision Type**: Highly Structured Policy Boundary + Deterministic Selection

**Precondition** (Policy Boundary):
- Only runs in `intervention` state

**Hard Guard Decisions**: None (policy gates everything)

**Policy Boundary**:
1. **Intervention eligibility**:
   - Get policy for current week from `ApprovedInterventionRegistry`
   - If no policy for week OR already used this policy in recent messages → unavailable
   - If not matched in current knowledge → unavailable

2. **Intervention-specific conditions**:
   - If `gainLossReview`: Requires user message to look like avoidance
   - If `maintenanceReview`: Requires either explicit thought or effective intervention from context

3. **Target selection** (per intervention type, 5-step priority):
   - (For all types) Explicit thought shaped per intervention type
   - (For all) If maintenance: use effective intervention label (if no explicit)
   - (For all) Diary thought (if matches topic)
   - (For all) Latest user message
   - (For all) Current message as fallback

4. **Forbidden targets**:
   - Cannot have empty target after all checks

**Deterministic Selection**:
1. **Selected knowledge item**: First item matching intervention policy
2. **Question sentence**: Fixed per intervention type (6 types)
3. **Reflection sentence**: Generated per type (6 variants)
4. **Goal sentence**: Fixed per type (6 variants)
5. **requiredAct**: Always `DialogueAct.socraticQuestion`
6. **userContextIds**:
   - If maintenance + no explicit thought + has effective intervention: [effectiveIntervention.id]
   - Else if explicit thought is null + diary used: [diary.id]
   - Else empty
7. **cbtContextIds**: [selected.id] (the knowledge item)
8. **InterventionPlan**:
   - type: From policy
   - target: Selected via priority
   - promptSentence: Fixed question
   - selectedCbtId: selected.id
   - recommendation: From ActivityRecommendationPolicy

**Unavailable Plan** (if above conditions fail):
- Same reflection/question/constraints/requiredAct as normal
- But `planningStatus: unavailable` (tells model to hold state)

**Output**:
- `CounselingTurnPlan` with:
  - Constraints: Reflection + ExactlyOneQuestion + forbid advice/facts/intervention/stageadvance
  - Provenance: cbtContextIds=[knowledge id], userContextIds=[context id if used]
  - `interventionPlan`: Non-null plan with type/target/question/recommendation
  - `progressGoalId`: None

---

### 7. ClosingTurnPlanner

**Execution Order**: Runs last

**Decision Type**: Policy Boundary + Deterministic Selection

**Precondition** (Policy Boundary):
- Only runs in `closing` state
- Requires non-empty user message

**Hard Guard Decisions**: None

**Policy Boundary**:
1. **Summary target selection**:
   - If current message is substantial (non-closing-only pattern) → use it
   - Else search recent messages for first substantial user message
   - If none found → use null (generic closing)

2. **Response type**:
   - If summary target found → include target in reflection
   - Else → generic reflection without target

**Deterministic Selection**:
1. **Reflection sentence**: Template-based
   - `"오늘은 \"[target]\"라는 이야기를 나눴습니다. 여기까지 이야기해 주셔서 감사합니다."`
   - Or generic: `"오늘 나눈 내용을 여기까지 정리하겠습니다. 여기까지 이야기해 주셔서 감사합니다."`

2. **Question sentence**: Empty (no follow-up question)
3. **requiredAct**: `DialogueAct.closing`
4. **progressGoalId**: None

**Output**:
- `CounselingTurnPlan` with:
  - Constraints: Reflection + NoQuestion + forbid advice/facts/intervention/stageadvance
  - Empty context
  - `questionSentence: ""`

---

## Summary: Guard/Boundary/Selection Classification

| Planner | Guard Type | Boundary Type | Selection Type |
|---------|-----------|---------------|----------------|
| InputGuard | Regex patterns (text only) | None (applies everywhere) | Fixed responses per violation |
| ProcessSignal | Regex patterns (text only) | State + closability check | Fixed response + act normalization |
| CheckIn | State only | Single fixed question (SUD) | Fixed format |
| Explore | State only | Context-aware question selection | Rotation among candidates |
| Reflect | State + thoughtfulness | 6-step priority + goal tracking | Rotation + goal sequencing |
| Intervention | State + registry + topic match | Eligibility chain (policy→knowledge→conditions) | Type-based templates |
| Closing | State only | Summary target detection | Template-based |

---

## Current PolicyBoundary Inputs (Empirical)

Each planner currently uses these information sources:

1. **From Context Always**:
   - `CounselingState state` (guards execution)
   - `String userMessage` (primary content)
   - `List<CounselingMessage> recentMessages` (for goal/thought tracking)

2. **From Knowledge (Selective)**:
   - InputGuard: None
   - ProcessSignal: None
   - CheckIn: None
   - Explore: None (uses surface only)
   - Reflect: `List<CbtKnowledgeItem> knowledge` (none used in planner, passed for future)
   - Intervention: `List<CbtKnowledgeItem> knowledge` (required for selection)
   - Closing: None

3. **From User Context (Selective)**:
   - InputGuard: None
   - ProcessSignal: None
   - CheckIn: None
   - Explore: None
   - Reflect: `MindriumCounselingContext? userContext` (for diary extraction)
   - Intervention: `MindriumCounselingContext? userContext` (for thought/diary extraction)
   - Closing: None

4. **From Registries (Selective)**:
   - InputGuard: None
   - ProcessSignal: None
   - CheckIn: None
   - Explore: None
   - Reflect: None
   - Intervention: `ApprovedInterventionRegistry` (policy lookup) + `ActivityRecommendationPolicy` (activity mapping)
   - Closing: None

5. **Derived (From above)**:
   - `int currentWeek` (for intervention policy lookup)
   - `RetrievalSummary retrievalSummary` (current: unused, future-ready)
   - Surface variation candidates (hard-coded)

---

## Phase 8 Implication

**Current System**: Planners are procedural (code-based, deterministic)
- Each planner is a function that turns `TurnPlanningContext` → `CounselingTurnPlan?`
- No explicit "policy" layer; policy is embedded in code

**Phase 8 Goal**: Extract policy layer to `PolicyBoundary`
- `PolicyBoundary` = "What is allowed this turn?"
- Agent layer uses this to generate `TurnPlan` (may differ from current)
- Fallback = current deterministic planner if no agent available

**Minimal Contract for Fallback**:
- `allowedActions`: Per-state (fixed: checkIn→[explore], explore→[explore/reflect], etc.)
- `candidateGoalIds`: For reflect planner (goal sequence tracking)
- `forbiddenActions`: Per-planner (hard constraints)
- `eligibleInterventionIds`: For intervention state (registry policy)
- `allowedFactIds`: What user context items can be referenced
- `progressInfo`: Recent goals/interventions to avoid repetition

---

## Files Generated This Phase

1. `PHASE8_PLANNER_INVENTORY.md` (this file)
2. `policy/policy_boundary.dart` (data model)
3. `policy/policy_boundary_request.dart` (input specification)
4. `test/counseling/phase8_planning_test.dart` (contract validation tests)
5. `docs/counseling/phase8_boundary_design.md` (architecture & examples)
