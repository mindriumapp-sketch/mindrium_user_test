# 데모 서버 배포 절차

기준: 2026-11-13, 프롬프트 `respond_v15`. 이미지 빌드와 환경 변수 목록은 [`../backend/app/README.md`](../backend/app/README.md)에 있다.
이 문서는 **배포용 OpenAI 키를 개발용과 분리해서** 올리는 순서와 확인 기준을 모은다.

## 1. 키를 다루는 원칙

| 원칙 | 이유 |
|---|---|
| 배포용 키는 개발용(`backend/app/.env`)과 **다른 키**를 쓴다 | 개발 중 사용량·유출 사고가 데모 서버에 번지지 않게 한다 |
| 키는 서버의 env 파일로만 넣는다. 이미지, 저장소, `docker build --build-arg`, 앱(Flutter)에는 넣지 않는다 | 이미지에 들어간 키는 `docker history`로 꺼낼 수 있다. 앱은 키 없이 백엔드만 부른다 |
| env 파일은 저장소 밖에 두고 권한을 600으로 한다 | 저장소 안의 `*.env`는 `.gitignore`가 막지만, 밖에 두는 편이 안전하다 |
| JWT 비밀 값도 배포용으로 새로 만든다 | 개발 값이 같으면 개발 환경에서 만든 토큰이 서버에서 통할 수 있다 |
| OpenAI 쪽에서 데모 전용 프로젝트를 만들고 월 사용 한도를 건다 | 키가 새거나 반복 호출돼도 비용이 한도에서 멈춘다 |

**키를 바꿔도 코드는 그대로다.** 백엔드는 `OPENAI_API_KEY` 환경 변수만 읽는다(`core/config.py`). 하드코딩된 곳은 없다.
모델 이름(`OPENAI_MODEL`, 기본 `gpt-6-luna`)은 키가 아니라 **계정·프로젝트 권한**에 달려 있어서, 새 키에서 그 모델이 안 열리면 상담이 전부 대체 응답으로 나간다.
그래서 배포 전에 3.2의 점검을 반드시 한다.

## 2. 새 키가 AI 상담에 미치는 범위

- 키를 바꿔도 **AI가 켜지는 계정은 그대로**다. 허용 목록(`internal_account_allowlist.dart`)에 있는 이메일만 B 경로와 원격 표현을 쓴다. 지금은 개발 계정과 데모 계정 `mindrium.demo@example.com`이다.
- 사용 호출은 세 곳이다: `POST /counseling/respond`, `POST /counseling/pattern-intent`, `POST /counseling/realize`. 모두 같은 키를 쓴다.
- 키가 없거나 틀리면 앱은 오류를 보이지 않고 결정론 응답(A)으로 대체한다. **챗봇이 답한다는 것만으로 AI가 정상이라고 판단하지 않는다.** 로그의 `LLM_LED` 그룹이 `direct`인지, 서버 로그에 `counseling_respond: fail reason=...`이 없는지 본다.

## 3. 순서

### 3.1 배포용 env 파일 만들기

```bash
# 저장소 밖 경로에 만든다. 키는 숨김 입력으로 받는다.
tools/deploy/init_env.sh ~/secrets/mindrium-demo.env mindrium_demo
```

- 개발용 키와 같은 키를 넣으면 거부한다.
- 같은 이름의 파일이 있으면 덮어쓰지 않는다.
- `MONGO_URI`는 Mac Docker에서 호스트 DB면 `host.docker.internal`, 서버에서 DB 컨테이너나 별도 DB를 쓰면 그 주소로 바꾼다.
- `DB_NAME`은 운영 DB와 다른 이름(`mindrium_demo`)으로 둔다.

### 3.2 키와 모델 권한 점검

```bash
tools/deploy/check_openai_key.sh ~/secrets/mindrium-demo.env
```

| 결과 | 뜻 | 조치 |
|---|---|---|
| 둘 다 OK | 키 유효, 상담 모델 사용 가능 | 다음 단계 |
| 401 | 키가 틀렸거나 폐기됨 | 키를 다시 복사 |
| 403/404 (모델 줄) | 이 프로젝트에 모델 권한이 없거나 이름이 틀림 | OpenAI 프로젝트의 모델 권한 확인, 또는 env의 `OPENAI_MODEL` 변경 |
| 429 | 한도 초과 | 결제·사용 한도 확인 |

모델 이름을 바꾸면 응답 품질이 달라질 수 있다. 바꿨다면 5절의 확인을 모델 이름까지 같은 조건으로 다시 한다.
`gpt-6-luna`가 아닌 모델에서는 백엔드가 보내는 `reasoning_effort` 옵션이 빠진다(`counseling_respond.py`).

### 3.3 로컬 Docker에서 같은 이미지로 먼저 확인

```bash
docker build -t mindrium-backend:$(git rev-parse --short HEAD) backend/app
docker run --rm --name mindrium-local --env-file ~/secrets/mindrium-demo.env \
  -p 127.0.0.1:8090:8070 mindrium-backend:$(git rev-parse --short HEAD)
```

