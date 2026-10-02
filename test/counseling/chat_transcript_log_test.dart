// The on-device transcript must not lose or reorder turns, even when the
// user and assistant appends are fired without awaiting (dogfood 2026-10-02:
// concurrent read-modify-write dropped user messages).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gad_app_team/chatbot/services/chat_transcript_log.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('transcript_'));
  tearDown(() => dir.deleteSync(recursive: true));

  const tricky = [
    '아니 싫어 그만해',
    '왜 너 할말만해?',
    '띄어쓰기없이쓰면어떻게돼',
    '이모지도 😥🙏 들어가고',
    '줄바꿈\n두 줄로\r\n세 줄',
    '"따옴표"랑 \'작은따옴표\' 그리고 \\역슬래시',
    'ㅋㅋㅋ ㅠㅠ ㄹㅇ',
    '{"json":"처럼 보이는 문장"}',
    '',
  ];

  test('fire-and-forget appends keep every turn, in order, losslessly', () async {
    final log = await ChatTranscriptLog.create(dir, now: DateTime(2026, 10, 2));
    final expected = <(String, String)>[];
    for (var round = 0; round < 20; round++) {
      for (final t in tricky) {
        // like the chat screen: neither call is awaited
        log.append(role: 'user', text: '$t #$round');
        log.append(role: 'ai', text: '응답 $round: $t');
        expected
          ..add(('user', '$t #$round'))
          ..add(('ai', '응답 $round: $t'));
      }
    }
    await log.flush();

    final saved = (jsonDecode(log.file.readAsStringSync()) as Map)['messages'] as List;
    expect(saved.length, expected.length);
    expect(log.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect((saved[i]['role'], saved[i]['text']), expected[i]);
    }
    expect(File('${log.file.path}.tmp').existsSync(), isFalse);
  });

  test('the file is valid JSON after every flushed append', () async {
    final log = await ChatTranscriptLog.create(dir);
    for (final t in tricky) {
      await log.append(role: 'user', text: t);
      expect(() => jsonDecode(log.file.readAsStringSync()), returnsNormally);
    }
  });
}
