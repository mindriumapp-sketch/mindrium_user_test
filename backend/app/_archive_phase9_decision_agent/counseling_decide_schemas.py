from typing import List, Literal, Optional

from pydantic import BaseModel, Field

# Phase 9.1: contract for POST /counseling/decide.
#
# This endpoint is NOT the sentence-realization endpoint (/counseling/realize
# stays untouched). It is a SELECTION endpoint: the model only picks among
# the ids the client already computed as allowed (allowed_actions /
# candidate_goal_ids / eligible_intervention_ids) — it never drafts reply
# text and never invents a new action/goal/intervention id. See
# docs/counseling/remote_gpt_realizer_integration.md for the sibling
# realize-endpoint's responsibility boundary; this endpoint mirrors that
# separation for the selection step instead of the wording step.
#
# Not wired into any production/shadow path yet (Phase 9.2's job) — this
# phase only establishes the contract.


class RemotePersonalContext(BaseModel):
    has_relevant_past_issue: bool = False
    has_previous_alternative_thought: bool = False
    has_helpful_activity: bool = False
    has_unfinished_issue: bool = False
    sud_trend: Optional[str] = None


class RemoteCbtKnowledgeRef(BaseModel):
    id: str
    title: str
    tags: List[str] = Field(default_factory=list)


class RemoteConversationTurn(BaseModel):
    role: Literal["user", "assistant"]
    text: str


class RemoteDialogueProgress(BaseModel):
    asked_goal_ids: List[str] = Field(default_factory=list)
    used_intervention_ids: List[str] = Field(default_factory=list)
    is_first_reflect_turn: bool = True


class CounselingDecideRequest(BaseModel):
    user_message: str
    current_state: str
    allowed_actions: List[str] = Field(default_factory=list)
    candidate_goal_ids: List[str] = Field(default_factory=list)
    eligible_intervention_ids: List[str] = Field(default_factory=list)
    forbidden_constraints: List[str] = Field(default_factory=list)
    goals_exhausted: bool = False
    goal_exhaustion_policy: str = "repeatLast"
    has_closing_summary_target: bool = False
    relevant_personal_context: RemotePersonalContext
    allowed_cbt_knowledge: List[RemoteCbtKnowledgeRef] = Field(default_factory=list)
    recent_conversation: List[RemoteConversationTurn] = Field(default_factory=list)
    dialogue_progress: RemoteDialogueProgress

    @property
    def is_available(self) -> bool:
        """Phase 9.2D: whether ANY action is selectable this turn. Mirrors
        `PolicyBoundary.allowedActions.isEmpty` on the Dart side — computed
        the same way (client sends the already-computed `allowed_actions`;
        this is just naming the derived fact, not re-deriving policy)."""
        return len(self.allowed_actions) > 0


class RemoteReflectionTarget(BaseModel):
    type: Literal["text", "none"]
    text: Optional[str] = None


class CounselingDecideResponse(BaseModel):
    # Phase 9.2D (decide_v2): explicit outcome discriminator. "unavailable"
    # is valid ONLY when the request's allowed_actions was empty — see
    # `decide_turn`'s enforcement. This closes the gap the real
    # phase9_2b_frozen_v1/decide_v1 evaluation found: 8/89 scenarios had
    # allowed_actions=[] and the model invented a non-existent
    # "selectedAction": "none" because it had no valid way to say "nothing
    # is selectable" — decide_v1's response schema had no such outcome.
    status: Literal["selected", "unavailable"] = "selected"

    selectedAction: Optional[str] = None
    selectedGoalId: Optional[str] = None
    selectedInterventionId: Optional[str] = None
    reflectionTarget: Optional[RemoteReflectionTarget] = None

    # Phase 9.2A.1: reproducibility metadata for shadow-evaluation logging.
    # model_identifier/prompt_version are always filled (the backend always
    # knows them); token counts are best-effort — left null if the upstream
    # response doesn't carry `usage` for some reason, rather than guessing.
    modelIdentifier: Optional[str] = None
    promptVersion: Optional[str] = None
    inputTokens: Optional[int] = None
    outputTokens: Optional[int] = None
