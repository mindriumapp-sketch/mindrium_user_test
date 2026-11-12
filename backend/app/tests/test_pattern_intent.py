import asyncio
import json
from types import SimpleNamespace

import httpx
import pytest
from fastapi import HTTPException
from routers import counseling_respond


def test_intent_sends_only_current_message_and_parses_result(monkeypatch):
    captured = {}

    class FakeClient:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            pass

        async def post(self, url, **kwargs):
            captured.update(kwargs['json'])
            return httpx.Response(200, request=httpx.Request('POST', url), json={
                'choices': [{'message': {'content': json.dumps({'pattern_request': True})}}],
            })

    monkeypatch.setattr(counseling_respond, 'get_settings', lambda: SimpleNamespace(
        openai_api_key='test', openai_api_base='https://example.com', openai_model='gpt-6-luna',
    ))
    monkeypatch.setattr(counseling_respond.httpx, 'AsyncClient', FakeClient)
    result = asyncio.run(counseling_respond.pattern_intent(
        counseling_respond.PatternIntentRequest(message='요즘 내가 어떤 것 같아?'), 'user',
    ))
    assert result == {'pattern_request': True}
    assert captured['messages'][1] == {'role': 'user', 'content': '요즘 내가 어떤 것 같아?'}
    assert 'user_facts' not in captured


def test_intent_without_key_reports_unavailable(monkeypatch):
    monkeypatch.setattr(counseling_respond, 'get_settings', lambda: SimpleNamespace(openai_api_key=''))
    with pytest.raises(HTTPException) as error:
        asyncio.run(counseling_respond.pattern_intent(counseling_respond.PatternIntentRequest(message='안녕'), 'user'))
    assert error.value.status_code == 503
