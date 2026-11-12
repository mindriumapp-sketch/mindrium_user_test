"""Aggregate recorded diary context and notification settings without diagnosing."""
from collections import Counter, defaultdict
from datetime import datetime, timedelta
import re

from core.utils import KST, ensure_utc
from routers.diaries import _normalize_loc_time

WINDOW_DAYS = 28
MIN_REPEATS = 3
MINUTES_NEAR = 60


def _time(raw):
    if not isinstance(raw, str):
        return None
    match = re.fullmatch(r'\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*', raw)
    if not match:
        return None
    h, m = map(int, match.groups())
    return h * 60 + m if h < 24 and m < 60 else None


def _label(value):
    if not isinstance(value, str):
        return None
    value = ' '.join(value.split())
    return value[:80] if value else None


def _place(value):
    value = _label(value)
    # Do not send street addresses or exact coordinates to the model.
    if not value or len(value) > 24 or re.search(r'특별시|광역시|(?:시|군|구)\s|(?:로|길)\s*\d|\d+호|^\d+(?:[- ]\d+)?$', value):
        return None
    return value


def analyze_patterns(diaries, alarms, now):
    now = ensure_utc(now)
    cutoff = now - timedelta(days=WINDOW_DAYS)
    records = []
    for diary in diaries:
        created = diary.get('created_at')
        if not isinstance(created, datetime):
            continue
        created = ensure_utc(created)
        if not cutoff <= created <= now:
            continue
        local = created.astimezone(KST)
        lt = _normalize_loc_time(diary.get('loc_time', diary.get('alarms'))) or {}
        explicit = _time(lt.get('time'))
        minutes = explicit if explicit is not None else local.hour * 60 + local.minute
        location = _place(lt.get('location') or lt.get('location_label'))
        activation = diary.get('activation') or {}
        topic = _label(activation.get('label')) if isinstance(activation, dict) else None
        score = diary.get('latest_sud')
        if not isinstance(score, int) or isinstance(score, bool) or not 0 <= score <= 10:
            score = None
        records.append({'weekday': local.isoweekday(), 'minutes': minutes,
                        'source': 'recorded' if explicit is not None else 'created',
                        'location': location, 'topic': topic, 'score': score})

    buckets = [(0, 6, '새벽'), (6, 12, '오전'), (12, 18, '오후'), (18, 24, '저녁')]
    counts = Counter((r['source'], next(label for start, end, label in buckets if start <= r['minutes'] // 60 < end)) for r in records)
    weekdays = Counter(r['weekday'] for r in records)
    locations = Counter(r['location'] for r in records if r['location'])
    scores = [r['score'] for r in records if r['score'] is not None]
    # Topics are used for relevance matching only; never imply a cause.
    topics = Counter(r['topic'] for r in records if r['topic'])
    patterns = []
    for (source, label), count in sorted(counts.items()):
        if count >= MIN_REPEATS:
            source_label = '일기에 적은 시간' if source == 'recorded' else '일기 작성 시간'
            patterns.append({'id': f'time:{source}:{label}', 'kind': 'time', 'label': label,
                             'count': count, 'ai_text': f'{source_label} 기준 {label} {count}건', 'text': f'최근 {WINDOW_DAYS}일 일기 {len(records)}건 중 {count}건은 {source_label} 기준 {label}에 해당합니다.'})
    day_labels = ('월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일')
    for day, count in sorted(weekdays.items()):
        if count >= MIN_REPEATS:
            label = day_labels[day - 1]
            patterns.append({'id': f'weekday:{day}', 'kind': 'weekday', 'label': label,
                             'count': count, 'ai_text': f'{label} 작성 {count}건', 'text': f'최근 {WINDOW_DAYS}일 일기 {len(records)}건 중 {count}건은 {label}에 작성됐습니다.'})
    for label, count in topics.most_common(10):
        if count >= MIN_REPEATS:
            patterns.append({'id': f'topic:{len(patterns)}', 'kind': 'topic', 'label': label,
                             'count': count, 'ai_text': f'상황 {label} {count}건', 'text': f'최근 {WINDOW_DAYS}일 일기 {len(records)}건 중 {count}건에 상황 {label}이 기록됐습니다.'})
    for label, count in sorted(locations.items()):
        patterns.append({'id': f'place:{len(patterns)}', 'kind': 'place', 'label': label,
                         'count': count, 'ai_text': f'장소 {label} {count}건', 'text': f'최근 {WINDOW_DAYS}일 일기 {len(records)}건 중 {count}건에 장소 {label}이 기록됐습니다.'})

    if scores:
        average = round(sum(scores) / len(scores), 1)
        patterns.append({'id': 'score:mean', 'kind': 'score', 'label': '불안 점수',
                         'count': len(scores), 'ai_text': f'마지막 불안 점수 {len(scores)}건의 평균 {average}점', 'text': f'최근 {WINDOW_DAYS}일 일기 중 마지막으로 기록된 불안 점수가 있는 기록 {len(scores)}건의 평균은 {average}점입니다.'})

    active = [a for a in alarms if a.enabled]
    matches = defaultdict(set)
    for idx, alarm in enumerate(active):
        schedule = alarm.schedule
        if schedule.timezone != 'Asia/Seoul':
            continue
        # Only compare a recorded event time, not diary creation time.
        for n, record in enumerate(records):
            if record['source'] != 'recorded' or record['weekday'] not in schedule.weekdays:
                continue
            # A location alarm needs both time and matching place.
            if alarm.location:
                alarm_place = _place(alarm.location.location)
                if not alarm_place or not record['location'] or alarm_place.casefold() != record['location'].casefold():
                    continue
            difference = abs(record['minutes'] - (schedule.hour * 60 + schedule.minute))
            if difference <= MINUTES_NEAR:
                matches[idx].add(n)
    for idx, matched in matches.items():
        if len(matched) >= MIN_REPEATS:
            alarm = active[idx]
            label = _label(alarm.label) or '알림'
            patterns.append({'id': f'alarm:{idx}', 'kind': 'alarm', 'label': label,
                             'count': len(matched), 'ai_text': f'현재 설정된 {label}과 가까운 일기 {len(matched)}건(작성 요일 기준, 실제 전달 여부 미확인)', 'text': f'최근 {WINDOW_DAYS}일 일기 {len(records)}건 중 {len(matched)}건은 설정된 {label} 시간과 1시간 이내이며, 작성일의 요일이 알림 요일과 같습니다. 실제 알림 전달 여부는 확인할 수 없습니다.'})
    # Keep the strongest representative for every category before the cap.
    # Otherwise time/day/topic entries can hide location and score entirely.
    prioritized = []
    for kind in ('time', 'place', 'score', 'alarm', 'weekday', 'topic'):
        group = [p for p in patterns if p['kind'] == kind]
        if group:
            prioritized.append(max(group, key=lambda p: p['count']))
    prioritized_ids = {p['id'] for p in prioritized}
    prioritized.extend(p for p in patterns if p['id'] not in prioritized_ids)
    return {'window_days': WINDOW_DAYS, 'diary_count': len(records),
            'score_count': len(scores), 'average_sud': round(sum(scores)/len(scores), 1) if scores else None,
            'active_alarm_count': len(active), 'patterns': prioritized[:12],
            'topics': [t for t, n in topics.most_common(10) if n >= MIN_REPEATS]}
