# Phase 14.2A: 의미 분류기(인식 전용) 계약.
# docs/counseling/phase14_dialogue_moves.md 5.1절. 분류기는 다음 상태, move,
# CBT, 마무리 여부, 응답 문장을 반환하지 않는다.
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

ContentType = Literal[
    "situation",
    "worry_thought",
    "meaningful_answer",
    "low_information",
    "emotion_expression",
    "meta_interaction",
    "app_guide",
    "mixed",
]
InteractionSignal = Literal[
    "none",
    "repeated_question",
    "stop_questioning",
    "assistant_not_understood",
    "process_resistance",
    "closing_accept",
    "closing_continue",
]
OpenContent = Literal["none", "elaboration", "new_worry", "new_evidence"]

CONTENT_TYPES = ContentType.__args__
INTERACTION_SIGNALS = InteractionSignal.__args__
OPEN_CONTENTS = OpenContent.__args__


class CounselingClassifyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str = Field(..., min_length=1, max_length=64)
    # 이번 사용자 발화와 직전 상담자 발화만 보낸다. 대화 전체를 보내지 않는다.
    user_text: str = Field(..., min_length=1, max_length=1000)
    assistant_prev: Optional[str] = Field(None, max_length=600)


class LabelConfidence(BaseModel):
    """모델이 스스로 매긴 값. 보정된 확률이 아니다(분석용)."""

    model_config = ConfigDict(extra="forbid")

    content_type: float = Field(..., ge=0.0, le=1.0)
    interaction_signal: float = Field(..., ge=0.0, le=1.0)
    open_content: float = Field(..., ge=0.0, le=1.0)


class ClassifierLabels(BaseModel):
    """모델 출력의 유일하게 허용되는 형태. 다른 키가 있으면 전체를 거부한다."""

    model_config = ConfigDict(extra="forbid", strict=True)

    content_type: ContentType
    interaction_signal: InteractionSignal
    open_content: OpenContent
    confidence: LabelConfidence


class CounselingClassifyResponse(BaseModel):
    request_id: str
    labels: ClassifierLabels
    model: str
    prompt_version: str
    latency_ms: int
    prompt_tokens: int = 0
    completion_tokens: int = 0
