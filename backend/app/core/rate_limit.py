"""In-memory rate limiting for auth endpoints (no DB required)."""

from __future__ import annotations

import time
from collections import defaultdict
from threading import Lock

from fastapi import HTTPException, Request

_INVALID_CREDENTIALS = "Invalid credentials"
_TOO_MANY_REQUESTS = "Too many requests. Please try again later."


class InMemoryRateLimiter:
    def __init__(self, *, max_attempts: int = 10, window_seconds: int = 60) -> None:
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._events: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    def check(self, key: str) -> None:
        now = time.time()
        with self._lock:
            window_start = now - self.window_seconds
            bucket = [t for t in self._events[key] if t >= window_start]
            if len(bucket) >= self.max_attempts:
                raise HTTPException(status_code=429, detail=_TOO_MANY_REQUESTS)
            bucket.append(now)
            self._events[key] = bucket


auth_rate_limiter = InMemoryRateLimiter(max_attempts=10, window_seconds=60)


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "unknown"
