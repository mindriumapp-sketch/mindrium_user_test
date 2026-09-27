# Counseling chatbot docs

**Start here: [`chatbot_architecture.md`](chatbot_architecture.md)** — the
current-state source of truth for the whole `디지털 CBT 상담` feature
(code structure, realization contract, canary rollout, known
limitations). Everything else in this directory either supports it or
is historical record.

## Active

- [`chatbot_architecture.md`](chatbot_architecture.md) — current architecture, updated as the system changes.
- [`phase10_7_baseline.md`](phase10_7_baseline.md) — the frozen `counseling-v1-clean-baseline` snapshot Phase 11 builds on top of (deterministic selection + validated Remote wording + safe fallback + rollout infra + cleaned production tree).
- [`phase11_1_selection_interaction_repair_design.md`](phase11_1_selection_interaction_repair_design.md) — **current phase**: Selection Policy & Interaction Repair, problem/contract freeze.
- [`adaptive_dialogue_policy.md`](adaptive_dialogue_policy.md) — forward-looking design for expanding GPT's role beyond wording-only.
- [`affective_system.md`](affective_system.md) — avatar/affect-cue subsystem reference.
- [`remote_gpt_realizer_integration.md`](remote_gpt_realizer_integration.md) — the original GPT-realizer integration contract (referenced from `chatbot_architecture.md`).
- [`session_summary_schema.md`](session_summary_schema.md) — session summary JSON contract.
- [`context_feature_gap.md`](context_feature_gap.md) — legacy-context vs current-retrieval gap analysis.

## Archive

[`archive/`](archive/) holds phase-by-phase build/evaluation history —
Phase 8 (selection architecture), Phase 9 (remote-decision-agent
evaluation, NO-GO), Phase 10 (realization quality: failure taxonomy,
semantic realization contract, LLM-realization dev/holdout evaluation,
canary rollout spec/infra/Stage 1 activation, dogfooding, production
cleanup — now closed as of `counseling-v1-clean-baseline`, 2026-09-28).
Every current fact from these has already been consolidated into
`chatbot_architecture.md`/`phase10_7_baseline.md`. Kept for provenance
(why the current design is what it is, what was tried and rejected), not
as something a new contributor needs to read to understand the system
today.
