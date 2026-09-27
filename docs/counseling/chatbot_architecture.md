# Mindrium 상담 챗봇 전체 구조와 설계

**최종 갱신: 2026-09-27 (Phase 10.6C-DOGFOOD 진행 중, 실기기 dogfooding 반영).**
이 개정에서 갱신된 주요 내용: Phase 10.2~10.6의 semantic realization 계약,
canary rollout 인프라, Stage 1 실기기 배선, 그리고 오늘 실기기 dogfooding에서
발견·수정한 두 건의 App/UI 결함(말풍선 중복, fallback 인용 문구) — 9, 9.3, 9.4,
19, 20, 22절을 특히 참고. 이전 개정(2026-09-17)은 온디바이스 경로 폐기만
반영했고, 이번 개정 전까지는 Phase 10 전체(semantic realizer, rollout, 실기기
검증)가 이 문서에 반영되어 있지 않았다.

## 1. 문서 목적

이 문서는 현재 Flutter 앱에 구현된 `디지털 CBT 상담` 기능의 실제 코드 구조와
런타임 동작을 설명한다. 초기 PoC, 결정론적 planner 실험, 온디바이스 LLM(Kanana
base/K2 QLoRA) 연결을 거쳤으나, 2026-09-17 온디바이스 경로 전체를 폐기하고
backend proxy를 통한 GPT 기반 `RemoteLlmRealizer`로 전환했다. 온디바이스 관련 Dart
코드와 문서는 저장소에서 제거했다(git 이전 커밋을 참고). vendor 플러그인
(`packages/llama_flutter_android_mindrium`)과 GGUF 모델 파일(`research_data/models/`)은
git에 커밋된 적이 없어 로컬에서 완전히 삭제됐고 복구할 수 없다 — 다시
필요하면 원본을 재확보하고 처음부터 다시 빌드해야 한다. 이후 Phase 10에서는
그 GPT 표현 계층 자체의 문장 품질(따옴표 인용, 문장 간 단절)을 실측 평가로
검증하고, 검증된 부분만 실기기 Stage 1 dogfooding으로 단계적으로 열었다. 이
문서는 다음을 구분해 기록한다.

- 현재 제품 화면에서 실행되는 경로
- 모델이 담당하는 일과 Harness가 통제하는 일
- 사용자 기록과 CBT corpus가 선택되는 방식
- 결정론적 fallback과 개발용 Mock의 역할
- 안전, 음성, 표정, 모델 lifecycle 정책
- 실현(realization) 품질을 어떻게 평가했고 무엇이 실제로 반영됐는지
- canary rollout이 실기기의 누구에게, 어떤 조건으로 열려 있는지
- 현재 확인된 성능·품질 한계와 다음 개선 방향

이 기능은 의료 진단이나 전문 치료를 대체하는 시스템이 아니다. 현재 안전 분류도
키워드 기반의 구조 검증 단계이며, 임상 배포 전에는 별도 검수와 강화가 필요하다.

---

## 2. 현재 구현 요약

현재 상담 화면에는 두 가지 조립 방식이 있고, GPT 표현 계층은 다시 두 겹의
게이트(빌드 플래그 + canary rollout)를 통과해야 실제로 켜진다.

| 구성 | 활성 조건 | 응답 생성 |
| --- | --- | --- |
| GPT 표현 계층 | `COUNSELING_REMOTE_REALIZER=true` **그리고** canary rollout이 이 세션을 허용(§9.4) | `TurnPlan` 초안을 backend `/counseling/realize` 경유 GPT(`gpt-4o-mini`)가 자연어로 다듬음 — explore/reflect 상태에서만 시도됨 |
| 결정론적 기본값 | 위 조건 중 하나라도 거짓 (오늘 기준 제품 기본값이자 사실상 전체 사용자) | 상태별 deterministic planner가 완성 문장을 그대로 사용 |

Flutter 앱은 OpenAI API를 직접 호출하지 않는다. `RemoteLlmRealizer`(Flutter)가
Mindrium backend의 `POST /counseling/realize`만 호출하고, API key와 실제 OpenAI
호출은 backend(`backend/app/routers/counseling_realize.py`)에만 있다. 모델·temperature·
max token은 backend 환경변수(`OPENAI_MODEL` 등, `backend/app/.env`)로 고정하고 앱
요청이 바꿀 수 없다.

현재 제품 기본값은 deterministic 경로다. GPT는 명시적인 define으로만 켠다. GPT
경로에서도 모델은 상담 정책을 정하지 않는다. `DeterministicCounselingTurnPlanner`가
반영 대상·질문 목표·CBT 개입·금지 행동을 먼저 정하고, GPT는 그 결과를 자연스러운
한국어로 표현만 바꾼다. `TurnPlanAdherenceValidator`류 검증(질문 개수 일치, 조언·
진단 금지, 태그/JSON 유출 금지)을 통과하지 못하거나 네트워크 오류가 나면 항상
deterministic draft로 되돌아간다 — 위기 대응, state 전이, CBT 선택은 GPT 없이도
항상 완전히 동작한다. 자세한 계약은
[`remote_gpt_realizer_integration.md`](remote_gpt_realizer_integration.md)에 있다.

**배포 경계(중요, 혼동 금지)**: Phase 10의 `/counseling/*` 엔드포인트(`realize`,
`decide`, `sessions`)는 이 저장소의 `backend/app`을 그대로 실행한 백엔드에만
존재한다. 앱 디버그 빌드가 기본으로 바라보는 공유 서버
(`http://115.145.134.180:8070`)는 이 엔드포인트가 **전혀 배포되어 있지 않다**
(자체 `openapi.json`으로 확인됨 — diaries/edu-sessions 등 상담 챗봇 이전 버전
API만 있음). 즉 "production 코드에 구현됨"과 "공유/운영 서버에 배포됨"은 서로
다른 사실이다 — 지금은 전자만 참이다. 실기기로 GPT 경로를 확인하려면
`--dart-define=API_BASE_URL=http://<이 저장소의 backend를 실행 중인 호스트>:<포트>`로
빌드해 이 저장소의 백엔드를 직접 가리켜야 한다(§22.2).

과거에는 온디바이스 GGUF(Kanana-2-3B base, 이후 KMI QLoRA 파인튜닝 K2)를 붙인
`CounselingHarness.fastOnDevice`/`.kananaBaseHybrid` 경로가 있었다. K2는 상담
문형은 개선했지만 Ko-IFEval에서 일반 지시 수행 능력이 크게 회귀했고, 온디바이스
경로 전체(vendor llama.cpp 플러그인, 모델 배포, 실기기 지연시간 문제)를
GPT 표현 계층으로 대체하기로 결정해 2026-09-17에 코드·모델·문서를 모두 제거했다.

---

## 3. 전체 실행 흐름

