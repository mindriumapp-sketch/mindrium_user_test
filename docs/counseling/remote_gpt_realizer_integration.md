# GPT API 기반 RemoteLlmRealizer 통합 가이드

> 기준: 2026-09-05 저장소 상태  
> 상태: 설계 및 연결 경계 준비 완료, GPT API 구현·배포는 보류

## 1. 목적

이 문서는 추후 GPT API key와 운영 backend가 준비됐을 때 상담 구조를 다시 설계하지
않고 원격 문장 생성 기능을 추가하기 위한 구현 기준이다.

GPT의 역할은 상담 전략 수립이 아니다. `CounselingHarness`가 확정한 상담 문장의 의미를
더 자연스럽게 표현하는 선택적 surface realizer다.

```text
CounselingHarness
  → SafetyGate
  → Context/Retrieval
  → StatePolicy
  → TurnPlanner
  → RealizationRequest
       ├─ DeterministicResponseRealizer  현재 제품 기본값
       ├─ OnDeviceResponseRealizer       선택 후보
       └─ RemoteLlmRealizer              추후 GPT API
  → validation
       ├─ PASS → 원격 응답 채택
       └─ FAIL → deterministicDraft 사용
```

## 2. 반드시 유지할 책임 경계

GPT에 맡기지 않는 항목:

- 위기·자해 위험 판정과 안전 응답
- 상담 state 및 state transition
- 이번 턴의 dialogue act
- 반영할 사용자 사실 선택
- 질문 목표와 질문 개수 결정
- CBT 기법과 corpus item 선택
- 앱 활동 추천과 화면 이동
- provenance 결정
- 금지 행동과 임상 정책

GPT에 허용하는 항목:

- 이미 완성된 deterministic draft의 자연스러운 한국어 표현
- 지정된 affect/tone에 맞춘 최소한의 어조 조정
- 의미, 질문 목표, 사용자 사실을 바꾸지 않는 범위의 문장 다듬기

이 경계를 넘는 출력은 모델 성능과 관계없이 폐기한다.

## 3. 현재 준비된 코드 계약

파일: `lib/features/counseling/response_realizer.dart`

### `RealizationRequest`

```text
deterministicDraft     Harness가 완성한 안전한 기본 답변
reflectionTarget      반드시 보존할 반영 대상
questionGoal          질문이 달성해야 하는 의미 목표
requiredAct           Harness가 확정한 dialogue act
affect                 관찰된 정서 신호(선택)
tone                   요청할 표현 어조
retrievalSummary       현재 턴에 허용된 압축 맥락
recentConversation    제한된 최근 대화
allowedCbtFacts        사용 가능한 CBT 사실 allow-list
forbiddenBehaviors     금지 행동
```

### `RealizationResult`

```text
reply                  사용자에게 보여줄 후보 문장
source                 deterministic | localLlm | remoteLlm
latency                원격 생성 시간
validationResult       채택 가능 여부와 위반 목록
```

현재 `DeterministicResponseRealizer`가 이 계약을 구현한다. Harness는 validation 실패나
빈 응답을 받으면 `deterministicDraft`로 복귀하도록 구성되어 있다.

## 4. 권장 네트워크 구조

Flutter 앱에서 OpenAI API를 직접 호출하거나 API key를 앱에 포함하면 안 된다.

```text
Flutter app
  └─ POST /counseling/realize
       Authorization: Mindrium access token
       ↓
Mindrium backend
  ├─ 사용자 인증·rate limit
  ├─ request allow-list 재검증
  ├─ OpenAI API 호출
  ├─ timeout/retry/circuit breaker
  ├─ 응답 schema 검증
  └─ 최소 운영 지표만 반환
       ↓
Flutter RemoteLlmRealizer
  └─ local adherence validator
       ├─ PASS → 채택
       └─ FAIL → deterministic fallback
```

API key는 backend secret/environment에만 저장한다. Flutter의 dart-define, asset,
SharedPreferences, source code, Git 저장소에는 넣지 않는다.

## 5. Backend API 초안

권장 endpoint:

```http
POST /counseling/realize
Authorization: Bearer <mindrium-access-token>
Content-Type: application/json
```

