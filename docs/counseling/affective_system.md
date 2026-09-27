# 정서 단서 탐지와 상담 태도 적응

## 이 시스템이 하는 일과 하지 않는 일

**한다**: 사용자 발화의 한국어 표층 표현에서 정서적 단서를 찾고, 상담 단계·안전 수준과
합쳐 상담사 아바타가 취할 태도를 정한다.

**하지 않는다**: 감정 인식(emotion recognition). 사용자의 실제 정서 상태를 추정한다고
주장하지 않는다.

이 구분은 문서상의 표현 문제가 아니다. 감정 인식 시스템이라고 부르는 순간 라벨링된
평가 데이터셋, 클래스별 정밀도/재현율, 인구집단별 편향 분석이 필요해진다. 현재 구현은
정규식 어휘 규칙이며 그런 평가를 뒷받침하지 않는다.

보고서·논문에서는 다음처럼 기술한다.

> affective cue detection + therapeutic stance adaptation

`AffectSignal.confidence` 는 규칙의 강도이지 보정된 확률이 아니다. "확신도 0.95" 를
"95% 정확" 으로 읽으면 안 된다.

## 구조

```
사용자 발화 + 최근 SUD + 직전 신호
        ↓  AffectSignalDetector      어휘 규칙, LLM 호출 없음
   AffectSignal { label, confidence, spike, streak, sud }
        ↓  AffectiveAdapter          + CounselingState + SafetyLevel
   AvatarExpression                  의미 상태 5개
        ↓  AvatarSelector            표정이 바뀔 때만 이미지 교체
   assets/npc_images/*.png
```

## 두 enum 을 합치지 않는다

| 사용자 신호 (`AffectLabel`) | 상담사 태도 (`AvatarExpression`) |
|---|---|
| distressed | concerned |
| anxious | attentive |
| positive | encouraging |
| neutral | warm / 단계 기본값 |
| uncertain | 단계 기본값 |

사용자가 괴로워한다고 상담사가 괴로운 표정을 짓지 않는다. 같은 enum 을 쓰면 이 미러링
방지가 코드에서 사라진다.

## 안전이 우선한다

`SafetyLevel` 이 normal 이 아니면 다른 모든 규칙을 무시하고 `attentive` 로 고정한다.
위기 상황에서 극적인 표정 연출은 도움이 되지 않는다.

## 한 턴당 모델 추론 1회

Step 3 에서 실제 온디바이스 모델이 들어와도 이 제약을 지킨다. 표정 판단을 위해
추론을 한 번 더 돌리지 않는다. 정확도가 필요해지면 `AffectSignalDetector` 뒤에
별도의 경량 분류기를 넣되, 상담 응답 생성 모델과는 분리한다.
