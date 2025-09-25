import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/user_pretest.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

/// 앱 사용법을 안내하는 튜토리얼 화면
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> tutorialPages = [
    {
      'icon': Icons.today,
      'title': '하루의 시작을 함께',
      'description': '오늘의 할 일과 리포트를 한눈에 확인하세요.',
    },
    {
      'icon': Icons.edit_note,
      'title': '감정과 생각을 기록해요',
      'description': '감정일기, 명상, 노출치료 등 다양한 도구를 제공합니다.',
    },
    {
      'icon': Icons.bar_chart,
      'title': '나의 변화 추적',
      'description': '통계를 통해 마음의 흐름을 시각적으로 확인할 수 있어요.',
    },
  ];

  Future<void> _goNext() async {
    if (_currentIndex < tutorialPages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      final hasSurvey = await UserDatabase.hasCompletedSurvey();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, hasSurvey ? '/home' : '/pretest');
    }
  }

  Future<void> _skipTutorial() async {
    final hasSurvey = await UserDatabase.hasCompletedSurvey();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, hasSurvey ? '/home' : '/pretest');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.padding),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skipTutorial,
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: tutorialPages.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final page = tutorialPages[index];
                  return Padding(
                    padding: const EdgeInsets.all(AppSizes.padding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page['icon'], size: 120, color: AppColors.indigo),
                        const SizedBox(height: AppSizes.space),
                        Text(
                          page['title'],
                          style: const TextStyle(fontSize: AppSizes.fontSize, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSizes.space),
                        Text(
                          page['description'],
                          style: const TextStyle(fontSize: AppSizes.fontSize, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                tutorialPages.length,
                (index) {
                  final isActive = _currentIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    width: isActive ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.indigo : Colors.grey,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.padding),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryActionButton(
                  onPressed: _goNext,
                  text: '다음'
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space),
          ],
        ),
      ),
    );
  }
}