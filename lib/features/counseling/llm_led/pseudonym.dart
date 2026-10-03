import 'dart:convert';

/// 세션 id를 기록용 가명으로 바꾼다(FNV-1a 32비트). 되돌릴 수 없다.
/// `LLM_LED` 로그에 원래 세션 id 대신 쓴다.
String pseudonymize(String sessionId) {
  var h = 0x811c9dc5;
  for (final unit in utf8.encode(sessionId)) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
