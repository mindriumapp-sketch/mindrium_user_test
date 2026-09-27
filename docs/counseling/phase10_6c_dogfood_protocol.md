# Phase 10.6C-DOGFOOD — Stage 1 Operational Observation Protocol

**Status: frozen before dogfooding starts.** This document fixes scope,
what to record, and exit criteria *before* any real internal session
runs, so results aren't judged against a standard invented after seeing
them.

Phase 10.6C-OBS verified the **mechanism** (routing, fallback, telemetry
shape) against a real backend with scripted calls. What that pass cannot
verify — because it requires an actual person having an actual multi-turn
conversation — is whether Remote wording holds up as *continuously
natural* across a real session, and whether real-network latency/fallback
frequency are operationally acceptable. That is this protocol's only job.

## Scope (fixed, do not expand)

```
Accounts       : 1-3 real internal accounts, explicitly added to
                 internalAccountEmailAllowlist
Rollout stage  : internalOnly (unchanged)
Sessions       : ~10-20 real counseling sessions
Eligible turns : ~30-50 Remote-eligible Explore/Reflect turns
                 (not a statistical re-proof — Phase 10.5B's unseen
                 holdout already established efficacy; this sample size
                 exists only to surface operational anomalies)
```

**No changes permitted during this phase**, regardless of what dogfooding
surfaces: `realize_v2` prompt, `CounselingRealizationSpec`,
`CounselorAgent`/selection policy, `HybridTurnRouter` boundary. If
dogfooding surfaces something that looks like it needs one of these
changed, that observation gets logged and deferred — it does not get
fixed inline mid-protocol.

`exhausted_repeat` stays tagged as the known selection-layer limitation
from `phase10_5a2_context_audit.md` (Track A) and is excluded from the
Realizer's own pass/fail judgment here, exactly as in every prior Phase
10.5/10.6 evaluation. A second, distinct selection-layer category —
the selection/router layer failing to recognize a **meta-conversation**
turn (a comment about the system's behavior, e.g. "왜 똑같은 말을
반복하지?", not new worry content) and re-probing the same exhausted
content instead of repairing the interaction — is *also* excluded from
the Realizer verdict for the same reason (it is not a wording defect),
but is tracked as its own category, not folded into `exhausted_repeat`.
See `phase10_6c_dogfood_log.md`'s findings taxonomy (layers 3 vs 4) and
backlog items A/B for why these stay separate.

**Build boundary**: findings and the 30-50 eligible-turn sample must be
attributed to a specific dogfood build (see `phase10_6c_dogfood_log.md`)
— a UI-level fix (e.g. the duplicate-bubble/fallback-quoting fixes found
during this phase) changes the observation condition even though it
never touches Remote efficacy, selection, or the realization contract.

## To actually start a session

1. ~~Add the real account email(s) to `internalAccountEmailAllowlist`~~ —
   done: `sehyun712@skku.edu` is registered
   (`internal_account_allowlist.dart`, verified by
   `internal_account_allowlist_test.dart`, 887/887 suite green).
2. Build/run with `--dart-define=COUNSELING_REMOTE_REALIZER=true` (kill
   switch left at its default `false`).
3. Use the app as that account, having a real counseling conversation.
4. Watch `flutter logs` (or IDE console / DevTools Logging, filtered to
   `counseling.realization`) — each Remote-eligible turn emits one
   `RealizationTelemetryEvent` log line.
5. After each session, transcribe the observed turns into the
   aggregate table and flag any turn against the issue checklist below.

## Aggregate table (fill in as sessions accumulate)

| Metric | Observed |
|---|---|
| Remote eligible turns (total) | |
| Remote success — count / rate | |
| Deterministic fallback — count / rate | |
| `question_count_mismatch` — count / rate | |
| timeout / connection error — count | |
| p50 latency | |
| p95 latency | |
| CheckIn Remote call | must stay 0 |
| Intervention Remote call | must stay 0 |
| Closing Remote call | must stay 0 |
| routing violation | must stay 0 |
| hallucinated fact / unauthorized CBT content | must stay 0 |
| fallback failure (broken/empty reply reached user) | must stay 0 |
| telemetry raw-text leak | must stay 0 |

## Per-turn issue checklist (mark only when something is wrong)

```
[ ] meaning diverged from the underlying CounselorDecision
[ ] question's goal/target changed
[ ] unnatural or mechanical wording
[ ] fabricated a user fact
[ ] response too slow
[ ] repeated same target/question despite new input (goal exhaustion —
    known selection-layer limitation, log it, don't count against Realizer)
[ ] ignored meta-feedback about the conversation itself (e.g. "왜 같은
    말을 반복해?") and kept probing worry-content instead of repairing —
    known selection-layer limitation, separate from goal exhaustion above,
    don't count against Realizer
[ ] other
```

## Stage 1 hard exit criteria (frozen now, evaluated after dogfooding)

```
routing violation                 = 0
CheckIn/Intervention/Closing call = 0
hallucinated user fact             = 0
unauthorized CBT content           = 0
fallback failure                   = 0
raw telemetry leakage              = 0
```

Fallback rate, `question_count_mismatch` rate, and p95 latency are
**measured, not pass/failed** at this sample size — the goal is to obtain
real numbers, not to construct a post-hoc threshold and grade a small
sample against it. Where Phase 10.5C already froze a latency budget, that
existing budget applies as-is; no new threshold is invented here.

## After this phase

If the hard exit criteria hold: proceed to **Phase 10.6D-PREP** (runtime
remote kill switch + backend aggregate telemetry — both deferred
prerequisites for any external-user pilot, not built yet). A
compile-time-only kill switch is acceptable for internal dogfooding but
explicitly not for a 5-10% external pilot, since an incident there would
need to be stoppable without waiting on a rebuild/release.

```
10.6C implementation              done
10.6C-OBS mechanism verification  done
10.6C-DOGFOOD (this phase)        real internal sessions, in progress
        -> pass
10.6D-PREP                        remote kill switch, backend telemetry
        ->
10.6D                             5-10% pilot
```
