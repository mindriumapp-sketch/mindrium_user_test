# Mindrium Backend API

FastAPI + MongoDB(Motor) 백엔드. 구조와 DB 모델은 [`docs/backend_and_database.md`](../../docs/backend_and_database.md),
상담 챗봇 API는 [`docs/counseling/chatbot_system.md`](../../docs/counseling/chatbot_system.md)를 본다.

## 포트

| 용도 | 포트 |
|---|---|
| 서버·Docker 컨테이너 기본값 | 8070 (`PORT` 또는 `API_PORT`로 변경) |
| 챗봇 로컬 개발(VS Code `Flutter 로컬 백엔드`, `tools/demo/preflight.sh`) | 8090 |

## 로컬 실행

```bash
# 저장소 루트에서, 처음 한 번
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/app/requirements.txt
cp backend/app/.env.example backend/app/.env   # 값 채우기

# 실행
cd backend/app
PYTHONPATH=. ../.venv/bin/python -m uvicorn main:app --reload --host 0.0.0.0 --port 8090
```

`curl http://127.0.0.1:8090/health`가 `{"status":"ok"}`이면 프로세스는 떠 있다.
이 응답은 DB·OpenAI 연결까지 확인하지 않으므로, 실제 동작은 로그인·상담으로 확인한다.

## 테스트

```bash
# 저장소 루트에서
PYTHONPATH=backend/app backend/.venv/bin/python -m pytest backend/app/tests -q -p no:cacheprovider
```

## Docker 배포

이미지에는 코드만 들어간다. `.env`, DB 데이터, 데모 계정은 포함되지 않는다.
**배포용 OpenAI 키는 개발용과 다른 키를 쓴다.** env 파일 만들기, 키·모델 권한 점검, 키 교체 절차는
[`docs/deployment.md`](../../docs/deployment.md)를 따른다(`tools/deploy/init_env.sh`, `check_openai_key.sh`).

### 1. 이미지 빌드

```bash
# 저장소 루트에서. 태그는 커밋 해시로 붙이면 어떤 코드인지 추적하기 쉽다.
docker build -t mindrium-backend:$(git rev-parse --short HEAD) backend/app

# Apple Silicon Mac 에서 x86 서버용으로 빌드할 때
docker build --platform linux/amd64 -t mindrium-backend:$(git rev-parse --short HEAD) backend/app
```

### 2. 로컬에서 같은 이미지 실행

```bash
docker run --rm --name mindrium-local \
  --env-file /경로/mindrium-local.env \
  -p 127.0.0.1:8090:8070 \
  mindrium-backend:<태그>
```

컨테이너 안의 `127.0.0.1`은 컨테이너 자신이다. Mac 호스트의 MongoDB는
`MONGO_URI=mongodb://host.docker.internal:27017`로 연결한다.

### 3. 서버에서 실행

```bash
docker run -d \
  --name mindrium-backend \
  --restart unless-stopped \
  --env-file /opt/mindrium/.env \
  -p 8070:8070 \
  mindrium-backend:<태그>
```

서버의 `.env`는 [`.env.example`](.env.example)을 기준으로 운영 값을 채운다.
레지스트리를 쓸 때는 `docker tag` / `docker push` 후 서버에서 `docker pull` 한다.

### 4. 이미지 업데이트

```bash
docker stop mindrium-backend && docker rm mindrium-backend
# 새 태그로 3번 명령을 다시 실행
```

DB를 같은 서버의 MongoDB 컨테이너로 운영한다면 데이터 볼륨을 붙여 재시작 후에도 유지되게 한다.

### 5. 데모 계정 준비

데모 계정 생성 스크립트 [`backend/scripts/seed_demo_account.py`](../scripts/seed_demo_account.py)는
이미지 밖에 있다. 대상 DB의 `MONGO_URI`, `DB_NAME`으로 저장소에서 한 번 실행한다.
다시 실행하면 데모 계정 기록이 초기화된다.

## 환경 변수

전체 목록과 기본값은 [`.env.example`](.env.example)에 있다.

- 필수: `MONGO_URI`, `DB_NAME`, `JWT_SECRET`, `JWT_REFRESH_SECRET`
- 상담 챗봇: `OPENAI_API_KEY`, `OPENAI_MODEL`(기본 `gpt-6-luna`)
- 선택: `CORS_ORIGINS`(기본 localhost 목록), `SMTP_*`, `EMAIL_FROM`, `PLATFORM_*`

## API 문서

서버 실행 후 `/docs`(Swagger UI), `/redoc`.
