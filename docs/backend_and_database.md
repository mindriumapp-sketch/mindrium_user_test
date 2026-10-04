# Mindrium Backend 및 Database 구조

> 기준: 2026-09-05 작성, 2026-10-04 상담 부분 갱신. 이 문서는 배포 중인 서버를 역추적한 문서가
> 아니라 `backend/app`, `lib/data/api`, `lib/data/storage`의 실제 구현을 기준으로 한다.

## 1. 전체 구조

```text
Flutter app
  ├─ Dio REST client
  │    └─ Authorization: Bearer <access JWT>
  ├─ FlutterSecureStorage
  │    ├─ access / refresh token
  │    └─ 로그인 세션 식별 정보
  ├─ SharedPreferences
  │    └─ 화면·진행 상태·알림 등 기기 로컬 상태
  └─ Kakao Local API (일부 화면에서 직접 호출)
          │
          ▼
FastAPI (`backend/app/main.py`)
  ├─ JWT 인증·계정 정책
  ├─ Pydantic request/response validation
  ├─ 도메인별 APIRouter
  └─ Motor async driver
          │
          ▼
MongoDB
  ├─ users
  ├─ diaries
  ├─ worry_groups
  ├─ custom_tags
  ├─ relaxation_tasks
  ├─ edu_sessions
  ├─ treatment_progress
  ├─ screen_time
  ├─ notification_settings
  └─ counseling_sessions
```

핵심 기술은 Flutter/Dart, Dio, FastAPI 0.115.4, Pydantic 2.9.2,
Motor 3.4.0, PyMongo 4.6.3, MongoDB, HS256 JWT다. Firebase와 Supabase는
사용하지 않으며 Android 설정에도 Firebase 미사용이 명시돼 있다.

## 2. Flutter의 backend 연결

### API endpoint 선택

`lib/data/api/api_client.dart`가 공통 `Dio` 인스턴스를 만든다.

우선순위는 다음과 같다.

1. `ApiClient(baseUrl: ...)` 생성자 인자
2. `--dart-define=API_BASE_URL=...`
3. Web 기본값: `https://mindrium-backend.onrender.com`
4. Debug mobile/desktop 기본값: `http://115.145.134.180:8070`
5. Release에서 define이 없으면 `StateError`

Release의 HTTP endpoint는 원칙적으로 거부하지만 현재
`115.145.134.180:8070`만 예외로 허용한다. 예제 define은
`dart_defines/api.example.json`에 있다.

### 인증과 자동 갱신

- 매 요청 전에 secure storage의 access token을 읽어 Bearer header에 넣는다.
- 401 응답을 받으면 refresh token으로 `POST /auth/refresh`를 호출한다.
- 갱신 성공 시 원 요청을 한 번만 재시도한다.
- 로그인 실패와 현재 비밀번호 오류 등은 refresh 대상에서 제외한다.
- connect/receive/send timeout은 각각 90/120/30초다.

`TokenStorage`는 access/refresh token을 `FlutterSecureStorage`에 저장한다.
`AuthSessionStorage`도 `user_id`, `patient_id`, email, 로그인 flag를 secure
storage에 저장하며 과거 SharedPreferences key는 읽는 즉시 이동한다.

### Flutter API wrapper와 backend router 대응

| Flutter | Backend prefix | 역할 |
|---|---|---|
| `AuthApi` | `/auth` | 가입, 로그인, token 갱신, 비밀번호 |
| `UsersApi` | `/users` | 내 계정, 탈퇴, 사용자 통계 |
| `UserDataApi` / `SurveyApi` | `/users/me` | 가치, 설문, 진행도, 오늘 할 일 |
| `DiariesApi` | `/diaries` | ABC 일기와 위치·시간 |
| `SudApi` | `/sud-scores` | 일기 내 SUD와 통계 |
| `WorryGroupsApi` | `/worry-groups` | 걱정 그룹과 아카이브 |
| `CustomTagsApi` | `/custom-tags` | A/B/C 태그와 교육 로그 |
| `RelaxationApi` | `/relaxation_tasks` | 이완 세션과 시간 통계 |
| `EduSessionsApi`, `Week7Api`, `Week8Api` | `/edu-sessions` | 주차별 교육 결과 |
| `TreatmentProgressApi` | `/treatment-progress` | 1~8주 진행 상태 |
| `ScreenTimeApi` | `/screen-time` | 앱 사용 세션과 통계 |
| `CounselingSessionsApi` | `/counseling-sessions` | 상담 원문이 아닌 구조화 세션 요약 upsert/조회 |
| `DioCounselingRespondApi` | `/counseling/respond` | 상담 주 경로(B): 경계 안에서 다음 응답 하나를 GPT가 JSON으로 결정 |
| `DioCounselingRealizeApi` | `/counseling/realize` | 대체 경로(A)의 문장 표현 |
| `AlarmSettingsApi` | `/alarm-settings` | 서버 동기화 알림 설정 |

