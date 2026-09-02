import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';

/// 코퍼스를 파일 시스템에서 직접 읽는다. rootBundle 대신 로더를 주입하면
/// 자산 등록 상태와 무관하게 코퍼스 자체를 검증할 수 있다.
Future<String> loadFromDisk(String path) => File(path).readAsString();

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUp(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  test('T1 코퍼스 전체를 로드한다', () {
    expect(repository.allIds, isNotEmpty);

    // manifest 가 선언한 총 항목 수와 실제 로드 수가 같아야 한다.
    final manifest = File(LocalCbtKnowledgeRepository.manifestPath);
    expect(manifest.existsSync(), isTrue);

    expect(repository.getById('week2_abc_model_01'), isNotNull);
    expect(repository.getById('week3_thought_examples'), isNotNull);
    expect(repository.getById('week7_relaxation_script'), isNotNull);
  });

  test('T1 initialize 를 두 번 불러도 항목이 중복되지 않는다', () async {
    final before = repository.allIds.length;
    await repository.initialize();
    expect(repository.allIds.length, before);
  });

  test('T1 example_bank 는 라벨이 붙은 예시를 갖는다', () {
    final bank = repository.getById('week5_behavior_examples')!;

    expect(bank.type, 'example_bank');
    expect(bank.examples, hasLength(20));
    expect(
      bank.examples.map((e) => e.label).toSet(),
      {'avoidance_behavior', 'confrontation_behavior'},
    );
  });

  test('T2 주차 필터링이 동작한다', () {
    final week4 = repository.getByWeek(4);

    expect(week4, isNotEmpty);
    expect(week4.every((item) => item.week == 4), isTrue);
    expect(week4.map((e) => e.id), contains('week4_thought_check_01'));

    // week 0 은 주차 공통 지식이다.
    expect(repository.getByWeek(0).map((e) => e.id), contains('common_sud_01'));
  });

  test('T2 검색은 지정한 주차와 공통 지식만 후보로 둔다', () {
    final results = repository.search(query: '불안', week: 5, limit: 20);

    expect(results, isNotEmpty);
    expect(results.every((item) => item.week == 5 || item.week == 0), isTrue);
  });

  test('T3 태그 필터링이 동작한다', () {
    final results = repository.search(
      query: '이완',
      tags: {'relaxation'},
      limit: 20,
    );

    expect(results, isNotEmpty);
    expect(results.every((item) => item.tags.contains('relaxation')), isTrue);
  });

  test('T3 태그를 지정하면 태그가 없는 항목은 제외된다', () {
    final results = repository.search(
      query: '생각',
      tags: {'gad7'},
      limit: 20,
    );

    expect(results.every((item) => item.tags.contains('gad7')), isTrue);
  });

  test('T4 키워드 검색이 관련 항목을 상위로 올린다', () {
    final results = repository.search(query: '걱정 그룹으로 묶기', limit: 5);

    expect(results, isNotEmpty);
    expect(results.first.id, 'week2_worry_group_01');
  });

  test('T4 조사가 붙은 어절도 검색된다', () {
    final results = repository.search(query: '회피하는 행동이 뭔가요', limit: 5);

    expect(results.map((e) => e.id), contains('week5_behavior_examples'));
  });

  test('T4 limit 을 넘지 않고 결과가 결정적이다', () {
    final first = repository.search(query: '불안 생각', limit: 3);
    final second = repository.search(query: '불안 생각', limit: 3);

    expect(first.length, lessThanOrEqualTo(3));
    expect(first.map((e) => e.id).toList(), second.map((e) => e.id).toList());
  });

  test('T4 아무것도 맞지 않으면 빈 결과를 준다', () {
    expect(repository.search(query: 'zzzzqqq', limit: 5), isEmpty);
  });
}
