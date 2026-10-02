# Phase 14.X: Bounded LLM-led 응답 계약. docs/counseling/phase14x_bounded_llm_led.md.
# 코드가 넘긴 사실·기법·앱 사실 id 안에서만 고른다. id 검증은 앱(Dart) 검증기가 한다.
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Domain = Literal["counseling", "app_guide", "mixed"]
Move = Literal[
    "acknowledge", "restate", "reflect_emotion", "clarify", "open_question",
    "ask_evidence", "ask_alternative", "ask_probability", "connect_past_record",
    "summarize", "listen", "repair", "intervention_question", "integrate",
    "answer_app", "offer_close", "finalize",
]
InterventionStep = Literal["prompt", "integration"]
SessionAction = Literal["continue", "offer_close", "finalize"]

DOMAINS = Domain.__args__
MOVES = Move.__args__
SESSION_ACTIONS = SessionAction.__args__


class Turn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    role: Literal["user", "assistant"]
    text: str = Field(..., max_length=1200)


class Fact(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str = Field(..., max_length=120)
    kind: str = Field(..., max_length=40)
    text: str = Field(..., max_length=600)


class Technique(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str = Field(..., max_length=120)
    name: str = Field(..., max_length=120)
    week: int
    purpose: str = Field(..., max_length=600)
    question_guide: str = Field("", max_length=600)


class Progress(BaseModel):
    """참고용 진행 상황. 응답을 강제하지 않는다."""

    model_config = ConfigDict(extra="forbid")
    stage: str = Field(..., max_length=20)
    round_worry: Optional[str] = Field(None, max_length=400)
    asked_goals: List[str] = Field(default_factory=list)
    intervention_pending: Optional[str] = Field(None, max_length=120)
    intervention_used: List[str] = Field(default_factory=list)
    closing_proposed: bool = False
    continuation_used: bool = False
    # respond_v2: structured progress evidence (advisory, not a script)
    concern_identified: bool = False
    thought_identified: bool = False
    evidence_explored: bool = False
    alternative_explored: bool = False
    intervention_available: bool = False
    intervention_completed: bool = False
    recent_no_progress_turns: int = 0
    exchange_count: int = 0
    recent_questions: List[str] = Field(default_factory=list, max_length=3)
    # respond_v3: exploration has run its course for this worry
    explore_closed: bool = False
    exploratory_questions: int = 0


class CounselingRespondRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: str = Field(..., min_length=1, max_length=64)
    current_week: int = Field(..., ge=0, le=8)
    conversation: List[Turn] = Field(..., min_length=1, max_length=12)
    progress: Progress
    user_facts: List[Fact] = Field(default_factory=list, max_length=20)
    techniques: List[Technique] = Field(default_factory=list, max_length=10)
    app_facts: List[Fact] = Field(default_factory=list, max_length=40)
    # respond_v3: approved definitions of CBT terms (from the corpus), with ids
    concepts: List[Fact] = Field(default_factory=list, max_length=25)


class InterventionChoice(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    id: str
    step: InterventionStep


class AgentOutput(BaseModel):
    """모델 출력의 유일하게 허용되는 형태 (respond_v2).

    문장(statement)과 질문(question)을 나눠 질문은 최대 1개만 가능하다. 기법은 하나의
    객체(id와 단계)라서 id 없는 기법 단계는 만들 수 없다.
    """

    model_config = ConfigDict(extra="forbid", strict=True)
    domain: Domain
    dialogue_moves: List[Move] = Field(..., min_length=1, max_length=5)
    intervention: Optional[InterventionChoice]
    used_user_fact_ids: List[str]
    used_app_fact_ids: List[str]
    used_concept_ids: List[str]
    session_action: SessionAction
    statement: str = Field(..., min_length=1, max_length=500)
    question: Optional[str] = Field(None, max_length=200)


class CounselingRespondResponse(BaseModel):
    request_id: str
    output: AgentOutput
    model: str
    prompt_version: str
    latency_ms: int
    prompt_tokens: int = 0
    completion_tokens: int = 0