이미지에는 `backend/app/.env`가 들어가지 않는다(`.dockerignore`가 `.env`, `.env.*`를 제외). 그래서 이 컨테이너가 **배포용 키만** 쓰는지 확인된다.
이 단계에서는 `DB_NAME=mindrium_demo`가 로컬 MongoDB에 새로 만들어지므로 데모 계정도 필요하다(3.4).

### 3.4 데모 계정과 점검

```bash
cd backend/app
MONGO_URI=<위와 같은 주소> DB_NAME=mindrium_demo DEMO_PASSWORD='<데모 비밀번호>' \
  python3 ../scripts/seed_demo_account.py

# 저장소 루트에서
BASE=http://127.0.0.1:8090 DEMO_PASSWORD='<데모 비밀번호>' tools/demo/preflight.sh
```

`preflight.sh`는 마지막에 `/counseling/respond`를 한 번 호출해 `prompt_version == respond_v15`를 확인한다. 키가 틀리면 여기서 실패한다.
시드 스크립트를 다시 돌리면 데모 계정 기록이 초기화된다.

### 3.5 외부 서버에 올리기

```bash
# x86 서버라면 --platform linux/amd64 로 빌드
docker save mindrium-backend:<태그> | ssh <서버> docker load      # 또는 레지스트리 push/pull
scp ~/secrets/mindrium-demo.env <서버>:/opt/mindrium/.env && ssh <서버> chmod 600 /opt/mindrium/.env
ssh <서버> docker run -d --name mindrium-backend --restart unless-stopped \
  --env-file /opt/mindrium/.env -p 8070:8070 mindrium-backend:<태그>
```

기존 서버가 8070을 쓰고 있다면 먼저 `docker ps`로 확인하고, 데모는 **다른 포트(예: 8071)** 로 띄워 비교한다. 기존 컨테이너와 DB는 건드리지 않는다.

그 뒤 서버 주소로 같은 점검을 한다.

```bash
BASE=http://<서버>:<포트> DEMO_PASSWORD='<데모 비밀번호>' tools/demo/preflight.sh
```

단, `preflight.sh`의 기기(adb) 항목은 USB·무선 디버깅 기기가 없으면 실패로 표시된다. 서버 점검 목적이면 그 항목은 무시해도 된다.

## 4. 키를 교체해야 할 때 (유출 의심, 만료)

1. OpenAI 대시보드에서 **먼저 해당 키를 폐기**한다.
2. 새 키를 발급해 env 파일의 `OPENAI_API_KEY`만 바꾼다.
3. `tools/deploy/check_openai_key.sh`로 확인한다.
4. **컨테이너를 다시 만든다.** `docker restart`는 env 파일을 다시 읽지 않는다.
   ```bash
   docker stop mindrium-backend && docker rm mindrium-backend
   docker run -d --name mindrium-backend --restart unless-stopped \
     --env-file /opt/mindrium/.env -p 8070:8070 mindrium-backend:<태그>
   ```
5. `tools/demo/preflight.sh`로 `respond_v15` 응답을 확인한다.

## 5. 배포 후 통과 기준

- [ ] `preflight.sh`가 `상담 모델 응답 (respond_v15, OpenAI 키 정상)`을 낸다
- [ ] 앱에서 상담 5턴 이상. `LLM_LED` 로그 그룹이 대부분 `direct`이고 `transport_fallback`이 없다
- [ ] 서버 로그에 `OPENAI_API_KEY not configured`, `counseling_respond: fail reason=http_401`, `http_429`가 없다
- [ ] 서버 DB(`mindrium_demo`)에 새 상담 요약이 저장된다
- [ ] 컨테이너를 다시 만든 뒤에도 상담 기록과 이전 상담 회상이 유지된다
- [ ] 모바일 데이터(Wi-Fi 끔)로 로그인과 상담이 된다

`/health`는 `{"status":"ok"}`만 반환하고 DB와 OpenAI 연결은 확인하지 않는다. 위 항목을 직접 해봐야 정상이다.

## 6. 저장소에 과거 키가 남아 있는지

과거에 `lib/chatbot/chatbot_main.dart`에 OpenAI 키(`sk-proj-...`)가 직접 적힌 로컬 커밋이 두 군데 있었다(2025-11, 2025-12). 둘 다 원격에는 올라간 적이 없다.
2026-11-14에 로컬 git에서 키가 든 커밋과 객체를 제거했고, 모든 객체에서 `sk-proj-` 패턴이 나오지 않는 것을 확인했다.

- 그 키들은 OpenAI 대시보드에서 폐기된 것으로 안다. 폐기를 다시 확인하고 싶으면 대시보드의 오래된 키 목록을 본다.
- 이 저장소를 복사해 둔 다른 PC나 백업에는 옛 기록이 남아 있을 수 있다. 키가 폐기됐다면 문제가 없다.
- 새로 만드는 키는 코드에 직접 적지 않는다. 이 문서의 방식(env 파일)만 쓴다.
- 커밋 전에 `git diff --cached | grep -n 'sk-'`처럼 키 패턴을 한 번 훑어 보면 실수를 막을 수 있다.
