from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
import httpx

from core.config import get_settings

settings = get_settings()

router = APIRouter(prefix="/ai", tags=["ai"])


class ChatMessage(BaseModel):
    role: str = Field(..., description="system|user|assistant")
    content: str = Field(..., min_length=1)


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    model: str | None = None
    temperature: float = 0.6
    max_tokens: int = 800


class ChatResponse(BaseModel):
    reply: str


class EmbeddingRequest(BaseModel):
    input: str
    model: str | None = None


class EmbeddingResponse(BaseModel):
    embedding: list[float]


async def _call_openai(path: str, payload: dict) -> dict:
    if not settings.openai_api_key:
        raise HTTPException(status_code=500, detail="OpenAI API key is not configured")

    url = f"{settings.openai_api_base.rstrip('/')}/{path.lstrip('/')}"
    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=40.0) as client:
            res = await client.post(url, headers=headers, json=payload)
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Upstream request failed: {e}") from e

    if res.status_code >= 400:
        try:
            detail = res.json()
        except ValueError:
            detail = res.text
        raise HTTPException(status_code=res.status_code, detail=detail)

    try:
        return res.json()
    except ValueError as e:
        raise HTTPException(status_code=502, detail="Failed to parse OpenAI response") from e


@router.post("/chat", response_model=ChatResponse)
async def proxy_chat(req: ChatRequest):
    if not req.messages:
        raise HTTPException(status_code=400, detail="messages is required")

    payload = {
        "model": req.model or settings.openai_model,
        "messages": [m.model_dump() for m in req.messages],
        "temperature": req.temperature,
        "max_tokens": req.max_tokens,
    }

    data = await _call_openai("chat/completions", payload)
    reply = (
        data.get("choices", [{}])[0]
        .get("message", {})
        .get("content", "")
        .strip()
    )
    if not reply:
        raise HTTPException(status_code=502, detail="Empty response from OpenAI")

    return {"reply": reply}


@router.post("/embedding", response_model=EmbeddingResponse)
async def proxy_embedding(req: EmbeddingRequest):
    payload = {
        "model": req.model or settings.openai_embedding_model,
        "input": req.input,
    }

    data = await _call_openai("embeddings", payload)
    embedding = data.get("data", [{}])[0].get("embedding") or []
    if not embedding:
        raise HTTPException(status_code=502, detail="Empty embedding from OpenAI")

    return {"embedding": embedding}
