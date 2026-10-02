# Phase 14.2A 결과: 의미 분류기 오프라인 평가와 그림자 연결 (A-1 ~ A-4)

기준: 2026-10-02. 설계는 [`phase14_dialogue_moves.md`](phase14_dialogue_moves.md) 5.1절과 10절입니다. 이 단계에서
분류기는 앱에 연결하지 않았고, 상담 결정에도 쓰지 않았습니다. 실제 사용자 발화는 외부로 보내지 않았고, 합성
발화만 썼습니다.

## 1. 무엇을 했나

| 단계 | 내용 | 결과물 |
|---|---|---|
| A-1 endpoint | `POST /counseling/classify`. 출력은 `content_type`, `interaction_signal`, `open_content`, 필드별 확신도로 제한 | `backend/app/routers/counseling_classify.py`, `schemas/counseling_classify.py` |
| A-1 계약 검증 | 결정 필드, 모르는 enum, 누락·추가 키, 과도한 길이, 비객체 응답, 업스트림 시간 초과·500·깨진 응답에서 응답 전체를 거부 | `backend/app/tests/test_counseling_classify.py` (21개 통과) |
| A-2 개발 세트 | 이미 본 holdout v1~v5 발화 426개. 프롬프트 디버깅에만 사용 | `fixtures/phase14_2_classifier_dev.json` |
| A-2 동결 세트 | 코드를 보지 않은 에이전트가 라벨 정의만 보고 작성. 247개. 분류기를 처음 실행하기 전에 커밋(`45aee44`) | `fixtures/phase14_2_classifier_frozen_v1.json` |
| A-2 비교 기준 | 같은 발화에 현재 규칙 판정을 적용 | `phase14_2_rule_labels_test.dart` |
| A-3 운영 지표 | 지연, 거부율, 토큰, 비용 | `tools/classifier_eval/score.py` |

**프롬프트 이력.** `classify_v1`은 개발 세트에서 응답의 10.8%가 거부됐습니다. 모델이 필드 값을 다른 필드에 넣는
경우(`content_type`에 "none")였습니다. `classify_v2`는 응답 형식을 JSON 스키마로 강제해(structured outputs, enum
고정) 거부가 0이 됐습니다. 동결 세트 실행 전에 v2로 고정해 커밋했습니다(`1f5d560`). 동결 세트는 한 번만
실행했고, 그 결과를 보고 프롬프트를 고치지 않았습니다.

## 2. 동결 세트 결과 (247개, 한 번 실행)

### 2.1 요약

| 항목 | 규칙 | 모델 |
|---|---|---|
| `interaction_signal` 정확도 | 85.4% | 87.0% |
| `content_type` 정확도 | 27.9% | 58.7% |
| `open_content` 정확도 | 61.5%(항상 none) | 74.5% |
| **메타 오탐** (정답이 none인 167개 중 메타 신호로 판정) | **2** | **8** |
| 거부율 | - | 0% |

`content_type`은 규칙에 해당 개념이 없는 분류(의미 있는 답, 감정, 앱 안내)가 많아 규칙과 직접 비교하기 어렵습니다.
마무리 답을 `meta_interaction`으로 본 작성자의 라벨 관례도 두 쪽 점수를 모두 낮춥니다. 판정은 아래 라벨별
수치로 합니다.

### 2.2 `interaction_signal` 라벨별

| 라벨 | 정답 수 | 모델 재현율 | 모델 정밀도 | 규칙 재현율 | 규칙 정밀도 |
|---|---|---|---|---|---|
| assistant_not_understood | 19 | **73.7** | 93.3 | 31.6 | 85.7 |
| repeated_question | 21 | 61.9 | 92.9 | 57.1 | 100.0 |
| process_resistance | 8 | 25.0 | 100.0 | 0.0 | - |
| stop_questioning | 8 | 100.0 | **53.3** | 100.0 | 88.9 |
| closing_accept | 14 | 78.6 | 91.7 | 92.9 | 81.2 |
| closing_continue | 10 | 90.0 | 60.0 | 80.0 | 80.0 |
| none | 167 | 94.6 | 90.8 | 98.2 | 85.0 |

