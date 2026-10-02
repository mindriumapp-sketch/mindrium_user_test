# Phase 14.1 설계: Dialogue Move 체계와 전이 규칙

상태: **초안 (동결 전)**. 작성 2026-10-02. 이 문서가 동결되면 14.2~14.7의 구현 기준이 됩니다. 이 단계에서
코드는 바꾸지 않습니다.

---

## 1. 목표와 범위

**목표.** "이 상태에서 다음 질문은 무엇인가"에서 "지금 이 사용자에게 어떤 대화 행동(move)이 필요한가"로
결정 단위를 바꿉니다. 사용자가 할 말이 남아 있는 동안 상담이 섣불리 닫히지 않게 하는 것이 목적이고,
상담을 길게 만드는 것 자체는 목적이 아닙니다.

**바꾸는 것**
- 각 상태 안에서 고를 수 있는 move의 종류와 조합
- 단계 전이와 마무리 조건(턴 수 → 진행 상황)

**바꾸지 않는 것**
- 상태 5개(checkIn → explore → reflect → intervention → closing)
- 안전 관문, 승인 기법 레지스트리, 누적·미래 주차 규칙
- 결정은 결정론, GPT는 표현만, 검증 실패 시 결정론 대체
- 복구·기법·마무리 턴은 원격 표현 금지
- 턴 메타데이터를 결정 근거로 쓰는 방식

---

## 2. 외부 자료 확인 결과

원문에서 확인한 내용만 적었습니다.

| 자료 | 확인한 사실 | MindRium에 쓰는 것 | 쓰지 않는 것 |
|---|---|---|---|
| ESConv (ACL 2021) | 1,300개 대화, 지지자 발화마다 전략 8종(Question 20.7%, Affirmation and Reassurance 15.4%, Providing Suggestions 16.1%, Self-disclosure 9.3%, Reflection of feelings 7.8%, Information 6.6%, Restatement or Paraphrasing 5.9%, Other 18.3%). 실패 대화 196건 별도 공개. **"academic research use only"** | 전략 분류 체계, 질문과 비질문 전략의 비율, 실패 대화의 구조 패턴(오프라인 분석) | 원문 발화(라이선스), 제안·자기 노출 전략 |
| HCoT-Corpus (Frontiers in Psychology 2026) | 22,341개 대화, 평균 9.47턴, 전략 사슬은 주로 7~13턴. 탐색 단계는 Restatement 33.9%, Interpretation 36.5%, 위로 단계는 Approval and Reassurance 57.4%, 행동 단계는 Direct Guidance 48.4%. GPT-4o가 생성한 **합성 중국어 데이터**이고, 저자가 임상 서비스에 직접 배포하는 것을 금지함 | 단계 안에서 여러 전략이 섞인다는 구조 원리, 길이 분포(참고치) | 길이를 목표치로 쓰는 것, Interpretation·Direct Guidance(승인 CBT 밖의 해석과 지시) |
| PsyPARSE (AAAI 2026) | 학습 없이 쓰는 프레임워크. 여러 치료법 RAG와 멀티턴 롤아웃으로 경로를 시뮬레이션해 응답을 고름 | "한 턴 앞을 보고 반복이나 섣부른 전환을 피한다"는 발상(결정론 규칙으로) | LLM이 치료 경로를 고르는 구조 전체 |

**결론.** 외부 자료에서는 **move 분류와 조합 원리만** 가져옵니다. 원문 발화, 길이 목표, 승인되지 않은
전략은 가져오지 않습니다. 따라서 이 단계에서는 Dialogue Strategy RAG를 만들지 않고, 명시적인 전이 규칙
표(6절)로 시작합니다. 규칙만으로 부족하다는 근거가 dogfood에서 나오면 그때 검토합니다.

---

## 3. 현재 구조의 진단

