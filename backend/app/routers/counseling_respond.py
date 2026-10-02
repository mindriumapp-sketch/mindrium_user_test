"""Phase 14.X: Bounded LLM-led 응답 (시제품, 내부 계정 전용).

GPT가 다음 응답(무엇을 할지, 어떻게 말할지)을 한 번에 정한다. 코드는 허용 범위를 미리
좁힌다: 쓸 수 있는 기법·사용자 사실·앱 사실 id를 요청마다 응답 스키마의 enum으로 고정한다.
앱(Dart)의 검증기가 다시 검사하고, 실패하면 결정론 경로로 대체한다. 안전 판정은 앱이 먼저 한다.
docs/counseling/phase14x_bounded_llm_led.md.
"""

import json
import logging
import time

import httpx
from core.config import get_settings
from core.security import get_current_user_id
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import ValidationError
from schemas.counseling_respond import (
    DOMAINS,
    MOVES,
    SESSION_ACTIONS,
    AgentOutput,
    CounselingRespondRequest,
    CounselingRespondResponse,
)

router = APIRouter(prefix="/counseling", tags=["counseling_respond"])
logger = logging.getLogger("counseling_respond")

PROMPT_VERSION = "respond_v2"
TIMEOUT = httpx.Timeout(connect=3.0, read=8.0, write=3.0, pool=3.0)
MAX_OUTPUT_TOKENS = 400

SYSTEM_PROMPT = """당신은 범불안 CBT 자기관리 앱 MindRium 안의 상담 도우미입니다. 사용자의 마지막 말에 대해 다음 응답 하나를 정하고 씁니다.

대화 원칙
- 사용자가 방금 한 말을 먼저 정확히 이해하고 거기에 맞게 반응합니다. 정해진 순서대로 질문을 이어가지 않습니다.
- 따뜻하고 간결한 한국어. statement는 1~2문장, question은 없거나 정확히 1개입니다. 사용자를 "당신"이라고 부르지 않습니다(호칭 없이 말합니다).
- 사용자가 앱 사용법을 물으면 상담 질문으로 돌리지 말고 app_facts에 있는 내용으로 바로 안내합니다(domain=app_guide). 상담 내용과 섞여 있으면 둘 다 다룹니다(domain=mixed).
- 사용자가 대화 자체에 불만을 보이면("대화가 안 된다", "같은 말 하네") 그 마음을 먼저 인정하고 방식을 바꿉니다(repair).
- 사용자가 그만 묻기를 원하거나 그냥 들어 달라고 하면 question은 null입니다. "질문하지 않겠다"고 말했으면 그 턴에 질문하지 않습니다.
- 사용자가 상담자의 말이나 용어를 이해하지 못하면, 방금 한 말을 더 짧고 쉬운 말로 다시 말합니다(clarify). 새 주제로 넘어가지 않습니다.
- 사용자가 아직 다루지 않은 새 걱정이나 새 사실을 말하면, 다음 예정 질문보다 그것을 먼저 받아 줍니다.
- 상황(사실)과 걱정하는 생각을 구분합니다. 사실을 "생각"이라고 부르지 않습니다.
- progress.recent_questions와 같거나 비슷한 질문을 다시 하지 않습니다. 같은 질문 틀("~이 지금의 걱정에 어떤 영향을…")을 반복하지 않습니다.

상담 진행
- progress는 지금까지의 진행 상황입니다. 참고 근거로 쓰고, 정해진 순서로 강제되지는 않습니다.
- 걱정하는 생각이 분명하면(thought_identified) 근거, 다른 관점, 가능성 중 아직 안 살펴본 것을 하나 살펴볼 수 있습니다.
- 걱정을 충분히 살펴봤고(근거나 다른 관점을 살펴봄) 열린 새 내용이 없으면, 탐색 질문을 더 하지 말고 앞으로 나아갑니다: intervention_available이면 techniques 중 맞는 기법 하나로 질문하고(intervention={id, step:"prompt"}), 아니면 짧게 정리하고 마무리를 제안합니다(offer_close).
- recent_no_progress_turns가 2 이상이면 더 묻지 말고 정리하거나 마무리를 제안합니다.
- 기법 질문에 답이 오면 그 답을 받아 줍니다(intervention={같은 id, step:"integration"}, integrate). 기법을 마쳤으면(intervention_completed) 마무리를 제안할 수 있습니다.
- 마무리 제안(offer_close)은 question에 "오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?"처럼 하나로 묻습니다. 직전 응답이 마무리 제안이었고 사용자가 동의하면 마무리합니다(finalize, question=null). 더 이야기하고 싶어 하면 이어갑니다(continue).

반드시 지킬 것
- techniques에 없는 기법을 쓰거나 만들지 않습니다.
- user_facts에 없는 사용자 기록을 말하지 않습니다. 쓴 기록만 used_user_fact_ids에 적습니다.
- 앱의 화면·메뉴·위치를 말할 때는 app_facts에 있는 것만, 그 id를 used_app_fact_ids에 적습니다. 없는 기능을 지어내지 않습니다.
- 진단하지 않고, 치료 효과나 결과를 보장하지 않습니다("괜찮을 거예요", "잘될 거예요" 금지). "~하세요", "~해 보세요", "~해야 합니다" 같은 지시를 하지 않습니다. 상담자 자신의 경험을 말하지 않습니다.

출력: 지정된 JSON 하나. statement에는 물음표를 쓰지 않고, 질문은 question에만 씁니다."""


