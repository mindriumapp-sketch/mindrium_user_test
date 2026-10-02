import json
import logging
import time

import httpx
from core.config import get_settings
from core.security import get_current_user_id
from fastapi import APIRouter, Depends, HTTPException, status
from schemas.counseling_realize import CounselingRealizeRequest, CounselingRealizeResponse

router = APIRouter(prefix="/counseling", tags=["counseling_realize"])
logger = logging.getLogger("counseling_realize")

# deterministic 응답이 이미 있으므로 원격 호출을 오래 기다릴 이유가 없다.
# docs/counseling/chatbot_system.md 9절.
_TIMEOUT = httpx.Timeout(connect=3.0, read=6.0, write=3.0, pool=3.0)
_MAX_OUTPUT_TOKENS = 150

# Phase 10.5A.2 Track B ("realize contract v2" — additive only): added
# sud_rating_value handling. The one rule line below is conditional in
# effect (a no-op without a value to act on) but present in every prompt
# now, so this is a real _SYSTEM_PROMPT text change — track it as
# realize_v2 in any evaluation manifest. Requests that omit
# sud_rating_value (older clients) see identical model BEHAVIOR to v1,
# just not byte-identical prompt text.
_SYSTEM_PROMPT = """당신은 문장 표현기 겸 제한된 행위 선택기입니다.
상담 전략이나 새로운 내용을 만들지 마세요.

다음 초안의 의미와 사실을 보존하여 자연스러운 한국어로 다듬으세요.

행위 선택 (chosen_act):
- 입력의 allowed_acts 목록 중에서만 이번 턴에 실제로 할 행위를 하나
  고르세요. allowed_acts가 비어 있으면 required_act를 그대로 고르세요.
- allowed_acts 밖의 행위는 절대 고르지 마세요. 목록에 없는 새 행위를
  지어내지 마세요.
- reflect/summarize를 고르면 질문 없이 반영/정리 문장만 씁니다.
- explore/socratic_question을 고르면 반드시 질문을 정확히 1개 포함합니다.
- recent conversation의 가장 최근 사용자 발화를 먼저 보세요. 사용자가
  지쳤다거나("그냥 지쳐서", "아무것도 생각하기 싫다"), 질문을 원치 않는다는
  신호("그냥 들어주세요", "질문 그만", "그냥 좀 들어줬으면")를 보이면,
  allowed_acts에 reflect/summarize가 있는 한 반드시 그중 하나를 골라 질문
  없이 반영만 하세요. 이런 신호가 없을 때만 explore/socratic_question처럼
  질문을 포함하는 행위를 고르세요.

필수:
- reflection target의 의미 보존 (단, 아래 금지 항목대로 그대로 인용하지 않음)
- question goal 보존 (질문을 포함하는 행위를 골랐을 때)
- 최대 2문장
- chosen_act에 맞는 질문 개수(위 "행위 선택" 참고)
- sud_rating_value가 주어지면, 그 숫자를 사용자가 방금 준 불안 정도 평정으로
  자연스럽게 한 번 인정한 뒤 이어가세요(그 숫자 자체를 판단하거나 새로운
  의미를 부여하지 말고, 받았다는 사실만 짧게 반영).

금지:
- 조언, 진단, 약속 추가
- 사용자에게 없는 사실 추가
- 다른 CBT 기법 추가
- 과거 기록을 새로 언급
- 사용자의 문장이나 초안의 인용구를 인용부호(" ", ' ')로 그대로 반복하기.
  초안에 사용자의 말이 그대로 인용되어 있어도, 그 인용부호를 없애고
  핵심 내용을 상담사 자신의 표현으로 짧게 풀어서 반영할 것

출력 형식: 다른 텍스트 없이 아래 JSON 객체 하나만 반환하세요.
{"chosen_act": "<allowed_acts 중 하나>", "reply": "<최종 답변 문장>"}"""


