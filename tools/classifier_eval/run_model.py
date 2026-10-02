"""Phase 14.2A: run the backend classifier on an eval set (offline, synthetic data only).

Calls the same `classify()` the endpoint uses, with the backend .env key.
Writes predictions, reject reasons, latency and token usage; never prints the key.

  cd backend/app && PYTHONPATH=. python3 ../../tools/classifier_eval/run_model.py \
      ../../test/counseling/evaluation/fixtures/phase14_2_classifier_dev.json \
      ../../build/classifier_eval/dev_model.json
"""
import asyncio
import json
import sys
from pathlib import Path

import httpx
from core.config import get_settings
from routers.counseling_classify import TIMEOUT, ClassifierRejected, classify

CONCURRENCY = 6


async def run(items):
    s = get_settings()
    if not s.openai_api_key:
        sys.exit("OPENAI_API_KEY not configured")
    sem = asyncio.Semaphore(CONCURRENCY)
    out = {}

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        async def one(item):
            async with sem:
                try:
                    r = await classify(client, api_base=s.openai_api_base, api_key=s.openai_api_key,
                                       model=s.openai_model, user_text=item["user"],
                                       assistant_prev=item.get("assistant_prev"))
                    out[item["id"]] = {
                        "labels": r.labels.model_dump(),
                        "latency_ms": r.latency_ms,
                        "prompt_tokens": r.prompt_tokens,
                        "completion_tokens": r.completion_tokens,
                    }
                except ClassifierRejected as e:
                    out[item["id"]] = {"rejected": e.reason}

        await asyncio.gather(*(one(i) for i in items))
    return s.openai_model, out


def main():
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    items = json.loads(src.read_text())["items"]
    model, out = asyncio.run(run(items))
    dst.parent.mkdir(parents=True, exist_ok=True)
    from routers.counseling_classify import PROMPT_VERSION
    dst.write_text(json.dumps({"model": model, "prompt_version": PROMPT_VERSION,
                               "source": src.name, "results": out}, ensure_ascii=False, indent=1))
    rej = sum(1 for v in out.values() if "rejected" in v)
    print(f"{len(out)} items, {rej} rejected -> {dst}")


if __name__ == "__main__":
    main()
