# Phase 14.1 설계: Dialogue Move 체계와 전이 규칙

상태: **동결 (2026-10-02)**. 14.2~14.7은 이 문서를 기준으로 구현합니다. 바꿀 때는 이 문서를 먼저 고치고 변경
이유를 12절에 남깁니다.

---

## 1. 목표와 범위

**목표.** 결정 단위를 "이 상태에서 다음 질문은 무엇인가"에서 "지금 이 사용자에게 어떤 대화 행동(move)이
필요한가"로 바꿉니다. 상담을 길게 만드는 것이 목적이 아니라, 사용자가 할 말이 남아 있는 동안 상담이 섣불리
닫히지 않게 하는 것이 목적입니다.

**핵심 원칙: 열린 내용 우선 (Open Content Priority).** Phase 14의 가장 강한 규칙입니다(6.1절).

> 사용자가 아직 다뤄지지 않은 새로운 걱정·근거·감정·맥락을 꺼냈다면, 다음 예정 질문이나 개입으로 넘어가기 전에
> 그 내용을 먼저 반영해야 한다.

**바꾸는 것**
- 각 상태 안에서 고를 수 있는 move의 종류와 조합
- 단계 전이와 마무리 조건(턴 수 → 진행 상황)
- 사용자 발화 인식(규칙 → 분류기 + 규칙 대체)

**바꾸지 않는 것**
- 상태 5개(checkIn → explore → reflect → intervention → closing)
- 안전 관문, 승인 기법 레지스트리, 누적·미래 주차 규칙
- 결정은 결정론, GPT는 표현만, 검증 실패 시 결정론 대체
- 복구·기법·마무리 턴은 원격 표현 금지
- 턴 메타데이터를 결정 근거로 쓰는 방식

**이번 Phase에서 하지 않는 것:** Dialogue Strategy RAG. 명시적 전이 규칙 표(6절)로 시작하고, 규칙으로 부족하다는
근거가 dogfood에서 나오면 그때 검토합니다.

---

## 2. 외부 자료 확인 결과

원문에서 확인한 내용만 적었습니다. 세 자료 모두 **구조 참고용**이며 MindRium의 임상 근거가 아닙니다.

| 자료 | 확인한 사실 | 쓰는 것 | 쓰지 않는 것 |
|---|---|---|---|
| ESConv (ACL 2021) | 1,300개 대화, 지지자 발화마다 전략 8종(Question 20.7%, Affirmation and Reassurance 15.4%, Providing Suggestions 16.1%, Self-disclosure 9.3%, Reflection of feelings 7.8%, Information 6.6%, Restatement or Paraphrasing 5.9%, Other 18.3%). 실패 대화 196건 별도 공개. **"academic research use only"** | 전략 분류 체계, 질문과 비질문 전략의 비율, 실패 대화의 구조 패턴(오프라인 분석) | 원문 발화(라이선스), 제안·자기 노출 전략 |
| HCoT-Corpus (Frontiers in Psychology 2026) | 22,341개 대화, 평균 9.47턴, 전략 사슬은 주로 7~13턴. 탐색 단계는 Restatement 33.9%, Interpretation 36.5%, 위로 단계는 Approval and Reassurance 57.4%, 행동 단계는 Direct Guidance 48.4%. GPT-4o로 만든 **합성 중국어 데이터**이고, 저자가 임상 서비스에 직접 배포하는 것을 금지함 | 단계 안에서 여러 전략이 섞인다는 구조 원리, 길이 규모 참고 | 길이를 목표나 근거로 쓰는 것, Interpretation·Direct Guidance |
| PsyPARSE (AAAI 2026) | 학습 없이 쓰는 프레임워크. 여러 치료법 RAG와 멀티턴 롤아웃으로 경로를 시뮬레이션해 응답을 고름 | 한 턴 앞을 보고 반복이나 섣부른 전환을 피한다는 발상(결정론 규칙으로) | LLM이 치료 경로를 고르는 구조 |

---

## 3. 현재 구조의 진단

| 항목 | 현재 | 문제 |
|---|---|---|
| explore | 1턴 고정 | 상황만 듣고 바로 생각 탐색으로 넘어감 |
| reflect | 근거 → 다른 관점 → 가능성 고정 순서, 최소 2·최대 4교환 | 사용자가 새 이야기를 꺼내도 다음 목표 질문으로 감 |
| 턴 구성 | 받아 주는 문장 1개 + 질문 1개 | 감정 반영, 요약, 경청이 독립된 행동이 아님 |
| 진행 판단 | 목표 사용 여부, 턴 수 | 참여 정도와 새 내용 여부를 보지 않음 |
| 마무리 | 기법 통합 직후 항상 제안 | 열린 내용이 남아 있어도 제안 |
| 결과 | 협조적 사용자 기준 5~6교환 뒤 마무리 제안 | 대화가 압축되고 정형화됨 |