```text
HomeScreen
  └─ AI 마음상담
      └─ ChatPage                         UI/STT/TTS/Avatar
          └─ CounselingProvider           세션/메시지/로딩 상태
              ├─ MindriumContextBuilder   사용자 데이터 검색·정규화
              └─ CounselingHarness        한 턴의 정책 파이프라인
                  ├─ SafetyGate
                  ├─ CbtKnowledgeRepository
                  ├─ CounselingStatePolicy
                  ├─ DeterministicCounselingTurnPlanner
                  │   └─ RealizationSpecBuilder → CounselingRealizationSpec (§9.3)
                  ├─ HybridTurnRouter.route()     → allowLlm (state 기반, explore/reflect만 true)
                  ├─ evaluateRollout()            → RolloutConfig 게이트 (§9.4, rolloutConfig가 있을 때만)
                  ├─ ResponseRealizer             → 위 둘 다 true일 때만 호출됨
                  │   ├─ DeterministicResponseRealizer (제품 기본값)
                  │   ├─ SemanticDeterministicResponseRealizer (Remote reject 시 fallback, §9.2)
                  │   └─ RemoteLlmRealizer (COUNSELING_REMOTE_REALIZER=true + rollout 허용)
                  │       └─ CounselingRealizeApi
                  │           └─ backend POST /counseling/realize
                  │               └─ OpenAI Chat Completions
                  ├─ CounselingOutputParser
                  ├─ provenance/act 검증
                  └─ RealizationTelemetrySink (구조적 메타데이터만, §9.4)
```

현재 제품의 정상 턴은 다음 순서로 처리된다.

```text
사용자 발화
  ↓
(현재는 비활성 — 실기기 dogfooding에서 말풍선 중복으로 판명돼 제거, §5.1)
  ↓
현재 발화와 관련된 사용자 기록 재선별
  ↓
SafetyGate
  ├─ elevated/crisis → 고정 안전 응답, LLM 호출 없음
  └─ normal
       ↓
현재 state/week에 맞는 CBT 검색
       ↓
TurnPlanner가 반영 대상·질문 목표·CBT 개입을 확정 (+ RealizationSpec 구성)
       ↓
HybridTurnRouter.allowLlm && evaluateRollout(...).attemptRemote 모두 true?
  ├─ 아니오 → deterministic draft 그대로 사용 (Remote 호출 자체가 없음)
  └─ 예 → RemoteLlmRealizer 호출
       ↓
출력 제약(질문 개수·조언 금지·태그 유출) 검사
  ├─ 통과 → GPT가 재표현한 문장 사용
  └─ 실패 또는 네트워크 오류
       → SemanticDeterministicResponseRealizer로 fallback
         (따옴표 인용 없는, 동일 질문의 결정론적 재표현 — §9.2)
       ↓
Harness가 required dialogue act와 construction provenance 확정
       ↓
telemetrySink가 있으면 구조적 telemetry 이벤트 1건 기록(원문 없음)
       ↓
StatePolicy가 다음 상태 결정
       ↓
ChatPage에 후속 질문 표시
```

---

## 4. 표시 계층: `ChatPage`

파일: `lib/chatbot/chatbot_main.dart`

`ChatPage`가 담당하는 일은 다음으로 제한한다.

- 메시지 입력과 말풍선 렌더링
- 상담 엔진 구현 조립
- STT와 TTS 사용자 제어
- 사용자 발화에 따른 상담사 아바타 표시
- 스크롤, 세션 재시작, 로컬 JSON 로그
- Harness가 반환한 UI action 처리

프롬프트 작성, CBT 검색, 상담 상태 전이, 일기 선택 같은 상담 판단은 UI 파일에
두지 않는다. 이를 검증하는 `legacy_disconnection_test.dart`가 있다.

### 4.1 GPT 기능 플래그와 canary rollout 배선

```text
COUNSELING_REMOTE_REALIZER=true
COUNSELING_REMOTE_REALIZER_KILL_SWITCH=false   (기본값, Phase 10.6C)
```

테스트용 `LlmService`가 주입되지 않았고 `COUNSELING_REMOTE_REALIZER`가
true일 때만 `CounselingHarness.remoteGpt` + `RemoteLlmRealizer`를 조립한다.
그 외에는 `CounselingHarness.deterministic`으로 조립한다(제품 기본값). 모델
이름·temperature·max token은 Flutter가 결정하지 않는다 — backend
`backend/app/.env`의 `OPENAI_MODEL`이 고정한다.

Phase 10.6C부터는 `useRemoteRealizer`가 true여도 그 자체로 GPT가 켜지지
않는다 — `_createProvider()`가 추가로 `RolloutConfig`를 만들어
`CounselingHarness.remoteGpt(...)`에 넘기고, 실제 허용 여부는 매 턴
`evaluateRollout()`이 결정한다(§9.4).

```dart
final rolloutConfig = useRemoteRealizer
    ? RolloutConfig(enabled: true, stage: RolloutStage.internalOnly,
        killSwitch: _rolloutKillSwitch)
    : null;
final isInternalAccount = isInternalAccountEmail(
    context.read<UserProvider>().userEmail);
// ... CounselingHarness.remoteGpt(..., rolloutConfig: rolloutConfig,
//     isInternalAccount: isInternalAccount,
//     telemetrySink: logRealizationTelemetryLocally)
```

오늘(2026-09-27) 기준 `RolloutStage.internalOnly`로 고정돼 있고,
`internalAccountEmailAllowlist`(`lib/features/counseling/policy/rollout/internal_account_allowlist.dart`)에
등록된 이메일의 계정만 실제로 GPT를 시도한다. 이 허용목록은 dogfooding용
테스트 계정 하나만 들어 있고, 일반 사용자는 이 플래그가 켜진 빌드를 받아도
전부 deterministic 경로로 떨어진다(§9.4, §22.3).

### 4.2 `RemoteLlmRealizer` 네트워크 구성

```text
Flutter RemoteLlmRealizer
  └─ CounselingRealizeApi.realize()
       └─ ApiClient(Dio) → POST /counseling/realize
            Authorization: Mindrium access token
```

`ApiClient`는 `TokenStorage`의 기존 로그인 세션 토큰을 그대로 쓴다. API key는
Flutter 코드·dart-define·저장소 어디에도 없다.

---

## 5. 세션 상태: `CounselingProvider`

파일: `lib/features/counseling/counseling_provider.dart`

Provider는 화면과 Harness 사이의 상태 소유자다.

- 현재 `CounselingSessionState`
- 사용자/상담자 메시지 목록
- 생성 중 여부
- 사용자 컨텍스트
- 최근 안전 수준
- Harness가 제안한 UI action

세션 중 원문 메시지와 상태는 화면 수명 동안 메모리에 둔다. 종료 시에는 원문 전체가
아니라 핵심 걱정, 자동적 생각, 대안적 생각, SUD, 사용한 개입과 construction
provenance를 구조화한 요약만 `/counseling-sessions`에 upsert한다.

- `closing` 최초 진입: `completed`
- 앱 pause/detach 또는 화면 이탈: `interrupted`
- 동일 `(user_id, session_id)`는 하나의 문서로 유지
- 완료 문서를 뒤늦은 interrupted snapshot이 덮어쓰지 않음
- 저장 호출은 client queue에서 직렬화하며 동일 turn snapshot은 중복 전송하지 않음
- 다음 세션은 최근 완료 세션을 우선하고, 중단 세션은 미해결 주제만 제한적으로 사용

2026-09-05 운영 서버 점검에서는 `/health`가 200이었지만
`/counseling-sessions`가 404였다. 앱·backend source·로컬 E2E 계약은 구현됐지만,
운영 persistence는 해당 backend 변경 배포 전까지 활성화되지 않는다.

### 5.1 즉시 공감(`instantEmpathy`) — 현재 실제 호출부에서는 비활성

