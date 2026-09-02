#!/usr/bin/env python3
"""assets/education_data/*.json → canonical CBT knowledge corpus 로 변환한다.

education_data 는 교육 슬라이드 UI 전용 포맷({title, paragraphs})이고 페이지 단위로
파일이 쪼개져 있다. 상담 harness 는 페이지가 아니라 '문서' 단위로 지식을 참조하므로
여기서 id / week / type / tags / source 를 붙인 canonical 스키마로 옮긴다.

단독 실행하면 요약을 출력하고, build_corpus.py 는 collect() 를 직접 호출한다.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "education_data"
OUT = ROOT / "assets" / "counseling" / "knowledge"

# education_data 의 part 번호 → canonical slug / type / tags
PART_META = {
    1: ("anxiety_basics", "education", ["anxiety", "psychoeducation"]),
    2: ("anxiety_mechanism", "education", ["anxiety", "mechanism", "psychoeducation"]),
    3: ("comorbidity", "education", ["comorbidity", "psychoeducation"]),
    4: ("treatment_options", "education", ["treatment", "psychoeducation"]),
    5: ("mindrium_method", "education", ["treatment", "program", "psychoeducation"]),
    6: ("self_understanding", "education", ["self_monitoring", "program"]),
}
RELAXATION_META = ("relaxation", "technique", ["relaxation", "technique", "body"])

FILENAME = re.compile(r"^week(?P<week>\d+)_(?:part(?P<part>\d+)|(?P<relax>relaxation))_(?P<page>\d+)$")


def normalise_title(title: str) -> str:
    """슬라이드 제목에 들어간 줄바꿈/중복 공백을 한 줄로 정리한다."""
    return re.sub(r"\s+", " ", title).strip()


def collect() -> dict[int, list[dict]]:
    """education_data 를 (week, slug) 단위로 모아 주차별 canonical item 리스트를 만든다."""
    buckets: dict[tuple[int, str], list[tuple[int, str, dict]]] = {}

    for path in sorted(SRC.glob("*.json")):
        m = FILENAME.match(path.stem)
        if not m:
            raise SystemExit(f"예상하지 못한 파일명: {path.name}")

        week = int(m.group("week"))
        page = int(m.group("page"))
        if m.group("relax"):
            slug, item_type, tags = RELAXATION_META
        else:
            part = int(m.group("part"))
            if part not in PART_META:
                raise SystemExit(f"PART_META 에 part{part} 정의가 없습니다: {path.name}")
            slug, item_type, tags = PART_META[part]

        docs = json.loads(path.read_text(encoding="utf-8"))
        if len(docs) != 1:
            raise SystemExit(f"파일당 문서 1개를 기대했지만 {len(docs)}개: {path.name}")
        doc = docs[0]

        rel = str(path.relative_to(ROOT))
        buckets.setdefault((week, slug), []).append((page, rel, {
            "type": item_type,
            "tags": tags,
            "title": normalise_title(doc["title"]),
            "paragraphs": doc["paragraphs"],
        }))

    out: dict[int, list[dict]] = {}
    for (week, slug), pages in sorted(buckets.items()):
        for seq, (page, rel, doc) in enumerate(sorted(pages), start=1):
            out.setdefault(week, []).append({
                "id": f"week{week}_{slug}_{seq:02d}",
                "week": week,
                "type": doc["type"],
                "title": doc["title"],
                "paragraphs": doc["paragraphs"],
                "tags": doc["tags"],
                "source": rel,
            })
    return out


def main() -> int:
    for week, items in sorted(collect().items()):
        print(f"week{week}: {len(items)} items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
