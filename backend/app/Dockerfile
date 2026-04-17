FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8070

WORKDIR /app

RUN addgroup --system appuser && adduser --system --ingroup appuser appuser

COPY requirements.txt .

RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . .

USER appuser

EXPOSE 8070

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-${API_PORT:-8070}}"]
