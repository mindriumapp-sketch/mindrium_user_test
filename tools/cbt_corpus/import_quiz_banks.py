#!/usr/bin/env python3
"""3주차 생각 분류 / 5주차 행동 분류 퀴즈 문항을 canonical example_bank 로 추출한다.

두 화면 모두 `quizSentences` 라는 Dart 리스트에 {text, type, wrongReason} 형태로
임상 검수된 예시를 갖고 있다. 손으로 옮기면 오탈자 위험이 있으므로 직접 파싱한다.
출력은 stdout(JSON) 이며, build_corpus.py 가 curated 파일과 합쳐 최종 자산을 만든다.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# (dart 경로, week, bank id, 제목, tags, type 라벨 매핑)
BANKS = [
    (
        "lib/features/3rd_treatment/week3_classification_screen.dart",
        3,
        "week3_thought_examples",
        "불안을 키우는 생각과 도움이 되는 생각 예시",
        ["thought", "cognitive_restructuring", "alternative_thought", "example"],
        {"anxious": "anxious_thought", "healthy": "helpful_thought"},
    ),
    (
        "lib/features/5th_treatment/week5_classification_screen.dart",
        5,
        "week5_behavior_examples",
        "불안 회피 행동과 직면 행동 예시",
        ["behavior", "avoidance", "confrontation", "example"],
        {"anxious": "avoidance_behavior", "healthy": "confrontation_behavior"},
    ),
]

BLOCK = re.compile(r"quizSentences\s*=\s*\[(.*?)\n  \];", re.S)
ENTRY = re.compile(
    r"\{\s*'text':\s*(?P<text>'(?:[^'\\]|\\.)*')\s*,\s*"
    r"'type':\s*'(?P<type>\w+)'\s*,\s*"
    r"'wrongReason':\s*(?P<reason>'(?:[^'\\]|\\.)*')\s*,?\s*\}",
    re.S,
)


def unquote(literal: str) -> str:
    """Dart 작은따옴표 문자열 리터럴을 실제 문자열로 되돌린다."""
    body = literal[1:-1]
    return body.replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")


def extract(path: Path, label_map: dict[str, str]) -> list[dict]:
    src = path.read_text(encoding="utf-8")
    block = BLOCK.search(src)
    if not block:
        raise SystemExit(f"quizSentences 블록을 찾지 못했습니다: {path}")

    examples = []
    for m in ENTRY.finditer(block.group(1)):
        kind = m.group("type")
        if kind not in label_map:
            raise SystemExit(f"알 수 없는 type '{kind}': {path}")
        examples.append({
            # 화면 줄바꿈은 레이아웃용이므로 지식 코퍼스에서는 공백으로 정규화한다.
            "text": re.sub(r"\s*\n\s*", " ", unquote(m.group("text"))).strip(),
            "label": label_map[kind],
            "rationale": unquote(m.group("reason")).strip(),
        })
    if not examples:
        raise SystemExit(f"문항을 하나도 파싱하지 못했습니다: {path}")
    return examples


def main() -> int:
    items = []
    for rel, week, bank_id, title, tags, label_map in BANKS:
        path = ROOT / rel
        examples = extract(path, label_map)
        items.append({
            "id": bank_id,
            "week": week,
            "type": "example_bank",
            "title": title,
            "paragraphs": [
                f"{title}입니다. 아래 예시는 Mindrium {week}주차 분류 연습에서 사용하는 "
                "임상 검수된 문항이며, 상담 중 예시를 들 때는 이 목록 안에서만 인용합니다."
            ],
            "tags": tags,
            "source": rel,
            "examples": examples,
        })
        print(f"{rel}: {len(examples)} examples", file=sys.stderr)

    json.dump(items, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