`EmpathyPlanner`(`lib/features/counseling/empathy_planner.dart`)와
`CounselingProvider.instantEmpathy` 플래그 자체는 여전히 존재하고 테스트로도
커버된다(`counseling_provider_test.dart`, `multi_session_e2e_test.dart`) — GPT
backend round-trip을 빈 화면으로 기다리지 않도록, 현재 발화에 근거한 짧은
공감 문장을 모델 호출 전에 먼저 보여주는 기능이다.

예시(기능 자체는 이렇게 동작):

| 사용자 단서 | 즉시 반응 예시 |
| --- | --- |
| 불안, 걱정 | 그 일 때문에 마음이 불안하고 신경 쓰이시는군요. |
| 힘듦, 피곤, 지침 | 그동안 많이 버티느라 마음도 몸도 지치셨겠어요. |
| 슬픔, 우울, 속상함 | 그 일을 겪으며 마음이 많이 무거우셨겠어요. |
| 두려움 | 그 상황이 많이 두렵게 느껴지시는군요. |
| 높은 숫자 응답 | 지금 불안이 꽤 크게 느껴지고 있군요. |

**하지만 2026-09-27부터 `chatbot_main.dart`의 실제 조립 지점은
`instantEmpathy: false`를 넘긴다** — 이전에는 `useRemoteRealizer`와 같은 값을
썼는데(GPT 경로일 때만 true), 실기기 Stage 1 dogfooding에서 이게 "말풍선이
매 턴 2개씩(즉시 공감 + 실제 답변) 뜨는" 문제로 이어진다는 걸 발견했다.
`instantEmpathy`가 즉시 공감을 실제 답변으로 *교체*하는 게 아니라 그 옆에
*추가*로만 붙이기 때문이다(`counseling_provider.dart`의 `_messages.add(empathy)`
다음에 `_messages.add(result.assistantMessage)`가 별도로 실행됨). Phase 10.5
평가 아티팩트는 시나리오당 완성 문장 하나만 보여줬기 때문에 이 이중 말풍선
문제가 원천적으로 드러날 수 없었다 — 실제 채팅 화면으로 봐야만 보이는
결함이었다(`phase10_6c_dogfood_log.md` 참고). 기능 자체를 지우지 않고 이 호출부의
배선만 끈 이유는, 다른 곳(테스트)에서는 여전히 유효한 기능이라서다.

### 5.2 컨텍스트 갱신

서버 데이터는 화면 수명 동안 한 번만 읽는다. 그러나 관련 기록 선택은 사용자 발화가
들어올 때마다 메모리 snapshot에서 다시 수행한다.

```text
API 원본 조회            화면 수명 중 1회
현재 발화 기반 재선별     매 사용자 턴
명시적 refreshContext     snapshot 무효화 후 API 재조회
```

이 방식은 세션 진입 시 우연히 선택된 한 일기가 모든 주제에 계속 붙는 문제를 막으면서
매 턴 API를 반복 호출하지 않는다.

---

## 6. 사용자 데이터 기반 경량 RAG

파일: `lib/data/counseling/mindrium_context_builder.dart`

현재 구현은 임베딩/vector DB 기반 RAG가 아니다. 서버의 구조화 데이터를 읽고 규칙
점수로 관련 항목을 선택하는 경량 retrieval이다.

### 6.1 데이터 소스

`ApiMindriumDataSource`는 다음 API를 감싼다.

- `DiariesApi`: ABC 일기 요약
- `WorryGroupsApi`: 걱정 그룹 이름
- `RelaxationApi`: 수행한 이완 과제와 전후 SUD

각 API는 독립적으로 실패할 수 있다. 하나가 실패해도 나머지 데이터로 degraded
context를 만들며 상담 진입을 막지 않는다.

### 6.2 정규화 결과

일기는 다음 형태의 `UserContextItem`으로 줄인다.

```text
id: diary:<diary_id>
type: diary
text: [그룹] 상황 / 생각 / 감정 / 행동
occurredAt
groupId
sud
```

대안적 생각은 `alt:<diary_id>`라는 별도 항목으로 만든다. 좌표와 주소 등 상담에
필요 없는 개인정보는 컨텍스트에 포함하지 않는다.

### 6.3 선택 정책

최대 최근 일기 30개를 후보로 보고 다음 점수를 사용한다.

| 조건 | 가중치 |
| --- | ---: |
| 최근 2주 이내 | +3 |
| focus worry group 일치 | +3 |
| 현재 발화 키워드 중첩 | +2 |
| SUD 7 이상 | +2 |

동점이면 최신순을 유지하고 최종 최대 5개를 컨텍스트에 둔다. 이 중 실제로
프롬프트/GPT 요청에 들어가는 개수는 각 realizer/promptBuilder가 따로 제한한다
(예: `RemoteLlmRealizer.maxCbtFacts` 기본값 1).

### 6.4 현재 RAG의 한계

- 형태소 분석이나 의미 임베딩이 없어 동의어와 간접 표현에 약하다.
- 최근성·높은 SUD가 키워드 관련성보다 강해 무관한 과거 기록이 선택될 수 있다.
- 관련 기록 원문을 모델이 과도하게 언급할 위험이 있다.
- retrieval 결과는 상담 전략 자체가 아니므로 planner/policy가 별도로 필요하다.

향후 RAG를 강화할 때도 긴 원문 여러 개를 모델에 넣기보다 관련 사용자 사실 1개와
승인된 CBT 근거 1개를 구조화·압축하는 방향이 적합하다.

---

## 7. CBT 지식 검색

파일:

- `lib/data/counseling/cbt_knowledge_repository.dart`
- `lib/data/counseling/local_cbt_knowledge_repository.dart`
- `assets/counseling/knowledge/week*.json`

CBT corpus는 앱 asset에서 로드한다. 검색 시 다음을 사용한다.

- 현재 사용자의 발화
- 현재 프로그램 주차
- 현재 상담 state의 retrieval tag
- 최대 검색 결과 3개

일반 compact prompt는 가장 관련 높은 CBT 1개를 모델에 제공한다. 현재
`FastPlainTextPromptBuilder`는 속도와 형식 안정성을 위해 CBT 본문과 ID를 모델 출력에
요구하지 않는다. 즉 CBT 검색 파이프라인은 유지되지만 빠른 평문 질문 생성에서는
직접적인 모델 grounding이 제한되어 있다.

---

## 8. 상담 상태 머신

파일: `lib/features/counseling/counseling_state.dart`

상태는 모델이 아니라 `CounselingStatePolicy`가 결정한다.

```text
checkIn → explore → reflect → intervention → closing
```

| 상태 | 기본 목적 | 턴 예산 | Harness required act |
| --- | --- | ---: | --- |
| checkIn | 오늘의 상태 확인 | 1 | explore |
| explore | 걱정 구체화 | 1 | explore |
| reflect | 핵심 생각 반영 | 2 | reflect |
| intervention | 다른 관점 질문/승인 개입 | 1 | socraticQuestion |
| closing | 요약과 마무리 | 최대 세션 한도 | closing |

전체 세션 한도는 20턴이다. 출력 act가 `unknown`이면 상태를 진행시키지 않는다.
빠른 평문 프로파일에서는 모델에게 act 분류를 시키지 않고 PromptBundle의
`requiredDialogueAct`를 Harness가 적용한다.

---

## 9. `CounselingHarness`

파일: `lib/features/counseling/counseling_harness.dart`

Harness는 한 상담 턴의 orchestration 경계다.

