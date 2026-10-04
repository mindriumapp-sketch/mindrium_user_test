# Mindrium 상담 챗봇 인수인계

기준: 2026-10-04, 브랜치 `2027_demo`, 태그 `counseling-handover-v2`(이 커밋에서 데모·인수인계 대상 챗봇이 재현됨, 프롬프트 `respond_v14`). 상담 챗봇을 처음 맡는 개발자가
실행하고, 구조를 파악하고, 고칠 곳을 찾는 데 필요한 내용만 담았습니다.

| 더 볼 문서 | 내용 |
|---|---|
| [`counseling/chatbot_system.md`](counseling/chatbot_system.md) | 챗봇 구조 전체: 두 경로, B 계약과 검증 규칙, A 파이프라인, 개인화, 표정 규칙, 테스트 |
| [`counseling/asis_tobe.md`](counseling/asis_tobe.md) | 예전 챗봇과 지금 챗봇 비교(AS-IS / TO-BE) |
| [`backend_and_database.md`](backend_and_database.md) | 백엔드 API, 인증, MongoDB 컬렉션 |
| [`../README.md`](../README.md) | 앱 전체(8주 프로그램, 화면, 기술 스택) |

> 이 챗봇은 진단이나 치료를 대체하지 않습니다. 위기 감지는 키워드 기반이고, 상담 문장과 위기 응답, 1~3주차
> 기법은 아직 임상 검수를 받지 않았습니다. 외부 사용자에게 공개하기 전에 검수가 필요합니다.

---

## 1. 무엇을 만든 것인가

범불안 CBT 앱(8주 프로그램) 안의 "AI 마음상담" 화면입니다. 사용자가 걱정을 말하면 짧은 세션 동안 걱정을 살펴보고,
그 주차까지 배운 CBT 기법을 적용하도록 돕습니다. 상담 중에 앱 사용법을 물어도 답하고, 지난 상담 기록을 기억합니다.

**설계의 핵심: 경계는 코드가, 대화는 LLM이.**

| 코드가 정함 (LLM 밖) | LLM이 정함 (경계 안) |
|---|---|
| 위기 판정(먼저 실행, 위기면 LLM을 부르지 않음) | 상담·앱 안내·혼합 중 무엇으로 답할지 |
| 쓸 수 있는 사용자 기록, 앱 사실, 승인 기법(id 목록) | 대화 전략(공감, 질문, 기법 제안, 마무리 제안) |
| 용어 정의와 과거 기록 회상의 근거 | 자연스러운 문장 |
| 최종 검증(조언·진단·보장 금지, 근거 없는 사실, 질문 수, 반복 등) | |

```
사용자 발화
  → SafetyGate ── 위기 → 고정 위기 응답
  → B: LlmLedContext(경계) → POST /counseling/respond (GPT 1회) → LlmLedValidator
        ├ 통과 → B 응답
        └ 거절·오류·8초 초과 → A: 결정론 파이프라인 응답 (이번 턴만)
  → 턴 메타데이터 → 다음 상태, 표정, 세션 저장
```

B는 허용 목록 계정에서만 켜집니다(사용자 원문이 OpenAI로 가기 때문). 다른 계정은 A만 씁니다.

---

## 2. 로컬에서 실행하기

### 2.1 준비물

- Flutter SDK(Dart 3.7 이상), Android 기기(무선 또는 USB 디버깅)
- Python 3.11 이상, MongoDB(`127.0.0.1:27017`)
- OpenAI API key

### 2.2 백엔드

`backend/app/.env`는 git에 없습니다. 값은 관리자에게 받습니다.

| 변수 | 필수 | 설명 |
|---|---|---|
| `MONGO_URI` | 예 | 로컬은 `mongodb://127.0.0.1:27017` |
| `DB_NAME` | 예 | 로컬 개발 DB `mindrium_dogfood`. 기본값 `flutter_test`는 공용 서버 DB 이름이니 꼭 지정 |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | 예 | 토큰 서명 키 |
| `OPENAI_API_KEY` | 예 | 없으면 B와 A의 문장 표현이 모두 실패하고 결정론 응답만 나감 |
| `OPENAI_MODEL` | 아니오 | 기본 `gpt-4o-mini` |

가상환경은 git에 없는 로컬 환경입니다. 의존성의 기준은 `backend/app/requirements.txt`입니다(Python 3.12에서 확인).

