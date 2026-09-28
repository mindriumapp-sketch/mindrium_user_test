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

### Session 2 (week 4, build 7c202cc, Remote Realizer on)

| # | Input | State | Device reply | Deterministic replay |
|---|---|---|---|---|
| 1 | 다음주에 여행이 계획 되어있는데 같이가는 친구들이랑 어색해 | checkIn | ok | same |
| 2 | 6 | explore | ok ("가장 걱정되는 순간은?") | same |
| 3 | 재밌게 놀아야하는데 어색해서 서로 조금 불편하게 놀까봐 걱정돼 | reflect | **N2**: turn 2's explore question again | clarify: "가장 걸리는 부분을 조금 더 구체적으로…" |
| 4 | 서로 불편할까봐 걱정된다고 | reflect | **N2**: turn 3's reply repeated **verbatim** | clarify: "어떤 생각이 스쳐 지나갔는지…" |
| 5 | 방금 말했잖아 | intervention | **F2 miss**: balanced-thought CBT delivered over the complaint | same |

**N2 upgraded: now the trigger of the complaints.** In both sessions the
user complained right after the GPT realization repeated the previous
sentence. The deterministic plan wanted a different question every time
(evidence → alternative in session 1, clarify → clarify-2 in session 2).
The realized text ignored `questionSentence` and copied the previous
assistant turn, and realization validation accepted it. That's 3
verbatim or near-verbatim repeats in 2 sessions. The Realizer is frozen
in Phase 12, but this is the evidence the freeze asks for before any
change. Candidate (needs approval): the realization validator rejects a
reply whose question matches the previous assistant message, and falls
back to `SemanticDeterministicResponseRealizer`.

**N3 — reflect never leaves clarify for "~할까봐 걱정돼" (class C, target
extraction).** "…서로 조금 불편하게 놀까봐 걱정돼" contains an explicit
feared outcome, but `UserThoughtExtractor.evaluativeThought` /
`thoughtShaped` don't treat it as a thought. Both reflect turns went to
the clarify branch, so no evidence or alternative goal was ever asked
before the budget moved to intervention. This predates Phase 11 and is
recorded only.

**F3:** not exercised. No complaint was detected, so there was nothing to
exclude. The intervention target ("서로 불편할까봐 걱정된다고") is a
content restatement, which is fine.

**F2 corpus (real, dogfood):**
2. 서로 불편할까봐 걱정된다고 (implicit repeatedQuestion: the user
   restates their own words with the quotative "~다고" meaning "I just
   told you". Missed. This one is hard, since the same form can also be
   plain content.)
3. 방금 말했잖아 (explicit repeatedQuestion, missed; the pattern only has
   "방금도 + 질문/얘기 + 했")

Pattern so far (3/3 real items): users refer to **their own previous
statement** ("아까 말했잖아", "방금 말했잖아", "~다고"), not to the
counselor's question. The 11.2 detector only models "you asked the same
question again", which is the core structural gap for 12.3B.

### Session 3 (week 4, build 7c202cc, Remote Realizer on)

| # | Input | State | Device reply | Deterministic replay |
|---|---|---|---|---|
| 1 | 내일 시험이 있어 | checkIn | ok | same |
| 2 | 4 | explore | "내일 시험이 있다는 사실이… 구체적인 계기는 무엇인가요?" | "가장 걱정되는 순간은?" |
| 3 | 내일 시험을 잘 못보면 어떡하지? | reflect | **N2**: turn 2 repeated **verbatim** | clarify-1 (N3 again) |
| 4 | 왜 똑같은 말을해? | reflect | **F2 miss + N2**: turn 2 repeated verbatim a second time | clarify-2 |
| 5 | 왜 똑같은 말 하냐고 | intervention | **F2 miss** + "“왜 똑같은 말을해”라는 생각을… 균형 있게 바꾼다면" | same |

This is the worst outcome observed. The same sentence appeared 3 turns in
a row, both complaints were ignored, and the CBT intervention then
restructured the complaint itself. F3 couldn't prevent this, because
exclusion needs the turn to be detected first. **F2 is a prerequisite for
F3 to take effect.**

- **N2 is now 3/3 sessions.** The deterministic plan asked a different
  question each turn. Every repeat came from the GPT realization.
- **N3 again.** "잘 못보면 어떡하지?" isn't extracted as a thought, so
  both reflect turns went to clarify.

**F2 corpus (real, dogfood):**
4. 왜 똑같은 말을해? (explicit; 11.2 requires "…말을 반복", so a bare
   "말을 해" misses)
5. 왜 똑같은 말 하냐고 (explicit, quotative re-ask)

## Phase 12.3 — repair hardening (N2, F2, F1, F6) and 12.3D re-evaluation