1. SafetyGate 실행
2. state/week/tag 기반 CBT 검색
3. 최근 메시지 window 구성
4. 선택적 TurnPlanner 실행
5. PromptBundle 생성
6. `ResponseRealizer`를 통한 deterministic 문장 또는 선택적 LLM 호출
7. 출력 파싱
8. dialogue act와 provenance 검증
9. state 전이
10. UI action 계산

### 9.1 주요 생성 모드

`TurnRealizationMode`는 다음 두 값을 가진다.

- `deterministic`: 모든 턴이 `ResponseRealizer`(deterministic 또는 remote)를 거친다
- `constrainedLlm`: (레거시) `HybridTurnRouter`가 허용한 turn만 raw LLM 호출, 나머지는 realizer — 어떤 production 조립 지점도 이 모드로 생성하지 않는다(테스트 전용, 도달 불가능)

`CounselingHarness.deterministic`과 `CounselingHarness.remoteGpt`
(`lib/features/counseling/counseling_harness.dart`) 둘 다
`turnPlanner: DeterministicCounselingTurnPlanner()` + `turnRealizationMode:
deterministic`을 쓴다. 차이는 `responseRealizer` 하나뿐이다.

```text
CounselingHarness.deterministic  → responseRealizer: DeterministicResponseRealizer()
CounselingHarness.remoteGpt      → responseRealizer: RemoteLlmRealizer(...)
```

즉 "무엇을 말할지"(반영 대상·질문 목표·CBT 개입·state 전이)는 두 구성 모두
`DeterministicCounselingTurnPlanner`가 정하고, 유일한 차이는 그 결과를 그대로
쓰는지(deterministic) GPT로 재표현한 뒤 검증하는지(remoteGpt)다.
`ChatPage`(`lib/chatbot/chatbot_main.dart`)는 `COUNSELING_REMOTE_REALIZER=true`
**그리고** rollout이 허용할 때만 `remoteGpt` 경로가 실제로 GPT를 호출하고,
그 외에는 항상 deterministic 문장이 나간다(§9.4).

`remoteGpt`를 조립했다고 해서 매 턴 GPT가 호출되는 것은 아니다 —
`handleTurn()`은 실제 호출 전에 두 개의 독립된 게이트를 통과시킨다.

```dart
final rolloutDecision = rolloutConfig == null ? null : evaluateRollout(
  config: rolloutConfig!, routerAllowsLlm: routing.allowLlm,
  cohortKey: resolvedCohortKey, isInternalAccount: isInternalAccount);
final effectiveAllowLlm =
    routing.allowLlm && (rolloutDecision?.attemptRemote ?? true);
```

- `routing.allowLlm` — `HybridTurnRouter.route()`가 `session.state` 기준으로
  계산한다. `explore`/`reflect`만 true가 될 수 있고, `checkIn`/`intervention`/
  `closing`은 이 harness가 존재하는 한 항상 false다(위기 대응·CBT 선택을 모델에
  맡기지 않는다는 §21 원칙의 실제 강제 지점). Phase 10.5에서 이 값이 "계산만
  되고 실제로 강제되지 않는" 잠재 버그였다는 걸 발견해 고쳤다 — 그 전에는
  `remoteGpt` 자체를 켜면 라우터 판단과 무관하게 매 턴 GPT가 불렸다.
- `rolloutDecision?.attemptRemote` — `rolloutConfig`가 있을 때만 계산되는
  canary rollout 판단(§9.4). `rolloutConfig == null`이면(이 필드를 쓰지 않는
  모든 옛 호출부) `true`로 취급해 이 게이트 도입 전과 완전히 동일하게
  동작한다.

`effectiveAllowLlm`이 false면 `responseRealizer`가 무엇으로 조립됐든 아예
호출되지 않는다 — deterministic draft가 그대로 나간다.

### 9.2 ResponseRealizer 계약

`lib/features/counseling/response_realizer.dart`가 planner와 표현 구현의 경계다.

`RealizationRequest`는 deterministic draft, reflection target, question goal,
required act, affect/tone 자리, RetrievalSummary, 최근 대화, 허용 CBT 사실, 금지 행동,
그리고 Phase 10.2의 `realizationSpec`(§9.3)을 담는다. `RealizationResult`는 reply,
source(`deterministic/localLlm/remoteLlm`), latency, validation result,
model/prompt 식별자(있으면)를 반환한다.

구현은 세 개다.

- `DeterministicResponseRealizer`(제품 기본값): draft를 그대로 반환, 항상 valid.
- `SemanticDeterministicResponseRealizer`(`policy/realization/semantic_deterministic_realizer.dart`,
  Phase 10.3/10.3B): `realizationSpec`을 읽어 반영 문장을 다시 만드는 첫
  realizer다. 레거시 draft의 `"$target"라고...` 따옴표 인용을 없애고, 다중
  문장·질문형 반영 대상처럼 접미사로 이어붙이면 어색해지는 경우를 감지해
  일반화된 인정 문구로 우회한다(`ReflectionTargetShape`). 원래는 production
  기본값이 아니라 **Remote가 reject됐을 때의 fallback**으로만 쓰인다(아래).
- `RemoteLlmRealizer`(`lib/features/counseling/remote_llm_realizer.dart`): backend
  `/counseling/realize`를 호출해 GPT가 재표현한 문장을 받는다. **어떤 예외도 밖으로
  던지지 않는다** — 네트워크 오류·timeout·4xx/5xx·형식 오류는 모두 잡아
  `isValid: false`인 결과로 바꾼다. 응답을 받으면 질문 개수 일치·조언 표현 금지·
  태그/역할 표기 유출 금지·길이 제한을 자체 검사하고, 하나라도 위반하면 역시
  invalid를 반환한다.

Harness는 Remote가 invalid를 반환하면(reject) — **2026-09-27부터** —
`turnPlan.deterministicReply`(레거시, 따옴표 인용 포함)가 아니라
`SemanticDeterministicResponseRealizer`의 결과로 되돌아간다
(`counseling_harness.dart`의 `handleTurn`). 원래는 레거시 draft로 fallback했는데,
실기기 dogfooding에서 이 fallback 문구 자체가 Phase 10 전체가 없애려던 그
따옴표 인용 패턴이라는 게 드러나 오늘 바꿨다 — Remote가 시도조차 되지 않은
턴(`effectiveAllowLlm == false`, 즉 checkIn/intervention/closing이나 rollout
미대상 사용자)의 deterministic 문장은 이 변경과 무관하게 그대로다.

GPT API를 쓰기 위해 Harness나 StatePolicy를 변경하지 않는다.

### 9.3 실현 의미 계약: `CounselingRealizationSpec` (Phase 10.2)

파일: `lib/features/counseling/policy/realization/realization_spec.dart`,
`policy/materializers/realization_spec_builder.dart`

레거시 `reflectionSentence`/`questionSentence`는 "선택"과 "표현"이 한 클래스
(`TurnPlanMaterializer`)에 섞여 있어, 실현 계층이 참조할 수 있는 구조화된
의미가 없었다. `CounselingRealizationSpec`은 그 틈을 순수 추가 필드로 메운다
(레거시 필드는 그대로 두고 아무것도 바꾸지 않음 — 그래서 Phase 10.2는
production 출력이 byte-identical했다).

주요 필드:

- `TransitionIntent` — 지금 턴이 이전 턴과 어떻게 이어지는지(반영만/반영+질문 등).
- `InterventionRationale` — 왜 지금 이 개입을 시작하는지, `InterventionType`에
  1:1로 근거를 둔 enum(새로 지어내지 않음).
