import 'package:gad_app_team/data/counseling/counseling_models.dart';

/// 의미가 같은 문형 중 최근 상담자가 쓰지 않은 것을 고른다.
///
/// 무작위 선택을 쓰지 않으므로 같은 대화 이력에는 항상 같은 결과가 나온다.
/// 모든 문형을 이미 썼다면 사용자 발화의 안정 해시로 하나를 고른다.
class DeterministicSurfaceVariation {
  const DeterministicSurfaceVariation();

  String select({
    required List<String> candidates,
    List<CounselingMessage> recentMessages = const [],
    String seed = '',
    List<String>? repetitionMarkers,
  }) {
    assert(candidates.isNotEmpty);
    assert(
      repetitionMarkers == null ||
          repetitionMarkers.length == candidates.length,
    );
    final assistantText = recentMessages
        .where((message) => !message.isUser)
        .map((message) => message.text)
        .join('\n');

    for (var index = 0; index < candidates.length; index++) {
      final marker = repetitionMarkers?[index] ?? candidates[index];
      if (!assistantText.contains(marker)) return candidates[index];
    }

    return candidates[_stableHash(seed) % candidates.length];
  }

  int _stableHash(String value) {
    var hash = 0;
    for (final rune in value.runes) {
      hash = ((hash * 31) + rune) & 0x7fffffff;
    }
    return hash;
  }
}