요청 예시:

```json
{
  "request_id": "uuid",
  "prompt_version": "remote-realizer-v1",
  "deterministic_draft": "그 상황이 계속 마음에 걸리시는군요. 가장 걱정되는 순간은 언제인가요?",
  "reflection_target": "내일 발표가 걱정된다",
  "question_goal": "가장 걱정되는 구체적인 순간을 하나 확인한다",
  "required_act": "explore",
  "affect": "anxious",
  "tone": "warm, calm, concise",
  "recent_conversation": [],
  "allowed_cbt_facts": [],
  "forbidden_behaviors": [
    "행동 해결책을 제안하지 않는다",
    "새로운 사용자 사실을 만들지 않는다"
  ]
}
```

응답 예시:

```json
{
  "request_id": "uuid",
  "reply": "내일 발표를 생각하면 마음이 계속 쓰이시는군요. 어떤 순간이 가장 걱정되나요?",
  "model": "configured-server-model",
  "prompt_version": "remote-realizer-v1",
  "latency_ms": 820
}
```

모델에게 provenance를 다시 신고시키지 않는다. provenance는 Planner가 실제 사용한
자료에서 생성한 construction provenance를 그대로 유지한다.

## 6. Prompt 원칙

원격 prompt는 길고 포괄적인 상담 system prompt가 아니라 제한된 rewriting 작업이어야
한다.

```text
당신은 문장 표현기입니다. 상담 전략이나 새로운 내용을 만들지 마세요.

다음 초안의 의미와 사실을 보존하여 자연스러운 한국어로 다듬으세요.

필수:
- reflection target 보존
- question goal 보존
- required act 보존
- 최대 2문장
- 질문 개수는 계획과 동일

금지:
- 조언, 진단, 약속 추가
- 사용자에게 없는 사실 추가
- 다른 CBT 기법 추가
- 과거 기록을 새로 언급
- JSON, Markdown, 역할·제어 token 출력

출력은 최종 reply 문자열만 반환하세요.
```

모델 선택, temperature, max output token은 backend 설정으로 고정하고 앱 요청이 임의로
바꾸지 못하게 한다. 첫 baseline은 낮은 temperature와 짧은 출력 한도로 시작한다.

## 7. 이중 검증과 fallback

Backend와 Flutter 양쪽에서 검증한다.

Hard gate:

- 응답이 비어 있지 않음
- 최대 문장·문자·token 길이 준수
- 요구된 질문 개수 준수
- `reflectionTarget`의 핵심 의미 보존
- `questionGoal` 충족
- advice/diagnosis/stage advance 금지
- 새로운 사용자 사실 없음
- 허용되지 않은 CBT 내용 없음
- control token, `<think>`, JSON wrapper 없음
- 개인정보나 prompt leakage 없음

다음 상황에서는 사용자에게 오류를 보이지 않고 deterministic draft를 사용한다.

- 네트워크 미연결 또는 timeout
- 401/403/429/5xx
- JSON/schema parse 실패
- 빈 응답
- adherence validation 실패
- safety policy 위반
- circuit breaker open

원격 응답 실패 때문에 상담 state를 되돌리거나 진행을 막지 않는다. state transition의
근거는 `TurnPlan.requiredAct`이며 원격 모델의 자체 분류가 아니다.

## 8. 개인정보와 로그 정책

정신건강 상담 데이터는 민감 정보로 취급한다.

- 가능한 한 deterministic draft와 최소 맥락만 전송한다.
- 일기 원문 전체, 전체 대화 transcript, 사용자 프로필 전체를 보내지 않는다.
- ID만으로 충분하면 원문 대신 ID를 사용한다.
- access token, API key, system prompt, raw model output을 일반 로그에 남기지 않는다.
- 운영 로그에는 request ID, source, latency, status, fallback reason 같은 최소 지표만 남긴다.
- 보존 기간, 삭제, 사용자 동의, 국외 이전 여부는 실제 배포 전 정책·법무 검토가 필요하다.
- provider의 데이터 보존/학습 사용 설정은 계약 시점의 공식 정책을 다시 확인한다.

