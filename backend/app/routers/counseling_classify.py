"""Phase 14.2A: 사용자 발화 의미 분류기 (인식 전용).

분류 결과는 정책의 입력 후보일 뿐이다. 다음 상태, move, CBT, 마무리 여부, 응답
문장은 반환하지 않으며, 모델 출력에 그런 필드가 있으면 응답 전체를 거부한다.
앱은 이 endpoint가 실패하면 규칙 판정을 쓴다.
docs/counseling/phase14_dialogue_moves.md 5.1절.
"""

import json
import logging
import time
from dataclasses import dataclass

import httpx
from core.config import get_settings
from core.security import get_current_user_id
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import ValidationError
from schemas.counseling_classify import (
    CONTENT_TYPES,
    INTERACTION_SIGNALS,
    OPEN_CONTENTS,
    ClassifierLabels,
    CounselingClassifyRequest,
    CounselingClassifyResponse,
)

router = APIRouter(prefix="/counseling", tags=["counseling_classify"])
logger = logging.getLogger("counseling_classify")

PROMPT_VERSION = "classify_v2"
# 규칙 판정이 항상 있으므로 오래 기다리지 않는다.
TIMEOUT = httpx.Timeout(connect=2.0, read=4.0, write=2.0, pool=2.0)
MAX_OUTPUT_TOKENS = 120
# 정상 출력은 200자 안팎이다. 이보다 길면 지시를 벗어난 출력으로 본다.
MAX_RAW_CHARS = 600

# 분류기가 절대 반환하면 안 되는 결정·문장 필드(이름만 봐도 거부 사유를 남긴다).
FORBIDDEN_KEYS = frozenset({
    "next_state", "state", "next_move", "move", "dialogue_move", "action",
    "cbt", "selected_cbt", "intervention", "should_close", "close",
    "reply", "response", "response_text", "text",
})

SYSTEM_PROMPT = """당신은 상담 챗봇의 입력 분류기입니다. 사용자의 마지막 발화를 아래 세 항목으로 분류만 하세요.
상담 응답을 쓰거나, 다음에 무엇을 할지 정하지 마세요.

입력: 직전 상담자 발화(있을 수 있음)와 사용자 발화.

content_type (하나):
- situation: 상황이나 사실만 말함. 걱정하는 생각은 없음
- worry_thought: 불안한 생각, 예측, 의심을 말함 ("~할 것 같아", "~하면 어떡하지", "~건 아닐까")
- meaningful_answer: 상담자 질문에 내용 있게 답함(근거, 다른 관점, 균형 잡힌 생각, 0~10 점수 질문에 대한 숫자)
- low_information: 쓸 내용이 없음 ("몰라", "그냥", "ㅇㅇ", "글쎄")
- emotion_expression: 생각이나 상황 없이 감정만 말함
- meta_interaction: 사용자 문제가 아니라 대화나 챗봇 자체에 대한 말
- app_guide: 앱 사용법을 물음
- mixed: 위 중 둘이 각각 내용 있게 섞임(예: 대화에 대한 불만 + 걱정, 앱 사용법 + 상담 내용)

interaction_signal (하나):
- none
- repeated_question: 챗봇이 같은 말이나 질문을 반복한다는 지적
- stop_questioning: 질문을 그만하거나 그냥 들어 달라는 요청
- assistant_not_understood: 챗봇의 말이나 질문을 이해하지 못함(용어를 모름 포함)
- process_resistance: 상담 방식이나 효과에 대한 회의, 거부
- closing_accept: 마무리 제안에 동의
- closing_continue: 마무리 제안에 더 이야기하고 싶다고 함
closing_accept/closing_continue는 직전 상담자 발화가 마무리 제안일 때만 씁니다.

open_content (하나):
- none
- elaboration: 지금 이야기 중인 걱정을 구체화하거나 덧붙임
- new_worry: 아직 다루지 않은 다른 걱정을 꺼냄
- new_evidence: 지금 걱정과 관련된 새 사실이나 경험(뒷받침하든 반대하든)

판단 규칙:
- 주어가 제3자인 경우("교수님이 무슨 말 하는지 모르겠어서 불안해")는 챗봇에 대한 말이 아닙니다.
- "모르겠어"가 걱정 속에 있으면("잘 모르겠어 그냥 발표 망할 것 같아") 걱정으로 봅니다. 챗봇의 말을 가리키면 이해 못함입니다.
- 반복 지적이나 이해 못함과 함께 새 내용이 있으면 interaction_signal과 open_content를 둘 다 표시합니다.
- 띄어쓰기 없음, 오타, 반말, 자음 채팅어를 감안해 의미로 판단합니다.

confidence: 세 항목 각각에 대해 0~1 사이 값.

출력: 다른 텍스트 없이 아래 JSON 객체 하나만. 다른 키를 추가하지 마세요.
{"content_type": "...", "interaction_signal": "...", "open_content": "...", "confidence": {"content_type": 0.0, "interaction_signal": 0.0, "open_content": 0.0}}"""


# classify_v2: 모델 쪽에서도 enum을 강제한다(structured outputs). v1은 필드를 섞어
# content_type에 "none"을 넣는 등 응답의 약 10%가 거부됐다. 우리 쪽 검증은 그대로 둔다.
def _enum(values):
    return {"type": "string", "enum": list(values)}