- `sudRatingValue`(Phase 10.5A.2 Track B) — 사용자가 "7점이요"/"한 8점 정도"처럼
  숫자로 답한 SUD 체크인을, realizer가 명시적으로 인정하도록 만드는 신호.
  `TurnPlanMaterializer._extractSudValue()`가 뽑아내고, 기존의 `_isSudResponse`
  문형 게이트와는 별개다(둘 다 있어야 함 — 후자는 레거시 분기, 전자는 이
  spec 전용).

이 spec을 실제로 소비하는 realizer는 `SemanticDeterministicResponseRealizer`와
`RemoteLlmRealizer`(backend 프롬프트로 전달, `realize_v2`)뿐이다.
`DeterministicResponseRealizer`는 이 필드를 무시하고 항상 레거시 draft를 쓴다.

### 9.4 Canary rollout과 telemetry (Phase 10.6)

파일: `lib/features/counseling/policy/rollout/rollout_config.dart`,
`policy/rollout/realization_telemetry.dart`

```dart
enum RolloutStage { off, internalOnly, pilot }
class RolloutConfig {
  final bool enabled; final RolloutStage stage;
  final int rolloutPercentage; final bool killSwitch;
}
```

`evaluateRollout()`은 순수 함수이며 판정 우선순위가 고정돼 있다: 라우터가
막은 턴 > kill switch > `enabled:false` > stage별 로직(`internalOnly`는 이메일
허용목록, `pilot`은 `stableBucket(cohortKey) < rolloutPercentage`의 안정
해시 버케팅 — 5%⊆10%⊆25% 단조성 보장). `rolloutConfig == null`이면
평가 자체를 건너뛰어 이 인프라 도입 전과 동일하게 동작한다(§9.1).

`RealizationTelemetryEvent`는 구조적 메타데이터만 담는다(rollout stage/cohort
버킷/state/rollout 사유/remote 시도·수락 여부/fallback 사유/latency/model·
prompt 식별자) — 원문 사용자 발화나 답변 텍스트는 어떤 필드에도 들어가지
않는다(`toLogEntry()` 테스트로 고정). 현재 sink는
`logRealizationTelemetryLocally`(`dart:developer.log`)뿐이라 백엔드 집계는
없고, 그 기기의 `flutter logs`/DevTools Logging에서만 보인다 — 여러 dogfooder를
전제로 한 pilot 단계 전에는 이 sink를 백엔드 집계로 바꿔야 한다(§19, §20).

**오늘(2026-09-27) 기준 실제 rollout 상태**: `RolloutStage.internalOnly`,
kill switch `false`, `internalAccountEmailAllowlist`에 dogfooding 테스트
계정 1개만 등록. 나머지 모든 사용자는 `not_internal_account` 사유로 항상
deterministic 경로다.

### 9.5 UI action

모델은 화면 이동을 결정하지 않는다. Harness가 검증된 응답과 턴 시작 state를 기준으로
다음 동작을 제안한다.

- 이완 활동 열기
- ABC 일기 열기
- SUD 기록

상태가 같은 턴에서 closing으로 전이되더라도 그 intervention 턴의 UI action이
유실되지 않도록 `stateBefore`를 기준으로 계산한다.

---

## 10. 결정론적 Turn Planner

파일:

- `lib/features/counseling/turn_plan.dart`
- `lib/features/counseling/intervention_registry.dart`
- `lib/features/counseling/turn_plan_prompt_builder.dart`

결정론적 경로는 서버나 모델이 없어도 안전한 제한 상담을 제공하기 위한 fallback이며,
동시에 상담 전략을 모델 밖에서 검증하기 위한 연구 경로다.

### 10.1 상태별 planner

`DeterministicCounselingTurnPlanner.plan()`은 다음 순서로 첫 번째로 값을 반환하는
planner를 채택한다. 앞의 두 개는 특정 state에 묶이지 않고 모든 state(closing 제외)에서
상담 "내용"보다 먼저 확인된다.

1. `DeterministicInputGuardTurnPlanner` — 의미 없는 입력(자모 나열, 키보드 연타,
   같은 문자 과도 반복), 봇을 향한 모욕, 프롬프트 조작/탈옥 시도를 잡는다. 걸리면
   `planningStatus: unavailable`로 표시해 `HybridTurnRouter`가 이 턴은 절대 LLM을
   호출하지 않게 한다. 질문 하나로 다시 답을 청하고 state는 그대로 둔다
   (`requiredAct: DialogueAct.unknown`이라 `CounselingStatePolicy`가 진행시키지 않음).
2. `DeterministicProcessSignalTurnPlanner` — "질문 그만하고 들어달라"는 공감 요청과
   상담 과정 자체에 대한 회의적 반응(저항)을 잡는다. 질문 없이 인정하는 문장만 내고
   해당 state의 진행 속도를 흐트러뜨리지 않는 act를 골라 쓴다(예: `explore` state에서는
   `DialogueAct.explore`를 써서 `reflect`로 조기 전이되지 않게 한다).
3. `DeterministicCheckInTurnPlanner`
4. `DeterministicExploreTurnPlanner`
5. `DeterministicReflectTurnPlanner`
6. `DeterministicInterventionTurnPlanner`
7. `DeterministicClosingTurnPlanner`

`CounselingTurnPlan`에는 반영 문장, 질문 문장, required act, 금지 행동,
사용한 사용자/CBT 근거 ID가 들어간다. 이 경우 provenance는 모델의 자기 신고가 아니라
Harness가 실제 문장을 만들 때 사용한 construction provenance다.

### 10.2 승인 개입 registry

Week 4~8은 정확한 corpus ID/type/tag/guidance 조건을 모두 만족하는 항목만 선택한다.

| Week | 개입 | 승인 CBT ID |
| ---: | --- | --- |
| 4 | balanced thought | `week4_alternative_thought_01` |
| 5 | behavior pattern review | `week5_confront_avoid_01` |
| 6 | short/long-term consequence | `week6_short_long_term_01` |
| 7 | gain/loss review | `week7_gain_lose_01` |
| 8 | maintenance review | `week8_maintenance_01` |

승인 항목이 없으면 임의의 다른 CBT 개입을 만들어내지 않고 unavailable plan으로
물러난다. Week 1~3에는 현재 승인 intervention이 없다.

### 10.3 알려진 결정론적 경로의 한계

상담 adherence와 즉시성은 강하지만 문장 골격과 질문 순서가 제한적이어서 여러 주제에
같은 패턴이 반복될 수 있다. 과거 제품 화면에서 “발표 상황에 하드코딩된 룰베이스”처럼
느껴졌던 직접 원인이며, AI 경로를 별도로 활성화한 이유다. Phase 10.5의 실측 평가로
explore/reflect의 문장 표현 자체는 GPT 경로가 결정적으로 낫다는 게 확인됐다(§22.1) —
다만 **이 한계는 표현이 아니라 선택(target/questionGoal)이 정해지는 이 계층에서
비롯된다는 점**은 GPT를 켜도 그대로 남는다. `GoalExhaustionPolicy.repeatLast`가
새 신호를 못 찾으면 같은 target/questionGoal을 다시 고르고, GPT는 같은 재료로
거의 같은 문장을 성실히 만들어낼 뿐이다 — 실기기 dogfooding에서 실제 대화로
재현됨(`phase10_6c_dogfood_log.md` 3번 항목). 더 나아가 사용자가 "왜 똑같은
말을 반복하지?"처럼 **시스템 행동 자체에 대한 메타 발화**를 해도, 이 계층은
그것을 새로운 걱정 내용과 구분하지 못하고 같은 target으로 계속 캐묻는다(같은
로그의 4번 항목, `metaConversation`/`interactionRepair` 같은 별도
dialogue act가 없어서 생기는 문제 — 이 두 가지는 Phase 10 selection-freeze
범위 밖의 별도 백로그다).

