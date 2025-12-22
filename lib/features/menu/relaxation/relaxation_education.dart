import 'dart:async';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:rive/rive.dart' as rive;
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'relaxation_logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

// --- 주차 타이틀 ---
const Map<int, String> kRelaxationWeekTitles = {
  1: '1주차 - 점진적 이완',
  2: '2주차 - 점진적 이완',
  3: '3주차 - 이완만 하는 이완',
  4: '4주차 - 신호 조절 이완',
  5: '5주차 - 차등 이완',
  6: '6주차 - 차등 이완',
  7: '7주차 - 신속 이완',
};


//TODO: --- 주차 화면 수 ---
const Map<int, int> kWeekScreens = {
  1: 6,
  2: 15,
  3: 12,
  4: 12,
  5: 12,
  6: 12,
  7: 12,
  8: 12,
};

String relaxationTitleForWeek(int? week) {
  final w = week ?? 1;
  return kRelaxationWeekTitles[w] ?? '$w주차 이완 훈련';
}

// 초기 싱크 보정
const Duration _kInitialAudioDelay = Duration(milliseconds: 0);
// 중간 자동 저장 주기
const Duration _kAutosaveInterval = Duration(seconds: 30);

// ✅ 전역 네비게이터 키 (검은화면 방지용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PracticePlayer extends StatefulWidget {
  final String? sessionId;
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;

  const PracticePlayer({
    super.key,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
    this.sessionId,
  });

  @override
  State<PracticePlayer> createState() => _PracticePlayerState();
}

