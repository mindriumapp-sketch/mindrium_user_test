import 'dart:convert';
import 'dart:io'
    if (dart.library.html) '../utils/file_stub.dart'
    show File, Directory;

import 'package:flutter/foundation.dart' show debugPrint;

/// 기기 로컬 대화 기록(개발·dogfood 분석용). 외부로 보내지 않는다.
///
/// 예전에는 매번 파일을 읽어 고친 뒤 다시 썼고, 사용자 발화와 응답 기록을
/// 기다리지 않고 동시에 실행했다. 그래서 한쪽 쓰기가 다른 쪽을 덮어쓰거나, 쓰는
/// 중인 파일을 읽다가 디코딩 오류가 나 사용자 발화가 빠졌다(dogfood 2026-10-02).
/// 지금은 문서를 메모리에 두고, 쓰기를 순서대로 줄 세우고, 임시 파일에 쓴 뒤
/// 이름을 바꾼다.
class ChatTranscriptLog {
  final File file;
  final Map<String, dynamic> _doc;
  Future<void> _queue = Future<void>.value();

  ChatTranscriptLog._(this.file, this._doc);

  static Future<ChatTranscriptLog> create(Directory dir, {DateTime? now}) async {
    final started = now ?? DateTime.now();
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = started.toIso8601String().replaceAll(':', '-');
    final log = ChatTranscriptLog._(
      File('${dir.path}/chat_session_$ts.json'),
      {
        'sessionId': ts,
        'startedAt': started.toIso8601String(),
        'messages': <Map<String, dynamic>>[],
      },
    );
    await log._enqueue();
    return log;
  }

  int get length => (_doc['messages'] as List).length;

  /// 순서대로 기록한다. 반환된 Future를 기다리지 않아도 순서와 내용은 보존된다.
  Future<void> append({
    required String role,
    required String text,
    Map<String, dynamic>? extra,
  }) {
    (_doc['messages'] as List).add({
      'ts': DateTime.now().toIso8601String(),
      'role': role,
      'text': text,
      if (extra != null) ...extra,
    });
    return _enqueue();
  }

  /// 대기 중인 쓰기가 모두 끝날 때까지 기다린다.
  Future<void> flush() => _queue;

  Future<void> _enqueue() {
    final snapshot = jsonEncode(_doc);
    _queue = _queue
        .then((_) => _write(snapshot))
        .catchError((Object e) => debugPrint('chat transcript log error: $e'));
    return _queue;
  }

  Future<void> _write(String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  }
}
