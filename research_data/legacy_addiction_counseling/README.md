# Legacy Addiction Counseling Corpus (런타임 제외)

기존 NPC 챗봇이 RAG 소스로 쓰던 데이터. **앱 번들에서 제외되어 있으며 런타임에서 읽지 않는다.**

| 파일 | 크기 | 내용 |
|---|---|---|
| `rag_singleton_with_embeddings.jsonl` | 40MB | 967행. query/response + OpenAI 임베딩 벡터 |
| `rag_singleton_dataset.jsonl` | 3.8MB | 6476행. 임베딩 없는 원본 |
| `dummy.json` | 803KB | 더미 환자 데이터. `defaultUserId = "JNSE2100"` |
| `dummy_rag.json` | 450B | 초기 실험용 |

## 왜 런타임에서 뺐는가

1. **대상 집단 불일치** — id 접두사가 `resource_addiction_*` 이다. 중독 환자 상담 기록이며
   Mindrium 의 범불안장애 CBT 프로그램과 대상이 다르다.
2. **provenance / 안전** — 내용이 CBT 지식이 아니라 상담사의 raw 발화다. 이걸 검색해 모방하면
   현재 프로그램 범위를 벗어난 개입이 나올 수 있고, 근거를 추적할 수 없다.
3. **앱 크기** — 44MB 가 그대로 번들에 실리고 있었다.

## 다시 쓰려면

임상 검수를 거쳐 범불안/CBT 목적에 맞는 subset 만 골라 `assets/counseling/examples/` 로
canonical 스키마에 맞춰 생성한다. 원본을 그대로 자산에 되돌리지 않는다.