class _PracticePlayerState extends State<PracticePlayer>
    with WidgetsBindingObserver {
  late final rive.FileLoader _fileLoader = rive.FileLoader.fromAsset(
    'assets/relaxation/${widget.riveAsset}',
    riveFactory: rive.Factory.rive,
  );

  rive.RiveWidgetController? _riveController;
  rive.StateMachine? _stateMachine;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isAudioFinished = false;
  bool _isRiveFinished = false;

  late final RelaxationLogger _logger;

  bool _finalSaved = false;
  Timer? _autosaveTimer;
  bool _audioStartedOnce = false;

// ✅ 현재 활성 상태가 시작된 시점
  DateTime? _lastActivityTime;

  late final ApiClient _apiClient;
  late final EduSessionsApi _eduSessionsApi;
  bool _sessionUpdated = false; // 중복 호출 방지

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _logger = RelaxationLogger(
      taskId: widget.taskId,
      weekNumber: widget.weekNumber,
    );
    _logger.logEvent("start");

    // 🔥 세션 시작 시점에 위치 한 번만 캡처해서 logger에 넣음
    _captureStartLocation();

    _apiClient = ApiClient(tokens: TokenStorage());
    _eduSessionsApi = EduSessionsApi(_apiClient);

    _startAutosaveTimer();
  }

  void _startAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(_kAutosaveInterval, (_) async {
      _logger.logEvent("autosave_tick");
      try {
        await _logger.saveLogs();
      } catch (e) {
        debugPrint('autosave error: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // 재생 중이었다면 재생 중지
      if (_isPlaying) {
        _audioPlayer.pause();
        _riveController?.active = false;
        _isPlaying = false;
      }
      _saveOnce(reason: 'app_paused');
    } else if (state == AppLifecycleState.resumed) {
      _startAutosaveTimer();
      // ✅ Resume 시 재생 중이었다면 활성 시간 측정 재개
      if (_isPlaying) {
        _lastActivityTime = DateTime.now();
      }
    }
  }

  Future<void> _startAudioOnce() async {
    if (_audioStartedOnce) return;
    _audioStartedOnce = true;
    await _audioPlayer.setSource(AssetSource('relaxation/${widget.mp3Asset}'));
    await _audioPlayer.setVolume(0.8);
    await Future.delayed(_kInitialAudioDelay);

    // ✅ 최초 재생 시작 시 활성 시간 측정 시작
    _lastActivityTime = DateTime.now();

    await _audioPlayer.resume();
    setState(() => _isPlaying = true);

    _audioPlayer.onPlayerComplete.listen((_) {
      _isAudioFinished = true;
      _logger.logEvent("audio_complete");
      _checkIfBothFinished();
    });
  }

  void _togglePlay() {
    if (_isPlaying) {
      _lastActivityTime = null; // 활성 시간 측정 중지
      _audioPlayer.pause();
      _riveController?.active = false;
      _logger.logEvent("pause");
    } else {
      _lastActivityTime = DateTime.now(); // 활성 시간 측정 시작
      _audioPlayer.resume();
      _riveController?.active = true;
      _logger.logEvent("resume");
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _saveOnce({required String reason}) async {
    if (_finalSaved) return;
    // 최종 세이브 전 측정 중지 (Pause와 동일 로직)
    if (_isPlaying && _lastActivityTime != null) {
      _lastActivityTime = null;
    }

    _finalSaved = true;

    try {
      _logger.logEvent("final_save_$reason");
      await _logger.saveLogs();
    } catch (e) {
      debugPrint('saveLogs error ($reason): $e');
    }
  }

  /// ✅ edu-sessions + UserProvider 로컬 진행도 동기화
  Future<void> _updateEduSessionOnComplete() async {
    final sessionId = widget.sessionId;

    // 세션 ID 없으면 조용히 스킵
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('[PracticePlayer] sessionId 없음, edu-sessions 업데이트 스킵');
      return;
    }
    if (_sessionUpdated) return;

    _sessionUpdated = true;

    try {
      // 1) 백엔드 edu_sessions 업데이트
      await _eduSessionsApi.updateEduSession(
        sessionId: sessionId,
        completed: true,
        lastScreenIndex: kWeekScreens[widget.weekNumber],
        endTime: DateTime.now(),
      );
      debugPrint('[PracticePlayer] edu-sessions 업데이트 성공 (sessionId=$sessionId)');

      // 2) 성공한 경우에만 UserProvider에서 /users/me/progress 다시 로딩
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      await userProvider.refreshProgress();
    } catch (e) {
      // 네비게이션은 막지 않고 로그만 남김
      debugPrint('[PracticePlayer] edu-sessions 업데이트 or progress refresh 실패: $e');
    }
  }

  void _checkIfBothFinished() async {
    if (_isAudioFinished && _isRiveFinished) {
      // ✅ 완주 플래그 먼저 세움
      _logger.setFullyCompleted();
      _logger.logEvent("session_complete");

      await _saveOnce(reason: 'complete');
      await _updateEduSessionOnComplete();
      if (!mounted) return;

      if (widget.taskId.contains('menu')) {
        Navigator.pushNamedAndRemoveUntil(context, '/contents', (_) => false);
      }
      else {
        Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
      }
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _audioPlayer.dispose();
    _saveOnce(reason: 'dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        _saveOnce(reason: 'back');
      },
      child: GestureDetector(
        onTap: _togglePlay,
        child: Scaffold(
          backgroundColor: AppColors.white,
          appBar: CustomAppBar(
            title: relaxationTitleForWeek(widget.weekNumber),
            showHome: true,
            confirmOnBack: true,
          ),
          body: Stack(
            children: [
              Center(
                child: rive.RiveWidgetBuilder(
                  fileLoader: _fileLoader,
                  builder: (context, state) {
                    if (state is rive.RiveLoading) {
                      return const CircularProgressIndicator();
                    }
                    if (state is rive.RiveFailed) {
                      debugPrint('Rive load failed: ${state.error}');
                      _isRiveFinished = true; // Rive는 완료 취급
                      _logger.logEvent("rive_failed");
                      return const SizedBox.shrink();
                    }
                    if (state is rive.RiveLoaded) {
                      if (_riveController == null) {
                        _riveController = rive.RiveWidgetController(
                          state.file,
                          stateMachineSelector: rive.StateMachineSelector.byName('State Machine 1'),
                          // artboardSelector: rive.ArtboardSelector.byName('Main'), // 필요 시
                        );

                        _stateMachine = _riveController!.stateMachine;

                        if (_stateMachine == null) {
                          // ✅ 디버깅용 로그만 남기고 '완료'로 몰지 않기
                          _logger.logEvent("rive_state_machine_missing");
                        } else {
                          // 이벤트 리스너 등록
                          _stateMachine!.addEventListener((event) {
                            if (event.name == 'done') {
                              if (_isRiveFinished) return;
                              _isRiveFinished = true;
                              _logger.logEvent("rive_complete");
                              _checkIfBothFinished();
                            }
                          });
                          // 시작
                          _riveController!.active = true;
                        }

                        _startAudioOnce();
                      }

                      return rive.RiveWidget(
                        controller: _riveController!,
                        fit: rive.Fit.contain,
                        alignment: Alignment.center,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              if (!_isPlaying)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureStartLocation() async {
    try {
      // 1) 권한 상태만 확인 (❌ 새로 요청은 안 함)
      final perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever ||
          perm == LocationPermission.unableToDetermine) {
        // 권한 없으면 조용히 위치 로깅 생략
        debugPrint('위치 권한 없음, 위치 로깅 생략');
        return;
      }

      // 2) 이미 허용된 경우에만 현재 위치 가져오기
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      // 3) 좌표 → 주소 문자열 변환 (가능하면)
      String? addressName;
      try {
        await setLocaleIdentifier('ko_KR');
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final components = <String?>[
            p.administrativeArea,
            p.locality,
            p.subLocality,
            p.thoroughfare,
          ];

          addressName = components
              .whereType<String>()
              .where((e) => e.isNotEmpty)
              .join(' ');
        }
      } catch (e) {
        debugPrint('reverse geocoding 실패: $e');
      }

      // 4) Logger에 위치 정보 저장 (없으면 null로 들어감)
      _logger.updateLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        addressName: addressName,
      );
    } catch (e) {
      debugPrint('위치 캡처 실패: $e');
    }
  }
}