---

## 11. 온디바이스 모델 계층 (제거됨)

`LlmService → OnDeviceLlmService → OnDeviceLlmRuntime → LlamaFlutterAndroidRuntime
→ llama_flutter_android_mindrium(vendor llama.cpp)` 추상화와 그 lifecycle
(load/generateStream/stop/unload/reload), UTF-8 byte-boundary 패치, STOP을
transaction abort로 다루는 처리, `ModelOutputSanitizer`(빈 `<think>` 제거, U+FFFD
탐지, 태그 유출 차단)는 모두 2026-09-17 온디바이스 경로 폐기와 함께 삭제했다.
`lib/features/counseling/runtime/`, `packages/llama_flutter_android_mindrium`
모두 저장소에 없다. 온디바이스 경로를 다시 검토할 일이 생기면 이 절이 있던
자리에 새로 설계해야 한다(기존 vendor 패치는 복구 불가).

---

## 12. 프롬프트와 출력 처리

`KananaTurnTaskPromptBuilder`, `FastPlainTextPromptBuilder`(온디바이스 전용
프롬프트 두 종)는 온디바이스 경로와 함께 제거했다. GPT 경로(`RemoteLlmRealizer`)는
Flutter에서 프롬프트 문자열을 만들지 않는다 — `RealizationRequest`의 구조화 필드
(draft, reflection target, question goal, forbidden 등)를 backend로 보내고,
실제 system/user 프롬프트 조립은 `backend/app/routers/counseling_realize.py`가
맡는다(원칙은 [`remote_gpt_realizer_integration.md`](remote_gpt_realizer_integration.md)
6절 참고).

### 12.1 `CompactPromptBuilder`(테스트 전용)

파일: `lib/features/counseling/compact_prompt_builder.dart`

reply와 provenance ID를 JSON으로 생성하는 실험용 프로파일이다. 온디바이스와
무관하게 애초에 프로덕션 경로(`ChatPage`)에서 조립되지 않으며, 회귀 비교
테스트(`test/counseling/compact_prompt_test.dart`)에만 남아 있다.

### 12.2 출력 파서

`CounselingOutputParser`는 다음 순서로 처리한다.

1. 전체 JSON strict parse
2. 코드펜스/주변 텍스트 안의 JSON 추출
3. 잘린 JSON에서 `reply` 문자열만 복구
4. 일반 평문 fallback

잘린 JSON의 `referenced_cbt_ids`, `referenced_user_context_ids` 같은 구현 필드는 사용자
말풍선에 노출하지 않는다.

---

## 13. 안전 설계

파일: `lib/features/counseling/safety_gate.dart`

SafetyGate는 모델보다 먼저 실행된다.

```text
normal   → 일반 상담 파이프라인
elevated → 고정 안내, 이완 UI action 가능, LLM 미호출
crisis   → 위기 고정 안내, LLM 미호출
```

현재 구현은 한국어 키워드 규칙이며 정확도를 주장하지 않는다. 위기 응답에는 109와
119 안내가 포함된다. 임상 배포 전에는 규칙, 경량 분류기, 운영 정책, 국가별 연락처를
임상팀과 검수해야 한다.

---

## 14. 아바타와 정서적 태도

관련 파일:

- `lib/chatbot/affective/affect_signal_detector.dart`
- `lib/chatbot/affective/affective_adapter.dart`
- `lib/chatbot/affective/avatar_selector.dart`
- `lib/chatbot/affective/avatar_asset_resolver.dart`

### 14.1 처리 흐름

```text
사용자 발화
  ↓ AffectSignalDetector
anxious / distressed / positive / neutral / uncertain
  ↓ AffectiveAdapter
warm / attentive / concerned / encouraging / neutral
  ↓ AvatarSelector
표정별 이미지 variant
```

감정을 그대로 흉내 내지 않고 상담사가 취할 태도로 변환한다. 예를 들어 distressed
사용자에게 distressed 표정을 보여주는 대신 concerned 또는 attentive 태도를 쓴다.

### 14.2 표정 안정화

- 같은 expression이면 이미지를 교체하지 않는다.
- 표정이 바뀔 때만 variant index를 진행한다.
- 각 assistant message ID에 당시 avatar asset을 저장한다.
- 즉시 공감과 같은 턴의 AI 질문은 동일한 사용자 신호에서 나온 표정을 공유한다.
- 과거 말풍선은 이후 state가 바뀌어도 당시 표정을 유지한다.

현재 정서 탐지는 어휘 규칙이며 감정 인식 정확도를 주장하지 않는다. 부정 표현,
복합 감정, 맥락 반전에는 취약하다.

---

## 15. STT와 TTS

### 15.1 STT

- 입력창 왼쪽 마이크 버튼을 사용자가 눌렀을 때만 시작한다.
- 엔진이 `done/notListening`으로 끝나도 자동 재시작하지 않는다.
- TTS 종료 후 자동으로 마이크를 켜지 않는다.
- 인식된 부분 결과는 입력창에 표시한다.
- 최종 결과는 설정된 자동 전송 흐름으로 보낼 수 있다.
- TTS 재생 중에는 자기 음성을 받아쓰지 않도록 STT를 중단한다.

### 15.2 TTS

- 상단 스피커 버튼으로 켜고 끈다.
- OFF하는 순간 현재 재생 중인 음성도 중단한다.
- OFF 상태에서는 이후 assistant 메시지를 읽지 않는다.
- 다시 켜도 이전 메시지를 자동으로 재생하지 않는다.
- 같은 메시지 ID는 한 번만 읽는다.

---

## 16. 모델 파일 관리 (제거됨)

`lib/features/counseling/model/`(`ModelManager`/`ModelDownloader`/`ModelStorage`/
`ModelManifest`)는 다운로드·SHA-256 검증·설치 목록·삭제를 제공할 예정이었지만,
`ChatPage`나 다른 어떤 제품 코드에서도 실제로 호출되지 않는 dead code였다.
2026-09-08 정리 작업에서 삭제했고, 2026-09-17 온디바이스 경로 전체 폐기로
관련 dart-define(`COUNSELING_CHAT_MODEL_PATH` 등)도 함께 없어졌다. GPT 경로는
클라이언트에 모델 파일을 두지 않으므로 이 계층이 다시 필요할 일은 없다.

---

## 17. 개발용 PoC (제거됨)

`lib/features/counseling/dev/`(`local_llm_poc.dart`, `local_llm_poc_screen.dart`,
`on_device_scenario_screen.dart`)는 `COUNSELING_LLM_POC`/`COUNSELING_SCENARIO_AUTO_START`
같은 dart-define으로만 열리는 개발용 화면이었다(기본값 false라 일반 빌드에는
노출되지 않음). `lib/app.dart`의 관련 라우트 배선과 함께 정리 작업(2026-09-08)에서
삭제했다. 온디바이스 모델의 실기기 lifecycle/템플릿 비교가 다시 필요하면
`integration_test/counseling_llm_scenarios_test.dart`처럼 앱 프로세스 밖 통합
테스트로 만드는 쪽을 우선 검토한다 — 제품 라우트에 개발 화면을 다시 노출하지 않는다.