화면에서 wrapper를 직접 생성하는 곳이 많고 중앙 DI container는 없다.
`ApiClient(TokenStorage())` 패턴을 각 provider/screen에서 반복 사용한다.

## 3. FastAPI backend

### 프로세스와 설정

- 진입점: `backend/app/main.py`
- 앱 이름/버전: `Mindrium API` / `0.1.0`
- 상태 확인: `GET /health`
- API 문서: `/docs`, `/redoc`
- Docker 시작 명령: `uvicorn main:app --host 0.0.0.0 --port ...`
- DB client: `AsyncIOMotorClient`, 프로세스 내 `lru_cache`로 재사용
- 기본 DB 이름: `flutter_test`

포트 기본값은 파일별로 차이가 있다. Dockerfile은 8070, `Settings.api_port`는
8050, backend README의 로컬 예시는 8080을 사용한다. 실행 환경에서는 `PORT` 또는
명시적인 uvicorn 인자로 하나를 선택해야 한다.

주요 환경 변수:

| 변수 | 용도 | 코드 기본값 |
|---|---|---|
| `MONGO_URI` | MongoDB 연결 문자열 | 빈 문자열 |
| `DB_NAME` | MongoDB database | `flutter_test` |
| `JWT_SECRET` | access/reset/verify JWT 서명 | 개발용 문자열 |
| `JWT_REFRESH_SECRET` | refresh JWT 서명 | 개발용 문자열 |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | access 만료 | 15분 |
| `REFRESH_TOKEN_EXPIRE_DAYS` | refresh 만료 | 7일 |
| `PLATFORM_SIGNUP_URL` | 외부 플랫폼 회원가입 endpoint | 없음 |
| `CORS_ORIGINS` | 허용 origin 설정값 | localhost 목록 |
| `SMTP_*`, `EMAIL_FROM` | 이메일 전송 설정 | 없음 |
| `OPENAI_*` | 상담 GPT 호출(respond, realize) 설정 | `backend/app/.env`에 실제 key 설정 |

`OPENAI_*`는 `routers/counseling_respond.py`(`POST /counseling/respond`, 상담 주 경로)와
`routers/counseling_realize.py`(`POST /counseling/realize`, 대체 경로의 문장 표현)가 사용한다.
모델은 `gpt-4o-mini`, 키는 서버에만 있고 앱은 백엔드를 거친다.
[`counseling/chatbot_system.md`](counseling/chatbot_system.md) 2절 참고.

### 인증 모델

1. 가입은 외부 플랫폼의 signup endpoint에 먼저 write를 위임한다.
2. 반환된 `patient_id`를 MongoDB `users`와 동기화한다.
3. 비밀번호는 bcrypt hash만 저장한다.
4. access/refresh token은 HS256 JWT이며 JWT `sub`는 Mongo `_id` 문자열이다.
5. refresh token 원문 대신 SHA-256 hash를 `users.refresh_hash`에 저장한다.
6. 일반 endpoint는 access token을 검증한 뒤 삭제되지 않은 user를 조회한다.
7. 도메인 데이터의 소유자 key는 외부용 문자열 `users.user_id`다.

즉 사용자 식별자는 세 종류가 공존한다.

| 식별자 | 의미 |
|---|---|
| `users._id` | Mongo ObjectId, JWT subject |
| `users.user_id` | `user_xxxxxxxx`, 앱 도메인 컬렉션 owner key |
| `users.patient_id` | 외부 플랫폼 사용자/환자 식별자 |

