# Phase 10.7A — Production Cleanup Inventory (KEEP / ARCHIVE / DELETE)

**Status: audit complete, no files touched.** This is read-only research —
5 parallel audits (reachability, EmpathyPlanner/RemoteCounselorAgent, docs/
evaluation artifacts, assets/env, test categorization) cross-checked against
actual code (grep/imports/DI wiring), not doc claims. Two of the original
candidate assumptions turned out to be wrong; both are corrected below
before the table, since acting on the original assumption would have been
a real mistake.

## Corrections to the original candidate list

- **`CompactPromptBuilder` is NOT test-only.** It's the base
  `CounselingHarness` constructor's default `promptBuilder`, and —
  critically — `TurnPlanPromptBuilder.build()` (the prompt builder both
  production factories actually use) falls back to
  `CompactPromptBuilder().build(context)` whenever `context.turnPlan ==
  null`. That's a live production fallback path, not dead code. **KEEP.**
- **`TurnRealizationMode.constrainedLlm` does not exist anywhere — not in
  code, not in git history (confirmed via `git log --all -S`).** The
  architecture doc was describing a real thing under a name that was
  never actually used. The real dead code it was gesturing at is
  `CounselingHarness.handleTurn()`'s `else` branch (`RealizationSource
  .localLlm`, raw `llm.generate()` + `CounselingOutputParser.parse()` +
  retry-on-repetition), reachable only when `turnPlanner == null` — which
  never happens through `.deterministic()`/`.remoteGpt()` (both always set
  a turnPlanner), only through bare `CounselingHarness(...)` construction
  in ~24 test call sites. See DELETE table below for the corrected item.

## KEEP — do not touch

```text
CounselingHarness, SafetyGate, CounselingStatePolicy
PolicyBoundary / CounselorAgent (abstract) / DeterministicCounselorAgent / CounselorDecision
CounselorDecisionValidator, TurnPlanAdapter, TurnPlanMaterializer
Deterministic planners/selectors (PolicyPipelineTurnPlanner and all state planners), InterventionRegistry
CounselingRealizationSpec, RealizationSpecBuilder
RemoteLlmRealizer, SemanticDeterministicResponseRealizer, DeterministicResponseRealizer
HybridTurnRouter
RolloutConfig, RealizationTelemetry, internal_account_allowlist
MindriumContextBuilder, CbtKnowledgeRepository / LocalCbtKnowledgeRepository
CounselingProvider, session summary/persistence contracts
CompactPromptBuilder, TurnPlanPromptBuilder  (correction above)
EmpathyPlanner / instantEmpathy (feature + tests — see note)
/counseling/realize backend, /counseling-sessions backend
assets/counseling/knowledge/* (manifest + week0-8, 1:1 match confirmed, no orphans)
assets/app_guide/app_guide_catalog.json (actively used — but see ACTION ITEM below, it's untracked in git)
docs/counseling/chatbot_architecture.md, phase8_boundary_design.md (still-live CounselorAgent contract)
```

**EmpathyPlanner/instantEmpathy note**: implementation + `CounselingProvider`
wiring + tests are all intact and correct. The real production call site
(`chatbot_main.dart`) sets `instantEmpathy: false` as of 2026-09-27 with a
comment stating the feature stays supported for a possible future
re-enable once the duplicate-bubble UX issue (§ dogfood log) is redesigned.
No other call site anywhere in the repo ever sets it `true` outside tests.
**Recommendation: KEEP as-is (dark, not deleted)** — this matches "재도입
계획 있음 → KEEP" from the original candidate framing; the comment is that
stated plan, however informal.

## ARCHIVE — move out of active tree, keep as historical/provenance record

| Item | Why archive, not keep or delete |
|---|---|
| `lib/features/counseling/policy/remote/remote_counselor_agent.dart` | Phase 9 concrete `CounselorAgent` implementation. Confirmed never imported by `counseling_harness.dart`/`production_turn_planner.dart`/`chatbot_main.dart`. Phase 9 formally concluded **NO-GO / Level 0** (`phase9_2_activation_criteria.md:208`, 2026-09-24). Archive, don't delete outright — it's evidence for *why* selection stays deterministic. |
| `remote_counselor_request.dart`, `remote_counselor_response.dart` | DTOs for the above — same reasoning. |
| `lib/features/counseling/policy/remote/remote_counselor_shadow_runner.dart` | Shadow-mode eval runner; `ShadowEvaluationConfig` defaults `enabled: false` even at the type level; never constructed by production. |
| `lib/data/api/counseling_decide_api.dart` (`CounselingDecideApi`/`DioCounselingDecideApi`) | Only client for `/counseling/decide`; never instantiated outside tests. |
| `backend/app/routers/counseling_decide.py`, `backend/app/schemas/counseling_decide.py` | Registered in `main.py` (route is live over HTTP) but has zero Flutter production caller — backend-registered-but-unused. Archive the router registration once decided (see DELETE table — this one's borderline, listed both places, needs your call). |
| `lib/features/counseling/policy/evaluation/{scenario_runner,evaluation_manifest,frozen_scenarios,scenario_fixture,activation_gate_evaluator}.dart` | Phase 9 decision-agent eval harness. `scenario_runner.dart` takes an optional `RemoteCounselorAgent` — decide-specific parts of this go with the above; **do not** blanket-delete this directory — some of it (holdout scenario definitions) is Phase 10 realization eval, a different subject (see next row). |
| `lib/features/counseling/policy/evaluation/{holdout_v1_scenarios,holdout_v2_realization_scenarios,human_review}.dart` | Phase 10.5 realization-quality eval fixtures — this IS the evidence behind the Remote-realizer GO decision. Archive (don't delete): keep runnable from a `research/`-style location, out of the main production tree. |
| `docs/counseling/phase9_2_activation_criteria.md` | Formal NO-GO closure record — keep as historical decision record, move to an archive docs subfolder. |
| `docs/counseling/phase10_1_*.md`, `phase10_2_*.md`, `phase10_3*.md`, `phase10_5*.md`, `phase10_6a_*.md`, `phase10_6b_*.md`, `phase10_6c_stage1_internal_activation.md` | Phase-by-phase build/evaluation history for realization quality and rollout — all superseded by the current state now consolidated in `chatbot_architecture.md`. Archive as provenance, not active reference. |
| `research_data/legacy_npc_engine/` | Already self-labeled "ARCHIVAL REFERENCE... not built/analyzed... review 2027-03-01" in its own README; not imported by `lib/` anywhere. Already effectively archived — just not physically relocated. |
| 5 evaluation JSON files currently sitting only in `/tmp` (`phase10_5a_full_requests.json`, `phase10_3_dev_comparison.json`, `phase10_5a_smoke_validated.json`, `phase10_5a2_trackA_responses.json`, `phase10_6c_backend.log`), referenced by name from committed docs | **Not in the repo at all today** — `/tmp` is ephemeral and could vanish any time, silently breaking the provenance trail the docs point to. Recommend copying these into a committed `research_archive/counseling/phase10_realizer/...` location as part of 10.7C, matching your proposed structure, rather than leaving the evidence trail dependent on a temp directory surviving. |

## DELETE — confirmed dead, safe to remove (pending final green build)

| Item | Confirmation |
|---|---|
| `CounselingHarness.handleTurn()`'s `else` branch (`RealizationSource.localLlm`, raw `llm.generate()`/`CounselingOutputParser.parse()`/retry logic, lines ~461-535) | Confirmed unreachable from `.deterministic()`/`.remoteGpt()` — only reachable via bare `CounselingHarness(...)` with no `turnPlanner`, which happens only in ~24 test call sites. **Caveat**: `LlmService`/`MockLlmService`/`LlmRequest`/`LlmResponse` stay part of the harness's live constructor signature (production still wires a `MockLlmService()` default in) — full removal needs a constructor-signature refactor, not just deleting the branch body. Treat as a scoped follow-up task, not a one-line delete. |
| `assets/npc_rag/` (`rag_singleton_dataset.jsonl` 3.8MB + `rag_singleton_with_embeddings.jsonl` 40MB, ~44MB total) | Zero references anywhere (pubspec/lib/test/backend) and **not even committed to git** (untracked). Strongest delete candidate in this whole audit — pure disk bloat with no history loss from deleting. |
| `assets/npc_images/counselor_profile_surprised.png` | Referenced only inside `AvatarAssetResolver.unusedAssets` — never selectable/renderable by `resolve()`. Low priority (small file), safe whenever convenient. |
| `research_data/legacy_addiction_counseling/*` (5 files) | Already deleted from disk; deletion just needs to be **staged and committed** (`git add -u` for this path) to actually finalize it — right now it's in a half-state (gone from disk, still in git index). |
| `backend/app/routers/auth.py`'s `PLATFORM_VERIFY_URL` fallback read | Read once (`os.getenv("PLATFORM_SIGNUP_URL") or os.getenv("PLATFORM_VERIFY_URL") or ""`), never set or documented anywhere. Genuine orphan. |
| `research_data/legacy_npc_engine/gpt_api.dart`'s `AI_PROXY_BASE_URL` reference | Dead code inside an already-unreferenced legacy file — goes away automatically once/if that directory is deleted rather than archived (see ARCHIVE row above — your call on archive vs delete for this whole directory). |

## Test suite reclassification (53 files: 49 `test/counseling/` + 4 `integration_test/`)

**41 files — MUST KEEP** (safety, policy boundary, CounselorDecision
validity, state transitions, intervention allow-list, Remote
validation/fallback, canary rollout gating, session persistence,
retrieval, ChatPage/STT/TTS, all confirmed reachable from production —
full list in the audit transcript, not repeated here to keep this doc
scannable).

**9 files — RESEARCH REGRESSION** (move out of main suite, keep runnable
separately):
```text
phase8_3b_selector_equivalence_test.dart
phase8_4_production_switch_test.dart      * see note
phase8_counselor_agent_equivalence_test.dart
phase8_policy_boundary_equivalence_test.dart
phase8_planning_test.dart
remote_counselor_agent_test.dart
remote_counselor_request_test.dart
remote_counselor_response_test.dart
remote_counselor_shadow_runner_test.dart
```
\* `phase8_4_production_switch_test.dart` contains one standalone assertion
("`CounselingHarness.deterministic()` no longer wires the legacy composite
planner directly") that's a live production-wiring guard, not just an
equivalence proof — extract that one test into a kept file before moving
the rest.

**0 files — outright delete candidates.** One sub-test (inside
`counseling_provider_test.dart`, exercising `instantEmpathy: true` at the
provider level) was flagged as depending on the EmpathyPlanner
reachability finding — that finding came back "keep, dark feature," so
this sub-test stays too. No test deletions from this audit.

## Action item (not a cleanup item — a bug)

`assets/app_guide/app_guide_catalog.json` is actively loaded by production
code (`local_app_guide_repository.dart`) and declared in `pubspec.yaml`,
but is **untracked in git** (`git ls-files` returns nothing for it). A
fresh clone of this repo would be missing this file and the App Guide
feature would fail to load its corpus. This should be `git add`ed
separately from any cleanup work — it's the opposite of a deletion
candidate.

## Env/define findings — no action needed

8 boolean dart-defines (`ENABLE_WEEK4_HELPFUL_THOUGHT_LOCK`,
`ENABLE_WEEK6_RESOLVE_LOCK`, `ENABLE_WEEK2_RELIEF_LOCK`,
`FORCE_RELAX_OR_ALTERNATIVE`, `COUNSELING_CHAT_AUTO_START`,
`COUNSELING_BENCH`, `COUNSELING_REMOTE_REALIZER`,
`COUNSELING_REMOTE_REALIZER_KILL_SWITCH`) are read in `lib/` but never set
in any committed build config (no CI exists in this repo at all) — this
is confirmed intentional (manual-only, off-by-default feature flags,
including our own dogfood flags), not leftover cruft. No action.
`API_BASE_URL`/`KAKAO_*` are properly wired via `dart_defines/*.json` +
README. Backend `SMTP_*`/`EMAIL_FROM`/`PLATFORM_SIGNUP_URL` are set
locally but absent from `render.yaml` — flagged for an ops/deploy review,
not a code cleanup.

## Recommended next steps (your call on sequencing/scope)

Per the proposed Phase 10.7 sequence — this document IS Phase 10.7A. Next,
if you want to proceed:

```text
10.7B — dead-code removal
  - the localLlm/else branch in counseling_harness.dart (needs a small
    constructor-signature discussion first, not a pure delete)
10.7C — artifact cleanup
  - assets/npc_rag/ deletion (44MB, zero refs, not committed)
  - commit the pending research_data/legacy_addiction_counseling/ deletion
  - copy the 5 /tmp evaluation files into a committed research_archive/
  - git add the orphaned assets/app_guide/app_guide_catalog.json (bug fix, not cleanup)
10.7D — test pruning
  - move the 9 RESEARCH REGRESSION files to a research/ suite (after
    extracting phase8_4_production_switch_test.dart's one live-wiring assertion)
10.7E — final freeze
  - flutter analyze, flutter test, backend tests, production build, real-device smoke test
```

Nothing above has been executed — this is the inventory only, per your own
stated sequencing.