---

## 18. 계측과 테스트

`CounselingBenchmark`는 다음 이벤트를 기록한다.

- corpus load
- provider ready
- turn total, state 전이, act, safety, parse 상태
- offered/referenced provenance 수

(온디바이스 model load/generation/TTFT/sanitizer 이벤트는 그 코드와 함께 제거했다.
GPT 경로의 latency/fallback 계측은 19.1절 기준 아직 없다.)

현재 상담 테스트 디렉터리는 다음을 포함한다.

- corpus 검색과 주차/tag 필터
- 사용자 데이터 정규화·선택·degraded 처리
- safety bypass
- prompt와 parser fallback
- deterministic planner와 전체 state E2E
- intervention allow-list와 unavailable 정책
- ChatPage, STT/TTS, avatar
- legacy 경로 분리
- 입력 가드(무의미/모욕/프롬프트 조작)와 공감 요청/과정 저항 감지
- `RemoteLlmRealizer`: 정상 채택, 각 검증 실패 케이스별 fallback, 예외 미전파,
  최근 대화 window 제한(`test/counseling/remote_llm_realizer_test.dart`)
- `SemanticDeterministicResponseRealizer`: 따옴표 제거, intervention bridge,
  `ReflectionTargetShape` 분류(다중 문장/질문형 반영 대상의 안전한 fallback)
- `RolloutConfig`/`evaluateRollout`/`stableBucket`: 우선순위 게이팅, 5%⊆10%⊆25%
  버케팅 단조성, checkIn/intervention/closing 0-call 불변식
  (`rollout_config_test.dart`, `canary_rollout_integration_test.dart`)
- Remote reject 시 fallback이 실제로 따옴표 없는 문구인지(신규,
  `canary_rollout_integration_test.dart`)
- `internal_account_allowlist_test.dart`: 기본 허용목록이 비어 있음/등록된
  주소만 매칭

2026-09-27 기준 전체 `test/counseling` 테스트는 888개가 통과한다(2026-09-17
당시의 337개에서 Phase 10.1~10.6C의 semantic realizer, canary rollout,
telemetry, 실기기 배선 테스트가 더해짐; 알려진 무관한 사전 결함 2건은
`reflect_planner_test.dart`의 `_sharesTopic` 단어 중첩 로직에 있으며 별도
이슈로 남아 있다). 여기에는 세션 요약 저장/복원, multi-session 재방문,
ResponseRealizer 계약(deterministic + semantic-deterministic + remote),
deterministic surface variation, 입력 가드/과정 신호 planner도 포함된다.

`integration_test/`의 시나리오(`counseling_production_scenarios_test.dart`,
`counseling_edge_case_scenarios_test.dart`,
`counseling_realistic_user_scenarios_test.dart`,
`counseling_input_guard_scenarios_test.dart`)는 모두 결정론 경로만 쓰며 실기기나
모델이 필요 없다. 온디바이스 GGUF를 실기기에서 바꿔 끼우던
`counseling_llm_scenarios_test.dart`/`counseling_kanana_hybrid_scenarios_test.dart`는
온디바이스 경로와 함께 제거했다. `RemoteLlmRealizer`의 실사용 D/G 비교는 아직
같은 방식의 통합 테스트가 없다(20절 1~2번 참고).

---

## 19. 현재 확인된 한계

### 19.1 GPT 경로 응답 지연과 비용

`RemoteLlmRealizer`는 backend round-trip(네트워크 + OpenAI 호출)만큼 지연이
늘어난다. 현재 backend timeout은 connect 3초/read 6초로 고정돼 있고(초과 시
deterministic으로 자동 복귀). Phase 10.5 평가(dev 48 + holdout 52, 총 100회
실제 API 호출)에서 latency는 측정됐지만 이건 평가용 순차 호출 기준이지, 실제
동시 사용자 트래픽의 p50/p95는 아직 없다 — Stage 1 dogfooding(§9.4)이 그
실사용 latency/fallback 비율을 처음으로 수집하는 단계다
(`phase10_6c_dogfood_protocol.md`).

폴백 발생률은 Phase 10.6B부터 `RealizationTelemetryEvent`로 턴 단위 기록은
되지만(§9.4), 로컬 기기 로그에만 남고 백엔드로 집계되지 않는다 — 여러
dogfooder/사용자를 아우르는 집계 대시보드는 아직 없다.

### 19.2 즉시 공감 규칙 — 실제 배선에서는 비활성

`EmpathyPlanner`의 어휘 기반 한계(§14.2와 동일한 종류)는 여전히 남아 있지만,
2026-09-27부터 이 기능은 실제 `ChatPage` 조립부에서 꺼져 있다(§5.1) — 실제
답변과 별개의 말풍선으로 겹쳐 보이는 문제 때문이다. 켜져 있던 시절의 한계
(어휘 기반, 문형 소진 시 반복 가능)는 기능 자체의 기록으로 남겨둔다.

### 19.3 대화 기억

최근 메시지는 제한된 window만 전달한다. 장기 기억은 전체 transcript가 아니라
구조화된 `CounselingSessionSummary`로 저장·복원한다. 단, 운영 서버에는
`/counseling-sessions` 라우트가 아직 배포되지 않아 실제 계정 persistence는 현재
비활성 상태다.

### 19.4 선택 레이어(selection)의 두 가지 알려진 한계 — Realizer 문제 아님

GPT 표현 계층을 켜도 고쳐지지 않는, "무엇을 말할지" 계층(§10.3)의 문제 두 가지가
실기기 dogfooding에서 실제 대화로 재현됐다(`phase10_6c_dogfood_log.md`).

- **Goal exhaustion 복구 부재**: `GoalExhaustionPolicy.repeatLast`가 새 신호를
  못 찾으면 항상 같은 target을 반복 선택한다. `summarize`/`revisitPreviousIssue`/
  `transition` 같은 다른 선택지가 없다.
- **Meta-conversation 인식 부재**: "왜 똑같은 말을 반복하지?" 같이 시스템
  행동 자체를 문제 삼는 발화를, 새로운 걱정 내용과 구분할 방법이 selection/
  router 계층에 없다. 이건 wording으로 고칠 수 없는 문제다 — 애초에 필요한
  것은 더 나은 표현이 아니라 다른 dialogue act(인정+교정)다.

둘 다 Phase 10의 selection-freeze 범위 밖이라 이번 단계에서 고치지 않았고,
다음 selection-policy phase의 문제 정의로 백로그에 남는다.

### 19.5 Canary rollout의 두 가지 임시 조치

Stage 1(내부 dogfooding)에는 충분하지만 외부 pilot 전에는 반드시 바뀌어야
한다(§9.4, §20).

- **Kill switch가 컴파일타임 플래그다** — 끄려면 재빌드가 필요하다. 실제
  사고 시 재배포를 기다릴 수 없는 외부 pilot에는 부적합하다.
- **Telemetry가 로컬 로그뿐이다** — 여러 사용자를 한 곳에서 집계할 방법이
  없다.

### 19.6 배포 경계

이 저장소의 `backend/app`을 그대로 실행한 백엔드에만 `/counseling/*`이
존재한다. 디버그 빌드가 기본으로 바라보는 공유 서버는 이 엔드포인트가
없다(§2) — 별도의 배포 작업이 필요하며, Phase 10의 범위가 아니다.

