import json
import logging
import time

import httpx
from core.config import get_settings
from core.security import get_current_user_id
from fastapi import APIRouter, Depends, HTTPException, status
from _archive_phase9_decision_agent.counseling_decide_schemas import (
    CounselingDecideRequest,
    CounselingDecideResponse,
)

router = APIRouter(prefix="/counseling", tags=["counseling_decide"])
logger = logging.getLogger("counseling_decide")

# Phase 9.1: mirrors counseling_realize.py's timeout budget — deterministic
# selection already exists, so this remote call must not be allowed to stall
# a turn for long. docs/counseling/remote_gpt_realizer_integration.md 9절.
_TIMEOUT = httpx.Timeout(connect=3.0, read=6.0, write=3.0, pool=3.0)
_MAX_OUTPUT_TOKENS = 200

# Phase 9.2D: bump this whenever _SYSTEM_PROMPT's wording/rules change, so
# shadow-evaluation logs can tell which prompt version produced a decision.
#
# v1 -> v2 changes (see docs/counseling/phase9_2_activation_criteria.md's
# Pass 2 real-evaluation findings for why): v1 never told the model what
# `reflectionTarget`/`selectedGoalId` shape each state actually requires
# (`TurnPlanMaterializer` force-casts assumed text/goal presence the
# validator never checked either) — the model frequently sent
# ReflectionTargetNone / a null goal for states that structurally cannot
# accept them. v2 states the per-decision requirement explicitly and in the
# same terms `decisionRequirementsFor` (decision_contract.dart) uses, so
# prompt, validator, and materializer share one description of what's valid
# instead of three independently-guessed ones.
_PROMPT_VERSION = "decide_v2"

_SYSTEM_PROMPT = """당신은 제한된 행위/목표 선택기입니다.
새로운 상담 전략이나 CBT 기법을 만들지 마세요. 사용자에 대한 사실을
지어내지 마세요.

규칙:
- selectedAction은 반드시 입력의 allowed_actions 목록 중 하나여야 합니다.
  목록 밖의 값을 만들어내지 마세요.
- selectedGoalId 규칙:
  - current_state가 reflect이고 selectedAction이 "explore"가 아니면
    반드시 candidate_goal_ids 중 하나를 선택해야 합니다(null 금지).
  - current_state가 reflect이고 selectedAction이 "explore"이면
    (아직 명확한 생각을 찾지 못해 더 구체적으로 묻는 경우) selectedGoalId는
    null이어도 됩니다.
  - 그 외 모든 state에서는 selectedGoalId를 항상 null로 두세요.
- selectedInterventionId 규칙:
  - current_state가 intervention이면 반드시 eligible_intervention_ids
    중 하나를 선택해야 합니다(null 금지).
  - 그 외 모든 state에서는 항상 null로 두세요.
- reflectionTarget 규칙:
  - current_state가 closing이면 {"type": "text", "text": "..."} 또는
    {"type": "none"} 둘 다 유효합니다.
  - 그 외 모든 state(checkIn/explore/reflect/intervention)에서는 반드시
    {"type": "text", "text": "<반영/질문의 대상이 되는 구체적 문장>"} 형태여야
    합니다. {"type": "none"}을 쓰지 마세요 — 이 state들은 항상 구체적인
    대상 문장이 필요합니다.
- allowed_cbt_knowledge, relevant_personal_context, recent_conversation에
  없는 사실을 지어내지 마세요.

출력 형식: 다른 텍스트/마크다운 없이 아래 JSON 객체 하나만 반환하세요.
{"selectedAction": "<allowed_actions 중 하나>", "selectedGoalId": <string|null>, "selectedInterventionId": <string|null>, "reflectionTarget": {"type": "text"|"none", "text": <string|null>} }"""


def _build_user_prompt(payload: CounselingDecideRequest) -> str:
    lines = [
        f"current state: {payload.current_state}",
        f"user message: {payload.user_message}",
        "allowed actions: " + (", ".join(payload.allowed_actions) or "(none)"),
        "candidate goal ids: " + (", ".join(payload.candidate_goal_ids) or "(none)"),
        "eligible intervention ids: "
        + (", ".join(payload.eligible_intervention_ids) or "(none)"),
        "forbidden constraints: "
        + (", ".join(payload.forbidden_constraints) or "(none)"),
        f"goals exhausted: {payload.goals_exhausted} ({payload.goal_exhaustion_policy})",
        f"has closing summary target: {payload.has_closing_summary_target}",
    ]
    ctx = payload.relevant_personal_context
    lines.append(
        "personal context signals: "
        f"relevant_past_issue={ctx.has_relevant_past_issue}, "
        f"previous_alternative_thought={ctx.has_previous_alternative_thought}, "
        f"helpful_activity={ctx.has_helpful_activity}, "
        f"unfinished_issue={ctx.has_unfinished_issue}, "
        f"sud_trend={ctx.sud_trend}"
    )
    if payload.allowed_cbt_knowledge:
        knowledge = " / ".join(
            f"{item.id}:{item.title}[{','.join(item.tags)}]"
            for item in payload.allowed_cbt_knowledge
        )
        lines.append(f"allowed cbt knowledge: {knowledge}")
    if payload.recent_conversation:
        recent = "\n".join(
            f"{turn.role}: {turn.text}" for turn in payload.recent_conversation
        )
        lines.append(f"recent conversation:\n{recent}")
    progress = payload.dialogue_progress
    lines.append(
        "dialogue progress: "
        f"asked_goal_ids={progress.asked_goal_ids}, "
        f"used_intervention_ids={progress.used_intervention_ids}, "
        f"is_first_reflect_turn={progress.is_first_reflect_turn}"
    )
    return "\n".join(lines)


