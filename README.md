# Mindrium

> 불안을 이해하고, 기록하고, 완화하는 8주형 CBT 기반 모바일 앱

Mindrium은 불안과 걱정을 다루는 사용자가 자신의 패턴을 관찰하고, 구조화된 인지행동치료(CBT) 연습을 일상에서 반복할 수 있도록 돕는 모바일 애플리케이션입니다. 앱은 8주 치료 프로그램, 걱정 일기, SUD 불안 점수 기록, 이완 훈련, 위치/시간 기반 알림, 리포트, 보관함을 하나의 흐름으로 연결합니다.

이 저장소에는 Flutter 앱과 FastAPI 백엔드가 함께 들어 있습니다. 앱은 Android와 iOS 중심으로 개발되어 있으며, Android/iOS 홈 위젯 코드와 Flutter Web 빌드 산출물도 포함되어 있습니다.

## 앱의 목적

- 사용자가 불안의 원리와 자신의 걱정 패턴을 이해하도록 돕습니다.
- 걱정이 생긴 상황, 생각, 감정, 신체 반응, 행동을 ABC 구조로 기록하게 합니다.
- 불안 강도를 SUD 점수로 기록하고, 개입 전후의 변화를 확인하게 합니다.
- 주차별 교육과 이완 훈련을 통해 CBT 기반 자기관리 루틴을 만들게 합니다.
- 반복되는 불안 상황에 시간/요일/위치 알림과 홈 위젯으로 빠르게 개입할 수 있게 합니다.

## 주요 사용자 흐름

1. 온보딩: 스플래시, 약관 동의, 회원가입/로그인, 튜토리얼, 사전 설문을 거칩니다.
2. 홈: 오늘의 과제, 불안 완화 알림, 위젯 안내, 권한 상태를 확인합니다.
3. 교육: 1주차부터 8주차까지 주차별 CBT 교육과 이완 세션을 진행합니다.
4. 일상 기록: 불안 강도 평가, ABC 일기 작성, 시간/위치 맥락 저장, 걱정 그룹화를 수행합니다.
5. 개입: 이완 훈련 또는 대안적 생각 적용으로 불안을 낮추고, 사후 SUD를 기록합니다.
6. 회고: 마인드리움 보관함, 걱정 물고기, 리포트, 마이페이지에서 기록과 진행도를 확인합니다.

## 현재 구현된 기능

| 영역 | 현재 앱 기능 |
| --- | --- |
| 인증/온보딩 | 이메일 기반 회원가입/로그인, 약관 동의, 튜토리얼, 사전 설문, 계정 관리 |
| 8주 CBT 프로그램 | 주차별 교육 화면, 교육 세션 기록, 이완 세션 기록, 현재 주차/완료 주차 표시 |
| ABC 걱정 일기 | 촉발 사건, 믿음/생각, 감정, 신체 반응, 행동을 칩 기반 UI로 작성하고 수정 |
| SUD 평가 | 개입 전후 불안 점수 기록, 일기별 최신 SUD, 주간 SUD 흐름 리포트 |
| 이완 훈련 | 주차별 MP3/Rive 또는 cue sheet 기반 이완 플레이어, 복습용 이완 플레이어 |
| 불안 완화 알림 | 시간, 요일, 위치를 조합한 알림 생성/수정/삭제, 로컬 알림과 서버 동기화 |
| 위치 기록 | 지도 기반 위치 선택, Kakao 지도 WebView 렌더러, Kakao Local API 기반 주소 검색/역지오코딩 |
| 홈 위젯 | Android/iOS 위젯에서 완료 주차, 일기 수, 이완 횟수를 표시하고 Relief 진입 지원 |
| 마인드리움 보관함 | 걱정 그룹을 캐릭터/수족관 형태로 시각화하고, 보관된 걱정 그룹을 조회 |
| 리포트 | 일기, 교육, 이완 활동을 날짜/주 단위로 모아 보고 완료율과 SUD 추이를 확인 |
| 스크린타임 기록 | 앱 포그라운드 사용 세션을 자동 기록하고 서버에 전송하는 기반 기능 |