---

## 20. 권장 다음 단계

2026-09-17판의 우선순위 상당수는 Phase 10.1~10.6C에서 완료됐다(D/G 비교,
remote realizer 지표, kill switch 1차 버전). 남은 우선순위는 다음과 같다.

1. **Stage 1 dogfooding 계속** — 오늘 수정한 Build B로 `phase10_6c_dogfood_protocol.md`의
   30~50 eligible turn을 실제로 채운다(진행 중, §9.4, §19.4).
2. **Selection-policy phase 착수 여부 결정** — goal exhaustion 복구, meta-conversation
   인식(§19.4)은 실제 사례가 이미 확보됐다. 다음 phase로 분리해 시작할지 결정.
3. **Phase 10.6D-PREP**: 런타임 remote kill switch(재빌드 없이 즉시 차단) +
   backend 집계 telemetry — 외부 pilot 전 필수 선행 조건(§19.5).
4. counseling session backend 변경 배포, 그리고 **Phase 10의 `/counseling/*`
   엔드포인트를 실제 공유/운영 서버에 배포**(§19.6, §22.2) — 지금은 로컬
   dogfood 백엔드에만 존재.
5. 로그인 실계정으로 interrupted/completed 저장 및 다음 세션 복원 확인.
6. 7~10턴 다주제·재방문 scripted E2E를 실기기에서 반복 검수.
7. surface family를 감정·state별로 확장하고 최근 family ID를 세션에 기록.
8. 임상 검수된 safety classifier와 운영 정책.
9. Phase 10.6D: 검증 통과 후 5~10% 외부 pilot.

---

## 21. 핵심 설계 원칙

현재 구현을 유지·확장할 때 지켜야 할 원칙은 다음과 같다.

1. 대화의 source of truth는 KV cache가 아니라 앱의 committed conversation이다.
2. 위기 대응과 상태 전이는 모델에게 맡기지 않는다.
3. CBT intervention은 승인 registry 안의 근거만 사용한다.
4. 사용자 기록은 현재 발화와 관련된 최소 항목만 제공한다.
5. 모델 출력 형식이 사용자 화면에 노출되지 않게 파서 경계를 둔다.
6. LLM(로컬이든 원격이든)에는 상담 전략보다 짧은 표현 역할을 맡긴다.
7. 모델 실패 시 조용히 Mock으로 위장하지 않는다.
8. STT/TTS는 사용자가 명시적으로 통제한다.
9. 아바타는 상담자 자신의 문장이 아니라 사용자 발화 신호에 반응한다.
10. 성능·품질·안전은 각각 독립된 gate와 로그로 검증한다.

---

## 22. GPT API 통합과 rollout 현황 (2026-09-27)

GPT API는 Flutter 앱에서 직접 호출하지 않고 backend proxy와 `RemoteLlmRealizer`를
통해서만 연결한다. 상담 정책, 개인정보 최소화, validation/fallback, 단계별
구현 및 D/G 평가 기준은
[`remote_gpt_realizer_integration.md`](remote_gpt_realizer_integration.md)에
정리되어 있다.

### 22.1 구현 상태(해당 문서의 R1~R5 기준)

| 단계 | 내용 | 상태 |
| --- | --- | --- |
| R1 | Backend client/endpoint (`POST /counseling/realize`) | 완료. `realize_v2`(Phase 10.5A.2)로 `sud_rating_value` 신호 추가 |
| R2 | Flutter `RemoteLlmRealizer` | 완료 |
| R3 | Validator(질문 개수·조언·태그 유출) | 완료(자체 구현, `TurnPlanAdherenceValidator`와는 별도) |
| R4 | Feature flag(`COUNSELING_REMOTE_REALIZER`) | 완료 + canary rollout 게이트(§9.4) 추가. 런타임(재빌드 없는) kill switch는 아직 컴파일타임 플래그뿐(§19.5) |
| R5 | D vs GPT 실사용 fixture 평가 | **완료 — GO 판정.** dev 48 + unseen holdout 52, 총 100회 실제 API 호출, 결정적 우위(dev 35:0, holdout 38:0), 치명적 실패 0건(`phase10_5_llm_realization_evaluation.md`, `phase10_5b_manifest.md`) |
| R6 (신규) | Canary rollout: Stage 0(off) → Stage 1(internalOnly) | Stage 1 실기기 배선 완료, dogfooding 진행 중(§9.4) |

**주의**: R5의 "GO 판정"은 *검토했던 특정 문장이 프로덕션에 저장돼 재생된다*는
뜻이 아니다 — 검증된 것은 realize_v2 프롬프트 + `CounselingRealizationSpec`
아키텍처이고, 실사용에서는 매번 새 문장이 생성된다. 평가 50여 개 답변 자체는
production asset이 아니다.

### 22.2 배포 경계 (§2, §19.6과 동일한 사실, 여기서도 강조)

```text
로컬 dogfood 백엔드 (이 저장소의 backend/app)
  → /counseling/* 존재, realize_v2 검증 가능
공유 서버 (115.145.134.180:8070, 디버그 빌드 기본값)
  → /counseling/* 미배포, Phase 10 검증 대상 아님, 별도 배포 blocker
```

### 22.3 실기기 Stage 1 현황

`internalAccountEmailAllowlist`에 등록된 계정 + `COUNSELING_REMOTE_REALIZER=true`
빌드 + kill switch `false`일 때만 GPT를 시도한다. 오늘 실기기(Android, 로컬
dogfood 백엔드 경유)에서 확인된 것:

- 정상 turn: SUD 숫자 응답을 자연스럽게 인정하며 이어감(realize_v2 효과 실사용
  재확인).
- reject turn: 이전에는 사용자에게 레거시 따옴표 인용이 그대로 노출됐으나,
  오늘 `SemanticDeterministicResponseRealizer`로 fallback을 바꿔 해결(§9.2).
- 말풍선 중복(즉시 공감 + 실제 답변)도 오늘 배선에서 제거(§5.1).
- 선택 레이어의 goal exhaustion/meta-conversation 한계는 실사용으로 재현됐고
  Realizer 결함이 아닌 별도 백로그로 기록(§19.4).

관련 파일:

- `backend/app/routers/counseling_realize.py`, `backend/app/schemas/counseling_realize.py`
- `lib/data/api/counseling_realize_api.dart`
- `lib/features/counseling/remote_llm_realizer.dart`
- `lib/features/counseling/policy/realization/semantic_deterministic_realizer.dart`
- `lib/features/counseling/policy/rollout/rollout_config.dart`,
  `policy/rollout/realization_telemetry.dart`,
  `policy/rollout/internal_account_allowlist.dart`
- `CounselingHarness.remoteGpt`(`lib/features/counseling/counseling_harness.dart`)
- `test/counseling/remote_llm_realizer_test.dart`(7개 케이스: 정상 채택, 빈 응답/
  질문개수 불일치/조언 표현/포맷 유출 각각 fallback, 예외 미전파, 최근 대화
  window 제한)
- `test/counseling/canary_rollout_integration_test.dart`,
  `test/counseling/rollout_config_test.dart`,
  `test/counseling/internal_account_allowlist_test.dart`
- `docs/counseling/phase10_realization_quality.md`(Phase 10 전체 인덱스),
  `docs/counseling/phase10_6c_dogfood_log.md`(오늘 발견 사항의 build 경계 포함
  상세 기록)