### Router 목록

- `/auth`: signup, login, refresh, password change/reset
- `/users`: 내 정보 조회·수정·soft delete, 주간 사용자 통계
- `/users/me`: value goal, embedded surveys, 전체 진행도, today task
- `/diaries`: 생성·목록·요약·최신·today-task·draft·단건·loc_time. 요약(`GET /diaries/summaries`)은 상담 챗봇이 쓰며 `alternative_thoughts`(사용자가 적은 도움이 되는 생각)를 포함한다
- `/sud-scores`: diary embedded SUD CRUD, 일/주 통계
- `/worry-groups`: 목록·아카이브 목록·CRUD·archive
- `/custom-tags`: 태그 CRUD, real-oddness/category embedded log
- `/relaxation_tasks`: 세션 CRUD 성격의 생성·갱신·조회와 시간 요약
- `/edu-sessions`: 주차별 생성·조회·갱신, 7/8주 세부 데이터
- `/treatment-progress`: 목록·active·주차 조회·repair
- `/screen-time`: 사용 세션 생성·목록·요약
- `/alarm-settings`: 사용자 알림 전체 조회·replace
- `/counseling-sessions`: 상담 세션 요약 upsert(`PUT /{session_id}`)·최근 목록(`GET`)
- `/counseling/respond`: 상담 주 경로(`POST`). 실패는 `detail.reason`으로 분류해 502/504로 돌려준다(`http_429`, `http_4xx_other`, `http_5xx`, `network_error`, `timeout`, `schema_reject`)
- `/counseling/realize`: 대체 경로의 상담 문장 GPT 표현(`POST`)

대부분 인증이 필요하다. `/auth/*`, `/`, `/health`가 대표적인 공개 경로다.

## 4. MongoDB 데이터 모델

MongoDB document DB이므로 SQL foreign key는 없다. 관계는 문자열 id로 표현하고
router가 항상 `user_id`를 함께 조건에 넣어 소유권을 제한한다. 주요 관계는 다음과 같다.

```text
users (1)
  ├─ embeds surveys[]
  ├─ (N) diaries
  │      ├─ embeds sud_scores[]
  │      ├─ embeds loc_time
  │      └─ references worry_groups.group_id
  ├─ (N) worry_groups
  ├─ (N) custom_tags
  │      ├─ embeds real_oddness_logs[] → diary_id
  │      └─ embeds category_logs[]     → diary_id
  ├─ (N) relaxation_tasks
  ├─ (N) edu_sessions
  ├─ (1 per week) treatment_progress
  │      ├─ references edu_sessions.session_id
  │      └─ references relaxation_tasks.relax_id
  ├─ (N) screen_time
  └─ (N) notification_settings (alarm_id별 1개)
```

### `users`

계정과 일부 사용자 프로필/설문을 함께 저장한다.

주요 필드:

```text
_id: ObjectId
user_id: string
patient_id: string | null
email, name, phone, gender, address, patient_code
password_hash, password_changed_at
refresh_hash, refresh_issued_at
failed_login_count, locked_until
survey_completed: bool
surveys: [{type, answers, completed_at}]
value_goal: string | null
email_verified: bool
is_deleted: bool
deleted_at: datetime | null
last_active_at, created_at, updated_at
```

탈퇴는 문서 삭제가 아니라 `is_deleted=true` 중심의 soft delete다.

인덱스:

- `email` unique
- `last_active_at`
- `created_at`

### `worry_groups`

일기를 묶는 사용자별 걱정 그룹이다.

```text
user_id, group_id
group_title, group_contents
character_id: 1..20
archived: bool
diary_count: int
sud_sum: number
created_at, updated_at, archived_at?
```

`avg_sud`는 저장 필드가 아니라 `sud_sum / diary_count`로 응답 시 계산한다.
일기 생성·수정 과정에서 그룹 metric을 application code로 갱신한다.

인덱스:

- `(user_id, created_at)`
- `(user_id, group_id)` unique

### `diaries`

ABC 걱정 일기의 중심 aggregate다. SUD와 위치/시간이 별도 컬렉션이 아니라
diary document에 embedded된다.

