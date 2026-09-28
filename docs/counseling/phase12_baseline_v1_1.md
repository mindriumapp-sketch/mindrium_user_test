# counseling-v1.1-selection-repair

**What this tag means:** the Phase 11/12 **selection-repair baseline**.
Interaction repair, goal-exhaustion recovery, target eligibility and the
realizer context are validated in automated multi-turn evaluation and on
a real device. **It does not mean the counseling chatbot is ready for
production.** Two critical blockers remain (below). Both must be fixed
before any external rollout.

Builds on `counseling-v1-clean-baseline` (Phase 10.7). Detailed record:
[`phase12_conversation_robustness.md`](phase12_conversation_robustness.md).

## Validated

| Area | What holds | Where |
|---|---|---|
| Repeated-question interaction repair | Meta feedback is detected and acknowledged without a new question. Generalized cue composition: frozen gate recall 24/24, FP 0 on 21 negatives x 4 states. Consecutive complaints get different acknowledgments | 11.2, 12.3B, F6 |
| Goal-exhaustion recovery | The last goal is never re-asked. Explicit `summarize` / `listenWithoutQuestion`, never the same recovery twice in a row | 11.3, 12.3C |
| Meta-content exclusion | A user turn answered by a repair is never used as reflection, intervention or closing content | 12.3A (F3) |
| Thought recognition | "~할까 봐", "~하면 어떡하지" and "X가 마음에 걸려" count as thoughts, so reflect reaches evidence/alternative instead of clarify twice | N3 |
| Realizer context | The realization request includes the user's current message. This was the root cause of GPT repeating its previous turn, a regression from 10.6C that is now fixed | N2 root cause |
| Duplicate-question guard | A realization that copies the previous question while the plan asked something new is rejected and falls back | N2 guard |
| Fallback surface | A clause is never slotted into a noun position ("…걸려 부분이…") | N5 |
| Intent routing | Mid-session, only an explicit app-usage question that names an app term reaches the app guide | N4, N4b |
| Multi-turn regression | 19 scenarios / 102 turns / all 5 states, every activation metric at 0 | 12.3D suite |
| Real device | 6 dogfood sessions (SM A716S, local backend). Session 6: GPT accepted on every realized turn, no repeats, reflect progressed | 12.1 |

`flutter test` **1230/1230**, `flutter analyze`: 5 pre-existing unrelated
infos.

## Known critical blockers before external rollout

- **N1: intervention deadlock.** When no approved intervention is
  eligible, the unavailable plan uses `DialogueAct.unknown`, which
  StatePolicy never counts as progress, so the session repeats the same
  template until the 20-turn cap and never reaches closing. This happens
  in weeks 1–3 (no approved technique) **and, per the Phase 13.1 audit,
  also in weeks 7–8 whenever their context gates fail** (5 of 8 weeks
  with ordinary worry content). See
  [`phase13_1_progression_audit.md`](phase13_1_progression_audit.md).
- **N7: fixed turn budget causes premature closing.** Budgets are 1/1/2/1,
  so every session closes on user turn 6. The intervention question is
  never answered (the answer goes to closing), reflect never reaches the
  probability goal, and closing can't be left even when the user objects.
  Affects every session.

Both are assigned to **Phase 13 — Intervention & Session Progression
Redesign**.

## Other known issues (not blockers)

- **N6**: deterministic checkIn/intervention templates quote the user
  verbatim ("“X”라고 말씀해 주셨군요", "“X”라는 생각을…"). These states
  don't go through GPT.
- **F4**: a low-information reply ("몰라요") can become the CBT target.
- **F5**: meta feedback in closing isn't handled (by design in Phase 11).
- Implicit restatement complaints ("~다고") aren't detected; that needs
  context.
- Mixed worry-plus-complaint messages lose their worry part as a target
  (12.3A tradeoff).

## Dogfood environment state (local only)

- The local `mindrium_dogfood` DB has a forced week-4 `treatment_progress`
  doc for the test account (`note: phase12.1 dogfood: forced week 4`),
  and a probe account `probe.dogfood@example.com` used for realizer
  replays.
- The backend runs from this repo on port 8090. The shared server still
  has no `/counseling/*` routes.