```bash
# 처음 한 번: 환경 만들기
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/app/requirements.txt

# 실행
cd backend/app
MONGO_URI=mongodb://127.0.0.1:27017 DB_NAME=mindrium_dogfood PYTHONPATH=. \
  ../.venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8090
```

- `PYTHONPATH=.`이 없으면 `ModuleNotFoundError: core`가 납니다.
- 시작할 때 `bcrypt ... __about__` 경고가 보이는데, passlib 버전 경고일 뿐 동작에는 영향이 없습니다.
- 저장소 루트의 `.venv`는 예전에 쓰던 환경이라 쓰지 않습니다.
- **프롬프트는 서버가 시작할 때 읽습니다.** `counseling_respond.py`를 고치면 반드시 재시작하세요.
- 정상이면 `curl http://127.0.0.1:8090/health`가 200입니다.

### 2.3 앱(실기기)

```bash
adb reverse tcp:8090 tcp:8090          # 무선 디버깅이 다시 연결되면 다시 실행
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://127.0.0.1:8090 \
  --dart-define=COUNSELING_LLM_LED_PATH=true \
  --dart-define=COUNSELING_REMOTE_REALIZER=true \
  --dart-define=COUNSELING_REMOTE_REALIZER_KILL_SWITCH=false
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

또는 `DEMO_PASSWORD='<데모 비밀번호>' tools/demo/preflight.sh --install`로 점검과 설치를 한 번에 합니다.

| 빌드 플래그 | 기본 | 뜻 |
|---|---|---|
| `API_BASE_URL` | 디버그는 `http://115.145.134.180:8070` | 백엔드 주소. 로컬은 포트 포워딩 후 `http://127.0.0.1:8090` |
| `COUNSELING_LLM_LED_PATH` | `false` | **B 경로(주 경로) 사용.** 끄면 A만 동작 |
| `COUNSELING_REMOTE_REALIZER` | `false` | A의 일반 탐색·되짚기 문장을 GPT로 다듬기 |
| `COUNSELING_REMOTE_REALIZER_KILL_SWITCH` | `false` | A의 GPT 문장 표현 즉시 차단 |

**허용 목록:** `lib/features/counseling/policy/rollout/internal_account_allowlist.dart`. B와 A의 GPT 표현은 여기 있는
이메일에만 켜집니다. 지금은 개발 계정과 데모 계정(`mindrium.demo@example.com`) 두 개입니다. 새 주소를 넣으면 그
사용자의 발화가 OpenAI로 가므로 의도적으로만 추가하세요(가드 테스트 `internal_account_allowlist_test.dart`).

### 2.4 개발용 DB와 데모 계정

로컬 DB는 `mindrium_dogfood` 하나입니다.

- **데모 계정:** `backend/scripts/seed_demo_account.py`로 만들고 되돌립니다. 5주차, 합성 과거 기록(발표 걱정 상담
  1건과 그때 정리한 생각, 수면 걱정 상담 1건, 걱정 일기 4개)이 들어갑니다. 다시 실행하면 데모 계정 데이터만 지우고
  같은 상태로 만듭니다. 명령은 7.1절에 있습니다.
- **개발 계정:** 실제로 테스트한 대화 기록이 남아 있으니 시연에 쓰지 마세요.

---

## 3. 코드 지도

