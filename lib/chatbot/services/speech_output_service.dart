import 'dart:async';
import 'dart:io' if (dart.library.html) '../utils/file_stub.dart' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_tts/flutter_tts.dart';

/// 음성 출력. presentation/접근성 계층에만 존재한다.
///
/// CounselingProvider 와 CounselingHarness 는 이 타입을 몰라야 한다. 상담 의사결정과
/// 음성 출력은 서로 독립이며, 음성이 꺼져 있어도 상담은 그대로 동작해야 한다.
abstract class SpeechOutputService {
  /// 재생 준비. 실패해도 예외를 던지지 않고 [isReady] 가 false 로 남는다.
  Future<void> initialize();

  bool get isReady;

  /// 말하기. 재생이 끝날 때까지 기다린다.
  Future<void> speak(String text);

  Future<void> stop();

  Future<void> dispose();

  /// 재생이 시작/종료될 때 알린다. STT 와의 충돌을 화면이 조정할 수 있게 열어 둔다.
  set onSpeakingChanged(void Function(bool speaking)? callback);
}

/// flutter_tts 구현.
class FlutterTtsSpeechOutputService implements SpeechOutputService {
  final FlutterTts _tts;

  bool _ready = false;
  bool _primed = false;
  void Function(bool speaking)? _onSpeakingChanged;

  /// 재생 완료를 기다리는 데 쓰는 completer. 한 번에 하나만 유지한다.
  Completer<void>? _speaking;

  FlutterTtsSpeechOutputService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  @override
  bool get isReady => _ready;

  @override
  set onSpeakingChanged(void Function(bool speaking)? callback) {
    _onSpeakingChanged = callback;
  }

  @override
  Future<void> initialize() async {
    try {
      await _tts.setLanguage('ko-KR');
      if (kIsWeb) {
        await _tts.setSpeechRate(0.5);
      } else if (Platform.isAndroid) {
        await _tts.setSpeechRate(0.5);
      } else if (Platform.isIOS) {
        await _tts.setSpeechRate(0.5);
        await _tts.setSharedInstance(true);
      } else {
        await _tts.setSpeechRate(1.0);
      }
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);

      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      } catch (_) {
        // iOS 전용 설정이라 다른 플랫폼에서는 실패해도 무시한다.
      }

      _tts.setStartHandler(() => _setSpeaking(true));
      _tts.setCompletionHandler(_finish);
      _tts.setCancelHandler(_finish);
      _tts.setErrorHandler((msg) {
        debugPrint('[SpeechOutput] TTS 오류: $msg');
        _finish();
      });

      _ready = true;
    } catch (e) {
      debugPrint('[SpeechOutput] 초기화 실패: $e');
      _ready = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_ready) return;

    // 마크다운 강조와 줄바꿈은 읽을 때 방해가 된다.
    final normalized = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\*+'), '')
        .trim();
    if (normalized.isEmpty) return;

    await _prime();
    await stop();

    final completer = Completer<void>();
    _speaking = completer;
    _setSpeaking(true);

    final result = await _tts.speak(normalized);
    if (result != 1) {
      _finish();
      return;
    }

    // 완료 핸들러가 오지 않는 경우를 대비해 상한을 둔다.
    await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: _finish,
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // 재생 중이 아닐 때 stop 은 실패할 수 있다.
    }
    _finish();
  }

  @override
  Future<void> dispose() async {
    await stop();
    _onSpeakingChanged = null;
  }

  /// 웹은 사용자 제스처 이후에만 소리를 낼 수 있어 무음 재생으로 한 번 깨운다.
  Future<void> _prime() async {
    if (_primed || !_ready) return;
    if (!kIsWeb) {
      _primed = true;
      return;
    }
    try {
      await _tts.setVolume(0.0);
      await _tts.speak('a');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _tts.stop();
      await _tts.setVolume(1.0);
      _primed = true;
    } catch (e) {
      debugPrint('[SpeechOutput] priming 실패: $e');
    }
  }

  void _finish() {
    final completer = _speaking;
    _speaking = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    _setSpeaking(false);
  }

  void _setSpeaking(bool speaking) => _onSpeakingChanged?.call(speaking);
}

/// 음성을 내지 않는 구현. 테스트와 음성 비활성 환경에서 쓴다.
class NoopSpeechOutputService implements SpeechOutputService {
  /// 어떤 문장을 말하라고 요청받았는지 기록한다.
  final List<String> spoken = [];
  int stopCount = 0;
  int disposeCount = 0;

  @override
  bool get isReady => true;

  @override
  set onSpeakingChanged(void Function(bool speaking)? callback) {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> dispose() async => disposeCount++;
}
