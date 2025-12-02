import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

typedef TextHandler = void Function(String);

class CharacterBattleAsr {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;
  String _recognized = '';

  bool get isReady => _ready;
  bool get isListening => _listening;
  String get recognizedText => _recognized;

  /// 초기화
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(Object error)? onError,
  }) async {
    try {
      _ready = await _speech.initialize(
        onStatus: (s) {
          debugPrint('🎤 [Battle STT Status] $s');
          if (onStatus != null) onStatus(s);
          if (s == 'notListening') _listening = false;
        },
        onError: (e) {
          debugPrint('❌ [Battle STT Error] ${e.errorMsg}');
          if (onError != null) onError(e);
          _listening = false;
        },
        debugLogging: true,
      );

      if (_ready) {
        debugPrint('✅ [Battle STT] 초기화 성공');
      } else {
        debugPrint('❌ [Battle STT] 초기화 실패');
      }
    } catch (e) {
      debugPrint('❌ [Battle STT Exception] $e');
      _ready = false;
      if (onError != null) onError(e);
    }
    return _ready;
  }

  /// 음성 인식 시작
  Future<bool> startListening({
    String localeId = 'ko_KR',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 5),
    TextHandler? onPartial,
    TextHandler? onFinal,
  }) async {
    if (!_ready) {
      debugPrint('⚠️ [Battle STT] 재초기화 필요');
      final ok = await initialize();
      if (!ok) return false;
    }

    if (!_speech.isAvailable) {
      debugPrint('❌ [Battle STT] 사용 불가');
      return false;
    }

    _recognized = '';
    _listening = true;

    try {
      debugPrint('🎤 [Battle STT] 리스닝 시작');
      final options = stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );

      await _speech.listen(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: options,
        onResult: (r) {
          _recognized = r.recognizedWords;
          debugPrint('📝 [Partial] ${r.recognizedWords}');

          if (onPartial != null) onPartial(_recognized);

          if (r.finalResult) {
            _listening = false;
            final trimmed = _recognized.trim();
            debugPrint('✅ [Final] "$trimmed"');
            if (onFinal != null) onFinal(trimmed);
          }
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ [Battle STT Listen Error] $e');
      _listening = false;
      return false;
    }
  }

  /// 중지
  Future<void> stop() async {
    try {
      debugPrint('🛑 [Battle STT] 중지');
      await _speech.cancel();
    } catch (e) {
      debugPrint('❌ [Stop Error] $e');
    }
    _listening = false;
  }

  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
  }

  // ========== 매칭 헬퍼 ==========

  static int chooseBestIndex(List<String> skills, String utter) {
    final q = utter.trim().toLowerCase();
    if (q.isEmpty || skills.isEmpty) return -1;

    List<MapEntry<int, double>> scores = [];
    for (int i = 0; i < skills.length; i++) {
      final s = skills[i].toLowerCase();
      final score = similarity(q, s);
      scores.add(MapEntry(i, score));
    }

    scores.sort((a, b) => b.value.compareTo(a.value));

    debugPrint('\n🎯 [매칭 결과] "$q"');
    for (int i = 0; i < (scores.length < 3 ? scores.length : 3); i++) {
      final idx = scores[i].key;
      final score = scores[i].value;
      debugPrint('  ${i + 1}위: "${skills[idx]}" (${score.toStringAsFixed(2)})');
    }

    return scores.isNotEmpty ? scores[0].key : -1;
  }

  static double similarity(String a, String b) {
    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();

    if (aLower == bLower) return 1.0;
    if (aLower.contains(bLower) || bLower.contains(aLower)) return 0.8;

    final charScore = _characterSimilarity(aLower, bLower);
    if (charScore > 0.6) return charScore;

    final ta = aLower.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toSet();
    final tb = bLower.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toSet();

    if (ta.isEmpty || tb.isEmpty) return 0.0;

    final inter = ta.intersection(tb).length.toDouble();
    final union = (ta.length + tb.length - inter).toDouble();
    return union == 0 ? 0.0 : inter / union;
  }

  static double _characterSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    int matches = 0;
    final minLen = a.length < b.length ? a.length : b.length;

    for (int i = 0; i < minLen; i++) {
      if (a[i] == b[i]) matches++;
    }

    final maxLen = a.length > b.length ? a.length : b.length;
    return matches / maxLen;
  }
}