| 항목 | 현재 | 문제 |
|---|---|---|
| explore | 1턴 고정 | 상황만 듣고 바로 생각 탐색으로 넘어감 |
| reflect | 근거 → 다른 관점 → 가능성 고정 순서, 최소 2턴·최대 4턴 | 사용자가 새 이야기를 꺼내도 다음 목표 질문으로 감 |
| 턴 구성 | 받아 주는 문장 1개 + 질문 1개 | 감정 반영, 요약, 경청이 각각 따로 있지 않음 |
| 진행 판단 | 목표를 썼는지, 턴 수 | 사용자가 참여 중인지, 새 내용이 나왔는지 보지 않음 |
| 마무리 | 기법 통합 직후 항상 제안 | 사용자에게 열린 내용이 남아 있어도 제안 |
| 결과 | 협조적 사용자 기준 사용자 입력 5~6번 후 마무리 제안 | 대화가 압축되고 정형화됨 |

---

## 4. Dialogue Move 체계

### 4.1 move 목록

| move | 정의 | 질문 | 허용 상태 | 원격 표현 | ESConv 대응 |
|---|---|---|---|---|---|
| `acknowledge` | 말해 준 것을 받아 줌 | 아니오 | 전체 | 예 | Affirmation |
| `restate` | 사용자 말의 요점을 다시 말함(인용 규칙 적용) | 아니오 | explore, reflect | 예 | Restatement |
| `reflectFeeling` | 드러난 감정을 이름 붙여 반영. 감정 단서가 있을 때만 | 아니오 | explore, reflect, intervention | 예 | Reflection of feelings |
| `reassure` | 걱정되는 마음이 자연스럽다고 인정. 결과를 약속하지 않음 | 아니오 | explore, reflect | 예 | Reassurance |
| `summarize` | 지금까지 나온 상황·생각·감정을 정리 | 아니오 | reflect, closing | 예 | Restatement |
| `connectEpisode` | 사용자 자신의 지난 기록과 연결(8A절 규칙, 근거 id 필수) | 아니오 | reflect, intervention | 아니오 | (없음) |
| `askSud` | 불안 정도 0~10 | 예 | checkIn, closing | 아니오 | Question |
| `openQuestion` | 상황·순간·맥락을 넓게 묻기 | 예 | explore, reflect | 예 | Question |
| `clarify` | 생각이 무엇인지 확인 | 예 | explore, reflect | 예 | Question |
| `askEvidence` / `askAlternative` / `askProbability` | CBT 되짚기 질문 | 예 | reflect | 예 | Question |
| `listen` | 질문 없이 들어 주기 | 아니오 | reflect | 아니오 | (없음) |
| `repair*` | 반복 지적·중단 요청·불만·헷갈림 복구(현행 4종) | 사유별 | 전체 | 아니오 | (없음) |
| `interventionPrompt` | 승인 기법 질문 | 예 | intervention | 아니오 | (없음) |
| `interventionIntegrate` | 기법 답 통합 | 아니오 | intervention | 아니오 | (없음) |
| `checkReadiness` | 더 이야기할지 확인(마무리 제안 포함) | 예 | intervention 뒤, closing | 아니오 | Question |
| `finalize` | 마무리 확정 | 아니오 | closing | 아니오 | (없음) |

**제외하는 전략.** 다음은 승인 CBT 경계 밖이라 move로 두지 않습니다.
- Providing Suggestions, Direct Guidance: 행동 지시
- Interpretation: 사용자 생각의 의미를 상담자가 해석
- Self-disclosure: 상담자의 경험 이야기
- Information: 승인 코퍼스 밖의 정보 제공

### 4.2 한 턴의 구성

한 턴은 다음 형태입니다.

```
[비질문 move 0~2개] + [질문 move 0~1개]
```

- **비질문 move 순서는 고정입니다.** `acknowledge` → `reflectFeeling` → `restate`/`summarize` → `connectEpisode` 순서이고, 같은 move는 한 턴에 한 번만 씁니다.
- **질문은 최대 1개입니다.** 지금의 질문 수 검증을 그대로 씁니다.
- **질문 없는 턴(`listen`, `summarize` 단독)도 허용합니다.** 다만 다음 턴에 사용자가 무엇을 해야 할지 알 수 있어야 합니다. 지금의 "질문 없는 대기"(deadTurnStatement) 지표로 지킵니다.

---

## 5. 입력: 사용자 행위와 진행 상황

### 5.1 사용자 행위 (`UserAct`, 14.2에서 분류기로 채움)

