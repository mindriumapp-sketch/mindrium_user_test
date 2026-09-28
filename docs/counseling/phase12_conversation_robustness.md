# Phase 12 — Conversation-Level Robustness

**Status: 12.2 (multi-turn frozen evaluation) done. 12.1 (real-device
dogfood) not done: it needs Korean typed by a person, because `adb input
text` can't send Hangul.** No production code changed. **Activation gate
not met**, so no `counseling-v1.1-selection-repair` tag.

## What was run

| Item | Count |
|---|---|
| Multi-turn scenarios | 12 (8 families M1–M8), 65 user turns, 4–8 turns each |
| States covered | all 5 (checkIn, explore, reflect, intervention, closing) |
| Unseen meta expressions | 11 (the Phase 12.1 examples), probed single-turn; 6 also used in multi-turn scenarios |
| Worry-repetition negatives | 5 single-turn + 5 in M5 |
| Runner | `test/counseling/evaluation/phase12_multi_turn_regression_test.dart` |

Scenarios run through the real deterministic `CounselingHarness`
(SafetyGate → retrieval → `PolicyPipelineTurnPlanner` → StatePolicy).
History is synced the way `CounselingProvider` does it with instant
empathy off: user and assistant messages are appended after each turn.
M2, M3c and M6 start from a hand-built exhausted-reflect history. All
other scenarios start naturally from checkIn.

## Metrics

| Metric | Result | Gate |
|---|---|---|
| immediateSameGoalRepeat | 0 | ✅ |
| **repeatedRecoveryLoop** | **2** | ❌ |
| ignoredMetaFeedback, seen phrasings, Hard-Guard states | 0 | ✅ |
| **ignoredMetaFeedback, unseen phrasings** | **6/6 in multi-turn, 11/11 single-turn** | ❌ |
| metaFalsePositive | 0 (10/10 negatives clean) | ✅ |
| abnormalEarlyTransition | 0 | ✅ |
| unauthorizedCbtDecision | 0 | ✅ |
| validatorOrMaterializerFailure | 0 | ✅ |
| deadEndConversation | 0 | ✅ |
| maximumConsecutiveSameGoal | 1 | ✅ |
| **maximumConsecutiveSameRecovery** | **2** | ❌ |
| *new:* metaTextUsedAsTarget | 6 | (not in the original gate; see F3) |
| *new:* lowInfoTextUsedAsTarget | 5 | (see F4) |
| *new:* metaInClosingUnhandled | 1 | (by design; see F5) |

The suite stays green. Every metric that holds today is asserted at 0.
Every known failure is frozen at its exact current value, so any change
in either direction fails the suite and has to go through this corpus.

## Failure corpus

Order followed for each: reproduced → classified → frozen test → root
cause. **Not fixed.**

### F1 — Recovery loop: `summarize → summarize` (class D, recovery selection)

- **Repro:** M2 and M6. With exhausted reflect, turn 1 gives `summarize`.
  The next user turn gives `summarize` again, with the same template
  sentence. In M6 it even quotes the same "몰라요" both times.
- **Root cause:** `ReflectDecisionSelector._selectRecovery` only reads
  the previous turn's `interactionRepairReason`. It never reads the
  previous turn's `goalExhaustionRecovery`, so nothing stops the same
  recovery twice in a row.
- **Bound:** reflect's budget is 2, so the loop is capped at 2 today. If
  the budget changes, the loop gets longer.
- **Likely fix (not applied):** in `_selectRecovery`, if the last
  assistant message's `goalExhaustionRecovery == summarize`, choose
  `listenWithoutQuestion`. The metadata is already carried on
  `CounselingMessage`.

### F2 — Unseen meta expressions are all missed (class A, detector miss)

- **Repro:** 11/11 Phase 12.1 example phrasings return no
  `interactionRepairReason`, for both repeated-question (7) and
  stop/listen (4). In multi-turn (M3b, M4b), the system then asks a new
  question: "다른 관점에서 본다면?", or three clarify questions in a row
  after the user asked it to stop.
- **Root cause:** `_repeatsInteraction` / `_requestsEmpathy` are
  closed-form alternations built from the 11.2 fixtures, so paraphrases
  fall through. Examples: "들어주면" vs the pattern's "들어(만)? 주(세요|시면)";
  "또 하는 거예요" vs "또 같은 거 물어"; "전에 대답했던" with no cue at
  all.
- **Frozen miss list:** 우리 이 얘기 아까 하지 않았어요? · 계속 비슷한 것만
  묻는 느낌인데요 · 그 질문 또 하는 거예요? · 이거 전에 대답했던 것 같은데 ·
  아까랑 질문이 거의 같은데요 · 계속 같은 데서 맴도는 느낌이에요 · 또 그
  질문이에요? · 이제 질문은 좀 안 했으면 좋겠어요 · 그냥 제 얘기만 들어주면
  안 돼요? · 더 물어보는 건 지금 부담돼요 · 굳이 답을 찾기보다 그냥 말하고
  싶어요
