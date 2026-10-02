"""Phase 14.X: respond contract — per-request id enums, strict output."""
import json

import pytest
from routers.counseling_respond import RespondRejected, parse_output, response_format
from schemas.counseling_respond import CounselingRespondRequest

REQ = CounselingRespondRequest.model_validate({
    "request_id": "t", "current_week": 4,
    "conversation": [{"role": "user", "text": "발표가 걱정돼"}],
    "progress": {"stage": "reflect"},
    "user_facts": [{"id": "session:s1", "kind": "past_episode", "text": "x"}],
    "techniques": [{"id": "week4_alternative_thought_01", "name": "균형", "week": 4, "purpose": "p"}],
    "app_facts": [],
})
OK = {
    "domain": "counseling", "dialogue_moves": ["acknowledge", "ask_evidence"],
    "intervention_id": None, "intervention_step": None,
    "used_user_fact_ids": [], "used_app_fact_ids": [],
    "session_action": "continue", "response_text": "그 생각의 근거가 있을까요?",
}


def test_ids_are_enums_per_request():
    schema = response_format(REQ)["json_schema"]["schema"]["properties"]
    assert schema["intervention_id"]["enum"] == ["week4_alternative_thought_01", None]
    assert schema["used_user_fact_ids"]["items"]["enum"] == ["session:s1"]
    assert schema["used_app_fact_ids"]["maxItems"] == 0


def test_no_techniques_means_null_only():
    req = REQ.model_copy(update={"techniques": []})
    assert response_format(req)["json_schema"]["schema"]["properties"]["intervention_id"] == {"type": "null"}


def test_valid_output_parses():
    assert parse_output(json.dumps(OK)).dialogue_moves == ["acknowledge", "ask_evidence"]


@pytest.mark.parametrize("bad", [
    {**OK, "next_state": "closing"},
    {**OK, "domain": "chitchat"},
    {**OK, "dialogue_moves": []},
    {**OK, "dialogue_moves": ["give_advice"]},
    {k: v for k, v in OK.items() if k != "session_action"},
])
def test_invalid_output_rejected(bad):
    with pytest.raises(RespondRejected):
        parse_output(json.dumps(bad))


def test_conversation_is_capped_at_12():
    with pytest.raises(Exception):
        CounselingRespondRequest.model_validate({**REQ.model_dump(), "conversation": [{"role": "user", "text": "a"}] * 13})