```text
user_id, diary_id
group_id → worry_groups.group_id
route: notification | today_task | solve | null
draft_progress
activation: {label, chip_id?, category?}
belief: DiaryChip[]
consequence_physical: DiaryChip[]
consequence_emotion: DiaryChip[]
consequence_action: DiaryChip[]
alternative_thoughts: string[]
sud_scores: [{sud_id, before_sud, after_sud?, created_at, updated_at}]
latest_sud: int | null
loc_time: {id, time?, location?, location_desc?, latitude?, longitude?} | null
loc_auto_filled: bool
created_at, updated_at
```

주의: Pydantic `DiaryCreate`에는 `alternative_thoughts`가 있지만 현재 create
router의 `diary_doc`에는 이 필드를 복사하지 않는다. 이후 PUT update에서는 기존
목록과 merge한다. 생성 요청부터 이 값이 필요하면 router 수정이 필요하다.

`latest_sud`는 embedded SUD 배열의 조회 비용을 줄이기 위한 denormalized 값이다.
`draft_progress`와 route는 today-task 임시 저장/완료 판단에도 사용한다.

인덱스:

- `(user_id, sud_scores.created_at)`
- `(user_id, group_id)`
- `(user_id, created_at desc)`
- `(user_id, diary_id)` unique

별도 `sud_scores` 컬렉션은 사용하지 않는다. startup 코드도 빈 컬렉션 생성을
피하려고 해당 인덱스를 만들지 않는다.

### `custom_tags`

ABC 입력 chip과 4/7주차 평가 로그를 한 document에 묶는다.

```text
user_id, chip_id
label
type: A | B | CP | CE | CA
is_preset, deleted
real_oddness_logs: [{
  log_id, diary_id, chip_id,
  before_odd, after_odd?, alternative_thought,
  completed_at, created_at, updated_at
}]
category_logs: [{
  log_id, diary_id, chip_id,
  category, short_term?, long_term?, is_changed,
  completed_at, created_at, updated_at
}]
created_at, updated_at
```

회원가입 시 preset tag를 생성하며 삭제는 `deleted` flag를 쓰는 soft delete다.
일부 log 저장은 해당 diary의 chip category도 함께 갱신한다.

인덱스:

- `(user_id, chip_id)` unique
- `(user_id, type, deleted, created_at)`
- `(user_id, real_oddness_logs.completed_at)`
- `(user_id, category_logs.completed_at)`

### `relaxation_tasks`

이완/명상 실행 세션을 저장한다.

```text
_id: ObjectId              # 응답에서는 relax_id로 직렬화
user_id
task_id, week_number?
is_first_completed: bool | null
start_time, end_time?
logs: [{action, timestamp, elapsed_seconds}]
duration_seconds           # logs를 이용한 순 실행 시간
latitude?, longitude?, address_name?
created_at, updated_at
```

인덱스:

- `(user_id, start_time)`
- `(user_id, end_time)`

### `edu_sessions`

주차별 교육 진행과 결과를 저장한다. 같은 주차에 여러 session을 허용한다.

공통 필드:

```text
user_id, session_id
week_number: 1..8
diary_id?
total_stages, last_stage_idx, completed
is_first_completed?
start_time, end_time?
created_at, updated_at
```

주차별 선택 필드:

- 3/5주: `negative_items`, `positive_items`, `classification_quiz`
- 7주: `behavior_items[]`와 실행/비실행 분석
- 8주: `effectiveness_evaluations[]`, `user_journey_responses[]`

인덱스:

- `(user_id, week_number, start_time desc)`
- `(user_id, created_at)`

### `treatment_progress`

사용자별 주차 진행 상태를 하나의 document로 관리한다.

```text
progress_id, user_id, week_number
started_at, ends_at
edu_session_id?
relaxation_task_id?
main_completed, main_completed_at?
daily_relax_count, daily_diary_count
requirements_met
completed_at?
created_at, updated_at
```

가입 시 1주차 document와 기본 tag/group이 자동 생성된다. 교육·이완·today-task
일기 완료 시 router가 이 컬렉션을 동기화하고 다음 주차 생성/완료 조건을 계산한다.

