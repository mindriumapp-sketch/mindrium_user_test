/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class BreathingMeditationPage extends StatefulWidget {
  const BreathingMeditationPage({super.key});

  @override
  State<BreathingMeditationPage> createState() => _BreathingMeditationPageState();
}

class _BreathingMeditationPageState extends State<BreathingMeditationPage>
    with SingleTickerProviderStateMixin {
  static const int inhaleDuration = 4;
  static const int exhaleDuration = 6;
  static const int prepDuration = 5;
  static const int totalSeconds = 60;

  int _secondsLeft = totalSeconds;
  int _prepCountdown = prepDuration;
  bool _isInhale = true;
  bool _isStarted = false;
  int _phaseSeconds = inhaleDuration;

  late final AnimationController _animationController;
  late final Animation<double> _sizeAnimation;

  Timer? _prepTimer;
  Timer? _phaseTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: inhaleDuration),
    );
    _sizeAnimation = Tween<double>(begin: 200, end: 300).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _startPrepCountdown();
  }

  void _startPrepCountdown() {
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepCountdown <= 1) {
        timer.cancel();
        _startMeditation();
      } else {
        setState(() => _prepCountdown--);
      }
    });
  }

  void _startMeditation() {
    setState(() {
      _isStarted = true;
      _isInhale = true;
      _phaseSeconds = inhaleDuration;
    });

    _animationController.duration = const Duration(seconds: inhaleDuration);
    _animationController.forward();

    _startPhaseTimer();
    _startCountdownTimer();
  }

  void _startPhaseTimer() {
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phaseSeconds <= 1) {
        setState(() {
          _isInhale = !_isInhale;
          _phaseSeconds = _isInhale ? inhaleDuration : exhaleDuration;
        });

        _animationController.duration = Duration(seconds: _phaseSeconds);
        _isInhale ? _animationController.forward() : _animationController.reverse();
        HapticFeedback.mediumImpact();
      } else {
        setState(() => _phaseSeconds--);
      }
    });
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        _stopSession();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _stopSession() {
    _phaseTimer?.cancel();
    _countdownTimer?.cancel();
    _animationController.stop();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('호흡 명상 완료'),
        content: const Text('점진적 근육 이완을 시작하겠습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pushNamed(context, '/muscle_relaxation');
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _phaseTimer?.cancel();
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildBreathingCircle() {
    return AnimatedBuilder(
      animation: _sizeAnimation,
      builder: (context, child) {
        return Container(
          width: _sizeAnimation.value,
          height: _sizeAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.indigo100,
                Colors.indigo,
                Colors.indigo,
              ],
              center: Alignment.center,
              radius: 0.85,
            ),
          ),
          child: const Center(
            child: Icon(Icons.self_improvement, size: 100, color: AppColors.white),
          ),
        );
      },
    );
  }

  Widget _buildInstructionText() {
    if (!_isStarted) {
      return Column(
        children: [
          const Text(
            '시작 전 준비해주세요',
            style: TextStyle(color: Colors.black, fontSize: AppSizes.fontSize, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSizes.space),
          Text('시작까지 $_prepCountdown초', style: const TextStyle(color: Colors.grey, fontSize: AppSizes.fontSize)),
        ],
      );
    } else {
      return Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _isInhale ? '들이쉬세요' : '내쉬세요',
              key: ValueKey<bool>(_isInhale),
              style: const TextStyle(fontSize: AppSizes.fontSize, fontWeight: FontWeight.bold, color: AppColors.indigo),
            ),
          ),
          const SizedBox(height: AppSizes.space),
          Text('남은 시간: $_phaseSeconds초', style: const TextStyle(color: AppColors.grey)),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '호흡 명상'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBreathingCircle(),
            const SizedBox(height: AppSizes.space),
            _buildInstructionText(),
          ],
        ),
      ),
    );
  }
}
*/