@router.post(
    "/decide",
    response_model=CounselingDecideResponse,
    summary="PolicyBoundary 안에서 다음 행위/목표를 GPT로 선택 (Phase 9.1: 계약만, 미배선)",
)
async def decide_turn(
    payload: CounselingDecideRequest,
    user_id: str = Depends(get_current_user_id),
):
    settings = get_settings()

    # Phase 9.2D: when allowed_actions is empty, no DialogueAct is
    # selectable at all — this is a deterministic fact of the request, not
    # something that needs (or should) be asked of the model. Short-circuit
    # entirely: no upstream call, no cost, no chance of the model inventing
    # a fake action (the exact failure the real phase9_2b_frozen_v1 run
    # found — 8/89 scenarios were exactly this case).
    if not payload.is_available:
        logger.info(
            "counseling_decide: short-circuit unavailable (allowed_actions "
            "empty) user_id=%s",
            user_id,
        )
        return CounselingDecideResponse(
            status="unavailable",
            modelIdentifier=settings.openai_model,
            promptVersion=_PROMPT_VERSION,
        )

    if not settings.openai_api_key:
        logger.warning("counseling_decide: OPENAI_API_KEY not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="decider not configured",
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
                    "temperature": 0.0,
                    "response_format": {"type": "json_object"},
                },
            )
    except httpx.TimeoutException:
        latency_ms = int((time.monotonic() - started) * 1000)
        logger.warning(
            "counseling_decide: upstream timeout latency_ms=%d", latency_ms
        )
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="decider timeout"
        )
    except httpx.HTTPError:
        logger.warning("counseling_decide: upstream request failed")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="decider unreachable"
        )

    latency_ms = int((time.monotonic() - started) * 1000)

    if response.status_code >= 400:
        logger.warning(
            "counseling_decide: upstream status=%d latency_ms=%d",
            response.status_code,
            latency_ms,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="decider upstream error"
        )

    try:
        body = response.json()
        content = body["choices"][0]["message"]["content"].strip()
        model_output = json.loads(content)
        selected_action = str(model_output["selectedAction"])
        selected_goal_id = model_output.get("selectedGoalId")
        selected_intervention_id = model_output.get("selectedInterventionId")
        reflection_target = model_output.get("reflectionTarget")
    except (KeyError, IndexError, ValueError, TypeError, json.JSONDecodeError):
        logger.warning("counseling_decide: malformed upstream response")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="malformed decider response"
        )

    # Best-effort only: absent/malformed `usage` must not fail the request —
    # these are reproducibility metadata, not part of the decision contract.
    usage = body.get("usage") if isinstance(body, dict) else None
    input_tokens = usage.get("prompt_tokens") if isinstance(usage, dict) else None
    output_tokens = usage.get("completion_tokens") if isinstance(usage, dict) else None
    # model_identifier must always be filled: fall back to the configured
    # model name if the upstream response omits `model` for some reason.
    model_identifier = (
        body.get("model") if isinstance(body, dict) else None
    ) or settings.openai_model

    # Fail-closed at the boundary the client also enforces: this endpoint
    # does not invent a fallback selectedAction the way /realize does with
    # required_act — an out-of-list action here must surface as an error the
    # client's fail-closed parser rejects, not be silently substituted.
    if payload.allowed_actions and selected_action not in payload.allowed_actions:
        logger.warning(
            "counseling_decide: model selected out-of-policy action=%s",
            selected_action,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="decider selected an action outside allowed_actions",
        )

    logger.info(
        "counseling_decide: ok user_id=%s latency_ms=%d", user_id, latency_ms
    )

    return CounselingDecideResponse(
        selectedAction=selected_action,
        selectedGoalId=selected_goal_id,
        selectedInterventionId=selected_intervention_id,
        reflectionTarget=reflection_target,
        modelIdentifier=model_identifier,
        promptVersion=_PROMPT_VERSION,
        inputTokens=input_tokens,
        outputTokens=output_tokens,
    )