_CONF = {"type": "number"}
RESPONSE_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "user_act",
        "strict": True,
        "schema": {
            "type": "object",
            "additionalProperties": False,
            "required": ["content_type", "interaction_signal", "open_content", "confidence"],
            "properties": {
                "content_type": _enum(CONTENT_TYPES),
                "interaction_signal": _enum(INTERACTION_SIGNALS),
                "open_content": _enum(OPEN_CONTENTS),
                "confidence": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["content_type", "interaction_signal", "open_content"],
                    "properties": {
                        "content_type": _CONF,
                        "interaction_signal": _CONF,
                        "open_content": _CONF,
                    },
                },
            },
        },
    },
}


class ClassifierRejected(Exception):
    """분류 결과를 쓸 수 없음. reason은 로그·지표용 짧은 코드."""

    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


@dataclass
class ClassifierResult:
    labels: ClassifierLabels
    latency_ms: int
    prompt_tokens: int
    completion_tokens: int


def build_messages(user_text: str, assistant_prev: str | None) -> list[dict]:
    lines = []
    if assistant_prev:
        lines.append(f"직전 상담자 발화: {assistant_prev}")
    lines.append(f"사용자 발화: {user_text}")
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": "\n".join(lines)},
    ]


def parse_model_content(content: str) -> ClassifierLabels:
    """모델 출력 문자열을 검증한다. 하나라도 어긋나면 전체를 거부한다."""
    if content is None:
        raise ClassifierRejected("empty")
    raw = content.strip()
    if not raw:
        raise ClassifierRejected("empty")
    if len(raw) > MAX_RAW_CHARS:
        raise ClassifierRejected("overlong")
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        raise ClassifierRejected("malformed_json")
    if not isinstance(data, dict):
        raise ClassifierRejected("not_object")
    if FORBIDDEN_KEYS & set(data):
        raise ClassifierRejected("forbidden_field")
    try:
        return ClassifierLabels.model_validate(data)
    except ValidationError as e:
        kinds = {err["type"] for err in e.errors()}
        if "missing" in kinds:
            raise ClassifierRejected("missing_field")
        if "extra_forbidden" in kinds:
            raise ClassifierRejected("extra_field")
        if "literal_error" in kinds:
            raise ClassifierRejected("unknown_enum")
        raise ClassifierRejected("invalid_value")


async def classify(
    client: httpx.AsyncClient,
    *,
    api_base: str,
    api_key: str,
    model: str,
    user_text: str,
    assistant_prev: str | None,
) -> ClassifierResult:
    started = time.monotonic()
    try:
        response = await client.post(
            f"{api_base}/chat/completions",
            headers={"Authorization": f"Bearer {api_key}"},
            json={
                "model": model,
                "messages": build_messages(user_text, assistant_prev),
                "max_tokens": MAX_OUTPUT_TOKENS,
                "temperature": 0,
                "response_format": RESPONSE_FORMAT,
            },
        )
    except httpx.TimeoutException:
        raise ClassifierRejected("timeout")
    except httpx.HTTPError:
        raise ClassifierRejected("unreachable")
    latency_ms = int((time.monotonic() - started) * 1000)

    if response.status_code >= 400:
        raise ClassifierRejected(f"upstream_{response.status_code}")
    try:
        body = response.json()
        content = body["choices"][0]["message"]["content"]
        usage = body.get("usage") or {}
    except (KeyError, IndexError, TypeError, ValueError):
        raise ClassifierRejected("malformed_upstream")

    labels = parse_model_content(content)
    return ClassifierResult(
        labels=labels,
        latency_ms=latency_ms,
        prompt_tokens=int(usage.get("prompt_tokens") or 0),
        completion_tokens=int(usage.get("completion_tokens") or 0),
    )


@router.post(
    "/classify",
    response_model=CounselingClassifyResponse,
    summary="사용자 발화 의미 분류 (인식 전용, Phase 14.2A)",
)
async def classify_turn(
    payload: CounselingClassifyRequest,
    user_id: str = Depends(get_current_user_id),
):
    settings = get_settings()
    if not settings.openai_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="classifier not configured",
        )
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            result = await classify(
                client,
                api_base=settings.openai_api_base,
                api_key=settings.openai_api_key,
                model=settings.openai_model,
                user_text=payload.user_text,
                assistant_prev=payload.assistant_prev,
            )
    except ClassifierRejected as e:
        # 원문은 남기지 않는다. 사유 코드만 남긴다.
        logger.warning(
            "counseling_classify: rejected reason=%s request_id=%s",
            e.reason,
            payload.request_id,
        )
        code = (
            status.HTTP_504_GATEWAY_TIMEOUT
            if e.reason == "timeout"
            else status.HTTP_502_BAD_GATEWAY
        )
        raise HTTPException(status_code=code, detail=f"classifier {e.reason}")

    logger.info(
        "counseling_classify: ok request_id=%s latency_ms=%d",
        payload.request_id,
        result.latency_ms,
    )
    return CounselingClassifyResponse(
        request_id=payload.request_id,
        labels=result.labels,
        model=settings.openai_model,
        prompt_version=PROMPT_VERSION,
        latency_ms=result.latency_ms,
        prompt_tokens=result.prompt_tokens,
        completion_tokens=result.completion_tokens,
    )
