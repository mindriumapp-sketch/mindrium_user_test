import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/8th_treatment/week8_planning_check_screen.dart';

class Week8Gad7Screen extends StatefulWidget {
  const Week8Gad7Screen({super.key});

  @override
  State<Week8Gad7Screen> createState() => _Week8Gad7ScreenState();
}

class _Week8Gad7ScreenState extends State<Week8Gad7Screen> {
  final List<int> _answers = List.filled(7, -1); // -1: 선택 안함, 0-3: 점수
  bool _isCompleted = false;

  final List<String> _questions = [
    '최근 2주간, 초조하거나 불안하거나 조마조마하게 느낀다.',
    '최근 2주간, 걱정하는 것을 멈추거나 조절할 수가 없다.',
    '최근 2주간, 여러 가지 것들에 대해 걱정을 너무 많이 한다.',
    '최근 2주간, 편하게 있기가 어렵다.',
    '최근 2주간, 쉽게 짜증이 나거나 쉽게 성을 내게 된다.',
    '최근 2주간, 너무 안절부절못해서 가만히 있기가 힘들다.',
    '최근 2주간, 마치 끔찍한 일이 생길 것처럼 두렵게 느껴진다.',
  ];

  final List<String> _options = ['없음', '2,3일 이상', '7일 이상', '거의 매일'];

  void _selectAnswer(int questionIndex, int answerIndex) {
    setState(() {
      _answers[questionIndex] = answerIndex; // 0~3점으로 변경
      _isCompleted = _answers.every((answer) => answer >= 0);
    });
  }

  int _calculateScore() {
    return _answers.reduce((sum, answer) => sum + answer);
  }

  String _getScoreInterpretation(int score) {
    if (score <= 4) return '최소한의 불안';
    if (score <= 9) return '경미한 불안';
    if (score <= 14) return '중등도의 불안';
    return '심한 불안';
  }

  Color _getScoreColor(int score) {
    if (score <= 4) return Colors.green;
    if (score <= 9) return Colors.orange;
    if (score <= 14) return Colors.red;
    return Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '8주차 - GAD-7 평가'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.space),

            // 안내 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'GAD-7 불안 평가',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '지난 2주 동안 다음 증상들이\n얼마나 자주 발생했는지 평가해주세요.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.space * 2),

            // 질문들
            ...List.generate(_questions.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF667EEA).withOpacity(0.1),
                                const Color(0xFF764BA2).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _questions[index],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_options.length, (optionIndex) {
                      final isSelected = _answers[index] == optionIndex;
                      return GestureDetector(
                        onTap: () => _selectAnswer(index, optionIndex),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF667EEA).withOpacity(0.1)
                                    : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF667EEA)
                                      : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? const Color(0xFF667EEA)
                                            : const Color(0xFFCBD5E0),
                                    width: 2,
                                  ),
                                  color:
                                      isSelected
                                          ? const Color(0xFF667EEA)
                                          : Colors.transparent,
                                ),
                                child:
                                    isSelected
                                        ? const Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _options[optionIndex],
                                  style: TextStyle(
                                    fontSize: 15,
                                    color:
                                        isSelected
                                            ? const Color(0xFF667EEA)
                                            : const Color(0xFF2D3748),
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSizes.space * 2),

            // 결과 표시 (완료 시)
            if (_isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getScoreColor(_calculateScore()).withOpacity(0.1),
                      _getScoreColor(_calculateScore()).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getScoreColor(_calculateScore()).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getScoreColor(_calculateScore()).withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getScoreColor(
                              _calculateScore(),
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.analytics_rounded,
                            color: _getScoreColor(_calculateScore()),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          '평가 결과',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(_calculateScore()),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _getScoreColor(
                                  _calculateScore(),
                                ).withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_calculateScore()}점',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _getScoreInterpretation(_calculateScore()),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _getScoreColor(_calculateScore()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF718096),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '1주차와 비교하여 불안 수준이 어떻게 변화했는지 확인해보세요.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF718096),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 다음 버튼
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient:
                    _isCompleted
                        ? const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        )
                        : LinearGradient(
                          colors: [
                            Colors.grey.withOpacity(0.3),
                            Colors.grey.withOpacity(0.2),
                          ],
                        ),
                borderRadius: BorderRadius.circular(16),
                boxShadow:
                    _isCompleted
                        ? [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ]
                        : null,
              ),
              child: ElevatedButton(
                onPressed:
                    _isCompleted
                        ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const Week8PlanningCheckScreen(),
                            ),
                          );
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isCompleted ? '다음으로' : '모든 질문에 답해주세요',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isCompleted ? Colors.white : Colors.grey,
                      ),
                    ),
                    if (_isCompleted) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.space * 2),
          ],
        ),
      ),
    );
  }
}
