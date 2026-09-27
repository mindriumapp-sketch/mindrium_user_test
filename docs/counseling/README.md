# Counseling chatbot docs

**Start here: [`chatbot_architecture.md`](chatbot_architecture.md)** — the
current-state source of truth for the whole `디지털 CBT 상담` feature
(code structure, realization contract, canary rollout, known
limitations). Everything else in this directory either supports it or
is historical record.

## Active

- [`chatbot_architecture.md`](chatbot_architecture.md) — current architecture, updated as the system changes.
- [`adaptive_dialogue_policy.md`](adaptive_dialogue_policy.md) — forward-looking design for expanding GPT's role beyond wording-only.
- [`affective_system.md`](affective_system.md) — avatar/affect-cue subsystem reference.
- [`remote_gpt_realizer_integration.md`](remote_gpt_realizer_integration.md) — the original GPT-realizer integration contract (referenced from `chatbot_architecture.md`).
- [`session_summary_schema.md`](session_summary_schema.md) — session summary JSON contract.
- [`context_feature_gap.md`](context_feature_gap.md) — legacy-context vs current-retrieval gap analysis.
- [`phase10_realization_quality.md`](phase10_realization_quality.md) — running index/changelog across every Phase 10 sub-phase (kept active — it's a chronological record still being appended to, not superseded by the architecture doc).
- [`phase10_6c_dogfood_protocol.md`](phase10_6c_dogfood_protocol.md) / [`phase10_6c_dogfood_log.md`](phase10_6c_dogfood_log.md) — Stage 1 real-device dogfooding, in progress.
- [`phase10_7a_cleanup_inventory.md`](phase10_7a_cleanup_inventory.md) — this cleanup phase's KEEP/ARCHIVE/DELETE audit, in progress.

## Archive

[`archive/`](archive/) holds phase-by-phase build/evaluation history
(Phase 8 selection architecture, Phase 9 remote-decision-agent
evaluation, Phase 10.1–10.6b realization-quality build log) — every
current fact from these has already been consolidated into
`chatbot_architecture.md`. Kept for provenance (why the current design
is what it is, what was tried and rejected), not as something a new
contributor needs to read to understand the system today.
