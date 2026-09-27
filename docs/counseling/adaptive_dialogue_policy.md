# Adaptive Dialogue Policy 설계와 단계별 도입 계획

## 1. 문서 목적

이 문서는 상담 챗봇에서 GPT(`RemoteLlmRealizer`)의 권한을 "문장 표현"에서
"제한된 상담 행동 선택"까지 확장하기 위한 설계와, 이를 한 번에 바꾸지 않고
3단계로 나눠 도입하는 계획을 기록한다. 배경은
[`chatbot_architecture.md`](chatbot_architecture.md) 18~22절에서 이미 확인된
한계다: 지금 구조에서는 `DeterministicCounselingTurnPlanner`가 반영 대상·질문
목표·요구 행위(`requiredAct`)를 먼저 확정하고, GPT는 그 결과를 자연스러운
한국어로 다듬기만 한다. 실제 기기 테스트(2026-09-18)에서 GPT 응답이 정상적으로
채택되고 있음(`realization_source=remoteLlm`)을 확인했음에도, 매 턴이 정해진
CBT 스크립트(SUD 0~10 질문, 고정된 반영→질문 패턴)를 벗어나지 못해 "룰베이스
챗봇처럼 느껴진다"는 문제가 재현됐다. 이 문서가 다루는 것은 그 근본 원인 —
"무엇을 할지"를 100% rule-base가 결정하는 구조 — 을 바꾸는 작업이다.

이 문서가 다루지 않는 것:
- 위기 대응 로직 변경 (SafetyGate는 항상 GPT 이전에 하드 차단하며, 이 문서의
  모든 단계에서 그대로 유지한다)
- 온디바이스 LLM 복원 (완전히 폐기됨, `chatbot_architecture.md` 참고)
- UI/UX 변경

## 2. 현재 권한 경계 (기준선)

코드 기준 사실 (2026-09-18):

| 계층 | 파일 | 결정하는 것 | 결정 방식 |
| --- | --- | --- | --- |
| `SafetyGate` | `safety_gate.dart` | 위기 발화 차단 | 키워드 규칙, 하드 |
| `CounselingStatePolicy` | `counseling_state.dart:142-221` | `state_before → state_after` | 턴 예산(`budgetFor`: checkIn 1, explore 1, reflect 2, intervention 1, closing 20) + `lastAct` 기반 acceleration. GPT 관여 없음 |
| `CounselingState.allowedActs`/`requiredAct` | `counseling_state.dart:30-70` | 이번 턴에 허용된 `DialogueAct` 집합과 강제 행위 | 상태별 고정 테이블. 현재는 사실상 `requiredAct` 하나만 쓰임 |
| `DeterministicXxxTurnPlanner` (7종, `turn_plan.dart`) | 반영 대상, 질문 목표, `deterministicDraft`, `forbidden`, `requiredAct` | 상태별 고정 템플릿 (`surface_variation.dart`로 표현만 소폭 변주) |
| `ApprovedInterventionRegistry` | `intervention_registry.dart` | 이번 주차에 쓸 수 있는 CBT 개입 | `policyForWeek(week)` — 주차당 정확히 1개, 목록이 아님 |
| `ResponseRealizer` (`RemoteLlmRealizer`) | `response_realizer.dart`, `remote_llm_realizer.dart` | 문장 표현만 | `deterministicDraft`를 자연어로 재표현. `reflectionTarget`/`questionGoal`/`requiredAct`는 입력으로 받아 그대로 보존해야 함 |
| `CounselingHarness.handleTurn` | `counseling_harness.dart:201-419` | 전체 오케스트레이션 | SafetyGate → retrieval → planner → realizer → validate → statePolicy.next |

핵심 관찰: `CounselingState.allowedActs`는 이미 "허용 행동 집합"이라는 개념을
갖고 있지만, 실제로는 `requiredAct` 하나로 좁혀져서 선택의 여지가 없다. 이
문서의 Phase 1은 바로 이 지점 — 이미 존재하는 집합을 GPT가 실제로 고르게
하는 것 — 에서 시작한다. 상태 전이 자체(턴 예산 기반 sequence)는 Phase 3
이전까지 건드리지 않는다.