---

## 4. Dialogue Move 체계

move는 두 축으로 나눕니다.

### 4.1 지지·반응 move (Support)

질문을 포함하지 않습니다.

| move | 정의 | 허용 상태 | 원격 표현 | 활성화 |
|---|---|---|---|---|
| `acknowledge` | 말해 준 것을 받아 줌 | 전체 | 예 | 켬 |
| `restate` | 사용자 말의 요점을 다시 말함(인용 규칙 적용) | explore, reflect | 예 | 켬 |
| `reflectEmotion` | 사용자 발화에 드러난 감정을 맥락과 함께 반영. 감정 단서가 있을 때만 | explore, reflect, intervention | 예 | **임상 검수 후** |
| `supportiveAffirmation` | 걱정이 커질 수 있는 상황임을 인정하거나, 지금 살펴보는 노력을 인정 | explore, reflect | 예 | **임상 검수 후** |
| `summarize` | 지금까지 나온 상황·생각·감정을 정리 | reflect, closing | 예 | 켬 |
| `connectPastRecord` | 사용자 자신의 저장 기록과 연결(4.4절) | reflect, intervention | 아니오 | 켬 |
| `listen` | 질문 없이 들어 주기 | reflect | 아니오 | 켬 |
| `repair` | 반복 지적·중단 요청·불만·헷갈림 복구(현행 4종) | 전체 | 아니오 | 켬 |
| `integrate` | 기법 답 통합 | intervention | 아니오 | 켬 |

**`supportiveAffirmation`의 계약.** 정서적 지지는 하되 결과를 보장하지 않습니다.
- 허용: "그 상황에서 걱정이 커질 수 있겠어요.", "지금처럼 걱정을 구체적으로 살펴보는 것도 의미가 있어요."
- 금지: "걱정하지 않아도 돼요.", "분명 잘될 거예요.", "아무 문제 없을 거예요."
- 검증기는 결과 보장 표현("잘될 거", "괜찮을 거", "문제없", "걱정 안 해도")을 금지 표현으로 거부합니다.

### 4.2 질문·진행 move (Question / Control)

| move | 정의 | 허용 상태 | 원격 표현 |
|---|---|---|---|
| `openQuestion` | 상황·순간·맥락을 넓게 묻기 | checkIn, explore, reflect | 예 |
| `clarify` | 생각이 무엇인지 확인 | explore, reflect | 예 |
| `askSud` | 불안 정도 0~10 | checkIn, closing | 아니오 |
| `askEvidence` / `askAlternative` / `askProbability` | CBT 되짚기 질문 | reflect | 예 |
| `interventionQuestion` | 승인 기법 질문 | intervention | 아니오 |
| `checkReadinessToClose` | 더 다룰 내용이 있는지 확인(마무리 제안 포함) | intervention 뒤, closing | 아니오 |
| `finalize` | 마무리 확정(질문 없음) | closing | 아니오 |

`checkReadinessToClose`는 의미 행위입니다. 문장은 여러 개를 두고 번갈아 씁니다.
- "여기서 조금 더 이야기해 보고 싶은 부분이 있을까요?"
- "지금 더 다뤄 보고 싶은 게 남아 있나요?"
- "이 정도에서 정리해도 괜찮을까요, 아니면 더 이야기해 볼까요?"

### 4.3 한 턴의 구성

```
Turn = [Support move 0~2개] + [Question/Control move 0~1개]
```

- Support move 순서는 고정입니다: `acknowledge` → `reflectEmotion` → `supportiveAffirmation` → `restate`/`summarize` → `connectPastRecord`. 같은 move는 한 턴에 한 번만 씁니다.
- Question move가 있으면 항상 마지막에 둡니다.
- `repair`, `integrate`, `listen`은 단독 또는 정해진 짝으로만 씁니다(현행 문장 계약).
- 질문 없는 턴도 허용하지만, 다음에 무엇을 하면 되는지 알 수 있어야 합니다(현행 `deadTurnStatement` 지표).
- 원격 표현 명세에는 move 목록을 순서대로 넘기고, 검증기는 질문 수와 move 순서를 확인합니다.