## 8주 프로그램 구성

| 주차 | 교육 세션 | 이완 세션 | 핵심 목표 |
| --- | --- | --- | --- |
| 1주차 | 불안에 대한 이해 | 점진적 이완 | 불안의 원리를 이해하고 몸을 천천히 편안하게 만드는 연습 시작 |
| 2주차 | ABC 일기 | 점진적 이완 | 상황-생각-감정 기록과 이완 복습 |
| 3주차 | 생각 구분 연습 | 이완만 하는 이완 | 불안을 키우는 생각과 도움이 되는 생각 구분 |
| 4주차 | 내 생각 점검하기 | 신호 조절 이완 | 생각을 유연하게 바꾸고 신호에 맞춰 이완 |
| 5주차 | 행동 선택 연습 | 차등 이완 | 회피하지 않는 행동 선택과 움직임 속 이완 |
| 6주차 | 내 행동 돌아보기 | 차등 이완 | 행동 패턴 회고와 이완 복습 |
| 7주차 | 내 행동 개선하기 | 신속 이완 | 불안한 순간의 행동 조정과 빠른 이완 |
| 8주차 | 여정 돌아보기 | 신속 이완 | 8주 여정 정리와 유지 계획 수립 |

현재 빌드에서는 총괄평가/테스트 편의를 위해 1~8주차 카드가 모두 열려 있습니다. 서버의 `currentWeek`, `lastCompletedWeek`, 교육/이완 완료 상태는 화면 표시와 복습 모드 판단에 사용되지만, 미래 주차 접근 자체는 `TreatmentScreen`에서 임시로 열어 둔 상태입니다.

## 화면 구조

하단 탭은 다음 5개 영역으로 구성됩니다.

| 탭 | 역할 |
| --- | --- |
| 홈 | 오늘의 과제, 불안 완화 진입, 알림/권한/위젯 관련 안내 |
| 교육 | 8주 프로그램과 주차별 교육/이완 세션 |
| 마인드리움 | 걱정 그룹을 수족관 형태로 보여주는 보관함 |
| 리포트 | 일기, 교육, 이완 활동과 SUD 변화 확인 |
| 마이페이지 | 사용자 정보, 치료 진행도, 설정/계정 관리 진입 |

## 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| App | Flutter, Dart, Material 3 |
| 상태 관리 | `provider` |
| 네트워크/인증 | `dio`, `flutter_secure_storage`, `shared_preferences`, JWT access/refresh token |
| UI/미디어 | `rive`, `audioplayers`, 자체 위젯 컴포넌트, NotoSansKR 폰트 자산 |
| 위치/지도 | `flutter_map`, `latlong2`, `geolocator`, `geocoding`, `webview_flutter`, Kakao Local API |
| 알림/권한 | `flutter_local_notifications`, `timezone`, `permission_handler`, `geofence_service` |
| 음성/사용 추적 | `speech_to_text`, `wakelock_plus`, 앱 라이프사이클 기반 스크린타임 기록 |
| 백엔드 | FastAPI, MongoDB/Motor, JWT 인증, Render 배포 설정 |

## 백엔드와 데이터

백엔드는 `backend/app` 아래의 FastAPI 앱입니다. 앱 시작 시 MongoDB 인덱스를 확인하고, 다음 도메인의 API 라우터를 등록합니다.

- 인증/토큰: `auth`
- 사용자/설문/계정: `users`, `user_data`
- 일기와 위치/시간 맥락: `diaries`
- SUD 점수: `sud_scores`
- 교육 세션: `edu_sessions`
- 이완 세션: `relaxation_tasks`
- 치료 진행도: `treatment_progress`
- 사용자 정의 칩/로그: `custom_tags`
- 걱정 그룹/아카이브: `worry_groups`
- 알림 설정: `alarm_settings`
- 스크린타임: `screen_time`