## 3. 목표 구조

```
사용자 발화
   │
   ▼
SafetyGate                         ← 하드 규칙, 변경 없음
   │
   ▼
Retrieval / Session Memory         ← 변경 없음 (CbtKnowledgeRepository)
   │
   ▼
Turn Boundary Builder              ← 신설: 이번 턴에 "허용된 선택지"를 계산
   │  allowed_actions: Set<DialogueAct>       (기존 CounselingState.allowedActs 활용)
   │  eligible_interventions: List<...>       (Phase 3에서 registry 확장)
   │  sud_ask_allowed: bool                   (Phase 2)
   │  reflection_target / question_goal 등    (기존 TurnPlanner 산출물 유지)
   ▼
AdaptiveDialoguePolicy (신설 계층)   ← GPT/Claude가 여기서 "무엇을 할지" 선택
   │  입력: Turn Boundary + 최근 대화 + retrieval summary
   │  출력: { chosen_act, reply, (선택된 intervention_id) }
   ▼
Policy / Grounding Validator        ← 신설: 화이트리스트 검증
   │  PASS → chosen_act·reply 사용
   │  FAIL → deterministic fallback (기존 TurnPlan.deterministicReply, 기존 act)
   ▼
State 전이 (CounselingStatePolicy)  ← 변경 없음 (Phase 1~2), Phase 3에서 permission-set화
   ▼
Chat UI
```

불변 원칙 (모든 단계에서 유지):
1. **위기 대응은 절대 GPT에 위임하지 않는다.** SafetyGate가 항상 먼저 차단한다.
2. **GPT는 검증기가 제공한 화이트리스트 밖의 것을 선택할 수 없다.** 화이트리스트
   밖을 고르면 항상 결정론적 기본값으로 fallback한다 — 에러를 사용자에게
   보이지 않는다 (`RemoteLlmRealizer`의 기존 "절대 예외를 던지지 않는다" 원칙과
   동일한 정신).
3. **GPT는 retrieval이 제공하지 않은 사용자 사실이나 CBT 항목을 새로 만들 수
   없다.** 기존 `referenced_cbt_ids`/`referenced_user_ids` 검증 방식을 그대로
   확장한다.
4. 모든 단계는 `COUNSELING_BENCH`로 새 필드를 로깅해서, 다음 단계로 넘어가기
   전에 실제 선택 분포를 확인할 수 있어야 한다.
5. 기존 deterministic 경로(GPT 비활성)는 각 단계에서 100% 그대로 동작해야
   한다. 즉 이 확장은 전부 `RemoteLlmRealizer`/`AdaptiveDialoguePolicy` 경로에만
   적용되고, `CounselingHarness.deterministic` 팩토리는 건드리지 않는다.

## 4. Phase 1 — 표현 방식 선택 (상태 전이 구조는 그대로)

**목표**: 상태 머신·턴 예산·intervention 선택은 그대로 두고, `explore`/`reflect`
상태에서 GPT가 `CounselingState.allowedActs` 안의 여러 행동 중 하나를 실제로
고르게 한다. 지금처럼 `requiredAct` 하나로 강제하지 않는다.

**바뀌는 범위**:
- `counseling_state.dart`: `explore`/`reflect`의 `allowedActs`를 현재보다 넓힌다
  (예: `reflect`에 `affirm`류 담기용으로 `DialogueAct`에 `affirm`,
  `listenWithoutQuestion` 추가 필요 — `lib/data/counseling/counseling_models.dart:96-116`
  의 `DialogueAct` enum 확장).
- `turn_plan.dart`의 `DeterministicExploreTurnPlanner`/`DeterministicReflectTurnPlanner`:
  `requiredAct` 하나만 내는 대신, "이번 턴에 허용된 행동 후보 목록 + 각 후보별
  deterministic fallback 문장"을 함께 낸다. 즉 `CounselingTurnPlan`에
  `allowedActsForTurn: Set<DialogueAct>` 필드를 추가 (기존 `requiredAct`는
  "검증 실패 시 fallback으로 쓸 안전한 기본 행동"으로 의미가 바뀐다).
