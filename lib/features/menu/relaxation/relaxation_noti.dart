import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:rive/rive.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'relaxation_logger.dart';  // 분리한 로거

class NotiPlayer extends StatefulWidget {
  final String taskId;
  final int weekNumber;
  final String mp3Asset;
  final String riveAsset;
  final String nextPage;

  const NotiPlayer({
    super.key,
    required this.taskId,
    required this.weekNumber,
    required this.mp3Asset,
    required this.riveAsset,
    required this.nextPage,
  });

  @override
  State<NotiPlayer> createState() => _NotiPlayerState();
}

class _NotiPlayerState extends State<NotiPlayer> {
  Artboard? _artboard;
  RiveAnimationController? _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = true;
  bool _isAudioFinished = false;
  bool _isRiveFinished = false;

  late final SessionLogger _logger;

  @override
  void initState() {
    super.initState();
    _logger = SessionLogger(
      taskId: widget.taskId,
      weekNumber: widget.weekNumber,
    );
    _logger.logEvent("start");

    _initRive();
    _initAudio();
  }

  Future<void> _initRive() async {
    await RiveFile.initialize();
    try {
      final data = await rootBundle.load(_resolveRiveAsset(widget.riveAsset));
      final file = RiveFile.import(data);
      final artboard = file.mainArtboard;

      RiveAnimationController? controller =
          StateMachineController.fromArtboard(artboard, 'StateMachine1');

      // Fallback: if there is no StateMachine named 'StateMachine1', start the first available animation.
      if (controller == null && artboard.animations.isNotEmpty) {
        controller = SimpleAnimation(artboard.animations.first.name);
        _logger.logEvent("rive_controller_fallback_${artboard.animations.first.name}");
      }

      if (controller != null) {
        artboard.addController(controller);
        _controller = controller;
      } else {
        _logger.logEvent("rive_no_controller");
      }

      // Always set the artboard so UI stops showing the spinner even if no controller found.
      setState(() {
        _artboard = artboard;
      });

      if (_isPlaying) {
        _controller?.isActive = true;
      }
    } catch (e) {
      _logger.logEvent("rive_load_error:$e");
      setState(() {
        _artboard = null;
      });
    }
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setSource(AssetSource(_resolveAudioAsset(widget.mp3Asset)));
    await _audioPlayer.setVolume(1);

    _audioPlayer.onPlayerComplete.listen((event) {
      _isAudioFinished = true;
      _isRiveFinished = true; // Tie Rive finish to audio end to avoid false positives from pauses
      _controller?.isActive = false;
      _logger.logEvent("audio_complete");
      _logger.logEvent("rive_complete");
      _checkIfBothFinished();
    });

    await _audioPlayer.resume();
    if (_isPlaying) {
      _controller?.isActive = true;
    }
  }

  String _resolveRiveAsset(String asset) {
    if (asset.startsWith('assets/')) {
      return asset;
    }
    if (asset.contains('/')) {
      return 'assets/$asset';
    }
    return 'assets/relaxation/$asset';
  }

  String _resolveAudioAsset(String asset) {
    final normalized = asset.startsWith('assets/')
        ? asset.substring('assets/'.length)
        : asset;
    if (normalized.contains('/')) {
      return normalized;
    }
    return 'relaxation/$normalized';
  }

  void _togglePlay() {
    if (_isPlaying) {
      _audioPlayer.pause();
      _controller?.isActive = false;
      _logger.logEvent("pause");
    } else {
      _audioPlayer.resume();
      _controller?.isActive = true;
      _logger.logEvent("resume");
    }

    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _checkIfBothFinished() async {
    if (_isAudioFinished && _isRiveFinished) {
      _logger.logEvent("session_complete");
      await _logger.saveLogs();  // DB 저장
      // TODO: 알림 후에 이완 다음 페이지 (세현님 알림 알고리즘이 어떻게 되나요...)
      Navigator.pushReplacementNamed(
        context,
        widget.nextPage,
        arguments: {
          'origin': 'apply'
        },
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: CustomAppBar(title: '${widget.weekNumber}주차 이완 훈련', showHome: false),
        body: Stack(
          children: [
            Center(
              child: _artboard == null
                  ? const CircularProgressIndicator()
                  : Rive(artboard: _artboard!),
            ),
            if (!_isPlaying)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