**제외하는 전략.** 다음은 승인 CBT 경계 밖이라 move로 두지 않습니다.
- Providing Suggestions, Direct Guidance: 행동 지시
- Interpretation: 사용자 생각의 의미를 상담자가 해석
- Self-disclosure: 상담자의 경험 이야기
- Information: 승인 코퍼스 밖의 정보 제공
- 결과 보장형 안심

### 4.4 `connectPastRecord` 자격

다음을 모두 만족할 때만 씁니다.

1. 실제 저장 기록입니다(세션 요약 또는 일기, 근거 id 필수).
2. 지금 주제와 관련이 충분합니다(현재는 주제어 겹침, Phase 15에서 관련도 검색으로 교체).
3. 이번 세션에서 같은 기록을 쓴 적이 없습니다.
4. 복구 턴이 아닙니다.
5. 사용자의 이번 새 발화를 덮어쓰지 않습니다. 열린 내용이 있으면 그것을 먼저 받습니다.

**횟수.** 먼저 꺼내는 연결은 세션당 최대 1회입니다. 균형 사고 기법 앞의 지난 대안 상기(현행 D2)는 기법 문장의 일부로
보고 이 횟수와 따로 셉니다. 단, 같은 기록은 두 번 쓰지 않습니다.

**reflect에서의 형태.** 탐색 질문으로 연결합니다. 예: "예전에 면접을 앞두고도 다른 사람의 평가가 걱정된다는
기록이 있었어요. 그때와 지금 걱정이 비슷하게 느껴지나요?"

**우선순위.**

```
지금 다루지 않은 열린 내용  >  관련 있는 지난 기록  >  다음 예정 CBT 목표
```

---

## 5. 입력: 사용자 행위와 진행 상황

### 5.1 의미 분류기 출력 (14.2)

분류기는 **인식만** 합니다. 출력은 아래 세 필드와 확신도로 제한합니다.

```text
content_type:        situation | worry_thought | meaningful_answer | low_information
                     | emotion_expression | meta_interaction | app_guide | mixed
interaction_signal:  none | repeated_question | stop_questioning | assistant_not_understood
                     | process_resistance | closing_accept | closing_continue
open_content:        none | elaboration | new_worry | new_evidence
confidence:          0.0 ~ 1.0 (필드별)
```

**분류기가 반환하면 안 되는 것:** 다음 상태, 다음 move, CBT 선택, 마무리 여부, 응답 문장. 응답 스키마에 이 필드가
있으면 응답 전체를 버립니다.

**대체 규칙.** 시간 초과, 스키마 위반, 낮은 확신도에서는 현재 규칙 판정을 씁니다. 확신도가 낮을 때는 진행을
**멈추는 쪽으로만** 반영합니다. 예를 들어 헷갈림인지 불확실하면 기법 성과를 인정하지 않습니다.

**현재 규칙과의 대응.**

| 분류 | 현재 규칙 |
|---|---|
| `worry_thought`, `situation` | `TargetEligibility` |
| `low_information` | `isLowInformation` |
| `meaningful_answer` | `isTechniqueAnswer` + `showsTechniqueMove` |
| `repeated_question` 등 메타 4종 | `InteractionRepairReason` |
| `closing_accept`/`closing_continue` | 마무리 핸드셰이크 판정 |
| `emotion_expression` | 감정 단서(affective) |
| `open_content` | 없음(새로 정의) |
| `app_guide`, `mixed` | 어시스턴트 분기 |

### 5.2 진행 상황 (`DialogueProgressLedger`)

**별도로 저장하지 않고 턴 메타데이터에서 매번 계산합니다**(`ledgerOf(messages)`). 같은 정보를 두 곳에 두면
어긋납니다. 2026-10-02 기억 버그가 그런 경우였습니다.

| 필드 | 계산 근거 |
|---|---|
| `concernKnown` | 라운드에 `situation` 또는 `worry_thought` 발화가 있음 |
| `thoughtKnown` | `roundWorryThought`가 있음 |
| `sudKnown` | 불안 점수 질문 다음 턴의 숫자 답 |
| `emotionAcknowledged` | 이번 라운드에 `reflectEmotion`이 있음 |
| `goalsAsked` | 이번 라운드의 `dialogueGoalId` 집합 |
| `goalsAnswered` | 목표 질문 다음 턴이 `meaningful_answer`인 목표, 또는 `new_evidence`로 먼저 답한 목표 |
| `openContent` | 최근 사용자 발화의 `open_content`가 none이 아니고, 그다음 응답에서 아직 받지 않음 |
| `pastRecordUsed` | 이번 세션에 쓴 기록 id 집합 |
| `engagement` | 최근 3교환의 사용자 발화 중 내용 있는 것의 비율 |
| `lowInfoRun`, `confusionRun`, `clarifyRun` | 연속 횟수(현행 조기 마무리 장치와 같음) |
| `stagnation` | 최근 3교환 동안 ledger의 새 필드가 하나도 채워지지 않음 |
| `interventionStep` | 기법 질문 / 통합 / 없음 |
| `continuationUsed` | 마무리 계속을 이미 썼는지 |