```
lib/chatbot/
  chatbot_main.dart                       상담 화면(ChatPage). 엔진 조립, 두 박자 표정, 음성, 새 세션(↻)
  affective/                              정서 단서 + 응답 행동 → 상담사 표정 (chatbot_system.md 11.1절)
lib/features/counseling/
  llm_led/llm_led_contract.dart           B: 경계 구성(LlmLedContext), 출력 파싱, 검증기, 메타데이터 매핑, 회상(RecallRequest)
  llm_led/term_glossary.dart              B: 용어 질문 판정
  counseling_harness.dart                 handleLlmLedTurn()(B), handleTurn()(A)
  counseling_provider.dart                화면 ↔ 엔진. B 먼저 → 실패 시 A, LLM_LED 로그, 세션 저장, 지난 세션 로드
  counseling_state.dart                   상태 전이
  turn_plan.dart                          A의 Hard Guard(입력 검사, 대화 반응, 조기 마무리, 마무리 핸드셰이크)
  policy/                                 A의 결정 계층(경계 → selector → 검증 → materializer), 공개 단계와 허용 목록
  safety_gate.dart                        위기 키워드 판정
  intervention_registry.dart              승인 기법 목록(4~8주차, 현재 주차까지 누적)
  hybrid_turn_router.dart, remote_llm_realizer.dart   A의 GPT 문장 표현 여부와 요청
lib/features/assistant/                   상담 / 앱 사용 안내 / 혼합 분기(A 경로)
lib/data/counseling/                      메시지·메타데이터 모델, 발화 해석, 지난 세션 이력, 사용자 맥락, 코퍼스 검색
lib/data/api/counseling_respond_api.dart  /counseling/respond 클라이언트와 실패 분류
assets/counseling/knowledge/              승인 CBT 코퍼스(week0~8.json). 생성: tools/cbt_corpus/
assets/counseling/glossary.json           용어 이름·별칭(정의는 코퍼스에서 읽음)
assets/app_guide/app_guide_catalog.json   앱 사용 안내 지식
assets/npc_images/                        상담사 표정 그림
backend/app/routers/counseling_respond.py POST /counseling/respond: 시스템 프롬프트(respond_v14), 요청별 JSON 스키마
backend/app/routers/counseling_realize.py POST /counseling/realize: A의 문장 표현
backend/app/routers/counseling_sessions.py PUT/GET /counseling-sessions: 세션 요약
backend/scripts/seed_demo_account.py      데모 계정과 합성 기록
tools/demo/                               preflight.sh(시연 전 점검), latency_breakdown.py(LLM_LED 로그 집계)
```

---

## 4. 자주 하게 될 수정과 고칠 곳

| 하고 싶은 것 | 고칠 곳 |
|---|---|
| B의 말투·대화 원칙 | `backend/app/routers/counseling_respond.py`의 `SYSTEM_PROMPT`(바꾸면 `PROMPT_VERSION`을 올리고 서버 재시작) |
| B가 받는 근거(사실·기법·진행 근거) | `llm_led_contract.dart`의 `LlmLedContext.build` |
| B 응답을 막는 규칙 추가·수정 | `llm_led_contract.dart`의 `LlmLedValidator`. **검증을 느슨하게 해서 대체율을 낮추지 않습니다.** 오탐만 고치고, 모델이 처음부터 맞게 쓰도록 프롬프트·근거를 바꿉니다 |
| 용어 추가 | `assets/counseling/glossary.json`(이름·별칭만, 정의는 코퍼스 항목 id로 연결) |
| 기법 추가·승인 | `intervention_registry.dart` + 코퍼스(`tools/cbt_corpus/curated/weekN.json` 수정 후 생성). 1~3주차 승인은 임상 검수 사항 |
| 종료 요청 인식 | `policy/selectors/closing_decision_selector.dart`(`isExplicitEnd`, `isEndOnly`) |
| 상담사 표정 | `lib/chatbot/affective/affective_adapter.dart`(`respond`), 그림 배정 `avatar_asset_resolver.dart` |
| 위기 키워드 | `safety_gate.dart` |
| A의 상담 문장 | `policy/materializers/turn_plan_materializer.dart` |
| B/A를 쓸 계정 | `policy/rollout/internal_account_allowlist.dart` |
| 세션 요약 필드 추가 | 아래 다섯 곳 |

**세션 요약 필드를 추가할 때 고칠 다섯 곳.** 하나라도 빠지면 오류 없이 값이 사라집니다.

1. `backend/app/schemas/counseling_session.py`
2. `backend/app/routers/counseling_sessions.py`의 `_serialize`
3. `lib/data/api/counseling_sessions_api.dart`의 `upsertSession`
4. `lib/data/counseling/previous_session.dart`의 `fromJson`
5. `lib/features/counseling/counseling_provider.dart`(저장할 값 채우기, `EpisodeFacts` 참고)

---

## 5. 테스트와 진단

```bash
flutter test                                                       # 10초 안팎
flutter analyze
cd backend/app && PYTHONPATH=. ../.venv/bin/python -m pytest -q tests  # 백엔드
```

| 묶음 | 위치 |
|---|---|
| 단위 (B 계약·검증기, 표정, A 구성요소, 저장·개인화) | `test/counseling/*_test.dart` |
| A 경로 회귀 (홀드아웃 v1~v5, 멀티턴, 주차별 진행, 비협조 사용자) | `test/counseling/regression/` |
| 데모 스모크 (실제 백엔드, 환경 변수 필요) | `test/counseling/regression/demo_smoke_test.dart` |

