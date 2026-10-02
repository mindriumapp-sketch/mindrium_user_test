# Mindrium 상담 챗봇 인수인계

기준: 2026-10-02, 브랜치 `2027_demo`. 이 문서는 상담 챗봇을 처음 맡는 개발자가 실행하고, 구조를 파악하고,
고칠 곳을 찾는 데 필요한 내용만 담았습니다.

| 더 볼 문서 | 내용 |
|---|---|
| [`counseling/chatbot_system.md`](counseling/chatbot_system.md) | 챗봇 구조와 규칙 전체(상태, 결정 계층, 기법, 발화 해석, 개인화, GPT 표현 계층) |
| [`backend_and_database.md`](backend_and_database.md) | 백엔드 API, 인증, MongoDB 컬렉션 |
| [`../README.md`](../README.md) | 앱 전체(8주 프로그램, 화면, 기술 스택) |

> 이 챗봇은 진단이나 치료를 대체하지 않습니다. 안전 관문은 키워드 기반이고, 상담 문장과 위기 응답은 아직 임상
> 검수를 받지 않았습니다. 외부 사용자에게 공개하기 전에 검수가 필요합니다.

---

## 1. 무엇을 만든 것인가

범불안 CBT 앱(8주 프로그램) 안의 "AI 마음상담" 화면입니다. 사용자가 걱정 하나를 말하면, 짧은 세션(보통 7~12턴)
동안 다음 순서로 진행합니다.

```
확인(불안 0~10) → 탐색(걱정되는 순간) → 되짚기(근거 → 다른 관점) → 기법(현재 주차까지 승인된 CBT 기법) → 마무리
```

설계의 핵심은 세 가지입니다.

1. **결정은 코드가, 표현만 GPT가.** 무엇을 물을지, 어떤 기법을 쓸지, 무엇을 인용할지는 모두 결정론 코드가
   정합니다. GPT(`gpt-4o-mini`, 백엔드 경유)는 일반 탐색·되짚기 턴의 문장만 다듬습니다. 검증에 실패하면 코드가
   만든 문장을 그대로 씁니다.
2. **턴 메타데이터로 흐름을 판단.** 각 응답 메시지에 목표 id, 기법 단계, 복구 사유, 마무리 단계 같은 메타데이터를
   붙이고, 다음 턴의 결정은 문장이 아니라 이 메타데이터를 읽습니다.
3. **세션 기억은 구조화된 요약만.** 대화 원문은 저장하지 않습니다. 세션이 끝나면 걱정, 핵심 생각, 대안 생각,
   사용 기법과 그 성과만 서버에 저장하고, 다음 세션에서 기법 순서를 정하거나 지난번 대안 생각을 다시 꺼낼 때
   씁니다.

---

## 2. 로컬에서 실행하기

### 2.1 준비물

- Flutter SDK(`pubspec.yaml`의 Dart 3.7 이상), Android 기기(무선 또는 USB 디버깅)
- Python 3.11 이상, MongoDB(로컬 `127.0.0.1:27017`)
- OpenAI API key(GPT 표현 계층을 쓸 때만)

### 2.2 백엔드

`backend/app/.env`는 git에 없습니다. 아래 키를 직접 만들어 넣으세요. 값은 관리자에게 받습니다.

| 변수 | 필수 | 설명 |
|---|---|---|
| `MONGO_URI` | 예 | 로컬 개발은 `mongodb://127.0.0.1:27017` |
| `DB_NAME` | 예 | 로컬 개발 DB는 `mindrium_dogfood`(2.4절). 기본값 `flutter_test`는 공용 서버 DB 이름이니 로컬에서는 꼭 지정 |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | 예 | 토큰 서명 키 |
| `OPENAI_API_KEY` | GPT 사용 시 | 없으면 `/counseling/realize`가 실패하고, 앱은 결정론 문장으로 대체 |
| `OPENAI_MODEL` | 아니오 | 기본 `gpt-4o-mini` |

```bash
cd backend/app
python3 -m pip install -r requirements.txt
MONGO_URI=mongodb://127.0.0.1:27017 DB_NAME=mindrium_dogfood PYTHONPATH=. \
  python3 -m uvicorn main:app --host 0.0.0.0 --port 8090
```

