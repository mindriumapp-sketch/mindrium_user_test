# 상담 세션 요약 계약

Step 4 의 `ConversationMemory` 가 만들 세션 요약의 형식. legacy NPC 의 summarizer
프롬프트(`agents.dart`)에 있던 구조를 정식 계약으로 옮긴 것이며, 그 파일은 폐기했다.

## 필드

```jsonc
{
  "session_id": "...",
  "main_worry": "핵심 걱정 / 상황 (ABC 의 A)",
  "automatic_thought": "자동적 사고 (B)",
  "emotion": "감정 (C)",
  "sud": { "before": 7, "after": 4 },
  "insight": "오늘의 통찰 또는 변화",
  "next_action": "다음에 해볼 실천/활동",
  "referenced_cbt_ids": ["week4_alternative_thought_01"],
  "referenced_user_context_ids": ["diary:abc123"]
}
```

legacy 프롬프트의 4줄 출력 형식은 그대로 대응된다.

| legacy 출력 | 여기 |
|---|---|
| 1) 상황/핵심걱정 (A) | `main_worry` |
| 2) 자동사고/감정 (B-C, SUD) | `automatic_thought`, `emotion`, `sud` |
| 3) 오늘의 통찰/변화 | `insight` |
| 4) 다음 실천/활동 | `next_action` |

## 만드는 방식

**먼저 결정론적으로 채운다.** 대부분의 필드는 세션 중 harness 가 이미 알고 있는 값
(참조한 일기, SUD, 사용한 CBT 항목, 도달한 상태)에서 그대로 나온다. 모델에 요약을
맡기는 것은 `insight` 처럼 문장 생성이 꼭 필요한 필드로 한정한다.

한 턴당 모델 추론 1회라는 제약은 요약에도 적용된다. 요약을 위해 별도 추론을 돌린다면
세션 종료 시점에 1회만 한다.

## provenance

요약도 근거를 남긴다. `referenced_*_ids` 는 harness 의 출력 검증을 통과한 id 만
담는다. 검증되지 않은 id 를 요약에 넣으면 세션 로그 전체의 추적성이 깨진다.