Order followed: F3 (12.3A) → device dogfood (12.1, 3 sessions) → N2 →
F2 (12.3B) → F1 (12.3C) → re-evaluation (12.3D). N2 was added to Phase
12.3 with approval after dogfood showed it causing every complaint.

| Fix | Layer | Production change | Evidence |
|---|---|---|---|
| **N2** realizer copies previous turn | G (Realizer validation) | `RemoteLlmRealizer._validate` adds `repeats_previous_question`: the reply's last question equals the previous assistant question while the plan asked something else, so it falls back to deterministic. Following the plan is never rejected. | 7 tests from real transcripts. Multi-turn with an always-copy API: 0 repeats shown; guard disabled: 5 (mutation check) |
| **F2** detector recall | A (detector) | `DeterministicProcessSignalTurnPlanner`: 4 cue-composition predicates (own-statement reference, same-thing repetition, question repetition, stop/listen), a third-party-subject guard, and exclusion of "질문을 받다". The 11.2 patterns and sentences are unchanged. | Gate frozen **before** the change (`dcd1ca4`): verification recall 2/24 → **24/24**, FP **0** (21 negatives x 4 states), design 4/4, implicit 0/5 (not gated) |
| **F1** recovery loop | D (recovery selection) | `_selectRecovery` reads the previous `goalExhaustionRecovery` and never repeats it. Repair still takes precedence. | repro 2/5 failing → pass; multi-turn loop 2 → **0** |
| **F6** identical repair twice (new, found in 12.3D) | G (process-signal surface) | Repair sentences alternate by the count of immediately preceding same-reason repairs (metadata). The first variant is the original. | multi-turn `consecutiveIdenticalReply` 4 → **0** |

**Caveat on F2 = 24/24.** The same author wrote the holdback and the
detector, and knew the cue families while writing it. Treat 24/24 as an
upper bound. The real generalization check is the next device session.

### 12.3D final metrics (19 scenarios, 102 user turns, all 5 states)

| Metric | Gate | Result |
|---|---|---|
| immediateSameGoalRepeat | 0 | 0 |
| repeatedRecoveryLoop | 0 | 0 (was 2) |
| ignoredMetaFeedback (seen / unseen) | 0 | 0 / 0 (unseen was 6) |
| metaFalsePositive | 0 | 0 |
| metaContentLeakage (detected) | 0 | 0 (was 6) |
| abnormalEarlyTransition | 0 | 0 |
| unauthorizedCbtDecision | 0 | 0 |
| validatorOrMaterializerFailure | 0 | 0 |
| deadEndConversation | 0 | 0 |
| maximumConsecutiveSameGoal | ≤1 | 1 |
| maximumConsecutiveSameRecovery | ≤1 | 1 (was 2) |
| repeatedQuestionShown (N2) | 0 | 0 |
| consecutiveIdenticalReply (F6) | 0 | 0 (was 4) |
| unseen meta detection (frozen 12.3B gate) | ≥80%, FP 0 | 100%, FP 0 |
| *reported:* untaggedMetaLeakage | — | 1 (closing, F5 by design) |
| *reported:* lowInfoTextUsedAsTarget (F4) | — | 5 (backlog, unchanged) |
| *reported:* implicit meta | — | 0/1 |

Dogfood replays: session 3 ("왜 똑같은 말을해?" x2) now gets two different
acknowledgments. Its intervention restructures the real worry, not the
complaint.

`flutter test` **1187/1187**, `flutter analyze` unchanged (5 infos).

### Activation gate / tag: not yet

Every automated gate passes. Two conditions from the plan remain:
1. **Real-device confirmation of these fixes.** The fixes haven't run
   on a device yet.
2. **"No new critical failure in dogfood."** N1 (weeks 1–3 intervention
   dead end) is critical. It predates Phase 11/12 and is assigned to
   Phase 13. Tagging `counseling-v1.1-selection-repair` requires
   explicitly accepting N1 as out of scope for this baseline.

### Remaining backlog
- **Phase 13:** cumulative intervention policy (N1).
- **F4:** low-information semantic target filtering.
- **N3:** "~할까봐 걱정돼" / "~하면 어떡하지" not extracted as thoughts, so
  reflect stays in clarify.
- **F5:** meta feedback in closing.
- Implicit restatement ("~다고") detection, which needs context.
- Mixed worry-plus-complaint messages lose their worry part as a target
  (12.3A tradeoff).
- Semantic-deterministic fallback wording quotes SUD answers as the
  concern ("7점이요 부분이 마음에 걸리시는") (G).

### Session 4 (week 4, build e4b461d, all 12.3 fixes; confirmation run)

