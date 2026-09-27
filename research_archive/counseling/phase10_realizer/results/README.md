# Phase 10 realizer evaluation results (raw captures)

These are the raw real-API-call captures behind the Phase 10.5 GO
decision for `RemoteLlmRealizer`, previously living only in `/tmp` (never
committed, referenced by name from `docs/counseling/phase10_5a_manifest.md`,
`phase10_5a2_context_audit.md`, `phase10_3_semantic_realizer.md`, and
`phase10_6c_obs_dogfood_verification.md`). Moved here as part of Phase
10.7 cleanup so the evidence trail doesn't depend on a temp directory
surviving.

- `phase10_5a_full_requests.json` — full dev-eval request/response capture (72 scenarios, 48 eligible).
- `phase10_3_dev_comparison.json` — Phase 10.3 legacy-vs-semantic-deterministic dev comparison export.
- `phase10_5a_smoke_validated.json` — smoke-test validation pass before the full Phase 10.5A run.
- `phase10_5a2_trackA_responses.json` — Track A (`exhausted_repeat`) ablation responses.
- `phase10_6c_backend_access.txt` — backend access log used to independently confirm zero real API calls during Phase 10.6C-OBS's boundary checks (`.txt` rather than `.log` so git doesn't ignore it — see `.gitignore`'s `*.log` rule).

These are historical evidence, not something production code reads.