Flutter 앱의 API 기본 주소는 `lib/data/api/api_client.dart`에서 결정됩니다. `API_BASE_URL` dart define이 있으면 그 값을 우선 사용하고, 없으면 디버그 Android 빌드에서 `http://115.145.134.180:8070`, 그 외 비웹 디버그 환경에서 `http://127.0.0.1:8080`, 웹에서 Render URL을 사용합니다. 릴리즈 빌드에서는 `API_BASE_URL`을 명시해야 합니다.

## 프로젝트 구조

```text
.
├── lib/
│   ├── app.dart                  # 앱 셸, 테마, 라우트
│   ├── main.dart                 # Provider와 ScreenTimeAutoTracker 초기화
│   ├── common/                   # 앱 환경값, 상수, Kakao 런타임 설정
│   ├── contents/                 # SUD, 이완/대안생각 선택 등 공통 플로우
│   ├── data/                     # API 클라이언트, 모델, Provider, 로컬 저장소
│   ├── features/                 # 인증, 알림, 1~8주 치료, 메뉴/보관함/설정
│   ├── navigation/               # 하단 네비게이션, 홈/교육/리포트/마이페이지
│   ├── utils/                    # 날짜, 텍스트 라인 처리 등 유틸
│   └── widgets/                  # 공통 UI 컴포넌트와 지도/일기/교육 UI
├── assets/
│   ├── education_data/           # 교육 콘텐츠 JSON
│   ├── image/                    # 앱 이미지, 캐릭터, 위젯 튜토리얼, 보관함 배경
│   └── relaxation/               # 이완 훈련 MP3/Rive/cue sheet 리소스
├── android/                      # Android 앱, 권한, 네이티브 홈 위젯
├── ios/                          # iOS 앱과 MindriumWidgetExtension
├── backend/app/                  # FastAPI 백엔드
├── dart_defines/                 # API/Kakao 키 예시 및 로컬 define 파일
├── docs/                         # Flutter Web 빌드 산출물
└── tool/                         # 로컬 설정 보조 스크립트
```

## 로컬 실행

### Flutter 앱

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines/api.example.json
```

Kakao 지도/주소 기능을 확인하려면 Kakao 관련 define도 함께 제공해야 합니다.

```bash
flutter run \
  --dart-define-from-file=dart_defines/api.example.json \
  --dart-define-from-file=dart_defines/kakao.api.json
```

### Android 릴리즈 빌드

```bash
flutter build appbundle --release \
  --dart-define-from-file=dart_defines/api.example.json \
  --dart-define-from-file=dart_defines/kakao.api.json
```

Android 릴리즈 빌드는 `android/key.properties`의 release keystore 설정으로 서명됩니다. Play Console 내부/비공개 테스트 업로드에는 `build/app/outputs/bundle/release/app-release.aab` 산출물을 사용합니다.

### 백엔드

```bash
cd backend/app
cp .env.example .env
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

필수 환경 변수는 `MONGO_URI`, `JWT_SECRET`, `JWT_REFRESH_SECRET`입니다. 백엔드 실행 후 Swagger 문서는 `http://localhost:8080/docs`, 상태 확인은 `http://localhost:8080/health`에서 확인할 수 있습니다.

## 개발 상태 메모

- 8주 프로그램 카드는 현재 테스트/평가용으로 모두 열려 있습니다.
- Week 2 Relief, Week 4 대안적 생각, Week 6 해결 흐름의 일부 잠금은 `bool.fromEnvironment` 플래그로 제어되며 기본값은 잠금 비활성화입니다.
- 스크린타임은 앱 라이프사이클 기반으로 서버에 기록하는 기능이 구현되어 있지만, 사용자에게 풍부한 분석 UI로 보여주는 단계는 제한적입니다.
- `pubspec.yaml`에 주석 처리된 패키지는 현재 사용 중인 기술 스택에서 제외했습니다.