---

## 6. 전이 규칙

### 6.1 우선순위 (위가 먼저)

1. 안전 관문(위기 응답)
2. 입력 검사(잡음, 욕설, 우회 시도)
3. 복구: 메타 발화 → `repair`
4. 조기 마무리: `lowInfoRun ≥ 2`, `confusionRun ≥ 2`, `stagnation` → `summarize` + `checkReadinessToClose`
5. **열린 내용 우선:** `openContent`가 있으면 그것을 먼저 받음(6.2)
6. 지난 기록 연결: 4.4절 자격을 만족하고 아직 쓰지 않았으면
7. 상태별 규칙(6.3)

### 6.2 열린 내용 처리

| `open_content` | move |
|---|---|
| `elaboration` (지금 걱정의 구체화) | `restate` (+ 감정 단서가 있으면 `reflectEmotion`) + 지금 목표를 이어가는 질문 |
| `new_worry` | `acknowledge` + `clarify`("그중 지금 더 마음에 걸리는 건 어느 쪽인가요?") → 고른 쪽이 라운드 대상 |
| `new_evidence` | 해당 목표를 답한 것으로 기록하고 `restate` + 다음 목표 질문 |
| 감정 표현만 | `reflectEmotion` + `listen` 또는 `openQuestion` |

`reflectEmotion`이 꺼져 있는 동안(임상 검수 전)은 `acknowledge`로 대신합니다.

### 6.3 상태별 규칙

**checkIn**
- `concernKnown`이 아니면 `acknowledge` + `openQuestion`
- `concernKnown`이고 `sudKnown`이 아니면 `acknowledge` + `askSud`
- 둘 다 되면 explore로

**explore** (검토 기준 3교환)
- `thoughtKnown`이 아니면 `restate` + `openQuestion`(걱정되는 순간). 두 번째부터는 `clarify`
- `thoughtKnown`이면 reflect로
- 검토 기준에 닿아도 생각이 안 나오면 reflect로 넘어가 확인 질문을 계속(현행과 같음)

**reflect** (최소 2교환, 라운드마다 검토 기준 6교환)
- 다음 목표: 아직 묻지 않았고 답하지도 않은 목표 중 `evidence` → `alternative` → `probability` 순서
- 목표 질문 앞의 Support move: 직전 답이 `meaningful_answer`이면 `restate`, 감정 단서가 있고 이번 라운드에 아직 반영하지 않았으면 `reflectEmotion`
- **intervention으로 넘어가는 조건(준비됨):** `thoughtKnown`, `goalsAnswered`에 `evidence` 포함, `openContent` 없음, 최소 교환 충족. `alternative`까지 답했으면 더 기다리지 않음
- 목표를 다 썼지만 준비되지 않았으면 현행 목표 소진 대응(`summarize`/`listen`)을 번갈아 씀

**intervention** (현행과 같음, 마지막만 바뀜)
- `interventionQuestion` → 답 → `integrate` + `checkReadinessToClose`
- 통합 뒤 답이 열린 내용이면 계속(closing의 1회 계속과 같은 경로), 아니면 마무리 제안

**closing**
- `closing_accept`이면 (`askSud` 선택) → `finalize`
- `closing_continue` 또는 열린 내용이면 1회 계속(reflect 새 라운드). 현행과 같음
- 계속을 이미 썼으면 현행처럼 새 상담을 안내하고 마무리

### 6.4 반복 방지 규칙

| 규칙 | 내용 |
|---|---|
| 같은 질문 move 연속 금지 | 직전 턴과 같은 질문 move(목표 포함)는 쓰지 않음 |
| 확인 질문 상한 | `clarify` 연속 2회 뒤에는 `summarize` 또는 조기 마무리(현행 진전 없음 장치) |
| 질문 없는 턴 상한 | 연속 1회까지 |
| 감정 반영 상한 | `reflectEmotion`은 라운드에 2회까지 |
| 같은 문장 연속 금지 | `checkReadinessToClose` 등 문장 후보가 여러 개인 move는 직전과 다른 문장(현행 변형 장치) |
| 한 턴 앞 보기 | 후보 move가 다음 턴에 고를 수 있는 move를 하나도 남기지 않으면(목표가 다 소진되는데 준비되지 않음) 대신 `summarize`를 고름 |

