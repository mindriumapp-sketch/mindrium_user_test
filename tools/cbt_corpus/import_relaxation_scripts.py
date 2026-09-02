#!/usr/bin/env python3
"""주차별 이완 오디오의 낭독 원고를 canonical corpus 항목으로 추출한다.

assets/relaxation/cue_sheets/week{N}_cue_sheet.json 의 각 큐에는 오디오에서 실제로
읽어주는 문장이 `spoken_focus_or_old_caption` 으로 들어 있다. 이 원고가 있어야
상담 중 이완을 단계별로 안내할 수 있고, 없으면 '앱에서 실행하기'만 제안할 수 있다.

출력은 stdout(JSON) 이며 build_corpus.py 가 사용한다.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CUE_DIR = ROOT / "assets" / "relaxation" / "cue_sheets"

# 주차 → (이완 이름, 추가 태그). 이름은 lib/data/education_week_contents.dart 기준.
RELAXATION_NAMES = {
    1: ("점진적 이완", []),
    2: ("점진적 이완", []),
    3: ("이완만 하는 이완", []),
    4: ("신호 조절 이완", ["cue_controlled"]),
    5: ("차등 이완", []),
    6: ("차등 이완", []),
    7: ("신속 이완", []),
    8: ("신속 이완", []),
}


def spoken_lines(cues: list[dict]) -> list[str]:
    """낭독 문장을 순서대로 뽑되, 연속 중복(호흡 카운트 반복 등)은 접는다."""
    lines: list[str] = []
    for cue in cues:
        text = re.sub(r"\s+", " ", (cue.get("spoken_focus_or_old_caption") or "")).strip()
        if text and (not lines or lines[-1] != text):
            lines.append(text)
    return lines


def main() -> int:
    items = []
    for week, (name, extra_tags) in sorted(RELAXATION_NAMES.items()):
        path = CUE_DIR / f"week{week}_cue_sheet.json"
        if not path.exists():
            raise SystemExit(f"큐시트가 없습니다: {path}")

        cues = json.loads(path.read_text(encoding="utf-8"))
        lines = spoken_lines(cues)
        if not lines:
            raise SystemExit(f"낭독 문장을 찾지 못했습니다: {path}")

        items.append({
            "id": f"week{week}_relaxation_script",
            "week": week,
            "type": "technique",
            "title": f"{week}주차 이완 훈련 원고: {name}",
            "paragraphs": [
                f"{week}주차 이완 훈련({name})에서 오디오가 실제로 안내하는 문장입니다. "
                "상담 중 이완을 단계별로 안내할 때는 이 순서와 표현을 따릅니다.",
                *lines,
            ],
            "tags": sorted({"relaxation", "technique", "body", *extra_tags}),
            "source": str(path.relative_to(ROOT)),
            "conversational_guidance_available": True,
        })
        print(f"week{week}: {len(lines)} 문장 ({name})", file=sys.stderr)

    json.dump(items, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
