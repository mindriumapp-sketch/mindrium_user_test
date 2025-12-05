/// 단어(공백 기준) 안에서는 줄바꿈이 일어나지 않도록
/// 각 글자 사이에 WORD JOINER(U+2060)를 삽입하는 함수.
/// - [[ ]] / ** ** / __ __ 같은 마크다운/하이라이트 마커는 깨지지 않게 예외 처리.
String protectKoreanWords(String text) {
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  final words = text.split(' ');

  for (int i = 0; i < words.length; i++) {
    final word = words[i];

    for (final codePoint in word.runes) {
      final ch = String.fromCharCode(codePoint); // code point 단위로 순회해 이모지 서러게이트 분리 방지
      buffer.write(ch);

      // 하이라이트/마크다운 마커는 깨지지 않도록 WORD JOINER를 붙이지 않음
      if (ch != '[' && ch != ']' && ch != '*' && ch != '_') {
        buffer.write('\u2060'); // WORD JOINER
      }
    }

    if (i != words.length - 1) {
      buffer.write(' ');
    }
  }

  return buffer.toString();
}
