import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2C 회귀 가드.
///
/// legacy NPC 엔진(GPT 프록시, 중독 상담 RAG, dummy.json)이 다시 런타임 경로로
/// 돌아오지 않는지 소스 트리에서 확인한다. 실행 시점의 호출 횟수는 chat_page_test 의
/// CountingLlmService 가 검증하고, 여기서는 "빌드에 포함될 수 있는가"를 막는다.
void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('T31 lib/ 에 GptApi 가 남아 있지 않다', () {
    expect(File('lib/chatbot/services/gpt_api.dart').existsSync(), isFalse);

    final offenders = dartFiles()
        .where((f) => f.readAsStringSync().contains('GptApi'))
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty, reason: 'GptApi 참조가 남아 있습니다: $offenders');
  });

  test('T31 lib/ 어디에서도 /ai/chat 엔드포인트를 호출하지 않는다', () {
    // 백엔드에 없는 엔드포인트다. 다시 들어오면 사용자 경로가 404 를 받는다.
    final offenders = dartFiles()
        .where((f) {
          final source = f.readAsStringSync();
          return source.contains('/ai/chat') || source.contains('/ai/embedding');
        })
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty, reason: 'AI 프록시 호출이 남아 있습니다: $offenders');
  });

  test('T32 lib/ 에 RagService 와 중독 상담 코퍼스 참조가 없다', () {
    expect(File('lib/chatbot/services/rag_service.dart').existsSync(), isFalse);

    final offenders = dartFiles()
        .where((f) {
          final source = f.readAsStringSync();
          return source.contains('RagService') ||
              source.contains('rag_singleton') ||
              source.contains('assets/data/');
        })
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty, reason: 'legacy RAG 참조가 남아 있습니다: $offenders');
  });

  test('T32 lib/ 에 dummy.json 기반 DataRepo 참조가 없다', () {
    final offenders = dartFiles()
        .where((f) {
          final source = f.readAsStringSync();
          return source.contains('DataRepo') || source.contains('dummy.json');
        })
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty, reason: 'DataRepo 참조가 남아 있습니다: $offenders');
  });

  test('T32 legacy Orchestrator 와 Agents 가 lib/ 에 없다', () {
    expect(File('lib/chatbot/services/orchestrator.dart').existsSync(), isFalse);
    expect(File('lib/chatbot/services/agents.dart').existsSync(), isFalse);
    expect(File('lib/chatbot/services/daily_context.dart').existsSync(), isFalse);
  });

  test('T32 중독 상담 코퍼스가 앱 자산으로 등록되어 있지 않다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assetLines = pubspec
        .split('\n')
        .where((line) => line.trimLeft().startsWith('- assets/'))
        .toList();

    expect(
      assetLines.where((line) => line.contains('assets/data/')),
      isEmpty,
      reason: 'assets/data/ 가 다시 번들에 포함되었습니다',
    );
    expect(Directory('assets/data').existsSync(), isFalse);
  });

  test('ChatPage 에 상담 판단 로직이 남아 있지 않다', () {
    final source = File('lib/chatbot/chatbot_main.dart').readAsStringSync();

    // 화면은 프롬프트를 만들지도, 검색하지도, 단계를 정하지도 않는다.
    expect(source.contains('PromptBuilder'), isFalse);
    expect(source.contains('.search('), isFalse);
    expect(source.contains('CounselingStatePolicy'), isFalse);
    expect(source.contains('SafetyResponseFactory'), isFalse);
  });
}
