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

### Found in the traces, not gated (frozen)

These are outside the Phase 13 gate list. The suite pins them at their
current values, so any change has to be deliberate.

**Q1: reflect's last question is dropped (56 of 56 sessions).** The turn
that completes reflect still asks the next reflective question, for
example "그 상황을 다른 관점에서 본다면 어떻게 볼 수 있을까요?". The
session is already in intervention by the time the user answers. That
answer then becomes the technique's entry turn (weeks 4–8), or it is
summarized over (weeks 1–3, noEligible). This is the same "question sent
≠ stage done" pattern that 13.3 fixed for intervention, now showing up
at the reflect → intervention boundary.

**Q2: the technique question quotes an unsuitable target (36).**
- Behavior-type techniques (week 5 behavior pattern, week 6 short/long
  term, week 7 gain/loss) quote the current message as "the behavior",
  whatever it says. Example: "“그래도 긴장되는 건 어쩔 수 없네요”라는
  행동의 영향을…". The single-turn design assumed the entry message
  described a behavior. Cumulative use (13.2) now applies these
  techniques to ordinary worry, which exposes the assumption. The same
  thing happens in weeks 5–6, where the technique is the current week's.
- Balanced thought (week 4) falls back to the previous user turn when the
  current one isn't thought-shaped. That turn is often the evidence
  answer ("예전에 발표하다 말이 막힌 적이 있어요") rather than the worry
  thought.

Both issues change what a technique addresses, so their fixes need a
decision (see "Open" below). They do not block the flow gate.

## Open

- Q1/Q2 fix scope: decide before the 13.7 device dogfood, because both
  are visible in every session on device.
- 13.7 real-device dogfood, then tag `counseling-v1.2-session-flow`.
- Backlog: F4 (reflect recovery quoting "네"), N6 surface phase, week 1–3
  clinical approval.