- **Note:** the false-positive side is solid (0/10), so the detector
  errs toward precision.
- **Before touching regex:** collect real phrasings from 12.1 first.
  Otherwise the next pattern overfits these 11 exactly the way 11.2
  overfit its 8.

### F3 — Meta feedback becomes the CBT/closing target (class F, metadata propagation)

- **Repro:** M3a, M3b, M3c, M7, M8. After a repair turn, the next state
  is intervention (normal budget). Intervention then quotes the user's
  complaint as the thought to restructure. For example: "“아까도
  물어봤잖아요”라는 생각을 함께 살펴보겠습니다. 이 생각을 조금 더 균형 있게
  바꾼다면…". In M8, closing says "오늘은 “이런 거 한다고 뭐가
  달라질까”라는 이야기를 나눴습니다".
- **Why it matters:** this is the most user-visible failure found. It
  treats a complaint about the bot as a cognitive distortion. The
  original gate doesn't catch it, since no goal repeats, no state
  shortcut happens and no unapproved CBT is used.
- **Root cause (to confirm):** intervention/closing target selection
  reads recent user messages by text and never checks whether the
  assistant reply to that message had an `interactionRepairReason`. The
  metadata exists. It just isn't used on that path.

### F4 — Low-info reply becomes the CBT/closing target (class C/G)

- **Repro:** M6, M6b: "“몰라요”라는 생각을 함께 살펴보겠습니다".
- This predates Phase 11 (it isn't caused by recovery), but it's the same
  target-selection gap as F3. It showed up here because multi-turn runs
  reach intervention after low-info turns.

### F5 — Meta feedback in closing isn't handled (by design)

- `DeterministicProcessSignalTurnPlanner` returns null in closing, so
  "뭐가 달라질까" there gets summarized as the session topic. This is
  recorded rather than counted as a detector miss, because the
  closing exclusion was a deliberate Phase 11 scope choice.

### Observation — natural sessions never reach goal exhaustion

Reflect's budget is 2 turns and there are 3 goals. In every natural
checkIn start (M1, M3a/b, M4, M5, M7, M8), reflect ends after
`evidence → alternative`, `probability` is never asked, and exhaustion
never happens. Phase 11.3's recovery is only reachable with a pre-seeded
history, or through a future multi-visit reflect. This isn't a bug (class
E, state budget interaction), but it means F1 affects few real users
today, while F2/F3 affect every session where a user complains.

## Priority (for the next phase, not done here)

1. **F3** — skip repair-tagged user turns when choosing intervention and
   closing targets. Highest user impact, and the metadata is already
   there.
2. **F2** — widen detection using 12.1 dogfood phrasings, not these 11.
3. **F1** — make `_selectRecovery` avoid repeating the previous recovery.
4. **F4** — skip low-info turns as intervention targets.

## Phase 12.3A — F3 fixed (metadata content exclusion)

**Root cause (confirmed in code):** every content selector read past user
messages by text only:
`InterventionDecisionSelector` (`latestUserMessage`),
`ClosingDecisionSelector._summaryTarget`,
`ReflectDecisionSelector` (`_explicitThoughtFromRecent`,
`latestUserMessage`), and `ExploreDecisionSelector._previousConcern`
(the SUD fallback). The repair metadata sits on the assistant message
that *answers* the user turn, and no selector looked at that message.

**Rule:** `UserThoughtExtractor.semanticContent(history)` drops the user
messages whose turn was closed by an assistant reply carrying
`interactionRepairReason`. "Closed by" means the last assistant message
before the next user message, so an instant-empathy bubble in between
doesn't hide the repair. The rule is metadata-only, with no string
matching. It excludes all three reasons (`repeatedQuestion`,
`stopQuestioning`, `processFrustration`), because the enum's contract is
"redirected away from worry-content selection". Only content reads use
this view. The goal-asked bookkeeping and `_selectRecovery` still read
the full history, and the history itself is never modified.

Known tradeoff: a message that mixes real worry with a stop request
("발표가 무서운데 왜 자꾸 물어봐요") now loses its worry part as a future
target. This is acceptable for now. Revisit it if 12.1 shows it happening.

**Production files:** `lib/data/counseling/user_thought_extractor.dart`,
plus the four selectors in `lib/features/counseling/policy/selectors/`
(`intervention_`, `closing_`, `reflect_`, `explore_decision_selector.dart`).