- `PYTHONPATH=.`이 없으면 `ModuleNotFoundError: core`로 뜨지 않습니다.
- 명령줄의 `MONGO_URI`가 `.env`보다 우선합니다. 빼면 `.env`에 적힌 서버로 붙고, 거기에 계정이 없으면 로그인이
  401로 실패합니다.
- 저장소 루트의 `.venv`가 예전 폴더 경로를 가리켜 `uvicorn` 실행 파일이 깨져 있을 수 있습니다. 그럴 때는 위처럼
  `python3 -m uvicorn`으로 띄우거나 가상환경을 다시 만드세요.
- 정상이면 `curl http://127.0.0.1:8090/health`가 200이고, `/counseling-sessions`는 로그인 없이 401을 돌려줍니다.

### 2.3 앱(실기기)

개발 Mac의 IP가 자주 바뀌므로, adb 포트 포워딩을 걸고 기기에서 `127.0.0.1`로 접속합니다.
`127.0.0.1` 평문 HTTP는 `android/app/src/main/res/xml/network_security_config.xml`에서 허용돼 있습니다.

```bash
adb reverse tcp:8090 tcp:8090          # 무선 디버깅이 다시 연결되면 다시 실행
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://127.0.0.1:8090 \
  --dart-define=COUNSELING_REMOTE_REALIZER=true \
  --dart-define=COUNSELING_REMOTE_REALIZER_KILL_SWITCH=false
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

| 빌드 플래그 | 기본 | 뜻 |
|---|---|---|
| `API_BASE_URL` | 디버그는 `http://115.145.134.180:8070` | 백엔드 주소 |
| `COUNSELING_REMOTE_REALIZER` | `false` | GPT 표현 계층 사용. 꺼져 있으면 모든 문장이 결정론 |
| `COUNSELING_REMOTE_REALIZER_KILL_SWITCH` | `false` | GPT 표현 즉시 차단 |
| `COUNSELING_SHADOW_CLASSIFIER` | `false` | 의미 분류기 그림자 관찰(Phase 14.2A). 내부 계정에서만, 결정에 쓰지 않음 |

GPT 표현은 플래그를 켜도 **내부 계정 허용 목록**에 있는 이메일에만 적용됩니다
(`lib/features/counseling/policy/rollout/internal_account_allowlist.dart`). 새 개발자는 자신의 계정 이메일을
여기에 추가해야 GPT 표현을 볼 수 있습니다.

### 2.4 개발용 DB

로컬 MongoDB에는 개발용 DB `mindrium_dogfood` 하나만 남아 있습니다(다른 테스트 DB는 2026-10-02에 삭제).

| 컬렉션 | 내용 |
|---|---|
| `users` | 테스트 계정 2개. 비밀번호는 관리자에게 받으세요 |
| `counseling_sessions` | 상담 세션 요약. 개인화 동작을 확인한 세션 기록이 들어 있음 |
| 그 밖 | 일기, 걱정 그룹, 진행도 등 앱 데이터 |

`counseling_sessions`에서 2026-10-02 05:10 UTC 이전 기록은 저장 로직을 고치기 전의 것이라 대안 생각 칸에 잘못된
값이 있습니다. 기법 성과(`intervention_outcome`)가 없거나 `acknowledged`라서 지난 대안 상기에는 쓰이지 않습니다.

```bash
mongosh mongodb://127.0.0.1:27017/mindrium_dogfood --eval \
  'db.counseling_sessions.find({},{_id:0,core_thought:1,alternative_thought:1,intervention_outcome:1}).sort({ended_at:-1}).limit(3)'
```

---

## 3. 코드 지도

