"""
식별정보관리 STEP 3: 감사 로그 (audit log)

서버 파일(`logs/audit.log`)에 식별자 관련 민감 행위를 append-only로 기록.
ICH E6(R3) ALCOA+ 원칙(누가/언제/무엇을 했는지 추적)을 충족.

기록 형식: JSON Lines (jsonl) — 한 줄에 JSON 객체 1개

운영 적용 시 파일에 OS 레벨 append-only 속성 부여:
  - macOS:  chflags uappnd backend/app/logs/audit.log
  - Linux:  chattr +a backend/app/logs/audit.log
"""

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

# 로그 디렉토리: backend/app/logs/
LOG_DIR = Path(__file__).resolve().parent.parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
AUDIT_LOG_PATH = LOG_DIR / "audit.log"

_audit_logger = logging.getLogger("mindrium.audit")
_audit_logger.setLevel(logging.INFO)
_audit_logger.propagate = False  # uvicorn 등 다른 로그와 섞이지 않게 분리

if not _audit_logger.handlers:
    _handler = logging.FileHandler(AUDIT_LOG_PATH, mode="a", encoding="utf-8")
    _handler.setFormatter(logging.Formatter("%(message)s"))
    _audit_logger.addHandler(_handler)


def audit_log(action: str, **fields) -> None:
    """
    감사 이벤트 1건을 audit.log에 append.

    Parameters
    ----------
    action : str
        이벤트 종류. 예: "code_use", "login", "pii_update"
    **fields : Any
        이벤트 부가 정보. 예: user_id, patient_id, role, source 등

    Note
    ----
    PII(이메일/이름/전화/주소)는 일부러 기록하지 않음.
    식별자(user_id, patient_id) 추적이 목적이며, PII 중복 저장은
    가명화 원칙에 어긋남.
    """
    entry = {
        "at": datetime.now(timezone.utc).isoformat(),
        "action": action,
        **fields,
    }
    _audit_logger.info(json.dumps(entry, ensure_ascii=False))