**Evidence:**
- `test/counseling/semantic_content_eligibility_test.dart` (19 tests):
  3 reasons x 4 selectors, a history-unchanged check, and normal-content
  controls. 12 of them failed before the fix. The first run had 3 bogus
  passes, caused by two weak inputs ("음..." isn't low-info, "7점이요"
  isn't SUD by the existing regex). Both were corrected, and I confirmed
  that reverting only the explore change makes exactly 3 tests fail again.
- The frozen multi-turn suite, same scenarios: `metaTextUsedAsTarget`
  went from 6 to 3, and **metaContentLeakage (detected repair utterances)
  = 0**. The remaining 3 were never detected (M3b and M3c are F2 misses,
  M8 is in closing, which is F5), so there is no metadata to exclude them
  by. They move to F2/F5.
- M3a, M7, M8 intervention now restructure the actual worry ("발표 중에
  실수하면…") instead of the complaint.
- Unchanged: F1 = 2, F2 miss set, F4 = 5 (no low-info heuristic added),
  11.4 frozen_v1, StatePolicy, Realizer, and CBT registry.
- `flutter test` **1169/1169**, `flutter analyze` unchanged (5 infos).

**Next, in order:** 12.1 device dogfood (needs you) → 12.3B F2 → 12.3C F1
→ 12.3D re-evaluation.

## Phase 12.1 — dogfood log

### Session 1 (week 1 account, build 7c202cc, Remote Realizer on)

| # | Input | State | Result |
|---|---|---|---|
| 1 | 내일 발표를 해야되는데 준비를 아직 못해서 불안해 | checkIn | ok |
| 2 | 7 | explore | ok (the bare SUD number re-reflects the prior concern) |
| 3 | 준비를 못한게 티가나서 혼날 것 같아 | reflect | ok (evidence goal) |
| 4 | 저번주 발표때 정말 열심히 준비했는데도 부족하다고 혼났어 | reflect | **N2**: the GPT reply repeats turn 3's question verbatim |
| 5 | (turn 4 resent) | intervention | **N1** unavailable template |
| 6 | 아까 말했잖아 지금 준비를 못해서 불안하다고 | intervention | **F2 miss** (real corpus item #1); N1 template again |
| 7 | 빨리 집중해서 준비해야하는데 불안해서 집중이 잘 안돼 | intervention | N1 template again |

**N1 — intervention dead end, weeks 1–3 (critical, predates Phase 11/12).**
`ApprovedInterventionRegistry` only has weeks 4–8. In weeks 1–3,
intervention produces `interventionUnavailable`, whose
`requiredAct = DialogueAct.unknown`. `CounselingStatePolicy.next()`
doesn't count unknown turns as progress, so the session never reaches
closing: it repeats "“…”라고 느끼고 계시는군요. 지금 떠오르는 생각이나
느낌을…" until the 20-turn cap, even after "고마워". I replayed the
dogfood session deterministically and it reproduces on weeks 0–3 every
time. Week 4 goes to closing normally. The 12.2 suite missed this because
every scenario ran at week 4, which is an evaluation-design gap.
→ **Promoted to Phase 13, Cumulative Intervention Policy:** an education
corpus audit, a registry v2 keyed on `introducedWeek` (anything learned up
to the current week, never future weeks), `microSupport` vs formal CBT,
context-aware selection, and an explicit `noEligibleIntervention` outcome
that goes to closing instead of `unknown`. The eval matrix is weeks
1/2/3/4/6/8. It is not fixed in Phase 12, because StatePolicy is frozen
here.
→ **Dogfood workaround:** the local `mindrium_dogfood` DB now has an
active week-4 `treatment_progress` doc for the test account
(`note: phase12.1 dogfood: forced week 4`). Delete it to go back to
week 1.

**N2 — Remote Realizer repeated the previous turn verbatim (class G).**
Deterministic replay gives the correct `alternative` question at turn 4.
The GPT realization copied its own previous sentence, and validation
didn't reject it. This is a wording-layer issue, which is frozen in
Phase 12, so it's only recorded. Candidate later check: reject a
realization identical to the previous assistant message.

**F2 corpus (real, dogfood):**
1. 아까 말했잖아 지금 준비를 못해서 불안하다고 (repeatedQuestion, mixed
   with a content restatement, missed)

## Phase 12.1 — dogfood protocol (to be done on device)

Build the same way as Phase 10.7E (local backend, SM A716S). Type each
line yourself, and **rephrase it**; don't copy these lines. Screenshot
each reply, or note down: the state, whether the reply asked a question,
and whether it quoted your complaint.

| Group | What to do | Watch for |
|---|---|---|
| A | Normal worry for 2 turns, then complain about repetition in your own words | Is it recognized (a "맞아요, 비슷한 질문을…" reply), or does it ask a new question? |
| B | Ask it to stop asking and just listen, in your own words | No-question reply? Does questioning resume right after? |
| C | Talk about worries that repeat ("같은 생각이 계속…") | Must **not** get a repair reply |
| D/E | After a repair reply, answer normally for 2–3 more turns | Does intervention quote your complaint (F3)? Any loop? Any dead end? |

Send me the phrasings that failed. They go into the F2 corpus as
real-user data, and the regex decision is made from that data rather
than from my examples.

## Regression

- `flutter test`: 1126 → **1149/1149** (+23 in this suite, counting the
  single-turn probe group)
- `flutter analyze`: unchanged, 5 pre-existing infos
- Production code: **not modified**