### 2.3 `open_content` 라벨별 (규칙에는 없는 개념)

| 라벨 | 정답 수 | 모델 재현율 | 모델 정밀도 |
|---|---|---|---|
| new_worry | 17 | 88.2 | 75.0 |
| new_evidence | 24 | 66.7 | 84.2 |
| elaboration | 54 | **11.1** | 66.7 |

### 2.4 `content_type` 중 위험한 것

| 라벨 | 모델 재현율 | 모델 정밀도 | 뜻 |
|---|---|---|---|
| low_information | 100.0 | **29.8** | 내용 있는 답을 저정보로 자주 판정. 실제로 쓰면 조기 마무리가 잘못 걸림 |
| worry_thought | 84.3 | 55.0 | |
| meaningful_answer | 70.6 | 94.6 | 규칙(3.9%)보다 크게 나음 |

### 2.5 모델 메타 오탐 8건

| 유형 | 건수 | 예 |
|---|---|---|
| 제3자 주어를 챗봇에 대한 말로 판정 | 3 | "선배가 그만 좀 물어보라고 할까봐요" → stop_questioning |
| 앱 안내 + 걱정 혼합을 질문 중단 요청으로 판정 | 4 | "ㅠㅠ시험 망할듯 일정 추가하는거 어딨어" → stop_questioning |
| 앱 사용법을 모름 → 챗봇을 이해 못함 | 1 | "걱정일기쓰는법모르겠어 쓰려고해도 머리가 하얘져" |

프롬프트에 제3자 규칙을 명시했는데도 오탐이 났습니다.

### 2.6 확신도

모델이 매긴 확신도는 정오를 구분하지 못합니다. `interaction_signal` 확신도의 중앙값이 맞은 경우 0.0, 틀린 경우
0.35였습니다. 활성화 기준으로 쓰지 않습니다.

### 2.7 운영

| 항목 | 값 |
|---|---|
| 지연 p50 / p95 | 1,053ms / 1,540ms (모델 호출만, 백엔드 왕복 제외) |
| 시간 초과·거부 | 0% (동결 세트), 개발 세트 v1에서 시간 초과 1건 |
| 토큰 | 입력 평균 931, 출력 평균 42 |
| 비용 추정 | 발화당 약 $0.00017, 10교환 세션당 약 $0.0017 (gpt-4o-mini 정가 기준 추정) |

지연이 약 1초라서, 실제로 적용하면 원격 표현 호출까지 합쳐 턴당 2초 이상이 될 수 있습니다.

## 3. 14.2A 종료 게이트 판정

| 게이트 | 기준 | 결과 |
|---|---|---|
| 금지 출력 수용 | 0 | **통과** (계약 테스트, 동결 세트 거부 0) |
| 모르는 enum 수용 | 0 | **통과** |
| 장애 시 규칙 대체 | 100% | **통과** (주입 7종 모두 거부 → 대체 경로) |
| 처음 보는 표현 인식이 규칙보다 높음 | 높음 | **부분 통과**: 헷갈림(31.6 → 73.7), 저항(0 → 25)은 높음. 반복 지적은 비슷함 |
| 기존 부정 사례 오탐 | 0 | **불통과**: 모델 8건(규칙 2건) |
| 혼합 발화 별도 보고 | 보고 | 2.5절 |
| 지연·비용·거부율 측정 | 측정 | **통과** |
| 그림자 인과성(결정 변화 0) | 0 | **미측정**: A-4 앱 연결 전 |

**결론: 분류기 전체를 정책 입력으로 쓰는 것(14.2B)은 아직 안 됩니다.** 오탐 게이트를 통과하지 못했습니다.
특히 stop_questioning 정밀도 53%와 low_information 정밀도 30%는 실제로 쓰면 상담을 잘못 멈추게 합니다.

