from typing import Any, Dict, Optional

TODAY_TASK_ROUTE = "today_task"
COMPLETED_DRAFT_PROGRESS = 80
LEGACY_COMPLETED_DRAFT_PROGRESS = 100
COMPLETED_DRAFT_PROGRESS_VALUES = (
    COMPLETED_DRAFT_PROGRESS,
    LEGACY_COMPLETED_DRAFT_PROGRESS,
)


def completed_draft_progress_filter() -> Dict[str, Any]:
    return {"$in": list(COMPLETED_DRAFT_PROGRESS_VALUES)}


def is_completed_draft_progress(progress: Optional[int]) -> bool:
    return progress in COMPLETED_DRAFT_PROGRESS_VALUES


def is_incomplete_draft_progress(progress: Optional[int]) -> bool:
    return progress is not None and not is_completed_draft_progress(progress)
