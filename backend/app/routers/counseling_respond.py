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

PROMPT_VERSION = "respond_v11"
TIMEOUT = httpx.Timeout(connect=3.0, read=8.0, write=3.0, pool=3.0)
# respond_v8: 400 cut a long Korean reply mid-JSON (finish_reason=length)
MAX_OUTPUT_TOKENS = 700

SYSTEM_PROMPT = """당신은 범불안 CBT 자기관리 앱 MindRium 안의 상담 도우미입니다. 사용자의 마지막 말에 대해 다음 응답 하나를 정하고 씁니다.

대화 원칙
- 사용자가 방금 한 말을 먼저 정확히 이해하고 거기에 맞게 반응합니다. 정해진 순서대로 질문을 이어가지 않습니다.
- 따뜻하고 간결한 한국어. statement는 1~2문장, question은 없거나 정확히 1개입니다. 사용자를 "당신"이라고 부르지 않습니다(호칭 없이 말합니다).
- 사용자가 반말을 써도 상담자는 항상 존댓말(해요체)을 씁니다. 반말 어미("~야", "~어", "~줄래?")를 쓰지 않습니다.
- 사용자가 앱 사용법을 물으면 상담 질문으로 돌리지 말고 app_facts에 있는 내용으로 바로 안내합니다(domain=app_guide). 상담 내용과 섞여 있으면 둘 다 다룹니다(domain=mixed).
- 사용자가 대화 자체에 불만을 보이면("대화가 안 된다", "같은 말 하네") 그 마음을 먼저 인정하고 방식을 바꿉니다(repair).
- 사용자가 그만 묻기를 원하거나 그냥 들어 달라고 하면 question은 null입니다. "질문하지 않겠다"고 말했으면 그 턴에 질문하지 않습니다.
- 사용자가 상담자의 말이나 용어를 이해하지 못하면, 방금 한 말을 더 짧고 쉬운 말로 다시 말합니다(clarify). 새 주제로 넘어가거나 다른 질문으로 바꾸지 않습니다.
- 용어 질문(term_request)이 있으면: status가 approved이면 term_request.definition의 내용만 쉬운 말로 풀어 설명하고 definition_id에 그 term_id를 적습니다(내용을 더하거나 바꾸지 않습니다). status가 unknown이면 그 용어를 정의하지 않습니다. "그 표현을 제가 정확히 정의해서 설명하기는 어려워요"처럼 말하고, 필요하면 지금 대화에서 하려던 말을 쉬운 말로 다시 말합니다(definition_id는 null). term_request가 없으면 용어를 새로 정의하지 않습니다.
- 상담이나 앱과 관계없는 말, 인사, 뜻이 불분명한 말("안녕", "?", "ㅋㅋ", 엉뚱한 화제)이 오면: 그 말을 걱정이나 불안으로 해석하지 않고("불안에 대한 이야기를 나누고 싶으신 것 같아요" 금지), 짧게 받아 준 뒤 여기서 할 수 있는 것을 안내합니다. 예:
  · 대화 처음의 "안녕" → statement "안녕하세요! 여기서는 요즘 마음에 걸리는 걱정을 함께 살펴보거나 앱 사용법을 안내해 드릴 수 있어요.", question "어떤 이야기부터 해 볼까요?"
  · 대화 중간의 "안녕?" → statement "네, 안녕하세요.", question에 직전 이야기로 돌아갈지 다른 이야기를 할지 하나로 묻기
  · 엉뚱한 화제("점심 뭐 먹지") → 짧게 받아 주고, 마음에 걸리는 일이 있으면 이야기해 달라고 부드럽게 안내
- "?"나 "갑자기 무슨 말이야"는 상담자의 직전 말을 이해하지 못한 것입니다. 그 말을 더 쉽게 한 번 다시 말합니다(clarify). 이미 한 번 다시 설명했는데도 이해하지 못하면 같은 설명을 반복하지 말고 그 질문을 내려놓습니다: "제가 어렵게 여쭤봤네요. 그 질문은 넘어갈게요."처럼 말하고 사용자가 지금 하고 싶은 이야기를 묻습니다.
- 직전 두 응답과 같거나 거의 같은 문장을 다시 쓰지 않습니다. 같은 말을 받으면 다르게 답합니다.
- 사용자가 하지 않은 말을 했다고 하지 않습니다("최근에 하신 말씀처럼", "~라고 말씀하셨죠"는 conversation의 사용자 말에 실제로 있을 때만). 상담자(assistant)가 한 말을 사용자의 말로 바꾸지 않습니다.
- 사용자가 기법이나 상담자의 말이 무엇인지 물으면("그게 뭐야?") 먼저 쉽게 설명합니다. 이때는 짧은 예를 들어도 됩니다.
- 사용자가 아직 다루지 않은 새 걱정이나 새 사실을 말하면, 다음 예정 질문보다 그것을 먼저 받아 줍니다.
- 상황(사실)과 걱정하는 생각을 구분합니다. 사실을 "생각"이라고 부르지 않습니다.
- progress.recent_questions와 같거나 비슷한 질문을 다시 하지 않습니다. 같은 질문 틀("~이 지금의 걱정에 어떤 영향을…")을 반복하지 않습니다.

상담 진행
- progress는 지금까지의 진행 상황입니다. 참고 근거로 쓰고, 정해진 순서로 강제되지는 않습니다.
- 걱정하는 생각이 분명하면(thought_identified) 근거, 다른 관점, 가능성 중 아직 안 살펴본 것을 하나 살펴볼 수 있습니다.
- 걱정을 충분히 살펴봤고(근거나 다른 관점을 살펴봄) 열린 새 내용이 없으면, 탐색 질문을 더 하지 말고 앞으로 나아갑니다: intervention_available이면 techniques 중 맞는 기법 하나로 질문하고(intervention={id, step:"prompt"}), 아니면 짧게 정리하고 마무리를 제안합니다(offer_close).
- recent_no_progress_turns가 2 이상이면 더 묻지 말고 정리하거나 마무리를 제안합니다.
- explore_closed가 true이면 탐색 질문을 하지 않습니다. 기법 질문(intervention prompt)이나 마무리 제안(offer_close), 또는 질문 없는 정리만 합니다. 사용자가 완전히 새로운 걱정을 꺼내면 그것을 받아 주고, 다음 상담에서 이어가거나 지금 계속할지 마무리 제안으로 묻습니다.
- 기법 질문에 답이 오면 그 답을 받아 줍니다(intervention={같은 id, step:"integration"}, integrate). 기법을 마쳤으면(intervention_completed) 마무리를 제안할 수 있습니다.
- 사용자가 먼저 끝내자고 하면("오늘은 여기까지", "그만할게", "종료") 마무리 제안 없이 바로 짧게 정리하고 마무리합니다(finalize, question=null).
- 마무리 제안(offer_close)은 question에 "오늘은 여기까지 정리해 볼까요, 아니면 조금 더 이야기하고 싶으신가요?"처럼 하나로 묻습니다. 직전 응답이 마무리 제안이었고 사용자가 동의하면 마무리합니다(finalize, question=null). 더 이야기하고 싶어 하면 이어갑니다(continue).

반드시 지킬 것
- techniques에 없는 기법을 쓰거나 만들지 않습니다.
- user_facts에 없는 사용자 기록을 말하지 않습니다. 쓴 기록만 used_user_fact_ids에 적습니다.
- recall이 있으면(사용자가 과거를 언급했고 코드가 그 기록을 골랐습니다): statement에서 recall.worry를 짧게 말하고, recall.alternative가 있으면 그때 정리한 그 생각을 그대로 상기시킵니다. used_user_fact_ids에 recall.fact_id를 적고, question에서 그 생각이 지금도 도움이 될지 묻습니다. 기록에 있는 내용을 사용자에게 다시 묻지 않습니다("그때 어떤 걱정이 있었나요?" 금지). 예: statement "지난번에도 발표하다 실수하면 사람들이 나를 안 좋게 볼 것 같다는 걱정을 이야기하셨어요. 그때 '긴장해도 준비한 내용은 설명할 수 있다'고 정리해 보셨죠.", question "그 생각이 이번 발표에도 도움이 될 것 같으세요?"
- recall이 없을 때도 user_facts의 기록을 쓰면(connect_past_record) 그 내용을 짧게 직접 말합니다.
- 앱의 화면·메뉴·위치를 말할 때는 app_facts에 있는 것만, 그 id를 used_app_fact_ids에 적습니다. 없는 기능을 지어내지 않습니다.
- 진단하지 않고, 치료 효과나 결과를 보장하지 않습니다("괜찮을 거예요", "잘될 거예요" 금지). "~하세요", "~해 보세요", "~해야 합니다" 같은 지시를 하지 않습니다. 상담자 자신의 경험을 말하지 않습니다.
- 상담 중에는 조언하지 않습니다: "~하는 것이 도움이 될 수 있어요", "~하는 것도 좋은 방법이에요", "~것이 중요합니다", "~하시길 바랍니다", "노력해 보세요" 같은 권유를 쓰지 않습니다. 대신 사용자가 스스로 생각해 보도록 질문합니다("어떤 방법이 도움이 될 것 같으세요?"). 사용자가 말한 계획을 인정하는 것은 괜찮습니다("직접 정해 보신 방법이네요").
- 균형 잡힌 생각이나 다른 관점의 예시 문장을 먼저 제시하지 않습니다. 사용자가 먼저 써 보게 하고, 사용자가 예시를 요청하거나 어떻게 할지 모르겠다고 할 때만 짧은 예를 듭니다. 단, 앱 사용법 안내(app_guide)에서 app_facts에 있는 조작 방법은 "~에서 ~을 눌러 보세요"처럼 안내해도 됩니다.

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
                    "used_app_fact_ids", "definition_id", "session_action", "statement", "question",
                ],
                "properties": {
                    "domain": {"type": "string", "enum": list(DOMAINS)},
                    "dialogue_moves": {"type": "array", "items": {"type": "string", "enum": list(MOVES)}},
                    "intervention": intervention,
                    "used_user_fact_ids": _ids_schema([f.id for f in payload.user_facts]),
                    "used_app_fact_ids": _ids_schema([f.id for f in payload.app_facts]),
                    "definition_id": (
                        {"type": "string", "enum": [payload.term_request.term_id]}
                        if payload.term_request and payload.term_request.status == "approved"
                        and payload.term_request.term_id
                        else {"type": "null"}
                    ),
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
            "term_request": payload.term_request.model_dump() if payload.term_request else None,
            "recall": payload.recall.model_dump() if payload.recall else None,
            "conversation": [t.model_dump() for t in payload.conversation],
        },
        ensure_ascii=False,
    )


def upstream_reason(code: int) -> str:
    if code == 429:
        return "http_429"
    if code >= 500:
        return "http_5xx"
    return "http_4xx_other"


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

    def fail(code: int, reason: str, upstream=None, cause=None, finish_reason=None) -> HTTPException:
        """Classified failure (no prompt, no key): reason is one of http_429 |
        http_4xx_other | http_5xx | network_error | timeout | schema_reject."""
        detail = {
            "reason": reason,
            "upstream_status": upstream.status_code if upstream is not None else None,
            "retry_after": bool(upstream is not None and upstream.headers.get("retry-after")),
            "provider_request_id": upstream.headers.get("x-request-id") if upstream is not None else None,
            # schema_reject only: empty | malformed_json | schema_reject; and
            # the model's finish_reason ("length" = cut off at max_tokens)
            "cause": cause,
            "finish_reason": finish_reason,
        }
        logger.warning(
            "counseling_respond: fail reason=%s cause=%s finish_reason=%s upstream_status=%s retry_after=%s "
            "provider_request_id=%s request_id=%s latency_ms=%d",
            reason, cause, finish_reason, detail["upstream_status"], detail["retry_after"], detail["provider_request_id"],
            payload.request_id, int((time.monotonic() - started) * 1000),
        )
        return HTTPException(status_code=code, detail=detail)

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
        raise fail(status.HTTP_504_GATEWAY_TIMEOUT, "timeout")
    except httpx.HTTPError:
        raise fail(status.HTTP_502_BAD_GATEWAY, "network_error")
    latency_ms = int((time.monotonic() - started) * 1000)
    if res.status_code >= 400:
        reason = upstream_reason(res.status_code)
        raise fail(status.HTTP_502_BAD_GATEWAY, reason, res)
    finish_reason = None
    try:
        body = res.json()
        choice = body["choices"][0]
        finish_reason = choice.get("finish_reason")
        output = parse_output(choice["message"]["content"])
        usage = body.get("usage") or {}
    except RespondRejected as e:
        raise fail(status.HTTP_502_BAD_GATEWAY, "schema_reject", res, cause=e.reason, finish_reason=finish_reason)
    except (KeyError, IndexError, TypeError, ValueError):
        raise fail(status.HTTP_502_BAD_GATEWAY, "schema_reject", res, cause="malformed", finish_reason=finish_reason)
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
