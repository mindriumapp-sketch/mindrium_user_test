# 컨텍스트 기능 대조: legacy DailyContext → MindriumContextBuilder

legacy `daily_context.dart` 를 폐기하기 전에, 그 안에 있던 "주차별로 어떤 정보를
상담에 보여주려 했는가"라는 제품 의도를 현재 `MindriumContextBuilder` 와 대조한 기록.

legacy 는 주차별로 서로 다른 데이터 소스를 골랐다.

| 주차 | legacy 가 고른 소스 | 현재 상태 |
|---|---|---|
| 1 | `relaxationTasks` 2건 | ✅ 이완 기록을 읽는다 (단, **효과가 확인된 것만** 남긴다) |
| 2 | `diaries` (activatingEvents 있는 것) 2건 | ✅ 일기 요약을 읽는다 |
| 3–4 | `customTags` 중 type 이 `B` 로 시작하는 것 3건 | ⚠️ **부분** — 일기의 belief 칩은 읽지만 독립 custom tag 는 읽지 않는다 |
| 5–6 | `habits` 2건 | ❌ **누락** — 7주차 생활 습관 계획을 읽지 않는다 |
| 7 | `screenTime` | ❌ **누락** — 스크린타임을 읽지 않는다 |
| 8 | `surveys` 2건 | ❌ **누락** — GAD-7 등 설문 점수를 읽지 않는다 |

## 판단

지금 바로 채우지 않는다. 이유는 두 가지다.

1. legacy 는 이 데이터를 번들된 `dummy.json` 에서 읽었다. 실제 서버 API 로 같은 것을
   가져오려면 `custom_tags_api` / `week7_api` / `screen_time_api` / `survey_api` 를
   각각 붙여야 하고, 이는 2A 의 범위를 넘는다.
2. 상담에 정말 필요한 정보인지 확인이 필요하다. 특히 스크린타임은 상담 대화에서
   쓰일 근거가 분명하지 않고, 개인정보 최소 수집 원칙에도 걸린다.

## 남은 작업

`MindriumDataSource` 에 소스를 추가하는 것으로 확장할 수 있다. 인터페이스가 이미
분리되어 있어 `MindriumContextBuilder` 의 선택·정규화 로직은 그대로 둔 채
소스만 늘리면 된다. 우선순위는 다음과 같이 본다.

1. **설문(GAD-7)** — 8주차 회고에서 실제로 필요하다. 단, 챗봇이 점수를 해석하지
   않는다는 제약(`week8_gad7_01`)을 지켜야 한다.
2. **생활 습관 계획** — 7·8주차에서 "계획한 행동을 실천했는지" 대화에 직접 쓰인다.
3. custom tags — 일기 belief 칩과 중복이 커서 이득이 작다.
4. 스크린타임 — 필요성 재검토 후 결정.
