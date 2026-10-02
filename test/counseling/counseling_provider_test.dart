import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/features/counseling/counseling_harness.dart';
import 'package:gad_app_team/features/counseling/counseling_provider.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/features/counseling/safety_gate.dart';

Future<String> loadFromDisk(String path) => File(path).readAsString();

/// 호출 횟수를 세는 데이터 소스. 턴마다 다시 조회하지 않는지 확인한다.
class CountingDataSource implements MindriumDataSource {
  int diaryCalls = 0;
  final bool fail;

  CountingDataSource({this.fail = false});

  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() async {
    diaryCalls++;
    if (fail) throw StateError('서버 없음');
    return [
      {
        'diary_id': 'd1',
        'activation': {'label': '발표 준비'},
        'belief': [
          {'label': '망칠 것 같다'},
        ],
        'latest_sud': 7,
        'created_at': DateTime.now().toIso8601String(),
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listWorryGroups() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listRelaxationTasks() async => const [];
}

void main() {
  late LocalCbtKnowledgeRepository repository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
  });

  CounselingProvider providerWith(MindriumDataSource? source) {
    return CounselingProvider(
      knowledgeRepository: repository,
      currentWeek: 4,
      contextBuilder: source == null
          ? null
          : MindriumContextBuilder(dataSource: source),
      harness: CounselingHarness(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      ),
    );
  }

  test('T24 세션 시작 시 사용자 컨텍스트를 한 번만 읽는다', () async {
    final source = CountingDataSource();
    final provider = providerWith(source);

    await provider.initialize();
    expect(source.diaryCalls, 1);
    expect(provider.userContext, isNotNull);
    expect(
      provider.userContext!.relevantItems.map((e) => e.id),
      contains('diary:d1'),
    );

    // 턴을 여러 번 돌려도 다시 조회하지 않는다.
    await provider.sendMessage('발표가 걱정돼요.');
    await provider.sendMessage('계속 생각이 나요.');
    expect(source.diaryCalls, 1);
  });

  test('T24 refreshContext 를 부르면 다시 읽는다', () async {
    final source = CountingDataSource();
    final provider = providerWith(source);

    await provider.initialize();
    await provider.refreshContext();

    expect(source.diaryCalls, 2);
  });

  test('T25 컨텍스트 조회가 실패해도 대화는 시작된다', () async {
    final provider = providerWith(CountingDataSource(fail: true));

    await provider.initialize();

    expect(provider.isReady, isTrue);
    expect(provider.messages, hasLength(1));
    // 일기 조회만 실패했으므로 degraded 컨텍스트가 만들어진다.
    expect(provider.userContext?.degraded, isTrue);

    await provider.sendMessage('발표가 걱정돼요.');
    expect(provider.messages.length, 3);
  });

  test('T25 컨텍스트 빌더가 없으면 개인화 없이 동작한다', () async {
    final provider = providerWith(null);

    await provider.initialize();
    await provider.sendMessage('발표가 걱정돼요.');

    expect(provider.userContext, isNull);
    expect(provider.messages.last.isUser, isFalse);
    expect(provider.messages.last.text, isNotEmpty);
  });

  test('무의미한 입력에는 즉시 공감을 붙이지 않는다', () async {
    final provider = CounselingProvider(
      knowledgeRepository: repository,
      currentWeek: 4,
      contextBuilder: null,
      harness: CounselingHarness.deterministic(
        llm: MockLlmService(),
        safetyGate: const KeywordSafetyGate(),
        knowledgeRepository: repository,
      ),
      instantEmpathy: true,
    );

    await provider.initialize();
    await provider.sendMessage('asdfasdf ㅁㄴㅇㄹ');

    // 즉시 공감(고정 문장) 없이 user + input guard 응답, 총 2개만 추가된다.
    expect(provider.messages.length, 3);
    expect(
      provider.messages.any((m) => m.text.contains('마음에 계속 걸리고')),
      isFalse,
    );
  });
}
