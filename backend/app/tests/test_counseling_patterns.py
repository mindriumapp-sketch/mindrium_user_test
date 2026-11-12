from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from core.counseling_patterns import analyze_patterns

NOW = datetime(2026, 11, 12, 6, tzinfo=timezone.utc)


def diary(days=0, time='14:00', location='학교', sud=6):
    return {'created_at': NOW - timedelta(days=days), 'loc_time': {'time': time, 'location': location, 'latitude': 37.0, 'longitude': 127.0}, 'latest_sud': sud, 'activation': {'label': '학교 발표'}}


def alarm(enabled=True, location=None, weekdays=None):
    return SimpleNamespace(enabled=enabled, label='오후 알림', schedule=SimpleNamespace(hour=14, minute=30, weekdays=weekdays or list(range(1, 8)), timezone='Asia/Seoul'), location=SimpleNamespace(location=location) if location else None)


def test_pattern_counts_match_only_recorded_times_and_never_expose_coordinates():
    result = analyze_patterns([diary(1), diary(2), diary(3), diary(4, time=None)], [alarm()], NOW)
    assert result['diary_count'] == 4
    assert next(p for p in result['patterns'] if p['kind'] == 'alarm')['count'] == 3
    assert next(p for p in result['patterns'] if p['kind'] == 'place')['count'] == 4
    assert '37.0' not in str(result) and '127.0' not in str(result)
    assert '실제 알림 전달 여부는 확인할 수 없습니다' in str(result)


def test_excludes_outside_window_and_disabled_or_wrong_location_alarm():
    result = analyze_patterns([diary(1), diary(2), diary(3), diary(29)], [alarm(False), alarm(location='집')], NOW)
    assert result['diary_count'] == 3
    assert not any(p['kind'] == 'alarm' for p in result['patterns'])
    assert result['active_alarm_count'] == 1


def test_insufficient_and_invalid_data_are_not_patterns():
    result = analyze_patterns([diary(1, time='99:99', location=None, sud=100)], [], NOW)
    assert result['patterns'] == []
    assert result['score_count'] == 0
    assert result['average_sud'] is None


def test_midnight_does_not_invent_previous_day_match():
    a = alarm()
    a.schedule.hour = 0
    a.schedule.minute = 10
    result = analyze_patterns([diary(1, time='23:50'), diary(2, time='23:50'), diary(3, time='23:50')], [a], NOW)
    assert not any(p['kind'] == 'alarm' for p in result['patterns'])


def test_endpoint_requires_authentication_and_filters_both_collections_by_user():
    from fastapi.testclient import TestClient
    from core.security import get_current_user_id
    from db.mongo import get_db
    from main import app

    class Cursor:
        def __init__(self, docs): self.docs = docs
        def sort(self, *_args): return self
        def __aiter__(self):
            async def iterator():
                for doc in self.docs:
                    yield doc
            return iterator()

    class Collection:
        def __init__(self, name): self.name = name
        def find(self, query, projection=None):
            assert query['user_id'] == 'user_a'
            if self.name == 'diaries':
                assert '$gte' in query['created_at']
                assert '$or' in query
                assert 'latitude' not in (projection or {})
                return Cursor([])
            return Cursor([])

    class DB:
        def __getitem__(self, name): return Collection(name)

    client = TestClient(app)
    assert client.get('/counseling/patterns').status_code in (401, 403)
    app.dependency_overrides[get_current_user_id] = lambda: 'user_a'
    app.dependency_overrides[get_db] = lambda: DB()
    try:
        response = client.get('/counseling/patterns')
        assert response.status_code == 200
        assert response.json()['diary_count'] == 0
    finally:
        app.dependency_overrides.clear()


def test_location_address_and_unsupported_timezone_are_not_used():
    address_diaries = [diary(1, location='서울 강남구 123'), diary(2, location='서울 강남구 123'), diary(3, location='서울 강남구 123')]
    other_zone_alarm = alarm()
    other_zone_alarm.schedule.timezone = 'America/New_York'
    result = analyze_patterns(address_diaries, [other_zone_alarm], NOW)
    assert not any(p['kind'] in ('place', 'alarm') for p in result['patterns'])
    assert '강남구' not in str(result)


def test_balanced_patterns_keep_place_and_score_when_many_topics_exist():
    data = []
    for i in range(18):
        row = diary(i % 20, location='학교', sud=6)
        row['activation'] = {'label': f'상황{i // 3}'}
        data.append(row)
    result = analyze_patterns(data, [alarm()], NOW)
    kinds = {p['kind'] for p in result['patterns']}
    assert {'time', 'place', 'score', 'alarm', 'topic'} <= kinds
    assert len(result['patterns']) <= 12


def test_single_location_is_reported_as_record_without_claiming_repetition():
    result = analyze_patterns([diary(1, location='2층 휴게실')], [], NOW)
    place = next(p for p in result['patterns'] if p['kind'] == 'place')
    assert place['count'] == 1
    assert '2층 휴게실' in place['text']
    assert '반복' not in place['text']
