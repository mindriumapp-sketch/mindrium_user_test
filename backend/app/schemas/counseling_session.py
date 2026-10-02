from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

# 세션이 어떻게 끝났는지.
#   completed   : closing 상태에 도달해 정상 종료
#   interrupted : 사용자가 중간에 화면을 벗어남
CompletionStatus = Literal["completed", "interrupted"]

# coreThought 가 어디서 왔는지. 다음 세션에서 근거를 추적하는 데 쓴다.
ThoughtSource = Literal["current_utterance", "recent_message", "diary"]


class CounselingSessionSummaryBase(BaseModel):
    """한 상담 세션에서 확인된 사실.

    **전체 대화 원문은 저장하지 않는다.** 프롬프트, 모델 raw output, thinking,
    최근 메시지 window 도 저장하지 않는다. 다음 세션 개인화에 실제로 쓰이는
    구조화 요약만 남긴다.

    core_thought / alternative_thought 는 사용자가 말한 문장을 그대로 담으므로
    정신건강 맥락의 민감 정보다. 기존 걱정 일기와 동일 이상의 보호가 필요하다.
    """

    week: int = Field(..., ge=0, le=8)
    completion_status: CompletionStatus
    final_state: Optional[str] = None
    safety_level: Optional[str] = None

    main_concern: Optional[str] = None
    core_thought: Optional[str] = None
    core_thought_source: Optional[ThoughtSource] = None
    alternative_thought: Optional[str] = None

    affect: Optional[str] = None
    sud_start: Optional[int] = Field(None, ge=0, le=10)
    sud_end: Optional[int] = Field(None, ge=0, le=10)

    intervention_used: Optional[str] = None
    activity_recommended: Optional[str] = None
    unfinished_issue: Optional[str] = None

    # 기법 답이 어떻게 받아들여졌는지. credited: 기법 성과로 인정,
    # acknowledged: 저정보·중립 답으로만 받아 줌. 기법이 없었으면 None.
    intervention_outcome: Optional[Literal["credited", "acknowledged"]] = None

    # 이 요약을 만드는 데 쓴 서버 기록 id. 원문을 다시 복사하지 않는다.
    provenance_ids: List[str] = Field(default_factory=list)

    turn_count: int = Field(default=0, ge=0)
    started_at: datetime
    ended_at: datetime


class CounselingSessionUpsert(CounselingSessionSummaryBase):
    session_id: str


class CounselingSessionResponse(CounselingSessionSummaryBase):
    session_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
