# Phase 13.2–13.6 — Session Flow Redesign

Starting point: `counseling-v1.1-selection-repair`. Audit:
[`phase13_1_progression_audit.md`](phase13_1_progression_audit.md).
Fixes N1 (intervention deadlock) and N7 (premature closing).

Decisions (user, Phase 13.1):

- Items 2–5 approved as proposed.
- Item 1: cumulative use of the **already-approved week 4–8 techniques
  only**. No week 1–3 technique is approved. `week3_alternative_thought_01`
  exists in the corpus, but that does not make it approved. New week 1–3
  approvals wait for clinical review.

## 13.2 Cumulative intervention policy (commit 9e225bf)

- `ApprovedInterventionRegistry.policiesUpTo(week)` returns every approved
  policy with `policy.week <= week`, most recent first. A future-week
  technique is never returned.
- `InterventionCandidateResolver` is the one place that picks the technique.
  The boundary builder and the selector both call it. The existing gates
  still apply: not already used this session, knowledge item available,
  gain/loss needs an avoidance-shaped message, maintenance needs a
  maintenance-shaped message or an effective-intervention record.
- When nothing fits, the result is an explicit `noEligibleIntervention`
  (`DialogueAct.summarize`, no CBT id). It is never `unknown`, which
  StatePolicy does not count as progress (the N1 deadlock). Weeks 1–3
  always take this path.

## 13.3 Intervention = ask → answer → integrate

- The prompt turn (`InterventionStep.prompt`) reports
  `StageProgress.inProgress`. Asking the question no longer ends the stage.
- `InterventionProgressTracker.pendingPromptTechniqueId` finds the technique
  whose question is still unanswered. Repair turns in between are skipped.
  The next turn is the integration (`DialogueAct.reflect` + the same
  technique id), and the decision contract has a branch for it.
- Integration acknowledges the answer in the technique's own terms and does
  not quote it. A low-information answer or a request to stop gets a
  no-pressure acknowledgment ("바로 떠오르지 않아도 괜찮아요…") and is not
  credited with a technique outcome.

## 13.4 Reflect by completion

- Reflect runs for at least 2 and at most 4 turns. Clarify turns and the
  first goal question report `inProgress`. A follow-up goal or a recovery
  turn reports `complete`.
- A repair turn never counts as completion, so it can only move state at
  the stage cap.

## 13.5 Closing handshake

- An integration or noEligible reply ends with one proposal:
  "오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?"
  (`ClosingStep.proposed`).
- Agreeing, an empty reply, or a closing-only reply → `finalized`. Wanting
  to continue, or any substantive reply → `continued` (back to reflect,
  `StageProgress.reopen`). Continuing is allowed once. After that, the
  next proposal finalizes.
- The `completed` session status and the UI end notice now happen on
  `finalized`. Before, they happened on entering closing. The final
  closing line no longer quotes the user.

## 13.6 Week × multi-turn evaluation

`test/counseling/evaluation/phase13_6_week_progression_test.dart`: 7
families × weeks 1–8 = 56 sessions, 412 user turns, run on the real
deterministic harness. The simulated user adapts to each reply: it answers
a proposal, a technique question, or a reflective question according to
its family.

Families: normal worry, low-info answer to the technique question, no
eligible technique, earlier-week technique (weeks 7–8 ordinary worry),
current-week technique (gate-satisfying entry), meta feedback during
intervention, continue at closing.

### Gate (all must be 0)

| Metric | Value |
|---|---|
| interventionDeadlock | 0 |
| prematureClosing | 0 |
| interventionResponseDropped | 0 |
| futureWeekTechniqueLeakage | 0 |
| unauthorizedCbt | 0 |
| noEligibleInterventionDeadlock | 0 |
| closingContinuationIgnored | 0 |
| sessionCompletedTooEarly | 0 |
| stateLoop | 0 |
| sessionNotFinalized (added) | 0 |

`sessionNotFinalized` was added because a session that never finishes
would otherwise pass every other metric vacuously.

Mutation checks confirm that each metric catches its failure. Each
mutation was applied alone and then reverted:

| Mutation | Metric that fired |
|---|---|
| `policiesUpTo` ignores the week | futureWeekTechniqueLeakage 78 |
| no pending-prompt tracking | interventionResponseDropped 81, prematureClosing 22, sessionCompletedTooEarly 22 |
| prompt reports `complete` | interventionResponseDropped 30, prematureClosing 35, sessionCompletedTooEarly 35 |
| integration reports `inProgress` | interventionResponseDropped 24, prematureClosing 24, sessionCompletedTooEarly 24, closingContinuationIgnored 5 |
| closing always finalizes | closingContinuationIgnored 8 |
| closing always continues | stateLoop 126, sessionNotFinalized 56 |
| noEligible `inProgress` + intervention cap 30 | noEligibleInterventionDeadlock 578, sessionNotFinalized 21 |

### Found in the traces: Q1, Q2 (fixed in 13.6b)

These are not in the Phase 13 gate list. The suite measured them, and
both are now fixed and pinned at 0.

**Q1: the answer to reflect's last question was dropped (56 of 56
sessions).** The turn that completes reflect still asks a reflective
question, for example "그 상황을 다른 관점에서 본다면 어떻게 볼 수
있을까요?". By the time the user answers, the session is in
intervention. The answer then became the technique's entry turn (weeks
4–8) or was summarized over (weeks 1–3). This is the same "question sent
≠ stage done" pattern 13.3 fixed for intervention, at the reflect →
intervention boundary.

Fix: the first intervention reply (technique prompt or noEligible
summary) now opens by acknowledging that answer, without quoting it. The
wording depends on which reflective goal was asked:

| Goal answered | Acknowledgment |
|---|---|
| evidence | 그 걱정이 어디서 오는지 조금 더 알 것 같아요. |
| alternative | 말씀해 주신 생각도 함께 담아 둘게요. |
| probability | 말씀해 주신 느낌도 함께 담아 둘게요. |
| low-info answer | 바로 떠오르지 않아도 괜찮아요. |

The wording has to hold whatever the answer says, because the answer's
content isn't judged. So it never claims the user found another view. A
stop request gets no acknowledgment. Repair turns in between are
skipped. The reflect turn itself was left alone: making the completing
turn ask nothing would force the user to reply to a statement with no
question.

**Q2: the technique question quoted an unsuitable target (36).**
Behavior-type techniques (weeks 5–7) quoted the current message as "the
behavior", whatever it said. Example: "“그래도 긴장되는 건 어쩔 수
없네요”라는 행동의 영향을…". Balanced thought (week 4) fell back to the
previous user turn, usually the evidence answer. Cumulative use (13.2)
exposed this, but weeks 5–6 had it with their own technique too.

Fix: the technique targets the worry the reflect round started from.
`UserThoughtExtractor.roundWorryThought` finds the user message that the
round's first goal question answered. A round starts at the session start
or at the last closing continuation, and repair turns are excluded.
- Balanced thought: round worry, else the current message if it is
  thought-shaped, else the previous fallbacks.
- Behavior techniques: if the user described a behavior
  (`looksLikeBehavior`), examine that behavior with the original wording.
  Otherwise ask about behavior around the round worry, with the same
  technique's question anchored to the worry. Example: "“…”라는 걱정과
  관련된 행동을 함께 살펴볼게요. 그 걱정이 들 때 보통 어떻게 하시는지
  떠올려 보면, 피하는 쪽과 마주하는 쪽 중 어디에 더 가까운가요?"
- Gain/loss keeps its avoidance gate, and maintenance its maintenance
  gate. Both already require a matching message.

No technique, gate, or approval changed. Only the target and the
technique question's anchor did.

Mutation checks: removing the round-worry target fails the Q2 checks;
removing the acknowledgment fails the Q1 checks.

## 13.7 Device dogfood

### Session 1 (week 4, 2026-09-29)

What went as intended:
- The reflect answer was acknowledged ("말씀해 주신 생각도 함께 담아
  둘게요.") before the technique question (Q1).
- The technique targeted the worry thought, not the latest answer (Q2).
- One closing proposal after the integration.

New defects. Each was reproduced as a failing test first
(`test/counseling/phase13_7_dogfood_regression_test.dart`), then fixed:

| | What the user saw | Cause | Fix |
|---|---|---|---|
| D1 | A real balanced thought, "선생님한테 혼나도 괜찮아, 다음에 더 열심히 하면 돼", got the low-info acknowledgment "바로 떠오르지 않아도 괜찮아요" | The stop-request pattern contained a bare "다음에" (and "그만", which also matches "그만큼") | Count them only with a verb of stopping or postponing: "그만할", "다음에 이야기할게" |
| D2 | "정리해보자" at the proposal reopened the session: "좋아요, 조금 더 이야기해 볼게요" | Agreement was matched only at the start of the reply, and anything else defaulted to "continue" | Taking up the proposal's own words (정리, 마무리, 여기까지, 끝내…) anywhere finalizes. Explicit "continue" words are still checked first ("아직 정리하기엔 이른 것 같아요" continues) |
| D3 | "내일 시험을 못봐서 혼날것같아" got one more clarify question | Thought shape required "것 같" with a space | Match `것\s*같` |

### Sessions 2–3 (week 4, 2026-09-29)

Confirmed on device: D1 (a balanced thought with "다음에" is integrated),
D2 ("정리하자" finalizes, end notice only after that), continue at closing
reopens once, and the low-info path works.

| | What the user saw | Cause | Fix |
|---|---|---|---|
| E1 | Two low-info answers in a row got "바로 떠오르지 않아도 괜찮아요" twice in a row | The reflect-answer acknowledgment and the integration used the same sentence | The integration uses "지금 바로 답하기 어려우셔도 괜찮아요." when the previous reply opened with it |
| E2 | A two-sentence message ("…너무 긴장되고 떨려. 실수할까봐 걱정돼") was quoted whole as "the thought" | The round worry was taken message by message | `UserThoughtExtractor.thoughtSentence` picks the thought-shaped sentence |
| E3 | After continuing at closing: "잘 모르겠어" → "지금까지 '잘 모르겠어'라는 이야기를 중심으로 함께 살펴보았습니다." → user: "네?" | (1) Reflect goals were counted for the whole session, so the reopened round was left with one goal and then fell into the no-question recovery. (2) The low-info set held only polite forms, so "잘 모르겠어" was treated as content and quoted (F4 on device) | Goals and reflect content are counted per round (`currentRound`) in both the selector and the boundary. The low-info check covers 반말 forms. A recovery never summarizes a low-info reply; it uses the round's worry |

Now the reopened round asks its own clarify, evidence, and alternative
questions, then a summary with the proposal. There is no statement left
without a question.

Not fixed (realizer frozen, N6 backlog): the remote realizer once asked
two questions in one reflect turn ("두려운 이유는 무엇인지, 그 감정을 다른
시각에서 어떻게 해석할 수 있을지").

## Open

- 13.7 real-device dogfood, then tag `counseling-v1.2-session-flow`.
- Backlog: F4 (reflect recovery quoting "네"), N6 surface phase, week 1–3
  clinical approval.
