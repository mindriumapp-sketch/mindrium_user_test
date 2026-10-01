# 상담 챗봇 문서

**시작점: [`chatbot_system.md`](chatbot_system.md).** 디지털 CBT 상담 챗봇의 구조, 기능, 테스트 체계,
알려진 한계를 정리한 기준 문서입니다(태그 `counseling-v1.2-session-flow`).

| 문서 | 내용 |
|---|---|
| [`chatbot_system.md`](chatbot_system.md) | 전체 구조와 기능 (기준 문서) |
| [`remote_gpt_realizer_integration.md`](remote_gpt_realizer_integration.md) | 원격 GPT 표현 계층 연동 계약 |
| [`session_summary_schema.md`](session_summary_schema.md) | 세션 요약 JSON 형식 |
| [`affective_system.md`](affective_system.md) | 아바타 표정·감정 신호 체계 |

Phase 8~13의 단계별 설계, 평가, dogfood 기록은 2026-10-02 정리 때 이 폴더에서 지웠습니다. git 기록에서 볼 수
있습니다.

```bash
git log --oneline -- docs/counseling
git show counseling-v1.2-session-flow:docs/counseling/phase13_status_and_plan.md
```