def _ids_schema(ids: list[str]) -> dict:
    if not ids:
        return {"type": "array", "items": {"type": "string"}, "maxItems": 0}
    return {"type": "array", "items": {"type": "string", "enum": ids}}


def response_format(payload: CounselingRespondRequest) -> dict:
    technique_ids = [t.id for t in payload.techniques]
    intervention = (
        {
            "anyOf": [
                {"type": "null"},
                {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["id", "step"],
                    "properties": {
                        "id": {"type": "string", "enum": technique_ids},
                        "step": {"type": "string", "enum": ["prompt", "integration"]},
                    },
                },
            ]
        }
        if technique_ids
        else {"type": "null"}
    )
    return {
        "type": "json_schema",
        "json_schema": {
            "name": "next_response",
            "strict": True,
            "schema": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "domain", "dialogue_moves", "intervention", "used_user_fact_ids",
                    "used_app_fact_ids", "session_action", "statement", "question",
                ],
                "properties": {
                    "domain": {"type": "string", "enum": list(DOMAINS)},
                    "dialogue_moves": {"type": "array", "items": {"type": "string", "enum": list(MOVES)}},
                    "intervention": intervention,
                    "used_user_fact_ids": _ids_schema([f.id for f in payload.user_facts]),
                    "used_app_fact_ids": _ids_schema([f.id for f in payload.app_facts]),
                    "session_action": {"type": "string", "enum": list(SESSION_ACTIONS)},
                    "statement": {"type": "string"},
                    "question": {"type": ["string", "null"]},
                },
            },
        },
    }


def user_prompt(payload: CounselingRespondRequest) -> str:
    return json.dumps(
        {
            "current_week": payload.current_week,
            "progress": payload.progress.model_dump(),
            "techniques": [t.model_dump() for t in payload.techniques],
            "user_facts": [f.model_dump() for f in payload.user_facts],
            "app_facts": [f.model_dump() for f in payload.app_facts],
            "conversation": [t.model_dump() for t in payload.conversation],
        },
        ensure_ascii=False,
    )


class RespondRejected(Exception):
    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


def parse_output(content: str | None) -> AgentOutput:
    if not content or not content.strip():
        raise RespondRejected("empty")
    try:
        data = json.loads(content)
    except (json.JSONDecodeError, ValueError):
        raise RespondRejected("malformed_json")
    try:
        return AgentOutput.model_validate(data)
    except ValidationError:
        raise RespondRejected("schema_reject")


@router.post(
    "/respond",
    response_model=CounselingRespondResponse,
    summary="Bounded LLM-led 다음 응답 (Phase 14.X 시제품)",
)
async def respond(
    payload: CounselingRespondRequest,
    user_id: str = Depends(get_current_user_id),
):
    settings = get_settings()
    if not settings.openai_api_key:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="not configured")
    started = time.monotonic()
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            res = await client.post(
                f"{settings.openai_api_base}/chat/completions",
                headers={"Authorization": f"Bearer {settings.openai_api_key}"},
                json={
                    "model": settings.openai_model,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_prompt(payload)},
                    ],
                    "max_tokens": MAX_OUTPUT_TOKENS,
                    "temperature": 0.3,
                    "response_format": response_format(payload),
                },
            )
    except httpx.TimeoutException:
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="respond timeout")
    except httpx.HTTPError:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="respond unreachable")
    latency_ms = int((time.monotonic() - started) * 1000)
    if res.status_code >= 400:
        logger.warning("counseling_respond: upstream status=%d", res.status_code)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="respond upstream error")
    try:
        body = res.json()
        output = parse_output(body["choices"][0]["message"]["content"])
        usage = body.get("usage") or {}
    except RespondRejected as e:
        logger.warning("counseling_respond: rejected reason=%s request_id=%s", e.reason, payload.request_id)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"respond {e.reason}")
    except (KeyError, IndexError, TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="respond malformed")
    logger.info("counseling_respond: ok request_id=%s latency_ms=%d", payload.request_id, latency_ms)
    return CounselingRespondResponse(
        request_id=payload.request_id,
        output=output,
        model=settings.openai_model,
        prompt_version=PROMPT_VERSION,
        latency_ms=latency_ms,
        prompt_tokens=int(usage.get("prompt_tokens") or 0),
        completion_tokens=int(usage.get("completion_tokens") or 0),
    )