**라벨별로 보면 쓸 만한 신호가 있습니다.** 최종 결정은 그림자 결과를 본 뒤에 합니다.

| 신호 | 판단 | 이유 |
|---|---|---|
| assistant_not_understood | 후보 | 재현율이 규칙의 2배 이상, 정밀도 93% |
| new_worry, new_evidence | 후보 | 규칙에는 없는 신호, 정밀도 75~84%. 열린 내용 우선 원칙(14.4)의 입력 |
| repeated_question | 보류 | 규칙과 차이가 작음 |
| stop_questioning, low_information | 사용 안 함 | 정밀도가 낮음 |
| elaboration | 사용 안 함 | 재현율 11% |
| 확신도 | 사용 안 함 | 정오와 무관 |

## 4. 다음 단계 제안

1. **그림자 연결(A-4) 전에 오탐을 줄일 구조를 정합니다.** 동결 세트의 오탐을 보고 프롬프트를 고치면 이 세트는
   판정에 다시 쓸 수 없습니다. 고친다면 판정용 동결 세트 v2를 새로 만들어야 합니다. 후보는 두 가지입니다.
   - **규칙 거부권:** 모델이 메타 신호를 내도, 규칙이 걱정 생각이나 제3자 주어로 보면 메타로 쓰지 않습니다. 앞의
     오탐 중 제3자 주어 3건이 이 경우입니다.
   - **라벨별 적용:** 위 표의 후보 신호만 그림자 비교 대상으로 삼습니다.
2. **A-4 그림자 연결:** 내부 계정에서만 켜고, 결정에는 쓰지 않으며, 원문 없이 라벨·일치 여부·지연만 기록합니다.
   결정 변화 0을 자동으로 확인합니다.

## 5. A-4 그림자 연결 (2026-10-02)

**`frozen_v1`의 지위 변경.** 아래 guard를 이 세트의 오탐 유형을 보고 설계했으므로, `frozen_v1`은 이제 개발·진단
세트입니다. 14.2B 판정에는 쓰지 않습니다. 14.2B 직전에 `frozen_v2`를 새로 만듭니다(6절).

**분류기는 바꾸지 않았습니다.** `classify_v2` 그대로입니다.

**관찰 범위**

| 신호 | A-4에서의 취급 |
|---|---|
| `assistant_not_understood` | guard 뒤 그림자 후보 |
| `new_worry`, `new_evidence` | guard 뒤 그림자 후보 |
| `repeated_question`, `process_resistance` | 모델 원값만 진단용으로 기록 |
| `stop_questioning`, `low_information`, `elaboration` | 원값만 기록, guard 값을 만들지 않음(모델 사용 금지) |
| 확신도 | 기록하지 않음, 정책에 쓰지 않음 |

**라벨별 guard** (`lib/features/counseling/perception/shadow_perception.dart`). 메타 신호와 내용 신호의 guard를
분리했습니다.
- `assistant_not_understood`: 제3자 주어("교수님이", "선배가", "친구가" …)이거나 앱 사용법 혼동(앱, 기능, 메뉴,
  설정, 알림, 일기 …)이면 버립니다. "그게 무슨 뜻이야"처럼 직전 상담자 발화를 가리키는 말은 통과합니다.
- `new_worry` / `new_evidence`: 걱정 내용인 것이 정상이므로 걱정 판정으로 막지 않습니다. 앱 안내 영역이거나
  내용이 없는 발화(메타만, 저정보)이면 버립니다.

**인과 차단.** 분류 요청은 응답이 정해진 뒤 기다리지 않고(unawaited) 보냅니다. 결과는 기록 함수로만 갑니다.
`test/counseling/shadow_perception_test.dart`가 다음을 자동으로 확인합니다.

