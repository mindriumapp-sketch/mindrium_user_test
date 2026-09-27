# Archived phase docs

Historical build/evaluation record, superseded by
[`../chatbot_architecture.md`](../chatbot_architecture.md) as the
current-state reference. Kept for provenance — these documents are the
evidence trail for *why* the system is built the way it is (what was
tried, measured, and rejected or adopted), not something you need to
read to understand today's behavior.

- `phase8/` — the `PolicyBoundary`/`CounselorAgent` selection architecture design.
- `phase9/` — evaluation of an LLM choosing counseling *selection* (not wording); concluded NO-GO / Level 0.
- `phase10/` — realization-quality build log: failure taxonomy, the semantic realization contract, the semantic-deterministic realizer, LLM-realization dev/holdout evaluation, and canary rollout spec/infrastructure — all the way up through Stage 1 activation and mechanism verification.