정책은 문장이 아니라 이 분류를 읽습니다. 분류기는 인식만 하고, 실패하면 현재 규칙 판정으로 대체합니다.

| 분류 | 예 | 현재 규칙의 대응 |
|---|---|---|
| `worryThought` | "사람들이 날 무능하게 볼 것 같아" | `TargetEligibility.worryThought` |
| `situation` | "내일 발표가 있어" | `situation` |
| `newContent` | 지금 대상 걱정과 다른, 새 걱정이나 근거 | (없음, 새로 정의) |
| `elaboration` | 지금 걱정을 구체화하거나 덧붙임 | (없음, 새로 정의) |
| `meaningfulAnswer` | 질문 목표에 맞는 답 | `isTechniqueAnswer` 일부 |
| `lowInformation` | "몰라", "그냥", "ㅇㅇ" | `isLowInformation` |
| `repeatedQuestion`, `stopQuestioning`, `processFrustration`, `assistantNotUnderstood` | 메타 발화 | `InteractionRepairReason` |
| `emotionExpression` | "너무 무서워", "답답해" | 감정 단서(affective) |
| `closingAccept`, `closingContinue` | "네 정리하자", "조금 더요" | 마무리 핸드셰이크 판정 |
| `appGuide` | "일기 어디서 써?" | 어시스턴트 분기 |

한 발화에 여러 분류가 함께 붙을 수 있습니다(예: 헷갈림 + 걱정). 확신도가 낮으면 진행을 **멈추는 쪽으로만**
반영합니다. 예를 들어 헷갈림인지 불확실하면 기법 성과를 인정하지 않습니다.

### 5.2 진행 상황 (`DialogueProgressLedger`)

**별도로 저장하지 않고 턴 메타데이터에서 매번 계산합니다**(`ledgerOf(messages)`). 같은 정보를 두 곳에 두면
어긋나는 버그가 생깁니다. 2026-10-02 기억 버그가 그런 경우였습니다.

| 필드 | 계산 근거 |
|---|---|
| `concernKnown` | 라운드에 `situation` 또는 `worryThought` 발화가 있음 |
| `thoughtKnown` | `roundWorryThought`가 있음 |
| `sudKnown` | 불안 점수 질문 다음 턴의 숫자 답 |
| `emotionAcknowledged` | 이번 라운드에 `reflectFeeling` move가 있음 |
| `goalsAsked` | 이번 라운드의 `dialogueGoalId` 집합 |
| `goalsAnswered` | 목표 질문 다음 턴이 `meaningfulAnswer`인 목표 |
| `openContent` | 최근 사용자 발화가 `newContent`/`elaboration`이고 아직 받아 주지 않음 |
| `engagement` | 최근 3턴의 사용자 발화 중 내용 있는 것의 비율 |
| `lowInfoRun`, `confusionRun`, `clarifyRun` | 연속 횟수(현행 조기 마무리 장치와 같음) |
| `stagnation` | 최근 3턴 동안 ledger의 새 필드가 하나도 채워지지 않음 |
| `interventionStep` | 기법 질문 / 통합 / 없음 |
| `continuationUsed` | 마무리 계속을 이미 썼는지 |

---

## 6. 전이 규칙

### 6.1 우선순위 (위가 먼저)

1. 안전 관문(위기 응답)
2. 입력 검사(잡음, 욕설, 우회 시도)
3. 복구: 메타 발화 → `repair*`
4. 조기 마무리: `lowInfoRun ≥ 2`, `confusionRun ≥ 2`, `stagnation` → 정리 후 `checkReadiness`
5. **열린 내용:** `openContent`가 있으면 그것을 먼저 받음(6.2)
6. 상태별 규칙(6.3)

### 6.2 열린 내용 처리

사용자가 새 이야기를 꺼내면 다음 목표 질문으로 넘어가기 전에 받아 줍니다.

