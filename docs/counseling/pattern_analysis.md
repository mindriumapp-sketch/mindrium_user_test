# 상담 중 불안 기록과 알림 분석

기준: 2026-11-13, 태그 `counseling-handover-v3`, 프롬프트 `respond_v15`. 챗봇 전체 구조는 [`chatbot_system.md`](chatbot_system.md)를 본다.

사용자가 "요즘 내가 주로 언제 불안해?"처럼 자신의 기록을 살펴봐 달라고 하면, 최근 28일 일기와 알림 설정을
집계해 상담 응답의 근거로 쓴다. 집계는 서버가 계산하고, 모델은 계산된 사실만 문장으로 연결한다.

## 1. 흐름

```
상담 화면 진입 / 맥락 새로 고침
  → GET /counseling/patterns (최근 28일 집계, 저장하지 않음)
사용자 발화
  → 분석 요청인가?
      ① 규칙: CounselingPatterns.explicitlyRequested
      ② (규칙이 아니고, 내부 계정 AI 상담이 켜져 있으면) POST /counseling/pattern-intent — 4초 제한
  → 요청이면: pattern:scope + 대표 집계(시간·장소·점수·상황)를 user_facts로 B 경로에 전달
    아니면: 발화와 관련된 집계만 user_facts에 포함
  → B 응답 검증 실패·호출 실패 시: 분석 요청이면 계산된 집계를 그대로 안내, 아니면 기존 상담 경로(A)
```

## 2. 코드 위치

| 하는 일 | 위치 |
|---|---|
| 집계 계산(기간 `WINDOW_DAYS = 28`, 기준 건수, 알림 비교) | `backend/app/core/counseling_patterns.py` |
| 집계 API | `backend/app/routers/counseling_patterns.py` (`GET /counseling/patterns`) |
| 분석 요청 AI 분류 | `backend/app/routers/counseling_respond.py`의 `pattern_intent` (`POST /counseling/pattern-intent`) |
| 집계 모델, 규칙 판정, `record_pattern` 사실 변환 | `lib/data/counseling/counseling_patterns.dart` |
| API 클라이언트 | `lib/data/api/counseling_patterns_api.dart`, `lib/data/api/counseling_respond_api.dart` |
| 요청 판단과 B 전달 | `lib/features/counseling/counseling_provider.dart` |
| 모델이 집계를 쓰는 규칙 | `counseling_respond.py`의 `SYSTEM_PROMPT`(`record_pattern`, `pattern:scope` 항목) |
| 테스트 | `backend/app/tests/test_counseling_patterns.py`, `test_pattern_intent.py`, `test/counseling/counseling_patterns_test.dart` |

## 3. 집계 규칙

**대상 데이터**
- 로그인한 사용자의 완료 일기와 현재 활성 알림 설정만 쓴다.
- 화면을 다시 열거나 상담 맥락을 새로 고치면 최신 상태로 다시 조회한다.

**시간과 요일**
- 일기 발생 시간은 `loc_time.time`을 쓴다. 없거나 잘못됐으면 일기 작성 시간으로 따로 집계한다.
- 요일은 발생일이 아니라 일기 작성일 기준이다. 현재 데이터는 발생 날짜를 따로 보장하지 않는다.

**반복으로 말하는 기준** (개발용 기준이며 임상 기준이 아니다)
- 같은 시간대, 요일, 상황은 세 번 이상일 때 제시한다.
- 장소는 한 건 이상이어도 건수와 함께 보여 주지만, 세 건 미만은 반복이라고 표현하지 않는다.
- 일기별 마지막 불안 점수가 한 건 이상이면 유효 건수와 평균을 제시한다. 세 건 미만은 경향으로 단정하지 않는다.
  중재 전후 효과나 진단을 뜻하지 않는다.

**알림과의 비교**
- 활성 알림이 일기에 적힌 시간과 1시간 이내이고, 일기 작성 요일이 알림 요일에 포함될 때만 비교한다.
- 위치 알림은 장소명도 같아야 한다. 서울 이외 시간대는 비교하지 않는다.
- 현재 설정을 과거 일기와 비교하므로, 과거에 그 알림이 설정됐거나 실제로 발송됐다는 뜻은 아니다.

## 4. 개인정보

- 주소로 보이는 장소, 좌표, 주소 필드는 결과에서 뺀다.
- 장소명은 사용자가 패턴을 직접 물었거나 현재 발화와 직접 관련될 때만 상담에 제공한다.
- 상황과 장소 이름은 사용자가 입력한 값이므로 서버 로그에 남기지 않는다.
- 분석 요청 분류(`pattern-intent`)에는 마지막 발화만 보내고 일기와 집계는 보내지 않는다.
  이 호출은 응답 시간과 API 비용을 늘린다.

## 5. 실패와 우선순위

- 위기 신호, 종료 요청, "기록 얘기하지 마" 같은 기록 언급 중단 요청이 우선한다.
  기록 언급 중단은 현재 상담 세션에만 적용된다.
- 분류가 실패하거나 4초를 넘기면 규칙 판정과 일반 상담 경로만 쓴다. 그래서 일부 표현은 분석 요청으로 인식하지 못할 수 있다.
- LLM을 쓸 수 없거나 답변 검증에 실패하면 일반 상담은 기존 경로로 이어 가고, 분석 요청이었다면 계산된 집계를 그대로 안내한다.
- AI가 근거를 빠뜨리거나 바꾸면 계산된 결과를 그대로 보여 준다. ID·문장 검사는 LLM 답변 전체의 정확성을 보장하지 않는다.
- 패턴 조회에 실패하면 상담은 계속하고, 사용자가 분석을 요청했을 때만 조회 실패를 안내한다.

## 6. 확인과 배포

```bash
# 저장소 루트에서
PYTHONPATH=backend/app backend/.venv/bin/python -m pytest backend/app/tests -q -p no:cacheprovider
flutter test --no-pub test/counseling
```

신규 API가 등록되려면 백엔드를 재시작해야 하고, Flutter 앱도 다시 실행해야 한다. 외부 서버에 적용하려면 백엔드
이미지와 앱을 각각 다시 배포해야 한다([`../../backend/app/README.md`](../../backend/app/README.md)).