인덱스: `(user_id, week_number)` unique.

### `counseling_sessions`

상담 transcript나 prompt를 저장하지 않고, 다음 세션에 필요한 구조화 요약만 저장한다.

```text
user_id, session_id, week
completion_status: completed | interrupted
final_state?, safety_level?
main_concern?, core_thought?, core_thought_source?
alternative_thought?, affect?
sud_start?, sud_end?
intervention_used?, activity_recommended?, unfinished_issue?
intervention_outcome?: credited | acknowledged   # 기법 답이 성과로 인정됐는지
provenance_ids[], turn_count
started_at, ended_at, created_at, updated_at
```

`PUT /counseling-sessions/{session_id}`는 같은 사용자와 session ID를 upsert한다. 이미
`completed`인 문서는 뒤늦은 `interrupted` snapshot으로 내리지 않는다.
`GET /counseling-sessions`는 최신 종료 시각 순이며 status filter와 limit(최대 20)을 지원한다.
앱은 시작할 때 최근 10건을 읽어 개인화에 쓴다.

응답은 router의 `_serialize`가 필드를 하나씩 나열해 만든다. 스키마에 필드를 추가하면
`_serialize`에도 넣어야 한다. 빠지면 저장은 되지만 조회 응답에서 null로 나온다.

인덱스:

- `(user_id, session_id)` unique
- `(user_id, ended_at desc)`

민감한 `core_thought`와 `alternative_thought`를 포함하므로 일기 데이터와 같은 수준의
접근 통제·보존·삭제 정책이 필요하다.

### `screen_time`

```text
_id: ObjectId              # 응답에서는 screen_id
user_id
start_time, end_time
duration_seconds
platform: android | ios | web | desktop | null
created_at
```

세션 저장 시 `users.last_active_at`도 갱신한다.

인덱스:

- `(user_id, start_time, end_time)`
- `(user_id, end_time desc)`

### `notification_settings`

사용자 한 명의 알림 전체를 PUT으로 replace한다. document 하나는 alarm 하나다.

```text
user_id, alarm_id
label, enabled, vibration
schedule: {hour, minute, weekdays[], timezone}
location?: {latitude, longitude, location?, address?, radius_meters}
created_at, updated_at
```

startup에서 구버전 `alarm_settings` 컬렉션만 있고 새 컬렉션이 없으면
`notification_settings`로 rename한다.

인덱스:

- `(user_id, alarm_id)` unique
- `(user_id, schedule.hour, schedule.minute, alarm_id)`

## 5. 데이터 일관성과 시간 정책

- 거의 모든 시간은 UTC-aware `datetime`으로 정규화해 저장한다.
- today/week 집계는 KST 날짜 경계를 만든 뒤 UTC 범위로 변환해 조회한다.
- DB foreign key/transaction보다 router의 application-level 동기화에 의존한다.
- `diaries.latest_sud`, `worry_groups.diary_count/sud_sum`,
  `treatment_progress`는 다른 데이터에서 파생되는 denormalized state다.
- 잘못된 중간 상태 복구를 위해 treatment progress의 `repair` endpoint가 있다.
- Mongo `_id`는 대부분 API에 직접 노출하지 않고 domain id로 직렬화한다.

## 6. 로컬 저장소와 서버 DB의 경계

서버의 source of truth가 아닌 기기 로컬 데이터도 있다.

| 저장소 | 내용 |
|---|---|
| FlutterSecureStorage | JWT, 사용자/환자 ID, email, 로그인 flag |
| SharedPreferences | 오늘 할 일 draft UI 상태, 교육 로컬 진행, 알림 scheduling 상태, widget/tutorial 상태 등 |

상담 `CounselingSessionState`와 원문 메시지는 메모리에만 둔다. Mongo의
`counseling_sessions`에는 다음 세션 개인화를 위한 구조화 요약만 저장하며 transcript,
prompt, 모델 raw output은 보내지 않는다.

