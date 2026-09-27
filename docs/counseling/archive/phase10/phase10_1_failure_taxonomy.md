# Phase 10.1 — Realization Failure Taxonomy

Built from `phase10_1_realization_inventory.md`'s code inventory plus the
Phase 9.2E human blind review evidence (`phase9_2_activation_criteria.md`).
Every category below is grounded in a specific code location, not a
subjective style judgment — see "Representative code" per entry.

| ID | Category | Definition | Representative code | Owner | Severity |
|---|---|---|---|---|---|
| R1 | Verbatim repetition | User's own words are quoted back inside `""` essentially unmodified | `checkIn` line 90 `"$clean"라고 말씀해 주셨군요.`; `intervention._reflectionFor` line 524-538 (every branch); `closing` line 126; 3/4 `explore` candidates; most `reflect` candidates | Materializer | High — the #1 complaint, present in every state |
| R2 | Mechanical acknowledgment skeleton | A small closed set of "...라고 말씀해 주셨군요/느끼시는군요" endings reused across unrelated content | all rotation candidate lists in `turn_plan_materializer.dart` | Materializer | Medium |
| R3 | Abrupt question transition | Reflection and question are two independently-authored sentences with no bridging clause between them | `CounselingTurnPlan.deterministicReply` (`turn_plan.dart:70-73`) — literal `join(' ')` of two strings | Materializer/plan shape (structural) | High — the #2 complaint, present in every state, single root cause |
| R4 | Reflection-question mismatch | The question doesn't reference or build on what was just reflected | `explore`'s `question` (line 179-184) is chosen by simple string-matching on `target`/`askedMoment`, independent of `reflectionSentence`'s actual chosen wording | Materializer | Medium |
| R5 | Generic empathy | Reflection defaults to a content-free fallback when `target` can't be cleanly quoted | `_clarifyingReflectionSentence`'s empty-`clean` fallback (line 311-317); `interventionUnavailable`'s empty-`clean` fallback (line 462) | Materializer | Low — only hit on empty/degenerate target |
| R6 | Redundant semantic repetition | Same idea stated in both reflection and question | Not conclusively found in this pass — flag for Phase 10.2 to check against more transcripts, not confirmed as a code-level pattern here | Materializer (suspected) | Unconfirmed |
| R7 | Intervention bridge failure | No stated reason "why this intervention, now, given what was just discussed" | `InterventionPlan` (`turn_plan.dart`) has no rationale/bridge field at all; `_reflectionFor` (line 524) states only *that* the topic will be examined, never *why this technique* | Materializer / plan shape | High — likely primary driver of intervention's 16/16 bothPoor |
| R8 | Intervention template rigidity | Same fixed sentence per intervention type regardless of specific content, zero rotation | `_reflectionFor`/`_questionFor`/`_goalFor` (lines 490-539) — one literal string per `InterventionType`, the only state group with **zero** `surfaceVariation.select` calls anywhere | Materializer | High — matches 16/16 bothPoor exactly |
| R9 | Closing discontinuity | Closing's reflection is a fresh one-off summary sentence, not connected to the specific flow of the immediately preceding turns | `closing` (line 118-146) only reads `reflectionTarget`, no `recentMessages` input at all | Materializer | Medium |
| R10 | Over-composed turn | Not observed as a real pattern in this codebase — every state caps at exactly reflection + one question (`TurnConstraint.requireExactlyOneQuestion`) | n/a | n/a | Not applicable — structurally prevented |
| R11 | Under-responsive turn | Question ignores the specific content of what the user said this turn, falling back to a generic script question | `checkIn`'s `questionSentence` (line 91) is a **fixed literal every time**, entirely independent of `reflectionTarget`; `intervention._questionFor` (line 490) likewise fixed per type only | Materializer | Medium — checkIn and intervention are the two states with zero question variation |
| R12 | Quote/punctuation artifact | Awkward Korean particle/punctuation joins from blind string interpolation | `.replaceFirst(RegExp(r'[.!?]+$'), '')` patterns throughout `turn_plan_materializer.dart` are a symptom of trying to patch this post hoc (e.g. `_reflectionSentence`'s multi-step `.replaceAll` chain, line 347-353) | Materializer | Low-Medium |

## Category → Phase 9.2E evidence cross-reference

- **R1 + R8 together fully explain `intervention_*` = 16/16 bothPoor**:
  intervention combines the single most rigid template (R8: zero rotation)
  with mandatory verbatim quoting (R1) and no bridge (R7) — three stacked
  issues in one state, and it shows as the worst-scoring category by a wide
  margin.
- **R3 is systemic**, not state-specific — it explains why `bothPoor` is
  spread broadly (62.5% overall) rather than concentrated in one place: the
  `join(' ')` concatenation in `turn_plan.dart:70-73` runs identically for
  every state.
- **checkIn/closing scoring comparatively better** (0/3 and 0/2 bothPoor in
  Phase 9.2E) despite also exhibiting R1 is notable — worth Phase 10.2
  investigating whether their *shorter, more predictable* structure (fixed
  single question, no branching) makes R1's quoting less noticeable than in
  richer states like `intervention`/`reflect`.

## What this taxonomy is not

Not a ranked backlog of "sentences to rewrite." R3, R7, and R8 in particular
are structural (a `join()` with no seam; a plan shape with no rationale
field; a template set with no rotation call) — fixing them well likely means
changing what `CounselingTurnPlan`/`InterventionPlan` *carry*, not just
editing string literals inside `TurnPlanMaterializer`. That design decision
is Phase 10.2's job, not this document's.
