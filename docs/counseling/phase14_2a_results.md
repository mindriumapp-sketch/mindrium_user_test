# Phase 14.2A 결과: 의미 분류기 오프라인 평가 (A-1 ~ A-3)

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

## 5. 재현

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
