# CBT Knowledge Corpus (Step 0)

상담 harness 가 참조하는 **canonical CBT knowledge source**. 승인된 CBT 지식만 사용한다는
제약을 지키려면 모델이 참조할 수 있는 지식이 코드가 아닌 데이터로 존재해야 하므로,
`assets/education_data` 의 슬라이드 JSON 과 주차별 Dart 화면에 흩어져 있던 임상 콘텐츠를
하나의 스키마로 모았다.

## 산출물

```
assets/counseling/knowledge/
├── manifest.json      # schema_version, 타입/태그 어휘, 파일 목록
├── week0.json         # 주차에 속하지 않는 프로그램 공통 지식 (SUD, 이완 사용 시점)
└── week1.json … week8.json
```

**출력 파일은 직접 수정하지 않는다.** 입력을 고치고 `build_corpus.py` 를 다시 실행한다.

## 항목 스키마

```jsonc
{
  "id": "week4_thought_check_01",   // week0 은 common_ 접두사
  "week": 4,                        // 0~8
  "type": "education",              // education | technique | example_bank | assessment
  "title": "생각의 믿음 정도 점검하기",
  "paragraphs": ["..."],            // 최소 1개, 빈 문자열 불가
  "tags": ["thought", "cognitive_restructuring"],  // manifest 의 tag_vocabulary 안에서만
  "source": "lib/features/4th_treatment/week4_classfication_screen.dart",

  // 이 항목의 내용을 상담 중 단계별로 안내해도 되는지. 생략하면 true.
  // false 면 harness 는 "앱에서 실행해보기" 까지만 제안하고 내용을 읊지 않는다.
  "conversational_guidance_available": true,

  // example_bank 전용(필수). 라벨이 붙은 임상 예시는 문단으로 펴면 라벨이 사라지므로
  // 별도 필드로 둔다. 상담 중 예시를 인용할 때는 이 목록 안에서만 인용한다.
  "examples": [
    {"text": "...", "label": "anxious_thought", "rationale": "..."}
  ]
}
```

`source` 는 임상 검수 시 원문을 되짚기 위한 출처다. 코퍼스 항목이 앱 화면 문구와
어긋나지 않는지 확인할 때 이 경로를 본다.

## 빌드

```bash
python3 tools/cbt_corpus/build_corpus.py
```

입력 세 갈래:

| 입력 | 처리 | 담당 스크립트 |
|---|---|---|
| `assets/education_data/*.json` | 자동 변환 (1주차 교육 37p, 이완 5p ×2주차) | `import_education_data.py` |
| week3 / week5 `quizSentences` (Dart) | 자동 파싱 (라벨 예시 40문항) | `import_quiz_banks.py` |
| `assets/relaxation/cue_sheets/*.json` | 자동 파싱 (8주차 이완 낭독 원고) | `import_relaxation_scripts.py` |
| week1~8 화면의 서술형 콘텐츠 | 사람이 정리 | `curated/*.json` |

자동 파싱이 가능한 것은 자동으로 뽑는다. 40문항을 손으로 옮기면 오탈자 위험이 있고,
화면 문구가 바뀌었을 때 코퍼스가 조용히 낡아버린다.

빌드는 쓰기 전에 검증한다: 필수 필드, id 중복/접두사, week 범위, 태그 어휘,
example_bank 의 examples 유무, `source` 파일 존재.

## 보조 도구

`extract_candidates.py` 는 주차별 Dart 화면에서 한글 문자열 리터럴을 뽑아 본문 후보와
UI 라벨로 나눠 출력한다. **후보일 뿐이며 코퍼스가 아니다.** curated 항목을 새로
정리하거나 화면 문구 변경을 따라잡을 때 훑어보는 용도다.

```bash
python3 tools/cbt_corpus/extract_candidates.py | less
```

## 아직 코퍼스에 없는 것

- 2~8주차 교육 슬라이드. `assets/education_data` 에는 1주차와 1·2주차 이완 안내만 있고,
  나머지 주차의 교육 내용은 화면 흐름 자체에 녹아 있어 curated 항목으로 요약해 두었다.
  요약이 임상적으로 충분한지는 `source` 를 따라 원문과 대조하는 검수가 필요하다.

이완 원고는 8주차 전부 `assets/relaxation/cue_sheets/` 의 `spoken_focus_or_old_caption`
필드에 있어 코퍼스에 포함되어 있다. 따라서 현재 모든 항목의
`conversational_guidance_available` 은 true 다. 원고 없이 오디오만 있는 콘텐츠가
추가되면 그 항목만 false 로 두면 된다.