```
lib/chatbot/chatbot_main.dart            상담 화면(ChatPage). harness 조립, 새 세션(↻)
lib/features/counseling/
  counseling_provider.dart               화면 ↔ 엔진. 메시지, 세션 저장, 지난 세션 로드
  counseling_harness.dart                한 턴 처리 진입점 handleTurn()
  counseling_state.dart                  상태 전이 CounselingStatePolicy
  turn_plan.dart                         Hard Guard(입력 검사, 대화 반응, 조기 마무리, 마무리 핸드셰이크)
  intervention_registry.dart             승인 기법 목록(4~8주차)
  hybrid_turn_router.dart                이번 턴에 GPT 표현을 써도 되는지
  remote_llm_realizer.dart               GPT 표현 요청과 검증
  safety_gate.dart                       위기 키워드 판정
  policy/
    production_turn_planner.dart         Hard Guard → 경계 → selector → 검증 → materializer
    selectors/                           상태별 결정(checkin, explore, reflect, intervention, closing)
    materializers/turn_plan_materializer.dart   결정 → 실제 문장. 상담 문장 대부분이 여기 있음
    intervention_eligibility_predicates.dart    기법 후보와 개인화 순서
    rollout/                             GPT 표현 공개 단계, 내부 계정 목록
lib/data/counseling/
  counseling_models.dart                 CounselingMessage와 턴 메타데이터
  user_thought_extractor.dart            발화 해석(걱정 생각인지, 저정보 답인지, 인용 가능한지)
  episode_history.dart                   지난 세션 이력(개인화)과 저장할 사실 추출(EpisodeFacts)
  local_cbt_knowledge_repository.dart    CBT 코퍼스 검색
lib/features/assistant/                  상담 / 앱 사용 안내 / 혼합 분기
lib/chatbot/affective/                   발화 감정 단서 → 아바타 표정
assets/counseling/knowledge/week0~8.json CBT 코퍼스(앱 번들)
assets/app_guide/app_guide_catalog.json  앱 사용 안내 지식
tools/cbt_corpus/                        코퍼스 생성 스크립트(curated/*.json → assets)
backend/app/routers/counseling_realize.py   POST /counseling/realize (GPT 호출, 시스템 프롬프트)
backend/app/routers/counseling_sessions.py  PUT/GET /counseling-sessions (세션 요약)
```

한 턴의 흐름은 다음과 같습니다.

```
사용자 발화 → SafetyGate(위기면 고정 응답) → 코퍼스 검색 → PolicyPipelineTurnPlanner
  → HybridTurnRouter ─ 허용: GPT 표현 → 검증(실패 시 결정론 문장)
                    └ 불허: 결정론 문장(기법·마무리·복구 턴은 항상 여기)
  → 응답 + 턴 메타데이터 → CounselingStatePolicy(다음 상태)
```

---

## 4. 자주 하게 될 수정과 고칠 곳

| 하고 싶은 것 | 고칠 곳 |
|---|---|
| 상담 문장(되짚기, 기법 질문, 통합, 마무리) 바꾸기 | `policy/materializers/turn_plan_materializer.dart` |
| 대화 반응 처리("무슨 말이야", "질문 그만해") 표현 추가 | `turn_plan.dart`의 `DeterministicProcessSignalTurnPlanner`. 오탐 예외 규칙도 같은 곳 |
| 걱정 생각·저정보 답 판정 바꾸기 | `lib/data/counseling/user_thought_extractor.dart` |
| 단계별 턴 수, 전이 조건 | `counseling_state.dart` |
| 기법 추가·승인 | `intervention_registry.dart` + 코퍼스(`tools/cbt_corpus/curated/weekN.json` 수정 후 `build_corpus.py`). 1~3주차 기법 승인은 임상 검수 사항이므로 임의로 추가하지 않습니다 |
| GPT 프롬프트·모델 | `backend/app/routers/counseling_realize.py`, `.env`의 `OPENAI_MODEL` |
| GPT 표현을 쓸 계정 | `policy/rollout/internal_account_allowlist.dart` |
| 위기 키워드 | `safety_gate.dart` |
| 세션 요약 필드 추가 | 아래 체크리스트 |

**세션 요약 필드를 추가할 때 고칠 다섯 곳.** 하나라도 빠지면 오류 없이 값이 사라집니다. 2026-10-02에 서버 목록
응답(`_serialize`)에 `intervention_outcome`이 빠져, 개인화가 기기에서만 동작하지 않은 적이 있습니다.

1. `backend/app/schemas/counseling_session.py`: 요청·응답 스키마
2. `backend/app/routers/counseling_sessions.py`의 `_serialize`: 응답 필드를 하나씩 나열하는 함수
3. `lib/data/api/counseling_sessions_api.dart`: `upsertSession` 매개변수
4. `lib/data/counseling/previous_session.dart`: `fromJson`
5. `lib/features/counseling/counseling_provider.dart`: 저장할 값 채우기(`EpisodeFacts` 참고)

---

## 5. 테스트

