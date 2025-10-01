import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:rive/rive.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'relaxation_logger.dart';  // 분리한 로거

class PracticePlayer extends StatefulWidget {
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
  });

  @override
  State<PracticePlayer> createState() => _PracticePlayerState();
}

class _PracticePlayerState extends State<PracticePlayer> {
  Artboard? _artboard;
  StateMachineController? _controller;
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
    final data = await rootBundle.load(widget.riveAsset);
    final file = RiveFile.import(data);
    final artboard = file.mainArtboard;

    final controller = StateMachineController.fromArtboard(artboard, 'StateMachine1');
    if (controller != null) {
      artboard.addController(controller);

      controller.isActiveChanged.addListener(() {
        if (!controller.isActive) {
          _isRiveFinished = true;
          _logger.logEvent("rive_complete");
          _checkIfBothFinished();
        }
      });

      setState(() {
        _artboard = artboard;
        _controller = controller;
      });
    }
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setSource(AssetSource(widget.mp3Asset));
    await _audioPlayer.setVolume(0.8);
    await _audioPlayer.resume();

    _audioPlayer.onPlayerComplete.listen((event) {
      _isAudioFinished = true;
      _logger.logEvent("audio_complete");
      _checkIfBothFinished();
    });
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