**실기기에서 문제가 생기면**

1. `adb logcat -d -s flutter | grep LLM_LED > log.txt` → `python3 tools/demo/latency_breakdown.py log.txt`로
   턴별 그룹(B 직접 / 내용 대체 / 전송 실패 대체), 거절 사유, 요청 상태, 지연을 봅니다.
2. 대화 원문은 기기 앱 저장소에 있습니다:
   `adb shell run-as com.mindrium.gad_app_team ls app_flutter/logs` (`chat_session_*.json`).
3. 백엔드 터미널에는 실패 사유(`counseling_respond: fail reason=...`)가 남습니다.

**주의:** 테스트의 서버는 가짜 저장소라 실제 백엔드 직렬화를 거치지 않습니다. 저장·조회 필드를 바꾸면 실기기나
실제 서버로 확인하세요.

---

## 6. 현재 상태와 남은 일

**동작함 (실기기 확인)** — 인수인계 태그 시점에 `flutter analyze`, `flutter test`, 백엔드 테스트, `preflight.sh`가 모두 통과했습니다.
- B 주 경로 + A 대체: 데모 스모크 19턴 대체 0, 상담 조언 노출 0, 지어낸 기록 0
- 상담 중 앱 사용법 질문(실제 앱 기준 기능 24개와 사용법 안내 10개, 없는 기능은 "없다"고 답함), 용어 질문(승인 정의만), 맥락 밖 입력(인사, "?", 엉뚱한 화제) 안내
- 과거 기록 회상(사용자가 "예전에도"라고 하면 지난 상담의 걱정과 그때 정리한 생각을 직접 말함), 일기에 적은 대안 생각 참고
- 챗봇은 불안 점수(0~10)를 묻지 않음(A·B 모두). 불안 점수는 앱의 '오늘의 할 일' 불안 평가에서만 기록
- 종료 요청 즉시 마무리, 위기 응답, 두 박자 상담사 표정
- 응답 시간: B 직접 응답 p50 약 3초(사용자 판단으로 추가 최적화하지 않음)

**알려진 한계**
- statement 안의 숨은 두 번째 질문 등으로 B가 거절되면 A가 답하는데, A 답은 덜 자연스럽습니다(데모 스모크 기준 드묾).
- "사용자가 하지 않은 말 인용"은 프롬프트로만 막습니다.
- 개인화 데이터 범위: "효과 있었던 기법"은 지난 상담 기록에서만 옵니다(이완 전후 불안 점수는 설계상 저장하지 않음). 일기에 적은 대안 생각은 상담에 전달됩니다.

**남은 일(우선순위 순)**
1. **임상 검수:** 상담 문장, 위기 응답과 위기 키워드, 1~3주차 기법 승인
2. **운영 준비:** 릴리스 빌드와 HTTPS, 서버 측 kill switch(지금은 빌드 플래그뿐), 서버 텔레메트리(지금은 기기 로그),
   운영 서버(`115.145.134.180:8070`)에 상담 API 배포, 상담용 OpenAI 키·사용량 분리
3. **품질:** 대체 사유 상위(숨은 두 번째 질문, 반복 질문) 감소, A 대체 응답 다듬기

예전 개발 기록(단계별 설계, 평가 결과, 예전 챗봇 코드)은 저장소에서 지웠고 git 기록에만 있습니다.

---

## 7. 시연하기

시연 전에는 상담 로직과 프롬프트를 바꾸지 않습니다(기준은 태그 `counseling-handover-v2`).

### 7.1 준비 (하루 전)

- 개발용 Mac, 안드로이드 기기, 같은 Wi-Fi(무선 디버깅) 또는 USB 케이블
- `backend/app/.env`의 `OPENAI_API_KEY`(값은 문서에 적지 않음), MongoDB 실행 중
- 데모 계정 비밀번호(따로 전달받은 값). 계정은 `mindrium.demo@example.com`
- 데모 계정 초기화. 리허설 대화도 "지난 상담"으로 저장되므로 **리허설 뒤에도 다시 실행**합니다:
  ```bash
  cd backend/app
  MONGO_URI=mongodb://127.0.0.1:27017 DB_NAME=mindrium_dogfood \
    DEMO_PASSWORD='<데모 비밀번호>' python3 ../scripts/seed_demo_account.py
  ```
  초기화할 때 넣은 비밀번호가 계정 비밀번호가 됩니다. 항상 같은 값을 쓰세요.