운영 상태 주의: 2026-09-05 기준 운영 서버(`115.145.134.180:8070`)에는 상담 API가
배포되지 않았었다(`/counseling-sessions` 404). 이후 상담 개발과 확인은 로컬 백엔드와 로컬
MongoDB(`mindrium_dogfood`)로 했다. 운영 배포 뒤 실계정으로 upsert/list와 completed 보호 규칙을
다시 확인해야 한다.

## 7. Schema와 migration 방식

전통적인 SQL migration framework는 없다.

- Pydantic schema가 API 입출력 계약을 정의한다.
- 실제 Mongo document shape는 router의 insert/update 코드가 정의한다.
- 앱 startup의 lifespan에서 인덱스를 idempotent하게 생성한다.
- 컬렉션 rename 같은 작은 호환 migration도 startup에서 수행한다.
- `backend/scripts/migrate_security_fields.py`는 기존 user의 보안 필드 보정용
  별도 스크립트다.

MongoDB는 schema-less이므로 Pydantic model만 보고 DB의 모든 legacy field가
없다고 단정하면 안 된다. 문서 변경 시 request/response schema, serializer,
router update, 인덱스, Flutter parser를 함께 갱신해야 한다.

## 8. 현재 구현상 주의점

1. `main.py`의 CORS middleware는 `CORS_ORIGINS` 설정값을 사용하지 않고 실제로
   `allow_origins=["*"]`를 적용한다. Bearer 방식이라 credentials는 false지만 운영
   origin 제한이 필요하면 코드 수정이 필요하다.
2. JWT secret에 개발용 기본값이 있으므로 운영 환경에서는 반드시 override해야 한다.
3. `MONGO_URI`가 비어 있어도 settings 생성은 되므로 startup 전 환경 검증이 약하다.
4. 가입은 외부 플랫폼 write 후 Mongo sync 순서다. 두 번째 단계가 실패하면 양 시스템
   상태가 어긋날 수 있고, 코드도 이 경우 운영 데이터 정합성 확인을 요구한다.
5. 명시적 Mongo transaction은 없다. diary/group metric과 progress sync 같은 다중
   document 갱신은 중간 실패 가능성을 고려해야 한다.
6. `user_id`, Mongo `_id`, `patient_id`를 혼용하면 권한/조회 오류가 생길 수 있다.
7. embedded log/SUD 배열은 사용자별 데이터가 커질수록 document 크기와 update 비용을
   감시해야 한다.
8. API wrapper 생성이 화면별로 분산돼 있어 base URL, retry, mock 주입의 일관된 테스트가
   어려울 수 있다.
9. `OPENAI_API_KEY`가 없으면 `/counseling/respond`와 `/counseling/realize`는 실패한다. 앱은 이 경우 결정론 경로(A)와 결정론 문장으로
   대체하므로 오류가 화면에 드러나지 않는다.
10. 리포지토리에 `.env.example`이 없다. 필요한 변수는 위 표와 `docs/chatbot_HANDOVER.md` 2.2절을 따른다.

## 9. 변경 시 확인 목록

```text
[ ] Pydantic request/response schema
[ ] Mongo insert/update/serializer
[ ] user_id 소유권 조건
[ ] 필요한 compound/unique index
[ ] UTC 저장 및 KST 집계 경계
[ ] Flutter API wrapper와 JSON key
[ ] denormalized field 동기화
[ ] legacy document의 optional/default 처리
[ ] API 및 Flutter 회귀 테스트
[ ] 운영 환경 변수와 secret
```

## 10. 주요 코드 위치

- Backend entry/index: `backend/app/main.py`
- Mongo connection: `backend/app/db/mongo.py`
- 환경 설정: `backend/app/core/config.py`
- JWT/password: `backend/app/core/security.py`
- API router: `backend/app/routers/`
- Pydantic schema: `backend/app/schemas/`
- Flutter HTTP client: `lib/data/api/api_client.dart`
- Flutter endpoint wrappers: `lib/data/api/`
- token/session storage: `lib/data/storage/`
- 상담 harness/orchestration: `lib/features/counseling/`
- 상담 주 경로(B): `backend/app/routers/counseling_respond.py`, `schemas/counseling_respond.py`
- 대체 경로(A) 문장 표현: `backend/app/routers/counseling_realize.py`
- 데모 계정 시드: `backend/scripts/seed_demo_account.py`
