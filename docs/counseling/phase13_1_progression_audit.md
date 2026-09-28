# Phase 13.1 — Current Progression Audit

**Status: audit only, no code changed.** This maps how a session moves
through states today, where N1 (intervention deadlock) and N7 (premature
closing) come from, and what the education corpus offers for a
cumulative intervention policy. Starting point:
`counseling-v1.1-selection-repair`.

## 1. Progression rules today

`CounselingStatePolicy.next(current, turnsInCurrentState, totalTurns, lastAct)`
(`lib/features/counseling/counseling_state.dart`):

1. `totalTurns >= 20` → closing
2. `lastAct == DialogueAct.unknown` → **stay in the current state**
   ("a turn we don't understand isn't progress")
3. `_acceleratesFrom(current, lastAct)` → advance early
   (explore+`reflect`, reflect+`summarize`)
4. `turnsInCurrentState + 1 >= budgetFor(current)` → advance

| State | Budget | Note |
|---|---|---|
| checkIn | 1 | |
| explore | 1 | |
| reflect | 2 | 3 goals exist (evidence, alternative, probability) |
| intervention | 1 | |
| closing | 20 | effectively terminal |

Advancement happens **on the same turn** the budget is used up. The
reply is generated in the old state, and the session then sits in the
next state for the following user turn.

## 2. Measured behavior, weeks 1–8 (same 8-turn script, deterministic harness)

Script: "내일 발표가 있어서 불안해요", "7점이요", "발표하다가 말을 못 하면
어떡하지", "예전에 발표하다 말이 막힌 적이 있어요", "한 번 막혔다고 매번
그런 건 아닐 수도 있겠네요", "준비한 만큼은 할 수 있을 것 같아요",
"고마워요", "네".

C = checkIn, E = explore, R = reflect, I = intervention delivered,
u = intervention unavailable (act `unknown`), Z = closing.

| Week | Turns 1–8 | Intervention delivered | Reaches closing | User's answer to the intervention question |
|---|---|---|---|---|
| 1 | C E R R u u u u | — | **never** | — |
| 2 | C E R R u u u u | — | **never** | — |
| 3 | C E R R u u u u | — | **never** | — |
| 4 | C E R R I Z Z Z | turn 5 | after turn 5 | **consumed by closing** |
| 5 | C E R R I Z Z Z | turn 5 | after turn 5 | **consumed by closing** |
| 6 | C E R R I Z Z Z | turn 5 | after turn 5 | **consumed by closing** |
| 7 | C E R R u u u u | — | **never** | — |
| 8 | C E R R u u u u | — | **never** | — |

**Correction to v1.1's N1 scope:** the deadlock isn't limited to weeks
1–3. It happens in **any week whose intervention eligibility fails**. In
week 7, gain/loss review requires `looksLikeAvoidance(userMessage)`. In
week 8, maintenance review requires `looksLikeMaintenance` or an
effective-intervention record. With ordinary worry content, 5 of 8
weeks deadlock.

## 3. N1 — why intervention deadlocks

- `ApprovedInterventionRegistry.policyForWeek(week)`: **exactly one**
  policy per week, weeks 4–8 only, matched by `policy.week == week`. So
  week 6 can't use the week-4 technique, and weeks 1–3 have none.
- `InterventionDecisionSelector.select` returns `isUnavailable` when there
  is no policy, the technique was `alreadyUsed` this session, the required
  item isn't in retrieved `knowledge`, week 7's avoidance gate fails, or
  week 8's maintenance gate fails.
- `TurnPlanAdapter`/`TurnPlanMaterializer.interventionUnavailable` builds
  a plan with `requiredAct: DialogueAct.unknown` and the question "지금
  떠오르는 생각이나 느낌을 조금 더 말씀해 주시겠어요?".
- StatePolicy rule 2 then keeps the session in intervention. The next turn
  re-runs the same selection, gets the same result, and loops until
  `totalTurns >= 20`.

"Unavailable" mixes two meanings: a contract/system failure, and "no
technique fits right now", which is a normal counseling outcome. Only the
first should ever be `unknown`.

## 4. N7 — why sessions end early