- 백엔드 스키마 (`backend/app/schemas/counseling_realize.py`): 요청에
  `allowed_actions: List[str]` 추가, 응답을 `reply` 단일 문자열에서
  `{"chosen_act": str, "reply": str}` 구조로 변경. `_SYSTEM_PROMPT`
  (`backend/app/routers/counseling_realize.py`)에 "allowed_actions 중 하나를
  선택하고 JSON으로만 답하라" 지시를 추가.
- `RealizationRequest`/`RealizationResult` (`response_realizer.dart`):
  `allowedActs` 입력 필드, `chosenAct` 출력 필드 추가.
- `RemoteLlmRealizer._validate()`: 기존 검사(질문 개수·조언 어휘·포맷 누출·
  길이)에 "`chosenAct`가 `allowedActs` 안에 있는가" 검사를 추가. 실패 시
  `TurnPlan.requiredAct`(안전 기본값)와 `deterministicReply`로 fallback.
- `counseling_harness.dart`: 검증 통과 시 `validated.dialogueAct`를
  `chosenAct`로 설정 (현재는 `parsed.dialogueAct`가 항상 planner의
  `requiredAct`에서 옴 — 이 지점만 바뀐다). `statePolicy.next()` 호출은 그대로
  두되, `lastAct`가 이제 GPT가 고른 값일 수 있다는 점만 인지.
- 벤치마크 (`counseling_provider.dart:287-310`): `'turn'` 이벤트에
  `chosen_act`, `act_source` (deterministic/remoteLlm) 필드 추가.

**검증 기준**: 동일 시나리오(발표 불안 흐름)를 10턴 이상 반복 실행했을 때,
`chosen_act`가 매번 같은 값으로 고정되지 않고 문맥에 따라 달라지는지
`COUNSELING_BENCH` 로그로 확인. 화이트리스트 밖 선택이 나왔을 때 항상
fallback되는지 단위 테스트로 확인 (`test/counseling/`에 추가).

**리스크**: 낮음. Intervention/SUD/상태 전이 로직을 건드리지 않으므로 안전
관련 회귀 위험이 가장 작다.

## 5. Phase 2 — SUD 질문 시점 위임

**목표**: "SUD를 지금 물어볼지"를 조건 기반으로 GPT에게 제안권만 준다.

**바뀌는 범위**:
- 조건 계산기 신설 (harness 또는 turn planner 내부): `sudAskAllowed`를
  다음 조건의 논리합으로 계산 — 세션 baseline SUD 없음 / 사용자가 명시적으로
  강한 불안 표현 / intervention 전후 비교 필요 / 최근 SUD가 N턴 이상 오래됨.
- Turn Boundary에 `sud_ask_allowed: bool` 추가, GPT의 `chosen_act`에
  `askSud` 옵션을 조건이 참일 때만 노출.
- Validator: `askSud`를 골랐는데 `sud_ask_allowed=false`이면 무조건 fallback.
- Phase 1의 액션 선택 인프라(JSON 계약, 검증기, 벤치마크 필드)를 그대로
  재사용 — 새 배관을 만들지 않는다.

**검증 기준**: SUD를 이미 최근에 물었는데도 다시 묻는 사례가 0건인지 회귀
시나리오로 확인.

**리스크**: 낮음~중간. 조건 계산기 버그 시 SUD를 전혀 못 묻는 방향으로만
실패하도록(fail-closed) 설계해서, 임상적으로 더 위험한 "불필요하게 자주
물음"보다 안전한 쪽으로 기울인다.

## 6. Phase 3 — 승인된 CBT 중 선택 + 상태 permission-set화

가장 민감하고 리팩터링 범위가 큰 단계이므로 Phase 1·2가 실제 기기에서
충분히 안정적으로 관찰된 뒤에만 시작한다.

