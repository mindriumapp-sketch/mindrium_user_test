from typing import List, Literal, Optional

from pydantic import BaseModel, Field

# GPT는 상담 전략을 정하지 않는다. Harness가 이미 확정한 초안을 자연스러운
# 한국어로 다듬는 선택적 표현 계층이다. 자세한 책임 경계는
# docs/counseling/chatbot_system.md 9절 참고.


class RecentTurn(BaseModel):
    role: Literal["user", "assistant"]
    text: str


class CounselingRealizeRequest(BaseModel):
    request_id: str
    prompt_version: str = "remote-realizer-v1"
    deterministic_draft: str
    reflection_target: str
    question_goal: str
    required_act: str
    # required_act 대신 골라도 되는 행위 후보. 비어 있으면 required_act로만
    # 응답해야 한다. docs/counseling/chatbot_system.md 4절.
    allowed_acts: List[str] = Field(default_factory=list)
    affect: Optional[str] = None
    tone: str = "warm, calm, concise"
    recent_conversation: List[RecentTurn] = Field(default_factory=list)
    allowed_cbt_facts: List[str] = Field(default_factory=list)
    forbidden_behaviors: List[str] = Field(default_factory=list)
    # Phase 10.5A.2 Track B: grounded 0-10 rating when this turn's target is
    # a bare SUD-style numeric reply (e.g. "7점이요") — additive, optional,
    # so decide_v1/realize_v1-era clients omitting it are unaffected.
    sud_rating_value: Optional[int] = None


class CounselingRealizeResponse(BaseModel):
    request_id: str
    reply: str
    # 실제로 표현한 발화 행위. allowed_acts가 비어 있었으면 항상 required_act와
    # 같다. 클라이언트(RemoteLlmRealizer)가 allowed_acts 안에 있는지 다시
    # 검증한다 — 여기 값은 참고용이며 신뢰 경계가 아니다.
    chosen_act: str
    model: str
    prompt_version: str
    latency_ms: int
