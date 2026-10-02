import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/counseling_models.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';

/// 서버 응답을 흉내 내는 데이터 소스. 실패 주입도 여기서 한다.
class FakeDataSource implements MindriumDataSource {
  List<Map<String, dynamic>> diaries;
  List<Map<String, dynamic>> groups;
  List<Map<String, dynamic>> relaxations;
  Set<String> failing;

  FakeDataSource({
    this.diaries = const [],
    this.groups = const [],
    this.relaxations = const [],
    this.failing = const {},
  });

  Future<List<Map<String, dynamic>>> _serve(
    String name,
    List<Map<String, dynamic>> value,
  ) async {
    if (failing.contains(name)) throw StateError('$name 조회 실패');
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() =>
      _serve('diaries', diaries);

  @override
  Future<List<Map<String, dynamic>>> listWorryGroups() =>
      _serve('groups', groups);

  @override
  Future<List<Map<String, dynamic>>> listRelaxationTasks() =>
      _serve('relaxation', relaxations);
}

Map<String, dynamic> diary({
  required String id,
  required String situation,
  List<String> thoughts = const [],
  List<String> emotions = const [],
  List<String> behaviors = const [],
  List<String> alternatives = const [],
  String? groupId,
  int? sud,
  int daysAgo = 1,
}) {
  Map<String, dynamic> chip(String label) => {'label': label};
  return {
    'diary_id': id,
    'group_id': groupId,
    'activation': chip(situation),
    'belief': thoughts.map(chip).toList(),
    'consequence_emotion': emotions.map(chip).toList(),
    'consequence_action': behaviors.map(chip).toList(),
    'alternative_thoughts': alternatives,
    'latest_sud': sud,
    'created_at':
        DateTime.now().subtract(Duration(days: daysAgo)).toIso8601String(),
  };
}

void main() {
  test('T16 일기를 id 가 붙은 컨텍스트 항목으로 정규화한다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          diary(
            id: 'abc123',
            situation: '연구 발표',
            thoughts: ['질문에 답을 못하면 무능해 보일 것이다'],
            emotions: ['불안'],
            behaviors: ['발표 준비를 미룸'],
            groupId: 'g1',
            sud: 7,
          ),
        ],
        groups: [
          {'group_id': 'g1', 'group_title': '발표 전 긴장'},
        ],
      ),
    );

    final context = await builder.build(
      currentWeek: 4,
      userMessage: '발표가 걱정돼요',
    );

    expect(context.relevantItems, hasLength(1));
    final item = context.relevantItems.single;
    expect(item.id, 'diary:abc123');
    expect(item.type, UserContextType.diary);
    expect(item.groupId, 'g1');
    expect(item.sud, 7);
    expect(item.text, contains('발표 전 긴장'));
    expect(item.text, contains('상황: 연구 발표'));
    expect(item.text, contains('생각: 질문에 답을 못하면 무능해 보일 것이다'));
    expect(context.degraded, isFalse);
  });

  test('T16 대안적 생각은 별도 id 를 가진 항목으로 분리한다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          diary(
            id: 'abc123',
            situation: '발표',
            thoughts: ['망칠 것 같다'],
            alternatives: ['실수해도 회의를 망치지는 않는다'],
          ),
        ],
      ),
    );

    final context = await builder.build(currentWeek: 4, userMessage: '발표');
    final ids = context.relevantItems.map((e) => e.id).toList();

    expect(ids, contains('diary:abc123'));
    expect(ids, contains('alt:abc123'));
    expect(
      context.relevantItems.firstWhere((e) => e.id == 'alt:abc123').type,
      UserContextType.alternativeThought,
    );
  });

  test('T17 위치·좌표는 컨텍스트에 담지 않는다', () async {
    final raw = diary(id: 'abc123', situation: '카페', thoughts: ['불안하다']);
    raw['loc_time'] = {
      'latitude': 37.123456,
      'longitude': 127.123456,
      'location': '서울시 관악구 봉천동 123-45',
    };

    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(diaries: [raw]),
    );
    final context = await builder.build(currentWeek: 2, userMessage: '불안해요');

    for (final item in context.relevantItems) {
      expect(item.text, isNot(contains('37.12')));
      expect(item.text, isNot(contains('127.12')));
      expect(item.text, isNot(contains('봉천동')));
    }
  });

  test('T18 선택은 상한을 지키고 결정적이다', () async {
    final diaries = List.generate(
      12,
      (i) =>
          diary(id: 'd$i', situation: '상황 $i', thoughts: ['걱정 $i'], daysAgo: 1),
    );
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(diaries: diaries),
    );

    final first = await builder.build(currentWeek: 3, userMessage: '걱정');
    final second = await builder.build(currentWeek: 3, userMessage: '걱정');

    expect(
      first.relevantItems.length,
      lessThanOrEqualTo(MindriumContextBuilder.maxItems),
    );
    expect(
      first.relevantItems.map((e) => e.id).toList(),
      second.relevantItems.map((e) => e.id).toList(),
    );
  });

  test('T18 같은 걱정 그룹과 높은 SUD 가 우선순위를 올린다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          // 최근이지만 그룹도 다르고 SUD 도 낮다.
          diary(id: 'low', situation: '산책', thoughts: ['별일 아니다'], sud: 2),
          // 같은 그룹 + 높은 SUD.
          diary(
            id: 'high',
            situation: '발표',
            thoughts: ['망칠 것 같다'],
            groupId: 'g1',
            sud: 9,
          ),
        ],
      ),
    );

    final context = await builder.build(
      currentWeek: 4,
      userMessage: '오늘도 힘들었어요',
      focusGroupId: 'g1',
    );

    expect(context.relevantItems.first.id, 'diary:high');
  });

  test('현재 인간관계 발화에 최근 고SUD 발표 일기를 섞지 않는다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          diary(
            id: 'presentation',
            situation: '연구 발표',
            thoughts: ['질문에 답하지 못하면 무능해 보일 것이다'],
            sud: 9,
          ),
        ],
      ),
    );

    final context = await builder.build(
      currentWeek: 4,
      userMessage: '친한 친구가 연락에 답하지 않아서 속상해요.',
    );

    expect(context.relevantItems, isEmpty);
  });

  test('T19 SUD 추이를 일기 점수에서 계산한다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          // 최신순. 최근 절반이 더 높으므로 increasing.
          diary(
            id: 'd1',
            situation: '발표',
            thoughts: ['걱정'],
            sud: 8,
            daysAgo: 1,
          ),
          diary(
            id: 'd2',
            situation: '발표',
            thoughts: ['걱정'],
            sud: 8,
            daysAgo: 2,
          ),
          diary(
            id: 'd3',
            situation: '발표',
            thoughts: ['걱정'],
            sud: 4,
            daysAgo: 3,
          ),
          diary(
            id: 'd4',
            situation: '발표',
            thoughts: ['걱정'],
            sud: 4,
            daysAgo: 4,
          ),
        ],
      ),
    );

    final context = await builder.build(currentWeek: 4, userMessage: '걱정');

    expect(context.recentSud, isNotNull);
    expect(context.recentSud!.latest, 8);
    expect(context.recentSud!.weeklyAverage, 6.0);
    expect(context.recentSud!.trend, 'increasing');
  });

  test('T20 효과가 확인된 이완만 개입 이력에 남는다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          diary(id: 'd1', situation: '발표', thoughts: ['걱정']),
        ],
        relaxations: [
          {'id': 'r1', 'task_id': '점진적 이완', 'before_sud': 7, 'after_sud': 4},
          // 낮아지지 않았으므로 제외된다.
          {'id': 'r2', 'task_id': '신속 이완', 'before_sud': 5, 'after_sud': 6},
          // 점수가 없으면 효과를 알 수 없으므로 제외된다.
          {'id': 'r3', 'task_id': '차등 이완'},
        ],
      ),
    );

    final context = await builder.build(currentWeek: 5, userMessage: '이완');

    expect(context.effectiveInterventions, hasLength(1));
    expect(context.effectiveInterventions.single.id, 'relax:r1');
    expect(context.effectiveInterventions.single.improved, isTrue);
  });

  test('T21 조회가 실패해도 예외 없이 degraded 컨텍스트를 준다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          diary(id: 'd1', situation: '발표', thoughts: ['걱정']),
        ],
        failing: {'groups', 'relaxation'},
      ),
    );

    final context = await builder.build(currentWeek: 4, userMessage: '걱정');

    expect(context.degraded, isTrue);
    expect(context.relevantItems, isNotEmpty);
    expect(context.effectiveInterventions, isEmpty);
  });

  test('T21 전부 실패하면 비어 있는 컨텍스트를 준다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(failing: {'diaries', 'groups', 'relaxation'}),
    );

    final context = await builder.build(currentWeek: 4, userMessage: '걱정');

    expect(context.degraded, isTrue);
    expect(context.isEmpty, isTrue);
    expect(context.offeredIds, isEmpty);
  });

  test('T22 offeredIds 는 항목과 개입 id 를 모두 포함한다', () async {
    final builder = MindriumContextBuilder(
      dataSource: FakeDataSource(
        diaries: [
          diary(
            id: 'd1',
            situation: '발표',
            thoughts: ['걱정'],
            alternatives: ['괜찮을 것이다'],
          ),
        ],
        relaxations: [
          {'id': 'r1', 'task_id': '점진적 이완', 'before_sud': 7, 'after_sud': 3},
        ],
      ),
    );

    final context = await builder.build(currentWeek: 5, userMessage: '걱정');

    expect(context.offeredIds, containsAll(['diary:d1', 'alt:d1', 'relax:r1']));
  });
}