---

## 7. 길이 안전장치

**세는 단위.** 사용자 발화 하나와 그에 대한 응답 하나를 **1교환(exchange)**으로 셉니다. 첫 인사는 세지 않습니다.

**길이 값은 전이 조건이 아니라 검토 기준입니다.** 기준에 닿으면 "진행 중인지"를 다시 보고, 진행 중이면 계속합니다.

| 장치 | 값 | 기준에 닿았을 때 |
|---|---|---|
| explore 검토 기준 | 3교환 | 생각이 안 나왔으면 reflect로(확인 질문 계속) |
| reflect 검토 기준 | 라운드마다 6교환 | 열린 내용이 없으면 준비됨으로 보고 intervention으로. 있으면 계속 |
| 부드러운 상한 | 14교환 | 열린 내용이 없고 진행이 낮으면 `summarize` + `checkReadinessToClose`를 우선. 열린 내용이 있으면 계속 |
| 절대 상한 | 24교환 | 마무리로 강하게 유도. 단 마지막 발화를 무시하지 않고 `acknowledge` → `summarize` → 마무리 |
| 정체 감지 | 3교환 동안 진행 없음 | `summarize` + `checkReadinessToClose` |

이 값은 초기값입니다. HCoT 길이 분포(평균 9.47, 주로 7~13)는 규모를 가늠하는 참고치일 뿐 임상 근거가 아닙니다.
14.6 평가 세트와 14.7 dogfood의 길이 분포를 보고 조정합니다.

---

## 8. 평가 (14.6에서 동결)

**기존 게이트 유지.** A층 12종은 0, B층 3종은 1% 이하입니다. 복원한 v1~v5는 회귀 확인용입니다.

**새로 추가하는 지표**

| 지표 | 뜻 | 기준 |
|---|---|---|
| `closedWithOpenContent` | 열린 내용이 남은 채로 마무리 제안 | A층(0) |
| `sameQuestionMoveRun` | 같은 질문 move 연속 | A층(0) |
| `questionlessRun` | 질문 없는 턴 2회 연속 | A층(0) |
| `outcomeReassurance` | 결과 보장형 안심 문장 | A층(0) |
| `pastRecordOveruse` | 먼저 꺼낸 지난 기록 연결이 세션당 2회 이상, 또는 같은 기록 재사용 | A층(0) |
| `openContentIgnored` | 새 내용을 받지 않고 다음 목표로 감 | B층 |
| `sessionLength` | 교환 수 분포 | 기록 |
| `moveDiversity` | 세션당 서로 다른 move 수 | 기록 |

**새 동결 세트(필수).** 코드를 보지 않은 사람이 작성합니다.
- 기존 범주: 협조적, 헷갈림, 저정보, 반복 지적, 중단·불만, 반말, 띄어쓰기 없음, 여러 문장, 메타 + 걱정 혼합
- 추가 범주:
  - 할 말이 많은 사용자: 답할 때마다 새 근거나 새 걱정을 꺼냄
  - 감정 위주 사용자
  - 마무리 제안에 망설이는 사용자
  - 지난 기록이 있는 사용자
  - 15교환 이상 장기 대화

---

## 9. 구현 순서와 영향 범위

| 단계 | 내용 | 주로 바뀌는 곳 |
|---|---|---|
| 14.2A | 분류기를 **그림자 모드**로 연결: 매 턴 분류만 하고 결정에는 쓰지 않음. 규칙 판정과의 차이를 로컬 기록. 한국어 동결 세트로 오프라인 인식률 측정 | 백엔드 분류 endpoint, `lib/data/counseling/` |
| 14.2B | 동결 평가를 통과한 뒤 분류 결과를 정책 입력으로 사용(대체 규칙 유지) | 발화 해석 계층 |
| 14.3 | `ledgerOf(messages)` + 준비됨 기반 전이 + 길이 안전장치 | `counseling_state.dart`, selectors |
| 14.4 | move 두 축을 결정 모델과 메타데이터에 추가, 반복 방지 규칙, 열린 내용 처리, 지난 기록 연결 확대 | `counselor_decision.dart`, `counseling_models.dart`, materializer |
| 14.5 | move 조합의 문장화, 원격 표현 명세에 move 목록 전달, 검증(질문 수·순서·결과 보장 금지) | `realization_spec*.dart`, `counseling_realize.py` |
| 14.6 | 새 동결 세트와 새 지표 | `test/counseling/evaluation/` |
| 14.7 | 기기 dogfood, 길이 초기값 조정 | (문서) |

