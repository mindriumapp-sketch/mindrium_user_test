import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_classification_screen.dart';

class Week3PracticeScreen extends StatelessWidget {
  const Week3PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '3주차 - Self Talk'),
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
              '방금 본 여성의 예시 상황에 몰입해 보면서\n도움이 되는 생각과 도움이 되지 않는 생각을 구분하는 연습을 해볼 거예요.',
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
                        (_, __, ___) => const Week3ClassificationScreen(),
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