## 9. Timeout과 성능 정책

deterministic 응답이 이미 있으므로 원격 호출을 오래 기다릴 이유가 없다.

초기 권장값:

```text
connect timeout     2~3초
total deadline      5~8초
retry               자동 1회 이하, 멱등 request_id 사용
429/5xx             즉시 fallback 또는 짧은 backoff
circuit breaker     연속 실패 시 일정 기간 remote 비활성화
```

실제 값은 네트워크 측정 후 조정한다. 응답이 늦게 도착해 이미 deterministic reply가
표시된 경우 뒤늦게 말풍선을 교체하지 않는다.

## 10. 단계별 구현 순서

### R1. Backend client와 endpoint

- OpenAI SDK/HTTP client를 backend에만 추가
- 환경 변수와 secret 설정
- 인증된 `/counseling/realize` endpoint
- request/response Pydantic schema
- timeout, rate limit, request ID

### R2. Flutter `RemoteLlmRealizer`

- `ResponseRealizer` 구현
- `ApiClient`를 통한 endpoint 호출
- 응답을 `RealizationResult(source: remoteLlm)`로 변환
- 네트워크 오류를 typed failure로 정규화

### R3. Validator

- 기존 `TurnPlanAdherenceValidator`를 remote contract에 맞게 확장
- hard constraint 위반 목록 기록
- 실패 시 deterministic draft 사용

### R4. Feature flag와 rollout

```text
COUNSELING_REMOTE_REALIZER=false  기본
```

앱 define만 믿지 말고 backend/user cohort 기준 remote kill switch도 둔다.

### R5. D vs GPT 평가

동일 fixture에서 다음을 비교한다.

```text
D    DeterministicResponseRealizer
G    RemoteLlmRealizer
```

평가 항목:

- reflection 보존
- progression
- question goal 및 질문 개수
- groundedness
- 자연스러운 한국어
- 금지 행동 위반률
- fallback 비율
- median/p95 latency
- 요청당 비용
- 사용자 이탈률 또는 만족도(동의된 제품 평가 단계)

GPT는 자연스러움이 유의미하게 개선되고 hard gate·지연·비용 기준을 모두 충족할 때만
채택한다. 개선이 작으면 deterministic 경로를 유지한다.

## 11. 테스트 목록

```text
[ ] 정상 응답 채택
[ ] timeout → deterministic fallback
[ ] 401/429/5xx → fallback
[ ] malformed JSON → fallback
[ ] 빈 reply → fallback
[ ] 질문 추가/삭제 → fallback
[ ] 조언·진단 추가 → fallback
[ ] 새로운 사용자 사실 추가 → fallback
[ ] CBT allow-list 위반 → fallback
[ ] 위기 턴에서 remote 호출 0회
[ ] provenance가 모델 출력으로 변하지 않음
[ ] 늦은 응답이 이미 표시된 문장을 교체하지 않음
[ ] API key가 앱 binary/repository/log에 없음
[ ] D/G fixture 회귀 평가
```

## 12. 구현 완료 조건

다음을 모두 충족해야 원격 realizer를 제품 후보로 본다.

1. 상담 정책과 state transition이 GPT 없이도 완전히 동작한다.
2. GPT 장애 시 같은 턴에서 즉시 deterministic fallback이 가능하다.
3. SafetyGate와 승인 CBT registry를 우회할 수 없다.
4. construction provenance가 그대로 유지된다.
5. 실사용 fixture의 hard constraint 위반이 없다.
6. 지연과 비용이 사전에 정한 운영 gate 안에 든다.
7. API key와 민감 상담 데이터의 보안 검토가 끝났다.
8. remote kill switch로 즉시 deterministic 경로로 복귀할 수 있다.

## 13. 현재 결론

현재는 GPT API가 없어도 기능 개발의 blocker가 아니다. 먼저 deterministic 상담,
세션 persistence, 반복 방지, multi-session E2E를 안정화한다. 추후에는
`RemoteLlmRealizer`와 backend endpoint만 추가하며, GPT는 상담 판단자가 아니라 검증
가능한 선택적 표현 계층으로 사용한다.
