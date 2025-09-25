import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_guide_screen.dart';

class Week3Screen extends StatefulWidget {
  const Week3Screen({super.key});

  @override
  State<Week3Screen> createState() => _Week3ScreenState();
}

class _Week3ScreenState extends State<Week3Screen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '3주차 - Self Talk'),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.lightbulb, size: 72, color: Color(0xFF3F51B5)),
            const SizedBox(height: 32),
            const Text(
              '예시를 통해 알아볼까요?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              '성인 여성의 상황을 예시로 살펴볼게요.',
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
                    pageBuilder: (_, __, ___) => const Week3GuideScreen(),
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
