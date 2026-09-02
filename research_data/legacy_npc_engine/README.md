# Legacy NPC Engine (컴파일 경로 밖)

2C 에서 `ChatPage` 의 상담 엔진을 `CounselingProvider` → `CounselingHarness` 로 교체하면서
`lib/chatbot/services/` 에서 옮겨온 파일들. **`lib/` 밖이라 빌드에 포함되지 않고,
런타임 call graph 에서도 완전히 끊겨 있다.**

삭제하지 않고 남긴 이유는 2B(AffectiveAdapter)와 이후 ConversationMemory 에서
참고할 계약이 남아 있기 때문이다.

| 파일 | 처분 | 비고 |
|---|---|---|
| `gpt_api.dart` | 폐기 | 백엔드에 없는 `/ai/chat`, `/ai/embedding` 호출. 온디바이스 방향과 충돌 |
| `rag_service.dart` | 폐기 | 중독 상담 코퍼스 검색. `LocalCbtKnowledgeRepository` 로 대체됨 |
| `orchestrator.dart` | 폐기 | 역할이 `CounselingHarness` 로 옮겨감 |
| `agents.dart` | 2B 에서 폐기 | summarizer 스키마는 `docs/counseling/session_summary_schema.md` 로 옮겼다 |
| `daily_context.dart` | 2B 에서 폐기 | 주차별 컨텍스트 의도는 `docs/counseling/context_feature_gap.md` 에 대조 결과로 남겼다 |
| `data_repo.dart` | 폐기 | `dummy.json` 로더. 실제 사용자 데이터는 `MindriumContextBuilder` 가 API 로 가져온다 |

## 옮기지 않고 `lib/chatbot/` 에 남긴 것

- `chatbot_main.dart` — 화면. UI/STT/TTS/스크롤/아바타만 담당하도록 정리됨
- `ui/chat_bubble.dart` — 말풍선. 그대로 재사용
- `services/speech_output_service.dart` — 2C 에서 새로 추출한 TTS 추상화
- `utils/file_stub.dart` — 웹 stub

## 4개 agent 는 어디로 갔나

| 기존 | 지금 |
|---|---|
| Counselor Agent | `LlmService` (유일하게 생성 모델을 쓰는 지점) |
| Cognitive Evaluator Agent | `CounselingStatePolicy` + `CbtKnowledgeRepository` + harness 의 출력 검증 |
| Summarization Agent | 미구현. `docs/counseling/session_summary_schema.md` 계약대로 ConversationMemory 로 예정 |
| Affective Adapter Agent | `lib/chatbot/affective/` (AffectSignalDetector → AffectiveAdapter → AvatarAssetResolver) |

한 턴에 LLM 을 4번 호출하던 구조가 **1번 호출 + deterministic 모듈**로 바뀌었다.