| 사용자 행위 | move |
|---|---|
| `elaboration` (지금 걱정의 구체화) | `restate` + (감정이 있으면 `reflectFeeling`) + 지금 목표를 이어가는 질문 |
| `newContent`가 새 걱정 | `acknowledge` + `clarify`("그중 지금 더 마음에 걸리는 건 어느 쪽인가요?") → 고른 쪽이 라운드 대상 |
| `newContent`가 근거나 다른 관점 | 해당 목표를 답한 것으로 기록(`goalsAnswered`)하고 다음 목표로 |
| `emotionExpression`만 | `reflectFeeling` + `listen` 또는 `openQuestion` |

### 6.3 상태별 규칙

**checkIn**
- `concernKnown`이 아니면 `acknowledge` + `openQuestion`
- `concernKnown`이고 `sudKnown`이 아니면 `acknowledge` + `askSud`
- 둘 다 되면 explore로

**explore** (현행 1턴 고정 → 최대 3턴)
- `thoughtKnown`이 아니면 `restate` + `openQuestion`(걱정되는 순간). 두 번째부터는 `clarify`
- `thoughtKnown`이면 reflect로
- 3턴 안에 생각이 안 나오면 reflect로 넘어가 확인 질문을 계속(현행과 같음)

**reflect** (현행 최대 4턴 → 최대 6턴, 최소 2턴)
- 다음 목표 고르기: 아직 묻지 않은 목표 중 `evidence` → `alternative` → `probability` 순서. 다만 사용자가 이미 답한 목표(`goalsAnswered`)는 건너뜁니다
- 목표 질문 앞에 붙이는 move: 직전 답이 `meaningfulAnswer`이면 `restate`, 감정 단서가 있고 이번 라운드에 아직 반영하지 않았으면 `reflectFeeling`
- 관련 에피소드가 있으면 `connectEpisode`를 라운드에 한 번만(균형 사고 기법 앞이 아닌 경우에 한함)
- **intervention으로 넘어가는 조건(준비됨):** `thoughtKnown`, `goalsAnswered`에 `evidence` 포함, `openContent` 없음, 최소 턴 충족. `alternative`까지 답했으면 더 기다리지 않음
- 목표를 다 썼지만 준비되지 않았으면 현행 목표 소진 대응(`summarize`/`listen`)을 번갈아 씀

**intervention** (현행과 같음)
- `interventionPrompt` → 답 → `interventionIntegrate`
- 통합 뒤에는 바로 마무리 제안이 아니라 `checkReadiness`. 통합 문장에 이어 "지금 마음은 어떠세요, 더 이야기하고 싶은 게 있나요?"처럼 묻습니다

**closing**
- `checkReadiness`에 대한 답이 `closingAccept`이면 `askSud`(선택) → `finalize`
- `closingContinue` 또는 `newContent`이면 1회 계속(reflect 새 라운드). 현행과 같음
- 계속을 이미 썼으면 현행처럼 새 상담을 안내하고 마무리

### 6.4 반복 방지 규칙

| 규칙 | 내용 |
|---|---|
| 같은 질문 move 연속 금지 | 직전 턴과 같은 질문 move(목표 포함)는 쓰지 않음 |
| 확인 질문 상한 | `clarify` 연속 2회 뒤에는 `summarize` 또는 조기 마무리(현행 진전 없음 장치) |
| 질문 없는 턴 상한 | 질문 없는 턴은 연속 1회까지 |
| 감정 반영 상한 | `reflectFeeling`은 라운드에 2회까지 |
| 한 턴 앞 보기 | 후보 move가 다음 턴에 고를 수 있는 move를 하나도 남기지 않으면(예: 목표가 다 소진되는데 준비되지 않음) 대신 `summarize`를 고름 |

---

## 7. 길이 안전장치

턴 수는 전이 규칙이 아니라 안전장치로만 씁니다.

| 장치 | 초기값 | 근거 |
|---|---|---|
| 상태별 상한 | explore 3, reflect 6(라운드마다), intervention 3 | 현행 상한 + 열린 내용 처리 여유 |
| 세션 부드러운 상한 | 사용자 턴 14 → `summarize` 후 `checkReadiness` | HCoT 평균 9.47턴, 주 분포 7~13턴(참고치) |
| 세션 절대 상한 | 사용자 턴 24 → 마무리 | 현행 20 + 여유 |
| 정체 감지 | 최근 3턴 동안 진행 없음 → 정리 후 `checkReadiness` | 제안된 피로 장치 |