- **The intervention answer is dropped.** The intervention reply asks a
  question ("이 생각을 조금 더 균형 있게 바꾼다면 어떤 문장이 될 수
  있을까요?"). Because the budget is 1, the state becomes closing **on
  that same turn**. The user's answer is handled by
  `ClosingDecisionSelector`, which summarizes it as the session topic. The
  technique's outcome (the balanced sentence) is never acknowledged or
  integrated.
- **The UI announces the end under the question.** `chatbot_main.dart:613`
  shows "오늘 상담은 여기까지예요. 새로운 주제로…" as soon as
  `state == closing`, which is right below the unanswered intervention
  question (seen in dogfood sessions 5 and 6).
- **Reflect never reaches probability.** Budget 2 vs 3 goals, so goal
  exhaustion is unreachable in a natural session (also noted in 12.2).
- **Closing is terminal.** It stays until the 20-turn cap. Every message,
  including "왜 벌써 상담을 끝내?", becomes "오늘은 “…”라는 이야기를
  나눴습니다". The Hard Guard is off in closing (F5), and there's no
  continuation path or transition prompt.
- `CounselingProvider` persists the session as `completed` on the first
  entry into closing (`counseling_provider.dart:388`), which currently
  happens before the intervention is finished.

## 5. Where N1 and N7 meet

Both live at the **intervention boundary × StatePolicy**:
- how intervention *starts*: eligibility is week-exclusive and fails
  closed into `unknown` → N1
- how intervention *ends*: a fixed 1-turn budget, with no notion of
  "the user answered" or "outcome integrated" → N7

Phase 13's shift is from a **fixed turn budget** to **completion
conditions**, with the budget kept as a soft cap.

## 6. Corpus audit (input to 13.2)

85 items (`assets/counseling/knowledge/`). The registry currently approves
5 items, one per week for weeks 4–8.

| Week | Technique-type items (candidates, **not approved**) | Currently approved |
|---|---|---|
| 0 | `common_relaxation_use_01`, `common_sud_01` | — |
| 1 | relaxation ×6 (`week1_relaxation_*`, script), `week1_value_goal_01` (core value) | — |
| 2 | relaxation ×6, `week2_diary_habit_01` (keep a worry diary), `week2_worry_group_01` (group worries) | — |
| 3 | **`week3_alternative_thought_01` (도움이 되는 생각 만들기)**, `week3_practice_01` (thought-sorting review), relaxation script | — |
| 4 | `week4_thought_check_01` (belief rating), relaxation script | `week4_alternative_thought_01` (balanced thought) |
| 5 | relaxation script | `week5_confront_avoid_01` (education, behavior pattern) |
| 6 | `week6_reflection_01`, relaxation script | `week6_short_long_term_01` |
| 7 | `week7_planning_01`, relaxation script | `week7_gain_lose_01` |
| 8 | `week8_practice_check_01`, relaxation script | `week8_maintenance_01` |

Observations:
- **Week 3 already teaches alternative thoughts**
  (`week3_alternative_thought_01`), but the registry starts that
  technique at week 4. Whether week 3 can offer it is a clinical call.
- Weeks 1–2 have only psychoeducation, relaxation, values and diary
  habits. These are candidates for a lightweight `microSupport` category
  (e.g. suggest a short relaxation already learned), **not** formal CBT.
- Relaxation scripts exist for every week and are flagged
  (conversational guidance off). They're app activities, not
  conversational techniques. The app already has a relaxation CTA path
  (`CounselingActivity.relaxation`).
- **No new technique may be invented.** Every addition must be an
  existing corpus item and needs sign-off. The registry is documented as
  "임상 검수된" (clinically reviewed).

## 7. Decisions needed before 13.2–13.5

1. **Clinical approval list:** which week 1–3 items (and which extra items
   in weeks 4–8) may be offered, as `microSupport` or formal CBT. This is
   the user's or clinical reviewer's call, not an engineering one.
2. **Intervention completion condition** per type. Minimum proposal:
   prompt → the user responds (any substantive reply) → a one-turn
   integration acknowledgment → complete.
3. **Reflect soft budget:** proposed min 2 / max 4, with completion when
   a usable thought exists and at least one reflective goal is answered.
4. **Closing:** a transition turn ("오늘은 여기까지 정리해볼까요?") and a
   single controlled return to explore/reflect when the user wants to
   continue. Where the UI end-hint and `completed` persistence move to.
5. **`noEligibleIntervention` outcome:** what the user sees (proposed: a
   brief summary of the session, then the closing transition). It must
   never be `unknown`.

## 8. Baseline metrics for 13.6 (today)

| Metric | Today (8-turn script) |
|---|---|
| interventionDeadlock (weeks with no closing) | **5/8 weeks** (1, 2, 3, 7, 8) |
| interventionResponseDropped | **3/3** weeks that deliver an intervention |
| prematureClosing (closing before the intervention outcome) | 3/3 |
| futureWeekTechniqueLeakage | 0 (week-exclusive by construction) |
| closingContinuationIgnored | 100% (no path exists) |