| 확인 | 방법 |
|---|---|
| 결정 변화 0 | 5개 시나리오(협조, 헷갈림, 저정보 + 계속, 반복·중단, 위기)를 그림자 없음 / 최악 라벨만 내는 그림자 / 실패하는 그림자 / 느린 그림자로 각각 돌려, 상태, 응답 문장, 행위, 목표, 복구 사유, 기법 단계, 마무리 단계, 조기 마무리, 확인 질문, 성과 인정, CBT id, 저장된 세션 요약이 모두 같음 |
| 턴을 막지 않음 | 응답하지 않는 분류기에서 시간 초과로 기록되고 턴은 진행됨 |
| 원문 없음 | 기록에 사용자 발화, 상담자 발화, 세션 id 원문이 없음(세션은 FNV-1a 가명) |
| guard | 제3자·앱 사용법 오탐 유형은 버리고, 챗봇을 가리키는 말은 통과 |

**켜는 조건.** 빌드 플래그 `COUNSELING_SHADOW_CLASSIFIER=true`(기본 false) **그리고** 내부 계정 허용 목록에 있는
계정일 때만 동작합니다. 켜면 그 계정의 사용자 발화와 직전 상담자 발화가 백엔드를 거쳐 OpenAI로 갑니다.

```bash
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://127.0.0.1:8090 \
  --dart-define=COUNSELING_REMOTE_REALIZER=true \
  --dart-define=COUNSELING_SHADOW_CLASSIFIER=true
# dogfood 뒤
adb logcat -d | grep SHADOW_PERCEPTION > build/classifier_eval/shadow.log
python3 tools/classifier_eval/analyze_shadow.py build/classifier_eval/shadow.log
```

기록 한 줄에는 가명 세션, 턴 번호, 규칙 신호, 모델 원값, guard 값과 버린 이유, 규칙과의 일치 여부, 지연, 실패
사유만 들어갑니다. 실제 사례의 원문 분석이 필요하면 사용자가 따로 적어 둔 문장만 평가 세트로 옮깁니다.

## 6. 남은 순서

1. **A-5 그림자 분석:** 내부 dogfood 기록으로 라벨별 추가 가치(규칙이 놓친 것을 모델이 잡은 비율), guard가 버린
   유형, 호출이 필요한 턴의 비율(선택 호출 가능성), 실제 지연을 봅니다.
2. **14.2B-0 `frozen_v2`:** A-5에서 본 실패 유형을 바탕으로, 실제 문장을 복사하지 않고 새 표현으로 작성합니다.
   코드를 보지 않은 작성자가 쓰고 첫 실행 전에 동결합니다.
3. **14.2B-1 라벨별 적용 결정:** 라벨마다 따로 정합니다. 기준을 넘지 못한 라벨은 규칙을 유지합니다.

## 7. 재현

```bash
python3 tools/classifier_eval/build_dev_set.py
F=test/counseling/evaluation/fixtures/phase14_2_classifier_frozen_v1.json
RULE_LABEL_IN=$F RULE_LABEL_OUT=build/classifier_eval/frozen_rules.json \
  flutter test test/counseling/evaluation/phase14_2_rule_labels_test.dart
(cd backend/app && PYTHONPATH=. python3 ../../tools/classifier_eval/run_model.py \
  ../../$F ../../build/classifier_eval/frozen_model.json)      # OpenAI 호출, 합성 발화만
python3 tools/classifier_eval/score.py $F build/classifier_eval/frozen_rules.json \
  build/classifier_eval/frozen_model.json build/classifier_eval/frozen_report.json
```

원본 결과는 `test/counseling/evaluation/results/phase14_2a_frozen_v1_classify_v2*.json`에 있습니다. `temperature 0`이어도 모델 응답은 실행마다 조금 다를 수 있습니다. 위 수치는 2026-10-02 한 번 실행한 결과입니다.

## 8. 14.2B-0/1: frozen_v2 결과 (2026-10-02, 한 번 실행)