**초기값은 임시입니다.** 14.7 dogfood와 14.6 평가 세트의 길이 분포를 보고 정합니다.

---

## 8. 평가 (14.6에서 동결)

**기존 게이트 유지.** A층 12종은 0, B층 3종은 1% 이하입니다. 복원한 v1~v5는 회귀 확인용입니다.

**새로 추가하는 지표**

| 지표 | 뜻 | 기준 |
|---|---|---|
| `closedWithOpenContent` | 열린 내용이 남은 채로 마무리 제안 | A층(0) |
| `sameQuestionMoveRun` | 같은 질문 move 연속 | A층(0) |
| `questionlessRun` | 질문 없는 턴 2회 연속 | A층(0) |
| `openContentIgnored` | 새 내용을 받지 않고 다음 목표로 감 | B층 |
| `sessionLength` | 사용자 턴 수 분포 | 기록 |
| `moveDiversity` | 세션당 서로 다른 move 수 | 기록 |

**새 동결 세트(필수).** 코드를 보지 않은 사람이 작성합니다.
- 기존 범주: 협조적, 헷갈림, 저정보, 반복 지적, 중단·불만, 반말, 띄어쓰기 없음, 여러 문장, 메타 + 걱정 혼합
- 추가 범주:
  - 할 말이 많은 사용자: 답할 때마다 새 근거나 새 걱정을 꺼냄
  - 감정 위주 사용자
  - 마무리 제안에 망설이는 사용자
  - 장기 대화(15턴 이상) 시나리오

---

## 9. 구현 순서와 영향 범위

| 단계 | 내용 | 주로 바뀌는 곳 |
|---|---|---|
| 14.2 | `UserAct` 분류기(인식 전용, 규칙 대체) + 한국어 동결 세트로 인식률 판정 | `lib/data/counseling/`, 백엔드 분류 endpoint |
| 14.3 | `ledgerOf(messages)` + 준비됨 기반 전이 + 길이 안전장치 | `counseling_state.dart`, selectors |
| 14.4 | move 체계(4절)를 결정 모델과 메타데이터에 추가, 반복 방지 규칙 | `counselor_decision.dart`, `counseling_models.dart`, materializer |
| 14.5 | move 조합의 문장화, 원격 표현 명세에 move 목록 전달 + 검증 | `realization_spec*.dart`, `counseling_realize.py` |
| 14.6 | 새 동결 세트와 새 지표 | `test/counseling/evaluation/` |
| 14.7 | 기기 dogfood, 길이 초기값 조정 | (문서) |

14.4를 14.3보다 늦추는 이유: 진행 판단을 먼저 바꿔야 move가 늘어나도 흐름이 닫히거나 맴돌지 않습니다.

---

## 10. 동결 전에 정할 것

1. **분류기 방식(14.2).** 백엔드 GPT 분류(턴마다 호출 1회 추가, 발화가 외부로 나감) 또는 기기 내 소형 모델. 제안은 백엔드 GPT 분류 + 시간 초과 시 규칙 대체입니다.
2. **`checkReadiness` 문장.** 기법 통합 뒤 "더 이야기하고 싶은 게 있나요?"를 물으면, 지금보다 마무리 제안이 한 턴 늦어집니다.
3. **세션 길이 초기값.** 부드러운 상한 14와 절대 상한 24를 그대로 쓸지 정해야 합니다.
4. **`connectEpisode` 범위.** 균형 사고 기법 앞 외에 reflect에서도 지난 기록을 연결할지 정해야 합니다. 이 경우 사용자 기록 인용이 늘어납니다.
5. **임상 검수 대상.** 새 move 문장 중 `reassure`와 `reflectFeeling`은 검수가 필요한 문장입니다.

---

## 참고

- ESConv 저장소: https://github.com/thu-coai/Emotional-Support-Conversation
- HCoT-Corpus: https://pmc.ncbi.nlm.nih.gov/articles/PMC13033663/
- PsyPARSE: https://ojs.aaai.org/index.php/AAAI/article/view/37089
