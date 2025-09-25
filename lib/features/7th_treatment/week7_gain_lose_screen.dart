import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';

class Week7GainLoseScreen extends StatefulWidget {
  final String behavior;

  const Week7GainLoseScreen({super.key, required this.behavior});

  @override
  State<Week7GainLoseScreen> createState() => _Week7GainLoseScreenState();
}

class _Week7GainLoseScreenState extends State<Week7GainLoseScreen> {
  final TextEditingController _executionGainController =
      TextEditingController();
  final TextEditingController _executionLoseController =
      TextEditingController();
  final TextEditingController _nonExecutionGainController =
      TextEditingController();
  final TextEditingController _nonExecutionLoseController =
      TextEditingController();

  int _currentStep =
      0; // 0: 단기적 이익, 1: 장기적 이익, 2: 하지 않았을 때 이익, 3: 단기적 불이익, 4: 장기적 불이익
  bool _isNextEnabled = false;
  bool? _hasLongTermBenefit; // 장기적 이익이 있는지 여부
  bool? _hasLongTermDisadvantage; // 장기적 불이익이 있는지 여부

  @override
  void initState() {
    super.initState();
    _executionGainController.addListener(_onTextChanged);
    _executionLoseController.addListener(_onTextChanged);
    _nonExecutionGainController.addListener(_onTextChanged);
    _nonExecutionLoseController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _executionGainController.dispose();
    _executionLoseController.dispose();
    _nonExecutionGainController.dispose();
    _nonExecutionLoseController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      switch (_currentStep) {
        case 0: // 단기적 이익
          _isNextEnabled = _executionGainController.text.trim().isNotEmpty;
          break;
        case 1: // 장기적 이익 (예/아니오)
          _isNextEnabled = _hasLongTermBenefit != null;
          break;
        case 2: // 하지 않았을 때 이익
          _isNextEnabled = _nonExecutionGainController.text.trim().isNotEmpty;
          break;
        case 3: // 단기적 불이익
          _isNextEnabled = _executionLoseController.text.trim().isNotEmpty;
          break;
        case 4: // 장기적 불이익 (예/아니오)
          _isNextEnabled = _hasLongTermDisadvantage != null;
          break;
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
        _isNextEnabled = false;
      });
    }
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return '회피 행동을 했을 때 단기적 이익';
      case 1:
        return '회피 행동을 했을 때 장기적 이익';
      case 2:
        return '회피 행동을 하지 않았을 때의 이익';
      case 3:
        return '회피 행동을 하지 않았을 때의 단기적 불이익';
      case 4:
        return '회피 행동을 하지 않았을 때의 장기적 불이익';
      default:
        return '';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case 0:
        return '이 회피 행동을 했을 때\n즉시 얻을 수 있는 좋은 점은 무엇인가요?';
      case 1:
        return '이 회피 행동을 했을 때\n장기적으로 얻을 수 있는 이익이 있나요?';
      case 2:
        return '이 회피 행동을 하지 않았을 때\n얻을 수 있는 이익은 무엇인가요?';
      case 3:
        return '이 회피 행동을 하지 않았을 때\n즉시 겪을 수 있는 어려운 점은 무엇인가요?';
      case 4:
        return '이 회피 행동을 하지 않았을 때\n장기적으로 겪을 수 있는 어려운 점이 있나요?';
      default:
        return '';
    }
  }

  IconData _getStepIcon() {
    switch (_currentStep) {
      case 0:
        return Icons.flash_on; // 단기적 이익
      case 1:
        return Icons.timeline; // 장기적 이익
      case 2:
        return Icons.trending_up; // 하지 않았을 때 이익
      case 3:
        return Icons.warning; // 단기적 불이익
      case 4:
        return Icons.trending_down; // 장기적 불이익
      default:
        return Icons.help;
    }
  }

  Color _getStepColor() {
    switch (_currentStep) {
      case 0:
        return const Color(0xFF4CAF50); // 초록색 (단기적 이익)
      case 1:
        return const Color(0xFF2196F3); // 파란색 (장기적 이익)
      case 2:
        return const Color(0xFF4CAF50); // 초록색 (하지 않았을 때 이익)
      case 3:
        return const Color(0xFFFF9800); // 주황색 (단기적 불이익)
      case 4:
        return const Color(0xFFFF5722); // 빨간색 (장기적 불이익)
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  TextEditingController _getCurrentController() {
    switch (_currentStep) {
      case 0: // 단기적 이익
        return _executionGainController;
      case 1: // 장기적 이익 (예/아니오)
        return _executionGainController; // 사용하지 않음
      case 2: // 하지 않았을 때 이익
        return _nonExecutionGainController;
      case 3: // 단기적 불이익
        return _executionLoseController;
      case 4: // 장기적 불이익
        return _nonExecutionLoseController;
      default:
        return _executionGainController;
    }
  }

  Widget _buildYesNoSelector() {
    final isStep1 = _currentStep == 1;
    final question = isStep1 ? '장기적으로 이익이 있나요?' : '장기적으로 불이익이 있나요?';
    final currentValue =
        isStep1 ? _hasLongTermBenefit : _hasLongTermDisadvantage;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 예 버튼
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isStep1) {
                    _hasLongTermBenefit = true;
                  } else {
                    _hasLongTermDisadvantage = true;
                  }
                  _isNextEnabled = true;
                });
              },
              child: Container(
                width: 120,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      currentValue == true
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        currentValue == true
                            ? const Color(0xFF4CAF50)
                            : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '예',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color:
                          currentValue == true
                              ? Colors.white
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
            // 아니오 버튼
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isStep1) {
                    _hasLongTermBenefit = false;
                  } else {
                    _hasLongTermDisadvantage = false;
                  }
                  _isNextEnabled = true;
                });
              },
              child: Container(
                width: 120,
                height: 60,
                decoration: BoxDecoration(
                  color:
                      currentValue == false
                          ? const Color(0xFFFF5722)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        currentValue == false
                            ? const Color(0xFFFF5722)
                            : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '아니오',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color:
                          currentValue == false
                              ? Colors.white
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return TextField(
      controller: _getCurrentController(),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: '여기에 입력해주세요...',
        hintStyle: TextStyle(
          fontSize: 16,
          color: _getStepColor().withOpacity(0.5),
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF2D3748),
        height: 1.5,
      ),
    );
  }

  void _showAddToHealthyHabitsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '건강한 생활 습관 추가',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이 행동을 건강한 생활 습관에\n추가하시겠습니까?',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF718096),
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) => const Week7AddDisplayScreen(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      '아니요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) => Week7AddDisplayScreen(
                                initialBehavior: widget.behavior,
                              ),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '예',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '7주차 - 생활 습관 개선'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 진행 단계 표시
              Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                      decoration: BoxDecoration(
                        color:
                            index <= _currentStep
                                ? _getStepColor()
                                : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              // 단계 아이콘
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_getStepColor(), _getStepColor().withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _getStepColor().withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(_getStepIcon(), size: 48, color: Colors.white),
              ),

              const SizedBox(height: 24),

              // 단계 제목
              Text(
                _getStepTitle(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: _getStepColor(),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 단계 설명
              Text(
                _getStepDescription(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF718096),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // 입력 필드 (텍스트 또는 예/아니오)
              Container(
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStepColor().withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getStepColor().withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child:
                    (_currentStep == 1 || _currentStep == 4)
                        ? _buildYesNoSelector() // 장기적 이익/불이익 단계
                        : _buildTextInput(), // 나머지 단계
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 안내 문구
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '입력 중에 "생각이 바뀌었어요. 건강한 생활 습관이 아닌것같아요."라고 생각되면\n아래 문 모양 버튼을 눌러서 돌아갈 수 있어요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6C757D),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 커스텀 네비게이션 버튼 (NavigationButtons와 동일한 스타일)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 이전 버튼 (NavigationButtons와 동일한 스타일)
                FilledButton(
                  onPressed: () {
                    if (_currentStep > 0) {
                      setState(() {
                        _currentStep--;
                        _isNextEnabled =
                            _getCurrentController().text.trim().isNotEmpty;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(AppColors.white),
                    foregroundColor: WidgetStateProperty.all(Colors.indigo),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadius,
                        ),
                        side: BorderSide(color: Colors.indigo.shade100),
                      ),
                    ),
                  ),
                  child: const Text('이전'),
                ),
                // 생각이 바뀌었어요 버튼 (문 모양 - 원형)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (_, __, ___) => const Week7AddDisplayScreen(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: const Icon(
                        Icons.door_front_door_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // 다음 버튼 (NavigationButtons와 동일한 스타일)
                FilledButton(
                  onPressed:
                      _isNextEnabled
                          ? () {
                            if (_currentStep < 4) {
                              _nextStep();
                            } else {
                              // 모든 단계 완료, 모달창 표시
                              _showAddToHealthyHabitsDialog();
                            }
                          }
                          : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled)) {
                        return AppColors.grey300;
                      }
                      return Colors.indigo;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey;
                      }
                      return AppColors.white;
                    }),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadius,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('다음'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
