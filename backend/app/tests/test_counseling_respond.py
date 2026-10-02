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
    "intervention": None,
    "used_user_fact_ids": [], "used_app_fact_ids": [], "definition_id": None,
    "session_action": "continue", "statement": "그런 생각이 드셨군요.",
    "question": "그 생각의 근거가 있을까요?",
}


def test_ids_are_enums_per_request():
    schema = response_format(REQ)["json_schema"]["schema"]["properties"]
    assert schema["intervention"]["anyOf"][1]["properties"]["id"]["enum"] == ["week4_alternative_thought_01"]
    assert schema["used_user_fact_ids"]["items"]["enum"] == ["session:s1"]
    assert schema["used_app_fact_ids"]["maxItems"] == 0


def test_no_techniques_means_null_only():
    req = REQ.model_copy(update={"techniques": []})
    assert response_format(req)["json_schema"]["schema"]["properties"]["intervention"] == {"type": "null"}


def test_valid_output_parses():
    assert parse_output(json.dumps(OK)).dialogue_moves == ["acknowledge", "ask_evidence"]


@pytest.mark.parametrize("bad", [
    {**OK, "next_state": "closing"},
    {**OK, "domain": "chitchat"},
    {**OK, "dialogue_moves": []},
    {**OK, "dialogue_moves": ["give_advice"]},
    {k: v for k, v in OK.items() if k != "session_action"},
    {**OK, "intervention": {"step": "prompt"}},
    {**OK, "intervention": {"id": "x", "step": "explain"}},
])
def test_invalid_output_rejected(bad):
    with pytest.raises(RespondRejected):
        parse_output(json.dumps(bad))


def test_conversation_is_capped_at_12():
    with pytest.raises(Exception):
        CounselingRespondRequest.model_validate({**REQ.model_dump(), "conversation": [{"role": "user", "text": "a"}] * 13})


def test_definition_id_is_pinned_to_the_requested_term():
    req = CounselingRespondRequest.model_validate({**REQ.model_dump(), "term_request": {
        "status": "approved", "term_id": "abc_model", "name": "ABC 모델", "definition": "x"}})
    assert response_format(req)["json_schema"]["schema"]["properties"]["definition_id"] == {
        "type": "string", "enum": ["abc_model"]}
    unknown = CounselingRespondRequest.model_validate({**REQ.model_dump(), "term_request": {
        "status": "unknown", "name": "탈파국화"}})
    assert response_format(unknown)["json_schema"]["schema"]["properties"]["definition_id"] == {"type": "null"}
    assert response_format(REQ)["json_schema"]["schema"]["properties"]["definition_id"] == {"type": "null"}
