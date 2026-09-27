# Phase 10.6C-DOGFOOD — Findings Log

Running log for real internal dogfooding against
`phase10_6c_dogfood_protocol.md`'s frozen protocol. This document exists
to keep three things that are easy to conflate cleanly separated: what
was evaluated pre-dogfood, what broke only once a real person used the
real app, and what remains a genuinely separate, deferred selection-layer
problem.

## Build boundary — Dogfood Build A vs Build B

Two real device builds were installed during this phase, and they are
**not the same observation condition**. Sessions run under Build A must
not be pooled with Build B sessions when counting Stage 1's 30-50
eligible-turn sample — Build A is kept only as defect-discovery evidence
for the two bugs it surfaced.

```
Dogfood Build A (first real-device install)
  - lib/chatbot/chatbot_main.dart:    instantEmpathy: useRemoteRealizer
  - lib/features/counseling/counseling_harness.dart:
      rejected-Remote fallback = turnPlan.deterministicReply (raw,
      verbatim-quoting legacy template)
  - Findings: duplicate bubbles (instant-empathy placeholder + real
    reply shown as two disconnected messages), quoted-legacy fallback
    text reaching the user, GoalExhaustionPolicy repeat pattern, a
    meta-feedback turn ignored (see taxonomy below)

Dogfood Build B (current, installed on SM A716S)
  - instantEmpathy: false at this call site (feature itself unchanged/
    still tested in counseling_provider_test.dart, just not wired here)
  - rejected-Remote fallback now routes through the already-built
    SemanticDeterministicResponseRealizer (Phase 10.3/10.3B) — no
    verbatim quoting
  - Selection policy, realize_v2 prompt, CounselingRealizationSpec,
    HybridTurnRouter: byte-for-byte unchanged from Build A
  - Regression-tested: 888/888 (`flutter test test/counseling/`),
    including a new assertion that the rejected-Remote fallback text
    contains neither curly-quote character
  - Verified live on-device: single bubble per turn, natural SUD
    acknowledgment on an accepted Remote turn
```

Both fixes are currently **uncommitted local changes** (`git status`:
`lib/chatbot/chatbot_main.dart`, `lib/features/counseling/counseling_harness.dart`
modified; `test/counseling/canary_rollout_integration_test.dart` new) —
this log's Build A/B boundary is defined by the diff described above,
not by a commit SHA, until/unless these are committed.

**Going forward: collect the Stage 1 30-50 eligible-turn sample from
Build B only.** Build A's turns are preserved below as defect-discovery
evidence, not folded into the aggregate table in
`phase10_6c_dogfood_protocol.md`.

## Deployment boundary — local dogfood backend vs shared server

Also not to be conflated:

```
Local dogfood backend (http://192.168.123.107:8090, this Mac)
  - Runs this checkout's backend/app, including realize_v2 and the
    sudRatingValue signal
  - This is the only backend Phase 10's /counseling/* endpoints exist on
  - What Build A and Build B were both tested against

Shared server (http://115.145.134.180:8070)
  - The debug build's default backend before this phase's dogfood setup
  - Has zero /counseling/* routes (confirmed via its own openapi.json) —
    an older deployment that predates the counseling chatbot entirely
  - Not a target Phase 10 has been verified against, and not something
    this phase changed — a separate deployment blocker, out of scope
    here (whoever owns deploying backend/ to that host would need to
    ship this checkout's backend/app to it before any non-local device
    could exercise Remote realization)
```

"Implemented in production code" and "deployed to a shared/production-like
backend" are two different claims — only the former is true today.

## Findings taxonomy (four layers — do not collapse)

### 1. Remote Realizer quality
Verified via A/B review + unseen holdout (`phase10_5_llm_realization_evaluation.md`,
`phase10_5b_manifest.md`) and reconfirmed live in Build B dogfooding (the
SUD "7" turn was accepted and acknowledged naturally). No new finding
this phase.

### 2. App/UI integration defects
Found only once a real person used the real app screen — the blind
review artifacts showed one realized string per scenario, never the full
chat UI, so neither of these could have surfaced there:
- Duplicate bubbles (`instantEmpathy` placeholder shown alongside, not
  replaced by, the real reply)
- Quoted-legacy text reaching the user on Remote rejection

Both fixed in Build B (see boundary above).

### 3. Selection-policy problem — goal exhaustion
`GoalExhaustionPolicy.repeatLast` re-selects the same `reflectionTarget`/
`questionGoal` when it finds no new signal in the user's reply. Remote is
still called and still faithfully realizes the (identical) material it's
given — this is not a Remote quality defect, exactly the Track A
conclusion from `phase10_5a2_context_audit.md`. Reproduced live this
session (same homework-related question asked twice, verbatim).

### 4. Meta-conversation / interaction-repair problem — NOT the same as #3
Distinct failure, worth tracking separately rather than filing under
"repeat": the user's turn was **"왜 똑같은 말을 반복하지?"** — a comment
about the *system's behavior*, not new content about their worry. The
selection/router layer has no way to recognize a meta-comment as
anything other than ordinary worry-content, so it fed the same
(exhausted) target back through the pipeline and asked the identical
question a third time. Wording cannot fix this — no realizer output
could have been the right response, because the turn needed a different
*dialogue act* (acknowledge-and-repair), not better phrasing of the same
act.

## Backlog — future selection-layer phase (not Phase 10, do not start now)

Two separate problem statements this dogfooding session surfaced
concrete real examples for:

```
A. Goal exhaustion recovery
   Instead of always repeatLast, can the selection layer choose:
   summarize / listenWithoutQuestion / revisitPreviousIssue /
   transition / closing?

B. User meta-feedback recovery (new — not previously identified)
   Detect turns like "왜 같은 말을 반복해?" / "아까도 물어봤잖아" /
   "그 질문 그만해" and switch out of ordinary worry-content selection
   into an interaction-repair act, instead of continuing to probe
   content the user just said isn't the problem.
```

B likely needs a new process signal / dialogue act (e.g.
`metaConversation` / `interactionRepair`) that does not exist in the
current `DialogueAct` enum or selection policy. Adding it now would
break Phase 10's selection-freeze invariant — stays backlog, scoped for
whenever selection-layer work is picked up next.

## Structural conclusion (current)

**Remote wording generation itself works.** The two real repeat failures
observed in live dogfooding trace to the selection layer's inability to
(a) recover from goal exhaustion, and (b) recognize meta-conversation —
neither is a Remote realization defect. This is not a Phase 10 failure;
it is Phase 10 dogfooding successfully producing a concrete, real-example
problem definition for the selection-policy phase that comes after it.

## Session log

| Build | Session | Turns | Findings |
|---|---|---|---|
| A | 1 (device, SUD "7" + placeholder inputs) | ~3 | duplicate bubbles; quoted fallback on 1 SUD turn; repeat pattern on placeholder inputs (not counted — synthetic content) |
| A | 2 (real content: 숙제/졸림 exchange) | ~4 | `exhausted_repeat` reproduced with real content; meta-feedback turn ignored (layer 4 above) |
| B | — | — | fixes verified (single bubble, no-quote fallback path unit-tested, natural SUD ack observed); real 30-50 turn collection not yet started |
