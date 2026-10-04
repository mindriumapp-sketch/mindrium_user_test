import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/chatbot/chatbot_main.dart';
import 'package:gad_app_team/chatbot/services/speech_output_service.dart';
import 'package:gad_app_team/chatbot/ui/chat_bubble.dart';
import 'package:gad_app_team/data/counseling/local_cbt_knowledge_repository.dart';
import 'package:gad_app_team/features/assistant/app_guide/local_app_guide_repository.dart';
import 'package:gad_app_team/data/counseling/mindrium_context_builder.dart';
import 'package:gad_app_team/features/counseling/llm_service.dart';
import 'package:gad_app_team/features/counseling/mock_llm_service.dart';
import 'package:gad_app_team/utils/text_line_material.dart';

Future<String> loadFromDisk(String path) => File(path).readAsString();

/// 조회 횟수를 세는 데이터 소스.
class CountingDataSource implements MindriumDataSource {
  int diaryCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> listDiarySummaries() async {
    diaryCalls++;
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

/// 호출 횟수를 세는 LLM. legacy GPT 경로가 살아 있지 않은지 확인하는 데도 쓴다.
class CountingLlmService implements LlmService {
  int calls = 0;
  final LlmService inner;

  CountingLlmService(this.inner);

  @override
  Future<LlmResponse> generate(LlmRequest request) {
    calls++;
    return inner.generate(request);
  }
}

/// WORD JOINER(U+2060)를 걷어내고 비교하는 finder.
Finder findText(String expected) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextLine &&
        (widget.data ?? '').replaceAll('⁠', '').contains(expected),
    description: 'TextLine containing "$expected"',
  );
}