**6.1 Intervention 다중 후보화**:
- `ApprovedInterventionRegistry.policyForWeek()`는 주차당 정책 1개만 반환한다
  (`intervention_registry.dart:88`). 이를 `policiesForWeek(week) -> List<..>`로
  확장하거나, "이번 주차 + 아직 안 쓴 것" 조건으로 여러 개를 동시에 후보로
  낼 수 있게 한다.
- `DeterministicInterventionTurnPlanner`가 후보 목록을 `eligible_interventions`
  로 Turn Boundary에 실어 보내고, GPT는 그중 하나 또는 "아직 개입하지 않음"을
  선택한다. **레지스트리에 없는 개입 id를 GPT가 지어내면 항상 거부** —
  이 검증은 Phase 1의 `referenced_cbt_ids` 검증 패턴을 그대로 재사용한다.

**6.2 상태를 sequence에서 permission-set으로**:
- 현재 `CounselingStatePolicy`(`counseling_state.dart:142-221`)의 고정 턴
  예산(`checkIn 1 / explore 1 / reflect 2 / intervention 1`)을 Opening /
  Working / Closing 3단계의 "허용 행동 범위"로 재정의한다. 상태 enum 자체를
  없애는 것이 아니라, "이번 턴에 반드시 이것을 해야 한다"는 성격을 "이번
  국면에서 할 수 있는 것의 범위"로 바꾼다.
- 이 변경은 `CounselingStatePolicy`, 관련 `DeterministicXxxTurnPlanner` 7종,
  그리고 이 turn budget에 의존하는 기존 테스트(정확한 개수는
  `test/counseling/counseling_harness_test.dart` 등에서 재확인 필요) 상당수에
  영향을 준다. 이 단계는 별도 하위 계획을 다시 문서화하고 시작한다 — 지금
  이 문서에는 방향만 기록한다.

**리스크**: 높음. 안전 관련 검증(레지스트리 화이트리스트)과 대규모 리팩터링
(상태 전이)이 겹치는 지점이라, Phase 1·2보다 훨씬 넓은 회귀 테스트가
필요하다. Phase 3 시작 전 별도로 범위를 좁게 다시 쪼갠다 (6.1과 6.2를
동시에 진행하지 않는다).

## 7. 공통 구현 규칙

- 모든 단계는 기존과 동일하게 **기능 정의(dart-define)로 켜고 끌 수 있어야
  한다.** 현재 `COUNSELING_REMOTE_REALIZER`처럼, 이번에도 새 계층 전체를 한
  번에 롤백할 수 있는 스위치를 유지한다 (예: 새 JSON 계약을 쓰는 백엔드
  엔드포인트를 `/counseling/realize`와 분리된 버전으로 두거나, `prompt_version`
  필드로 구분).
- 백엔드 시스템 프롬프트는 여전히 "새 상담 전략을 만들지 마라"는 기존
  금지 목록을 유지하고, 그 위에 "제공된 allowed_actions/eligible_interventions
  중에서만 선택하라"는 지시를 얹는다 — 완전히 새로 쓰지 않는다.
- 각 단계 완료 후 `docs/counseling/chatbot_architecture.md`의 관련 절을
  갱신한다 (특히 9.1/9.2 "모델이 담당하는 일" 구분표).

## 8. 다음 실행 항목

1. Phase 1의 `DialogueAct` 확장안(`affirm`, `listenWithoutQuestion` 등 정확한
   목록)과 `CounselingTurnPlan.allowedActsForTurn` 필드 설계를 코드로 옮기기
   전에 한 번 더 검토.
2. 백엔드 `/counseling/realize` 응답을 JSON 구조(`chosen_act`+`reply`)로
   바꾸는 스키마 변경 — 기존 클라이언트와의 호환을 위해 `prompt_version`을
   올리고, 구버전 요청은 기존 문자열 응답 경로를 유지할지 결정 필요.
3. Phase 1 구현 착수 여부 확인.