```bash
flutter test                    # 단위·대화·평가 테스트 934개, 10초 안팎
flutter analyze
flutter test integration_test/counseling_production_scenarios_test.dart -d <기기>   # 실기기, 로그인 상태 필요
```

| 묶음 | 위치 | 확인하는 것 |
|---|---|---|
| 단위 | `test/counseling/*_test.dart` | planner, selector, materializer, 라우터, 발화 해석 |
| 대화 재현 | `phase13_7_*`, `phase13_8_*`, `phase13_9c_dev_v2_test.dart` | 실기기에서 나온 결함을 대화 단위로 재현 |
| 세션·개인화 | `session_persistence_test.dart`, `multi_session_e2e_test.dart`, `personalization_episode_test.dart` | 저장, 지난 세션 로드, 기법 순서, 지난 대안 상기 |
| 평가 게이트 | `test/counseling/evaluation/` | 동결 발화 세트로 72세션 채점. 지표와 기준선은 `chatbot_system.md` 13절 |
| 실기기 시나리오 | `integration_test/` | 설치된 앱과 같은 경로로 실제 서버 데이터를 써서 여러 시나리오 실행 |

**주의:** 테스트의 서버는 가짜 저장소(`_InMemorySessionsApi`)라 실제 백엔드의 직렬화를 거치지 않습니다. 저장·조회
필드를 바꾸면 실기기나 실제 서버로 한 번 확인하세요.

**결함을 고치는 순서.** 지금까지 이 순서를 지켰습니다.

1. 기기에서 결함 발견
2. 의미 범주 정의(예: "챗봇에게 다시 설명을 요청하는 말")
3. 턴 메타데이터와 계약 정의
4. 결정론 정책으로 구현
5. 기기 대화를 테스트로 재현
6. 처음 보는 표현으로 확인
7. 기기에서 다시 확인

키워드 하나를 추가하는 식의 땜질보다, 검출에 실패해도 흐름이 망가지지 않는 구조적 안전장치를 먼저 둡니다
(`chatbot_system.md` 8.4절).

---

## 6. 현재 상태와 남은 일

**동작함(기기에서 확인)**
- 세션 흐름 전체: 확인 → 탐색 → 되짚기 → 기법 → 마무리, 마무리 제안 후 확정 또는 1회 계속
- 헷갈림, 저정보 답, 불만, 질문 반복 지적 처리와 조기 마무리
- 누적 기법(현재 주차까지), 위기 표현 차단
- 개인화: 지난 세션의 기법 성과로 기법 순서 조정, 비슷한 걱정이면 지난번 대안 생각을 다시 꺼냄

**진행 중:** Phase 14(적응형 multi-turn 상담). 설계(동결)는 [`counseling/phase14_dialogue_moves.md`](counseling/phase14_dialogue_moves.md)입니다.

**남은 일(우선순위 순)**
1. **임상 검수:** 상담 문장, 위기 응답, 1~3주차 기법 승인
2. **운영 준비:** 릴리스 빌드와 HTTPS, 서버 측 kill switch(지금은 빌드 플래그뿐), 서버 텔레메트리(지금은 기기 로컬
   로그), 운영 서버(`115.145.134.180:8070`)에 상담 API 배포 여부 확인
3. **처음 보는 표현 인식:** 규칙 기반이라 새 표현의 헷갈림·저정보 답을 놓칩니다. 지금은 흐름 안전장치가 피해를
   막습니다. 근본 해결은 모델 기반 의도 분류입니다.
4. **GPT 표현 품질:** 가끔 딱딱한 표현이 나옵니다(예: "걱정이 8이라는 점을 인정합니다"). 검증 규칙이나
   프롬프트로 다듬을 수 있습니다.
5. **개인화 확장:** 반복 걱정 패턴, 미해결 주제로 세션 시작, SUD 변화 반영은 아직 없습니다.

**개발 과정 기록**은 저장소에서 지웠고 git에 남아 있습니다. 단계별 설계 문서와 이전 엔진은 태그
`counseling-v1.2-session-flow`에서 볼 수 있습니다. 평가 세트는 회귀 게이트로 쓰기 위해 다시 저장소에 두었습니다.

```bash
git show counseling-v1.2-session-flow --stat
git log --oneline -- docs/counseling test/counseling/evaluation
```
