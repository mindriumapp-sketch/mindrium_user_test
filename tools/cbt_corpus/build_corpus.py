#!/usr/bin/env python3
"""Mindrium 상담 harness 용 canonical CBT knowledge corpus 를 빌드한다.

입력
  1. assets/education_data/*.json           (1주차 교육 슬라이드 + 이완 안내)
  2. lib/features/**/week{3,5}_classification_screen.dart  (분류 연습 문항 뱅크)
  3. assets/relaxation/cue_sheets/*.json    (주차별 이완 낭독 원고)
  4. tools/cbt_corpus/curated/*.json        (Dart 화면 코드에서 사람이 정리한 항목)

출력
  assets/counseling/knowledge/week{0..8}.json
  assets/counseling/knowledge/manifest.json

week0 은 특정 주차에 속하지 않는 프로그램 공통 지식(SUD, 이완 사용 시점 등)이다.
빌드는 idempotent 하며, 출력 파일을 직접 손으로 고치지 말고 입력을 고친 뒤 다시 실행한다.
"""

from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_education_data  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CURATED = Path(__file__).resolve().parent / "curated"
OUT = ROOT / "assets" / "counseling" / "knowledge"

SCHEMA_VERSION = 1

ITEM_TYPES = {"education", "technique", "example_bank", "assessment"}

# 통제된 태그 어휘. 키워드 검색이 태그에 의존하므로 자유 입력을 허용하지 않는다.
TAG_VOCABULARY = {
    "abc_model", "alternative_thought", "anxiety", "assessment", "avoidance",
    "behavior", "belief_rating", "body", "cbt", "cognitive_restructuring",
    "comorbidity", "confrontation", "diary", "example", "exposure", "gad7",
    "goal_setting", "habit", "maintenance", "mechanism", "planning", "program",
    "psychoeducation", "relapse_prevention", "relaxation", "self_monitoring",
    "sud", "technique", "thought", "treatment", "values", "worry_group",
    "cue_controlled",
}

REQUIRED = ("id", "week", "type", "title", "paragraphs", "tags", "source")


def run_importer(script_name: str) -> list[dict]:
    """stdout 으로 canonical item 배열을 내보내는 보조 임포터를 실행한다."""
    script = Path(__file__).resolve().parent / script_name
    proc = subprocess.run(
        [sys.executable, str(script)], capture_output=True, text=True, check=False
    )
    if proc.returncode != 0:
        raise SystemExit(f"{script_name} 실패:\n{proc.stderr}")
    return json.loads(proc.stdout)


def load_curated() -> list[dict]:
    items: list[dict] = []
    for path in sorted(CURATED.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        items.extend(payload["items"])
    return items


def validate(items: list[dict]) -> None:
    seen: dict[str, str] = {}
    for item in items:
        ident = item.get("id", "<id 없음>")

        missing = [f for f in REQUIRED if f not in item]
        if missing:
            raise SystemExit(f"[{ident}] 필수 필드 누락: {missing}")
        if ident in seen:
            raise SystemExit(f"[{ident}] id 중복")
        seen[ident] = item["source"]

        if item["type"] not in ITEM_TYPES:
            raise SystemExit(f"[{ident}] 알 수 없는 type: {item['type']}")
        if not isinstance(item["week"], int) or not 0 <= item["week"] <= 8:
            raise SystemExit(f"[{ident}] week 는 0~8 정수여야 합니다: {item['week']!r}")
        if not item["paragraphs"] or not all(
            isinstance(p, str) and p.strip() for p in item["paragraphs"]
        ):
            raise SystemExit(f"[{ident}] paragraphs 가 비었거나 빈 문자열을 포함합니다")

        unknown = sorted(set(item["tags"]) - TAG_VOCABULARY)
        if unknown:
            raise SystemExit(f"[{ident}] 어휘에 없는 태그: {unknown}")
        if not item["tags"]:
            raise SystemExit(f"[{ident}] 태그가 최소 1개 필요합니다")

        # week0(공통) 항목을 제외하면 id 는 주차 접두사를 지켜야 추적이 쉽다.
        expected_prefix = "common_" if item["week"] == 0 else f"week{item['week']}_"
        if not ident.startswith(expected_prefix):
            raise SystemExit(f"[{ident}] id 접두사가 '{expected_prefix}' 이어야 합니다")

        guidance = item.get("conversational_guidance_available", True)
        if not isinstance(guidance, bool):
            raise SystemExit(f"[{ident}] conversational_guidance_available 는 bool 이어야 합니다")

        if item["type"] == "example_bank" and not item.get("examples"):
            raise SystemExit(f"[{ident}] example_bank 인데 examples 가 없습니다")
        for ex in item.get("examples", []):
            if not all(k in ex for k in ("text", "label", "rationale")):
                raise SystemExit(f"[{ident}] example 은 text/label/rationale 이 필요합니다")

        source = (ROOT / item["source"].split("#")[0])
        if not source.exists():
            raise SystemExit(f"[{ident}] source 파일이 없습니다: {item['source']}")


def main() -> int:
    items: list[dict] = []
    for week_items in import_education_data.collect().values():
        items.extend(week_items)
    items.extend(run_importer("import_quiz_banks.py"))
    items.extend(run_importer("import_relaxation_scripts.py"))
    items.extend(load_curated())

    validate(items)

    by_week: dict[int, list[dict]] = defaultdict(list)
    for item in items:
        by_week[item["week"]].append(item)

    OUT.mkdir(parents=True, exist_ok=True)
    for stale in OUT.glob("*.json"):
        stale.unlink()

    files = []
    for week in sorted(by_week):
        week_items = sorted(by_week[week], key=lambda it: it["id"])
        name = f"week{week}.json"
        (OUT / name).write_text(
            json.dumps(
                {"schema_version": SCHEMA_VERSION, "week": week, "items": week_items},
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        files.append({"week": week, "file": name, "item_count": len(week_items)})
        print(f"week{week}: {len(week_items)} items")

    (OUT / "manifest.json").write_text(
        json.dumps(
            {
                "schema_version": SCHEMA_VERSION,
                "generated_by": "tools/cbt_corpus/build_corpus.py",
                "item_types": sorted(ITEM_TYPES),
                "tag_vocabulary": sorted(TAG_VOCABULARY),
                "files": files,
                "total_items": len(items),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"total: {len(items)} items → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
