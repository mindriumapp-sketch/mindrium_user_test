import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/7th_treatment/week7_gain_lose_screen.dart';

class Week7ReasonInputScreen extends StatefulWidget {
  final String behavior;

  const Week7ReasonInputScreen({super.key, required this.behavior});

  @override
  State<Week7ReasonInputScreen> createState() => _Week7ReasonInputScreenState();
}

class _Week7ReasonInputScreenState extends State<Week7ReasonInputScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isNextEnabled = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      setState(() {
        _isNextEnabled = _reasonController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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

              // 질문 아이콘
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.question_mark,
                  size: 48,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              // 질문 텍스트
              const Text(
                '왜 불안 회피 행동이\n건강한 생활 습관이라고\n생각하세요?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              const Text(
                '자유롭게 생각을 적어보세요',
                style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // 텍스트 입력 필드
              Container(
                height: 200, // 고정 높이 설정
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _reasonController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '여기에 입력해주세요...',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFA0AEC0),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2D3748),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 100), // 하단 여백 추가
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: NavigationButtons(
          onBack: () => Navigator.pop(context),
          onNext:
              _isNextEnabled
                  ? () {
                    // TODO: 입력된 이유를 저장하는 로직 구현
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) =>
                                Week7GainLoseScreen(behavior: widget.behavior),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                  : null,
        ),
      ),
    );
  }
}
