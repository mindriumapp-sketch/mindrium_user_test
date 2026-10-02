"""Phase 14.2A: 분류기 계약과 장애 주입.

모델 출력에 결정 필드가 섞이거나 형식이 어긋나면 응답 전체를 거부해야 하고,
업스트림 장애는 모두 ClassifierRejected로 끝나야 한다(앱은 규칙 판정으로 대체).
실행: cd backend/app && PYTHONPATH=. python3 -m pytest tests -q
"""

import asyncio
import json

import httpx
import pytest
from routers.counseling_classify import (
    ClassifierRejected,
    classify,
    parse_model_content,
)

VALID = {
    "content_type": "worry_thought",
    "interaction_signal": "none",
    "open_content": "none",
    "confidence": {"content_type": 0.9, "interaction_signal": 0.8, "open_content": 1},
}


def _reason(fn, *a):
    with pytest.raises(ClassifierRejected) as e:
        fn(*a)
    return e.value.reason


def test_valid_output_is_accepted():
    labels = parse_model_content(json.dumps(VALID))
    assert labels.content_type == "worry_thought"


@pytest.mark.parametrize(
    "key", ["next_move", "next_state", "selected_cbt", "should_close", "reply"]
)
def test_any_decision_field_rejects_the_whole_response(key):
    bad = {**VALID, key: "x"}
    assert _reason(parse_model_content, json.dumps(bad)) == "forbidden_field"


def test_unlisted_extra_field_rejects():
    bad = {**VALID, "notes": "x"}
    assert _reason(parse_model_content, json.dumps(bad)) == "extra_field"


def test_unknown_enum_rejects():
    bad = {**VALID, "content_type": "anxiety"}
    assert _reason(parse_model_content, json.dumps(bad)) == "unknown_enum"


def test_missing_field_rejects():
    bad = {k: v for k, v in VALID.items() if k != "open_content"}
    assert _reason(parse_model_content, json.dumps(bad)) == "missing_field"


def test_confidence_out_of_range_rejects():
    bad = {**VALID, "confidence": {**VALID["confidence"], "content_type": 1.5}}
    assert _reason(parse_model_content, json.dumps(bad)) == "invalid_value"


def test_extra_confidence_key_rejects():
    bad = {**VALID, "confidence": {**VALID["confidence"], "next_move": 0.2}}
    assert _reason(parse_model_content, json.dumps(bad)) == "extra_field"


@pytest.mark.parametrize(
    "raw,reason",
    [
        ("", "empty"),
        ("not json", "malformed_json"),
        ("[1, 2]", "not_object"),
        (json.dumps({**VALID, "content_type": "x" * 700}), "overlong"),
    ],
)
def test_malformed_outputs_reject(raw, reason):
    assert _reason(parse_model_content, raw) == reason


def _run(handler):
    async def go():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as c:
            return await classify(
                c, api_base="https://x", api_key="k", model="m",
                user_text="무슨 말이야", assistant_prev=None,
            )
    return asyncio.run(go())


def _upstream(content):
    return lambda req: httpx.Response(
        200,
        json={"choices": [{"message": {"content": content}}],
              "usage": {"prompt_tokens": 10, "completion_tokens": 5}},
    )


def test_end_to_end_ok_reports_usage():
    r = _run(_upstream(json.dumps(VALID)))
    assert r.labels.open_content == "none"
    assert (r.prompt_tokens, r.completion_tokens) == (10, 5)


def test_upstream_timeout():
    def h(req):
        raise httpx.ReadTimeout("t", request=req)
    with pytest.raises(ClassifierRejected) as e:
        _run(h)
    assert e.value.reason == "timeout"


def test_upstream_500():
    with pytest.raises(ClassifierRejected) as e:
        _run(lambda req: httpx.Response(500))
    assert e.value.reason == "upstream_500"


def test_upstream_garbage_body():
    with pytest.raises(ClassifierRejected) as e:
        _run(lambda req: httpx.Response(200, json={"oops": 1}))
    assert e.value.reason == "malformed_upstream"


def test_upstream_forbidden_field_end_to_end():
    with pytest.raises(ClassifierRejected) as e:
        _run(_upstream(json.dumps({**VALID, "next_move": "askEvidence"})))
    assert e.value.reason == "forbidden_field"


def test_request_never_carries_more_than_two_messages_of_context():
    seen = {}

    def h(req):
        seen.update(json.loads(req.content))
        return _upstream(json.dumps(VALID))(req)

    _run(h)
    assert [m["role"] for m in seen["messages"]] == ["system", "user"]
    assert seen["temperature"] == 0
