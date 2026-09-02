#!/usr/bin/env python3
"""Step 0 보조 도구: 주차별 화면 Dart 코드에서 한글 문자열 리터럴을 추출한다.

이 스크립트의 출력은 *canonical corpus 가 아니라 후보(candidate)* 다.
사람이 검수해서 assets/counseling/knowledge/*.json 으로 옮기는 것을 전제로 한다.
UI 라벨/버튼 텍스트와 교육 본문을 길이 기준으로 대략 분리해 둔다.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

HANGUL = re.compile(r"[가-힣]")
# 'single' 또는 "double" 리터럴 (이스케이프 허용). raw/삼중따옴표는 별도 처리 없이 근사.
LITERAL = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")
# 주석 라인 (// 로 시작) 제외
COMMENT = re.compile(r"^\s*//")

# 본문으로 볼 최소 길이. 이보다 짧으면 UI 라벨 후보로 분류.
BODY_MIN_LEN = 25


def literals_in(path: Path) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if COMMENT.match(line):
            continue
        for m in LITERAL.finditer(line):
            raw = m.group(1) if m.group(1) is not None else m.group(2)
            if raw is None or not HANGUL.search(raw):
                continue
            text = raw.replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"')
            out.append((lineno, text.strip()))
    return out


def main() -> int:
    targets: list[Path] = []
    for d in sorted((ROOT / "lib" / "features").glob("*_treatment")):
        targets += sorted(d.glob("*.dart"))
    targets += sorted((ROOT / "lib" / "contents").rglob("*.dart"))

    result: dict[str, dict] = {}
    for path in targets:
        rel = str(path.relative_to(ROOT))
        body: list[dict] = []
        labels: list[dict] = []
        seen: set[str] = set()
        for lineno, text in literals_in(path):
            if text in seen:
                continue
            seen.add(text)
            entry = {"line": lineno, "text": text}
            (body if len(text) >= BODY_MIN_LEN else labels).append(entry)
        if body or labels:
            result[rel] = {"body_candidates": body, "ui_labels": labels}

    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