def _build_user_prompt(payload: CounselingRealizeRequest) -> str:
    lines = [
        f"초안: {payload.deterministic_draft}",
        f"reflection target: {payload.reflection_target}",
        f"question goal: {payload.question_goal}",
        f"required act: {payload.required_act}",
        "allowed acts: "
        + (", ".join(payload.allowed_acts) or payload.required_act),
    ]
    if payload.affect:
        lines.append(f"affect: {payload.affect}")
    if payload.sud_rating_value is not None:
        lines.append(f"sud_rating_value: {payload.sud_rating_value}")
    lines.append(f"tone: {payload.tone}")
    if payload.allowed_cbt_facts:
        lines.append("allowed cbt facts: " + " / ".join(payload.allowed_cbt_facts))
    if payload.forbidden_behaviors:
        lines.append("forbidden: " + " / ".join(payload.forbidden_behaviors))
    if payload.recent_conversation:
        recent = "\n".join(
            f"{turn.role}: {turn.text}" for turn in payload.recent_conversation
        )
        lines.append(f"recent conversation:\n{recent}")
    return "\n".join(lines)


@router.post(
    "/realize",
    response_model=CounselingRealizeResponse,
    summary="TurnPlan 초안을 GPT로 자연스럽게 재표현",
)
async def realize_turn(
    payload: CounselingRealizeRequest,
    user_id: str = Depends(get_current_user_id),
):
    settings = get_settings()
    if not settings.openai_api_key:
        # 키가 없으면 즉시 실패해 앱이 deterministic draft로 물러나게 한다.
        # 여기서 원문 프롬프트나 사용자 발화는 로그에 남기지 않는다.
        logger.warning(
            "counseling_realize: OPENAI_API_KEY not configured request_id=%s",
            payload.request_id,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="realizer not configured",
        )

    started = time.monotonic()
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            response = await client.post(
                f"{settings.openai_api_base}/chat/completions",
                headers={"Authorization": f"Bearer {settings.openai_api_key}"},
                json={
                    "model": settings.openai_model,
                    "messages": [
                        {"role": "system", "content": _SYSTEM_PROMPT},
                        {"role": "user", "content": _build_user_prompt(payload)},
                    ],
                    "max_tokens": _MAX_OUTPUT_TOKENS,
                    "temperature": 0.2,
                    "response_format": {"type": "json_object"},
                },
            )
    except httpx.TimeoutException:
        latency_ms = int((time.monotonic() - started) * 1000)
        logger.warning(
            "counseling_realize: upstream timeout request_id=%s latency_ms=%d",
            payload.request_id,
            latency_ms,
        )
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="realizer timeout"
        )
    except httpx.HTTPError:
        logger.warning(
            "counseling_realize: upstream request failed request_id=%s",
            payload.request_id,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="realizer unreachable"
        )

    latency_ms = int((time.monotonic() - started) * 1000)

    if response.status_code >= 400:
        logger.warning(
            "counseling_realize: upstream status=%d request_id=%s latency_ms=%d",
            response.status_code,
            payload.request_id,
            latency_ms,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="realizer upstream error"
        )

    try:
        body = response.json()
        content = body["choices"][0]["message"]["content"].strip()
        model_output = json.loads(content)
        reply = str(model_output["reply"]).strip()
        # chosen_act가 없거나 이상해도 요청을 실패시키지 않는다 — 클라이언트가
        # allowed_acts 밖이면 어차피 거부하고 required_act로 되돌아간다.
        chosen_act = str(model_output.get("chosen_act") or payload.required_act)
    except (KeyError, IndexError, ValueError, TypeError, json.JSONDecodeError):
        logger.warning(
            "counseling_realize: malformed upstream response request_id=%s",
            payload.request_id,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="malformed realizer response"
        )

    if not reply:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="empty realizer reply"
        )

    logger.info(
        "counseling_realize: ok request_id=%s user_id=%s latency_ms=%d",
        payload.request_id,
        user_id,
        latency_ms,
    )

    return CounselingRealizeResponse(
        request_id=payload.request_id,
        reply=reply,
        chosen_act=chosen_act,
        model=settings.openai_model,
        prompt_version=payload.prompt_version,
        latency_ms=latency_ms,
    )