`frozen_v2`(240개)는 코드와 dogfood 문장을 보지 않은 작성자가 실패 유형 설명만 보고 썼고, 실행 전에 커밋했습니다
(`97f0f8b`). 분류기는 `classify_v2` 그대로입니다. guard 값은 앱의 guard(`shadow_perception.dart`)와 같은 정규식으로
계산했습니다. 원본: `test/counseling/evaluation/results/phase14_2b_frozen_v2_classify_v2*.json`.

| 신호 | 규칙 재현율 / 정밀도 | 모델(guard) 재현율 / 정밀도 | v1(진단) guard 값 | 판단 |
|---|---|---|---|---|
| assistant_not_understood (27) | 7.4 / 100 | **37.0 / 90.9** | 73.7 / 100 | 적용 후보. 오탐 1건("방금 내가 한 말 읽긴 했어?")도 챗봇을 향한 말 |
| stop_questioning (25) | 40.0 / 84.6 | **88.0 / 88.5** | 100 / 72.7 | 적용 후보. v2 오탐 3건은 모두 챗봇의 진행 방식에 대한 불만(정답 process_resistance)이라 질문을 멈춰도 해가 작음. v1 오탐은 앱 위치 질문("어디서") |
| new_worry (19) | - | **73.7 / 100** | 88.2 / 75.0 | 후보. 다만 실기기 32턴에서는 한 번도 표시하지 않음 |
| new_evidence (12) | - | 50.0 / 75.0 | 66.7 / 84.2 | 보류(표본 작음, 재현율 낮음) |
| repeated_question (15) | 53.3 / 88.9 | 80.0 / 73.3(원값) | - | 규칙 유지 |
| process_resistance (22) | 4.5 / 100 | 27.3 / 100(원값) | 25.0 / 100 | 그림자 유지(재현율 낮음) |
| low_information | 50.0 / 63.6 | 100 / 32.5(원값) | 100 / 29.8 | 사용 안 함 |
| 메타 오탐(정답 none 122개) | 2 | 2 | - | 같음. 제3자 주어 1건(g172 "선생님이 같은 질문만…")은 guard가 없는 repeated_question |

운영: 시간 초과 2건(0.8%), 지연 p50 1.0초 / p95 1.9초.

## 9. 14.2B 적용 결정과 구현 (2026-10-02)

**적용(규칙 OR guard 통과 모델):** `assistant_not_understood`, `stop_questioning`.
**그대로:** `new_worry`·`new_evidence`·`process_resistance`는 그림자, `repeated_question`·`low_information`은 규칙,
`elaboration`·확신도는 사용 안 함. 분류기와 프롬프트(`classify_v2`)는 동결.

| 항목 | 구현 |
|---|---|
| 우선순위 | 안전 > 질문 중단 > 챗봇 말을 못 알아들음 > 그 밖의 복구 > 일반 상담. 규칙이 반복 지적으로 봐도 모델이 질문 중단이면 질문 중단 |
| 행동 계약 | 두 신호 모두 기존 결정론 복구 문장으로만 연결. 질문 중단은 질문 없는 복구(세션 종료 아님), 마무리 제안 중이면 마무리. 못 알아들음은 대기 중이던 질문을 쉬운 말로 다시 묻는 기존 복구 |
| guard | 제3자 주어, 앱 사용법(14.2B에서 "어디서/어딨/어디에/어떻게 들어가" 추가). 두 신호에 같은 guard |
| 선택 호출 | 안전 관문에 걸린 턴, 앱 안내만인 턴, 잘못된 입력, 규칙이 이미 두 신호 중 하나를 잡은 턴은 호출하지 않음. 그 밖에는 최대 2초 기다리고, 시간 초과·실패면 규칙만 |
| 비조기 마무리 | 모델이 복구를 잡은 턴에는 저정보·진전 없음 조기 마무리 장치가 동작하지 않음(비답변이 아니므로) |
| 켜는 조건 | 빌드 플래그 `COUNSELING_SEMANTIC_REPAIR=true` + 내부 계정. 기본은 꺼짐(그림자 관찰은 `COUNSELING_SHADOW_CLASSIFIER`) |