| # | Input | State | Device reply | Source |
|---|---|---|---|---|
| 1 | 내일까지 해야할 일이 너무 많아 | checkIn | ok | deterministic |
| 2 | 7 | explore | ok ("…느끼는 이유가 무엇인지…") | GPT |
| 3 | 수업 과제도 해야하고 공모전 준비, 논문 작성, 융합연구 미팅준비 등 할게 진짜 많아 | — | **N4**: "걱정 기록는 홈 → 오늘의 할 일 → 불안 평가에서 확인할 수 있어요." | app-guide route |
| 4 | 갑자기 무슨말이야 | reflect | ok, natural | GPT |
| 5 | 미팅준비가 가장 마음에 걸려 | reflect | **N5**: "미팅준비가 가장 마음에 걸려 부분이 마음에 걸리시는 것 같아요." | semantic-deterministic fallback (GPT reply rejected) |
| 6 | 내일 미팅인데 준비를 하나도 못했어. 교수님께 양해를… 답장이 없어 | intervention | **N6**: "“미팅준비가 가장 마음에 걸려”라는 생각을 함께 살펴보겠습니다…" | deterministic |

Confirmed: no repeated question reached the user (N2 held), no dead end.
No meta complaint was made this session, so F2/F3/F6 weren't exercised.

**User feedback (primary): quoting the user's words back is unnatural.**
The worst case was turn 5. Three different root causes:

- **N5 — fallback template slots a whole clause into a noun position (G).**
  `SemanticDeterministicResponseRealizer` builds `'$clean 부분이 마음에
  걸리시는 것 같아요.'` / `'지금 $clean 때문에…'` / `'$clean 생각이…'`.
  `classifyReflectionTargetShape` only diverts multi-sentence and
  question targets to the generic acknowledgment. A single verb-final
  clause ("…마음에 걸려", "7점이요") passes as if it were a noun phrase.
  **Interaction with the N2 fix:** the new guard sends more turns to this
  fallback, so its ugly surface shows up more often.
- **N6 — deterministic templates parrot verbatim (G), and the target is
  stale (C).** The deterministic realization quotes the raw utterance
  ("“X”라고 말씀해 주셨군요", "“X”라는 생각을 함께 살펴보겠습니다").
  Intervention and checkIn never go through GPT, so nothing paraphrases
  them. Here the target is also the *previous* message: the rich current
  message isn't `thoughtShaped`, so the selector falls back to
  `latestUserMessage` (same family as N3/F4).
- **N4 — intent router misroutes counseling to app guide (new layer: intent
  routing).** The message has no counseling stem (불안/걱정…), and the
  entity signal fires on a single 2+-character keyword overlap with the
  app catalog (e.g. "작성"). The router also ignores that a counseling
  session is in progress. There's a grammar bug in the guide answer too
  ("걱정 기록는" should use 은).

### Session 4 follow-ups fixed (N5, N4)

| Fix | Layer | Change | Evidence |
|---|---|---|---|
| **N5** clause in a noun slot | G (semantic fallback surface) | `SemanticDeterministicResponseRealizer`: declarative and predicate-final targets get the generic acknowledgment; only noun phrases fill "X 부분이 / X 때문에 / X 생각이". This also stops verbatim parroting in the fallback. | 6/6 real-shape repros failed before and pass after; noun phrases keep the specific template. Two 10.3/10.3B tests that pinned the old behavior were updated with the reason. `3c61ba8` |
| **N4** counseling routed to app guide | intent routing | `DeterministicAssistantIntentRouter.detect(counselingInProgress:)`: mid-session (`totalTurns > 0`) only an explicit usage question reaches the app guide, never a bare feature-name overlap. First-turn behavior is unchanged. The guide answer now picks 은/는 by batchim. | Router 7 tests with the real catalog; harness test with production wiring (mutation: disabling the flag fails it); particle test (mutation-checked). `lib/features/assistant/` was untracked and is now committed. `ff69db7` |

N6 (verbatim quoting in the deterministic checkIn/intervention templates,
and a stale intervention target) is **not** addressed here. It needs a
realization-surface design (which states go through GPT, how to
paraphrase without GPT). Recommended as its own phase.

`flutter test` **1206/1206**, `flutter analyze` unchanged.

### N3 fixed — worry-thought recognition (and the N2 root cause)

**Why the realizer rejected GPT (session 4, turn 5).** I rebuilt the exact
request the app sent and replayed it to the local backend 8 times. GPT
returned the previous assistant turn verbatim **8/8**, and the validator
rejected it with `repeats_previous_question` (N2 guard). Ablation, 4 runs
each:

| Variant | Copies |
|---|---|
| no `recent_conversation` | 0/4 |
| forbidden list + "don't repeat the previous turn" | 4/4 (ineffective) |
| plan question semantically different (evidence) | 0/4 |
| previous assistant turn not a similar question | 0/4 |

Copying happens when the plan asks **the same question as the previous
turn** and that turn is in context. The same-question plan came from N3:
the user's worry ("미팅준비가 가장 마음에 걸려") wasn't recognized as a
thought, so reflect asked clarify again.

**Fix (C, target extraction).** `UserThoughtExtractor._hasThoughtShape`
now accepts feared-outcome "~까 봐" (excluding "해볼까 봐"), "~면
어떡하지", and a named concern "X가/이 (가장) 마음에 걸려 / 신경 쓰여".
Negatives stay non-thoughts: plain feeling, situation-plus-feeling ("발표가
내일이라 걱정돼", "시험이 있어서 신경 쓰여").

**Evidence.**
- `worry_thought_recognition_test.dart`: 7 positives, 7 negatives, 3
  dogfood replays at selector level. 9 failed before the fix; all 18 pass.
- Multi-turn: dogfood s2 replay now goes evidence → alternative (was
  clarify → clarify), and s3 gets evidence. All 12.3D gates are still 0.
- **Real GPT, same session-4 context, new plan: verbatim copy 8/8 → 0/8**,
  same-question 0/8, no quoting. The Realizer prompt is unchanged. The N2
  guard stays as a safety net.
- `flutter test` **1224/1224**, `flutter analyze` unchanged.

Open: session 1's copy happened with different plan questions (evidence →
alternative), not reproduced yet. If copies persist on device after this
fix, open a separate `realize_v3` prompt phase.

### Phase 12 closing status

- Remaining before the `counseling-v1.1-selection-repair` tag: one or two
  final device sessions on the N3 build.
- **N1 is deferred to Phase 13 (cumulative intervention policy) as an
  unresolved CRITICAL blocker.** Weeks 1–3 users can't reach closing
  (intervention repeats until the 20-turn cap). **This must be fixed before
  any external rollout that includes weeks 1–3.** v1.1 means the "Phase
  11/12 selection repair baseline", not "production-ready counseling
  chatbot".

### Session 5 (week 4, build b1e6d26, N3 build) and the real N2 root cause

| # | Input | State | Device reply | Finding |
|---|---|---|---|---|
| 3 | 내일 시험인데 공부를 많이 못했어… 못볼까봐 걱정이야 | reflect | generic fallback + **evidence question** | N3 works (not clarify). GPT reply rejected |
| 4 | 저번 기말고사때… 이번에도 망칠까봐 걱정돼 | reflect | generic fallback + **alternative question** | N3 works. GPT rejected again |
| 5 | 다른 관점에서 어떻게 봐야할지 모르겠어 | intervention | app guide: "…기능 정보에서는 해당 내용을 찾을 수 없어요" | **N4b** |
| 6 | 갑자기 무슨 말이야 | intervention | "“다른 관점에서 어떻게 봐야할지 모르겠어”라는 생각을…" | stale target (N6 family) |

**N2 root cause (class F, context propagation). This is a regression I
introduced in Phase 10.6C-DOGFOOD.** Replaying turn 3 to the real
Remote Realizer: GPT returned the previous turn verbatim **6/6**, even
though the plan asked a different question. Ablation showed the copies
disappear whenever the previous assistant turn isn't the last thing in
context. The request showed why: `recent_conversation` was `[user "9",
assistant <previous question>]`, and **the user's current message was
missing**. `CounselingProvider` synced the current turn into
`session.messages` only inside the instant-empathy branch, and Phase
10.6C-DOGFOOD disabled instant empathy (duplicate-bubble fix). From then
on, the model saw a conversation ending on its own question and repeated
it. This explains every copy in sessions 1–5, including session 1's
"different questions" case.

**Fix** (`1e4333e`): the harness appends the current user message to the
**realization request only**. Session history isn't changed, so the
selectors, which rely on history ending on the previous assistant reply,
are unaffected. Nothing is added if the history already ends with the
message. Real-GPT check: s5 T3 copies 6/6 → **0/8**, all accepted; s4 T5
with the old clarify plan 8/8 → **0/6**. The N2 guard and the N3 fix stay;
they're now defense in depth, not the primary fix. `realize_v3` isn't
needed.

**N4b** (`81a859d`): mid-session, a usage pattern ("어떻게 … 봐") also has
to name something in the app (앱/기능/설정/알림/기록/… or a catalog
entity), so "다른 관점에서 어떻게 봐야할지 모르겠어" stays counseling.

`flutter test` **1231/1231**, `flutter analyze` unchanged.

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
