import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/5th_treatment/week5_classification_screen.dart';

class Week5PracticeScreen extends StatelessWidget {
  const Week5PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '5주차 - 불안 직면 VS 회피'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.edit, size: 72, color: Color(0xFF3F51B5)),
            const SizedBox(height: 32),
            const Text(
              '한번 연습해볼까요?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              '방금 본 여성의 예시 상황에 몰입해 보면서\n불안을 직면하는 행동(불안을 점차 감소시킬 수 있는 행동)과 불안을 회피하는 행동(지속 시 불안을 증가시킬 수 있는 행동)을 구분하는 연습을 해볼 거예요.',
              style: TextStyle(fontSize: 20, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => const Week5ClassificationScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}