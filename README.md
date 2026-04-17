# Mindrium

> 불안을 이해하고, 기록하고, 완화하는 8주형 CBT 기반 모바일 앱

Mindrium은 불안장애 치료와 자기관리를 지원하기 위해 개발 중인 Flutter 기반 모바일 애플리케이션입니다. 사용자는 주차별 심리 교육, 걱정 일기, 이완 훈련, 시간/위치 기반 알림, 리포트를 통해 자신의 불안 패턴을 관찰하고 꾸준한 연습 루틴을 만들어갈 수 있습니다.

이 저장소는 모바일 앱 프론트엔드와 연동용 백엔드를 함께 포함하고 있으며, 현재 Android/iOS 중심으로 개발이 진행되고 있습니다.

## 핵심 기능

| 영역 | 설명 |
| --- | --- |
| 8주 프로그램 | `Week1`부터 `Week8`까지 이어지는 치료 플로우와 진행도 기반 잠금/해제 구조를 제공합니다. |
| 불안 교육 | 불안의 개념, 원리, 동반 문제, 치료 방법, 자기 이해 방법 등을 카드형 교육 콘텐츠로 학습할 수 있습니다. |
| 걱정 일기와 ABC 기록 | 촉발 사건, 생각, 감정, 신체 반응, 행동을 칩 기반 UI로 기록하고 구조화할 수 있습니다. |
| 이완 훈련 | MP3 오디오와 Rive 애니메이션을 활용한 주차별 이완 세션을 제공합니다. |
| 불안 완화 알림 | 시간, 요일, 위치를 조합한 알림을 설정해 불안을 자주 느끼는 상황에 맞춰 개입할 수 있습니다. |
| 홈 위젯 | 2주차 이후 홈 화면 위젯에서 진행 현황을 확인하고 `Relief` 활동으로 빠르게 진입할 수 있습니다. |
| 보관함과 시각화 | 걱정 그룹, 캐릭터, 수족관 스타일 아카이브를 통해 완료한 기록을 시각적으로 확인할 수 있습니다. |
| 리포트와 마이페이지 | 일기/교육/이완 완료율, 주간 SUD 추이, 스크린타임 요약, 계정 정보를 확인할 수 있습니다. |

## 사용자 흐름

1. 온보딩: 스플래시, 약관 동의, 회원가입/로그인, 튜토리얼, 사전 설문
2. 치료 진입: 현재 주차에 맞는 CBT 학습과 실습 진행
3. 일상 기록: 걱정 일기 작성, 위치/시간 맥락 저장, 그룹화 및 회고
4. 개입과 유지: 이완 훈련, 불안 완화 알림, 홈 위젯, 리포트 확인

## 기술 스택

- App: Flutter, Dart
- State Management: `provider`, `flutter_riverpod`
- Networking/Auth: `dio`, `flutter_secure_storage`, `shared_preferences`
- UI/Interaction: `rive`, `lottie`, `fl_chart`, `table_calendar`, `google_fonts`
- Media: `audioplayers`, `image_picker`
- Location/Alarm: `flutter_map`, `latlong2`, `geolocator`, `geocoding`, `geofence_service`, `flutter_local_notifications`
- Voice/Web: `flutter_tts`, `speech_to_text`, `webview_flutter`
- Backend: FastAPI (`backend/app`), Render 배포 설정(`render.yaml`)

## 프로젝트 구조

```text
.
├── lib/
│   ├── app.dart                  # 앱 셸, 테마, 라우트
│   ├── features/                 # 인증, 알림, 위클리 치료 플로우, 메뉴 기능
│   ├── navigation/               # 하단 네비게이션과 홈 화면
│   ├── data/                     # API, 모델, Provider, 저장소
│   ├── widgets/                  # 공통 UI 컴포넌트
│   └── contents/                 # 공통 플로우 화면
├── assets/
│   ├── education_data/           # 교육 콘텐츠 JSON
│   ├── image/                    # 앱 이미지 및 일러스트
│   └── relaxation/               # 이완 훈련 MP3/Rive 리소스
├── backend/app/                  # FastAPI 백엔드
├── docs/                         # 웹 배포 산출물/문서용 정적 파일
└── tool/                         # 로컬 설정 보조 스크립트
```