14.3을 14.4보다 먼저 하는 이유: 진행 판단을 먼저 바꿔야 move가 늘어나도 흐름이 닫히거나 맴돌지 않습니다.

---

## 10. 14.2 성공 기준

정확도 숫자만으로 판정하지 않습니다.

| 기준 | 판정 |
|---|---|
| 처음 보는 반말·띄어쓰기 없음·혼합 발화의 인식 | 새 동결 세트에서 메타 4종과 저정보 인식률이 현재 규칙(v5 기준 헷갈림 0/12, 저정보 2/10)보다 의미 있게 높음 |
| 오탐 | 걱정처럼 보이는 메타 아닌 발화의 오탐이 현재 수준(0)을 유지 |
| 기존 결정 보존 | 분류기를 켜도 A층 0, 안전·CBT·상태 결정 변화 없음 |
| 대체 동작 | 시간 초과·스키마 위반을 주입해도 규칙 판정으로 상담이 이어짐 |
| 비용 | 턴당 지연 증가와 호출 비용을 측정해 기록 |

---

## 11. 활성화 정책

| 항목 | 상태 |
|---|---|
| `reflectEmotion` | 구현은 하되 꺼 둠. 임상 검수 후 켬. 꺼져 있는 동안 `acknowledge`로 대체 |
| `supportiveAffirmation` | 구현은 하되 꺼 둠. 임상 검수 후 켬. 결과 보장 금지 검증은 항상 켬 |
| 분류기 | 14.2A는 그림자 모드, 14.2B에서 정책 입력 |
| 나머지 move | 14.4 구현과 함께 켬 |

켜고 끄는 것은 승인 기법 레지스트리와 같은 방식(코드 안 승인 목록)으로 합니다.

---

## 12. 동결 결정과 변경 이력

| 결정 | 내용 |
|---|---|
| 의미 분류기 | 백엔드 GPT 분류, 출력은 5.1절의 세 필드로 제한, 시간 초과·스키마 위반·낮은 확신도에서 규칙 대체. 그림자 모드 뒤 실제 적용 |
| 통합 뒤 계속 확인 | 추가. 고정 문장이 아니라 `checkReadinessToClose` move(문장 후보 여러 개) |
| 길이 | 부드러운 상한 14교환, 절대 상한 24교환. 검토 기준으로만 사용 |
| 지난 기록 연결 | reflect에서도 허용. 4.4절 자격, 먼저 꺼내는 연결은 세션당 1회 |
| 감정 반영 | 임상 검수 후 켬 |
| 안심 | 결과 보장형 금지. `supportiveAffirmation`으로 좁혀 임상 검수 후 켬 |
| move 구조 | 지지·반응 move와 질문·진행 move 두 축. 질문은 마지막 |
| 열린 내용 우선 | Phase 14 핵심 원칙 |
| 진행 ledger | 저장하지 않고 턴 메타데이터에서 계산 |
| Strategy RAG | 이번 Phase에서 만들지 않음 |

- 2026-10-02 초안 작성(`a765fea`)
- 2026-10-02 14.2A 결과 반영: 분류기 전체 적용(14.2B)은 보류. 후보 신호 3개(`assistant_not_understood`, `new_worry`, `new_evidence`)만 라벨별 guard 뒤 그림자 관찰. `frozen_v1`은 진단 세트로 전환하고 14.2B 전에 `frozen_v2`를 새로 동결([`phase14_2a_results.md`](phase14_2a_results.md))
- 2026-10-02 검토 의견 반영 후 동결: move 두 축 분리, 안심을 `supportiveAffirmation`으로 축소, 지난 기록 연결 자격과 횟수, 교환 단위 정의, 길이를 검토 기준으로 명시, 14.2를 A/B로 분리, 분류기 출력 제한

---

## 참고

- ESConv 저장소: https://github.com/thu-coai/Emotional-Support-Conversation
- HCoT-Corpus: https://pmc.ncbi.nlm.nih.gov/articles/PMC13033663/
- PsyPARSE: https://ojs.aaai.org/index.php/AAAI/article/view/37089