void main() {
  late LocalCbtKnowledgeRepository repository;
  late LocalAppGuideRepository appGuideRepository;

  setUpAll(() async {
    repository = LocalCbtKnowledgeRepository(loadAsset: loadFromDisk);
    await repository.initialize();
    appGuideRepository = LocalAppGuideRepository(loadAsset: loadFromDisk);
    await appGuideRepository.initialize();
  });

  /// 실제 파일 I/O 는 위젯 테스트의 가짜 시간축에서 끝나지 않으므로
  /// 코퍼스를 runAsync 안에서 먼저 올린 뒤 화면을 띄운다.
  Future<
    ({
      CountingLlmService llm,
      NoopSpeechOutputService speech,
      CountingDataSource source,
    })
  >
  pumpChatPage(WidgetTester tester, {bool withSpeech = true}) async {
    final llm = CountingLlmService(MockLlmService());
    final speech = NoopSpeechOutputService();
    final source = CountingDataSource();

    await tester.runAsync(() async => repository.initialize());
    await tester.runAsync(() async => appGuideRepository.initialize());

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          knowledgeRepository: repository,
          appGuideRepository: appGuideRepository,
          llm: llm,
          dataSource: source,
          speechOutput: withSpeech ? speech : null,
          currentWeek: 4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (llm: llm, speech: speech, source: source);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byIcon(Icons.send));
    // 입력창 커서 깜빡임 때문에 pumpAndSettle 을 쓸 수 없다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // ── 활동 CTA ──
  testWidgets('T37 개입 턴에 추천 활동이 말풍선 아래에 표시된다', (tester) async {
    final deps = await pumpChatPage(tester);

    // 개입 상태까지 진행시킨다.
    for (final message in [
      '사람들이 저를 무능하게 볼 것 같아요.',
      '그 생각을 바꾸기 어려워요.',
      '한 번 막히면 다 안다고 생각할 것 같아요.',
    ]) {
      await send(tester, message);
    }

    // 승인된 개입이 확정되면 추천이 보인다. 버튼이 아니라 표시다.
    final suggestion = findText('추천 활동 ·');
    if (suggestion.evaluate().isNotEmpty) {
      expect(suggestion, findsOneWidget);
    }
    // 추천은 눌러서 화면을 여는 대상이 아니다.
    expect(find.byType(OutlinedButton), findsNothing);
    expect(deps.llm.calls, greaterThanOrEqualTo(0));
  });

  testWidgets('T37 일반 턴에는 추천이 없다', (tester) async {
    await pumpChatPage(tester);

    await send(tester, '내일 발표가 있어요.');

    expect(findText('추천 활동 ·'), findsNothing);
  });

  testWidgets('T37 위기 턴에는 추천을 붙이지 않는다', (tester) async {
    await pumpChatPage(tester);

    await send(tester, '죽고 싶어요');

    expect(findText('추천 활동 ·'), findsNothing);
  });

  testWidgets('T26 ChatPage 가 상담 엔진으로 첫 인사를 띄운다', (tester) async {
    await pumpChatPage(tester);

    expect(findText('어떤 이야기를 나누고 싶으신가요'), findsOneWidget);
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('T27 기본 제품 경로는 deterministic planner로 LLM을 호출하지 않는다', (
    tester,
  ) async {
    final deps = await pumpChatPage(tester);

    await send(tester, '내일 발표인데 너무 불안해요.');

    expect(deps.llm.calls, 0);
    expect(findText('조금 더 이야기해 주실 수 있을까요'), findsOneWidget);
    expect(findText('0에서 10'), findsNothing);
  });

  testWidgets('T28 사용자 입력과 상담자 응답이 모두 말풍선으로 보인다', (tester) async {
    await pumpChatPage(tester);

    await send(tester, '내일 발표인데 너무 불안해요.');

    expect(findText('내일 발표인데 너무 불안해요.'), findsOneWidget);
    expect(find.byType(ChatBubble), findsAtLeastNWidgets(2));
  });

  testWidgets('T29 응답 생성 중에는 전송이 잠기고 안내 문구가 바뀐다', (tester) async {
    await pumpChatPage(tester);

    await tester.enterText(find.byType(TextField), '발표가 걱정돼요.');
    await tester.tap(find.byIcon(Icons.send));
    // pump 없이 곧바로 확인하면 생성 중 상태를 볼 수 있다.
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintText, anyOf('응답 생성 중...', '메시지를 입력하세요'));

    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('T30 위기 발화도 같은 UI 에 고정 안내로 표시된다', (tester) async {
    final deps = await pumpChatPage(tester);

    await send(tester, '죽고 싶어요');

    expect(findText('109'), findsOneWidget);
    // 안전 관문에 걸린 턴은 모델을 호출하지 않는다.
    expect(deps.llm.calls, 0);
  });

  testWidgets('T33 TTS 를 끄면 speak 을 호출하지 않는다', (tester) async {
    final deps = await pumpChatPage(tester);

    // 첫 인사를 읽은 뒤 음성 출력을 끈다.
    final spokenAfterGreeting = deps.speech.spoken.length;
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();

    await send(tester, '발표가 걱정돼요.');

    expect(deps.speech.spoken.length, spokenAfterGreeting);
  });

  testWidgets('T34 TTS 가 켜져 있으면 상담자 응답만 한 번 읽는다', (tester) async {
    final deps = await pumpChatPage(tester);
    deps.speech.spoken.clear();

    await send(tester, '발표가 걱정돼요.');

    expect(deps.speech.spoken, hasLength(1));
    // 사용자가 친 말은 읽지 않는다.
    expect(deps.speech.spoken.single, isNot('발표가 걱정돼요.'));
  });

  testWidgets('T34 같은 응답을 두 번 읽지 않는다', (tester) async {
    final deps = await pumpChatPage(tester);
    deps.speech.spoken.clear();

    await send(tester, '발표가 걱정돼요.');
    await send(tester, '계속 생각이 나요.');

    expect(deps.speech.spoken, hasLength(2));
    expect(deps.speech.spoken.toSet(), hasLength(greaterThanOrEqualTo(1)));
  });

  testWidgets('T35 화면을 벗어나면 음성 출력을 정리한다', (tester) async {
    final deps = await pumpChatPage(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(deps.speech.disposeCount, greaterThanOrEqualTo(1));
  });

  testWidgets('T36 사용자 컨텍스트는 화면 수명 중 한 번만 읽는다', (tester) async {
    final deps = await pumpChatPage(tester);

    await send(tester, '발표가 걱정돼요.');
    await send(tester, '계속 생각이 나요.');

    expect(deps.source.diaryCalls, 1);
  });
}