### 7.2 당일 순서

1. 백엔드 실행(2.2절 명령). 코드를 바꿨다면 반드시 재시작
2. 사전 점검과 설치: `DEMO_PASSWORD='<데모 비밀번호>' tools/demo/preflight.sh --install`
   - 점검 항목: 백엔드 응답, 데모 계정 로그인, 5주차, 과거 상담 기록, 상담 모델 응답(`respond_v14`, OpenAI 키), 기기 연결, 포트 포워딩, B 경로 빌드 설치
   - 모두 `OK`여야 합니다. 무선 디버깅이 다시 붙으면 다시 실행합니다(포워딩을 다시 건다).
3. 앱에서 데모 계정으로 로그인 → 홈에 "데모 사용자님", 5주차인지 확인
4. 앱 내 확인(각 1턴). 확인 뒤에는 데모 계정을 다시 초기화하고 앱을 재시작합니다.

   | 입력 | 정상 |
   |---|---|
   | "다음 주 발표 때문에 걱정돼요" | 걱정을 받아 주고 질문 하나 |
   | "걱정 일기는 어디서 봐요?" | 실제 메뉴로 안내 |
   | "나 예전에도 발표로 걱정한 적이 있었던 것 같아" | 지난 발표 상담의 걱정과 그때 정리한 생각('긴장해도 준비한 내용은 설명할 수 있고…')을 직접 말함 |
   | "오늘은 여기까지만 할래요" | 바로 마무리 |

### 7.3 시연 대본 (한 세션)

| 순서 | 사용자 | 보여 주는 것 |
|---|---|---|
| 1 | "다음 주 발표 때문에 걱정돼." | 자연스러운 상담 시작 |
| 2 | (상담자 질문에 답하기) "말이 막히면 다들 비웃을 것 같아." | 맥락을 따라가는 대화 |
| 3 | "예전에 나도 비슷한 걱정 한 적 있었나?" | DB 기반 개인화(과거 상담 회상) |
| 4 | (회상 질문에) "응, 준비한 건 설명할 수 있을 것 같아." | 기법 진행. 짧은 답("좋아")보다 내용 있는 답이 자연스럽게 이어짐 |
| 5 | "그때 적은 걱정일기는 앱에서 어디서 볼 수 있어?" | 상담 → 앱 안내 전환 |
| 6 | "그럼 지금 걱정으로 다시 얘기해보자." | 상담 복귀 |
| 7 | "자동사고가 뭐야?" | 승인된 용어 정의 |
| 8 | "오늘은 여기까지만 할래." | 자연스러운 종료 |

- 응답은 매번 조금씩 다릅니다(LLM). 대본은 흐름을 보여 주는 용도입니다.
- "탈파국화"처럼 코퍼스 밖 용어는 정의하지 않는 것이 정상입니다.
- **위기 응답은 메인 시연에 넣지 않습니다.** 질문을 받으면 "위기 표현은 LLM보다 먼저 SafetyGate가 처리하고 고정 안내(109, 119)를 낸다"고 설명하고, 키워드 기반 감지와 전문가 검수 전 문구라는 한계를 함께 말합니다.
- **말하지 말 것:** 임상적으로 검증된 치료 도구라고 소개하지 않습니다. 데모 계정의 과거 기록은 합성 데이터이며 실제 사용자 기록이 아닙니다.

### 7.4 문제가 생기면

| 증상 | 조치 |
|---|---|
| 답이 기계적이고 "그 일에 대해 조금 더 이야기해 주실 수 있을까요?"처럼 정해진 문장만 나온다 | B 경로가 꺼짐: 데모 계정이 아니거나 빌드 플래그 누락 → `preflight.sh --install` |
| 응답이 오지 않거나 로그인 실패 | 포워딩 끊김 또는 백엔드 꺼짐 → `preflight.sh` |
| "Invalid or expired access token" | 로그아웃 후 다시 로그인 |
| 비밀번호가 맞는데 로그인 실패 | 다시 로그인 시도(포워딩 직후 첫 요청이 실패하는 경우가 있음), 그래도 안 되면 `preflight.sh` |
| 과거 기록을 회상하지 않는다 | 데모 데이터가 지워짐 → 7.1절 초기화, 앱 재시작 |
