import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:flutter/services.dart';

import 'package:gad_app_team/widgets/custom_appbar.dart';

/// 근육 이완 명상 페이지
class MuscleRelaxationPage extends StatefulWidget {
  const MuscleRelaxationPage({super.key});

  @override
  State<MuscleRelaxationPage> createState() => _MuscleRelaxationPageState();
}

class _MuscleRelaxationPageState extends State<MuscleRelaxationPage>
    with SingleTickerProviderStateMixin {
  final List<Map<String, String>> steps = [
    {'title': '1. 팔꿈치 아래', 'description': '주먹을 꽉 쥐고 손목을 몸 쪽으로 굽혀주세요.'},
    // {'title': '2. 팔꿈치 윗부분', 'description': '손목을 어깨 쪽으로 조여 팔꿈치를 긴장시켜주세요.'},
    // {'title': '3. 무릎 아래', 'description': '다리를 들어 발끝을 몸 쪽으로 당겨주세요.'},
    // {'title': '4. 배', 'description': '배를 힘껏 조여 긴장시켜주세요.'},
    // {'title': '5. 가슴', 'description': '깊게 숨을 들이쉬며 가슴에 힘을 주세요.'},
    // {'title': '6. 어깨', 'description': '어깨를 귀 쪽으로 힘껏 올리세요.'},
    // {'title': '7. 목', 'description': '턱을 가슴 쪽으로 당겨 목 근육을 긴장시켜주세요.'},
    // {'title': '8. 얼굴', 'description': '입술을 다물고 얼굴 전체에 힘을 주세요.'},
  ];

  final int contractDuration = 1;
  final int relaxDuration = 1;
  final int prepDuration = 1;

  int _currentStep = 0;
  int _prepCountdown = 0;
  int _phaseTime = 0;

  bool _isContracting = true;
  bool _isStarted = false;

  Timer? _prepTimer;
  Timer? _phaseTimer;

  late final AnimationController _animationController;
  late final Animation<double> _iconSizeAnimation;

  @override
  void initState() {
    super.initState();
    _prepCountdown = prepDuration;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _iconSizeAnimation = Tween<double>(begin: 200, end: 300).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _startPrepCountdown();
  }

  void _startPrepCountdown() {
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepCountdown <= 1) {
        timer.cancel();
        _startRelaxation();
      } else {
        setState(() => _prepCountdown--);
      }
    });
  }

  void _startRelaxation() {
    setState(() {
      _isStarted = true;
      _isContracting = true;
      _phaseTime = contractDuration;
    });

    _updateAnimationDuration(contractDuration);
    _animationController.forward();

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _phaseTime--);
      if (_phaseTime <= 0) {
        _isContracting ? _switchToRelaxation() : _advanceToNextStepOrFinish();
      }
    });
  }

  void _switchToRelaxation() {
    setState(() {
      _isContracting = false;
      _phaseTime = relaxDuration;
    });

    _updateAnimationDuration(relaxDuration);
    _animationController.reverse();
    HapticFeedback.mediumImpact();
  }

  void _advanceToNextStepOrFinish() {
    if (_currentStep < steps.length - 1) {
      setState(() {
        _currentStep++;
        _isContracting = true;
        _phaseTime = contractDuration;
      });

      _updateAnimationDuration(contractDuration);
      _animationController.forward();
    } else {
      _phaseTimer?.cancel();
      _showFinishDialog();
    }
  }

  void _updateAnimationDuration(int seconds) {
    _animationController.duration = Duration(seconds: seconds);
  }

  void _showFinishDialog() {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId   = args['abcId'] as String?;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('이완 완료'),
        content: const Text('이제 당신의 온몸은 이완되고 편안함을 느낍니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                '/relaxation_score',
                arguments: {'abcId': abcId}
              );
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = steps[_currentStep];

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '근육 이완'),
      body: Center(
        child: !_isStarted ? _buildPreparationView() : _buildRelaxationView(current),
      ),
    );
  }

  Widget _buildPreparationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.accessibility_new, size: 200, color: AppColors.indigo),
        const SizedBox(height: AppSizes.space),
        const Text('시작 전 준비해주세요.', style: TextStyle(fontSize: AppSizes.fontSize, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.space),
        Text('시작까지 $_prepCountdown초', style: const TextStyle(color: AppColors.grey)),
      ],
    );
  }

  Widget _buildRelaxationView(Map<String, String> current) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(current['title']!, style: const TextStyle(fontSize: AppSizes.fontSize, fontWeight: FontWeight.bold)),
        Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Text(
            current['description']!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppSizes.fontSize),
          ),
        ),
        const SizedBox(height: AppSizes.space),
        AnimatedBuilder(
          animation: _iconSizeAnimation,
          builder: (context, child) {
            return Icon(
              Icons.accessibility_new,
              size: _iconSizeAnimation.value,
              color: _isContracting ? Colors.red.shade300 : Colors.indigo.shade300,
            );
          },
        ),
        const SizedBox(height: AppSizes.space),
        Text(
          _isContracting ? '수축하세요' : '이완하세요',
          style: TextStyle(
            fontSize: AppSizes.fontSize,
            fontWeight: FontWeight.bold,
            color: _isContracting ? Colors.red : Colors.indigo,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        Text('남은 시간: $_phaseTime초', style: const TextStyle(color: AppColors.grey)),
      ],
    );
  }
}