**허용된 인과 차이와 금지된 차이** (`test/counseling/phase14_2b_semantic_repair_test.dart`)
- 허용: 위 두 복구. 그 턴 이전의 결정은 그대로
- 금지(테스트로 확인): 모델이 none일 때 변화, 다른 라벨(`process_resistance` 등)에 의한 변화, 위기 턴 변화(분류기 호출도 안 함), 앱 안내만인 턴(호출 안 함), 제3자·앱 사용법 오탐, 느린 분류기(시간 초과 → 규칙과 같은 결과), 적용을 끈 상태의 변화, 복구 발화가 이후 인용 대상이 되는 것

**알려진 점:** 의도 분류기가 "걱정일기는 어디서 써?"를 상담으로 분류합니다(기존 동작). 이 경우 분류기가 호출되지만
앱 사용법 guard가 막습니다.

## 10. 14.2B 실기기 1차와 후속 (2026-10-02)

**실기기 1차(1세션 9턴):** "무슨 뜻이야?"를 규칙은 놓치고 모델이 잡아 결정론 못 알아들음 복구로 이어짐. 마무리 제안 중
"질문좀 그만해"는 규칙이 잡아 마무리. 오탐 0. 반응하면 안 되는 문장은 이 세션에 없어 실기기 확인 못 함.
분류기 지연 p50 1.7초 / p95 2.6초, 8턴 중 2턴이 2초 제한을 넘어 규칙만으로 처리됨(기록에 남지 않던 문제).

**후속 구현(투기적 실행 + 커밋 지점):**
- 분류기를 부를 턴이면 분류기와 임시(일반) 턴을 함께 시작. 임시 턴은 원격 표현을 요청할 수 있음
- 분류기 답이나 제한 시간(2초, 그대로) 전에는 아무것도 확정하지 않음. guard 통과 복구가 나오면 임시 결과를 버리고
  세션 카운터(상태, 상태 내 턴 수, 전체 턴 수)를 되돌린 뒤 그 복구로 결정론 계획을 다시 세움. 아니면 임시 결과 사용
- 복구 턴의 최종 응답은 항상 결정론(원격 표현 미사용). 버린 원격 요청은 `discard_reason=causal_repair_override`로 기록
- 기록: 규칙 신호(분류기 전에 따로 계산), 모델 원값, guard 값, 실제 반영 신호, 분류기 상태(success / timeout /
  http_error / schema_reject / skipped), 지연, 원격 요청·사용 여부, 버린 이유. 시간 초과는 none과 구분
- 분류기 프롬프트는 바꾸지 않음(`classify_v2`). 축소(`classify_v3-short`)는 별도 비교 후

**표현 문제 2건 계층 확인(같은 대화를 앱 하네스로 재생해 원격 요청을 대조):**

| 턴 | 현상 | 원격 요청 내용 | 분류 |
|---|---|---|---|
| 2 | 사실("다음주 미팅때 발표해야해")을 "생각"이라고 함 | 결정론 초안이 이미 "…라고 **느끼고** 계시는군요", 질문 목표가 "…라고 느끼게 된 계기를 확인한다" | **상류(결정·문장 계약) 결함**: explore가 상황 서술을 느낌·생각처럼 다룸. GPT가 이를 "생각"으로 키움 |
| 6 | 질문 없이 끝남 | 허용 행위가 `socraticQuestion, reflect, summarize`, GPT가 `reflect`(질문 없음) 선택 | **계약 안이지만 계약이 느슨함**: 비답변("몰라. 딱히 없어") 뒤에도 질문 없는 행위를 모델이 고를 수 있음. 검증기 누락 아님 |
