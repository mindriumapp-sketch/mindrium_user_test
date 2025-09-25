import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_practice_screen.dart';

class Week3ConsequenceScreen extends StatelessWidget {
  const Week3ConsequenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '3주차 - Self Talk'),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/scenario_3.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              color: Colors.black.withValues(alpha: 0.45),
              child: const Text(
                '수업 중에도 쉽게 피로를 느끼고, 가슴이 갑갑하거나 속이 울렁거리는 증상이 가끔 나타납니다. 집중력도 눈에 띄게 떨어져서 수업 자료를 준비하다가도 멍하니 시간을 보내는 일이 잦아졌고, 동료나 가족과 대화를 나눌 때도 예민하게 반응하거나 감정 기복이 커졌다는 이야기를 듣게 되었습니다. 점점 친구들을 만나는 것도 부담스럽게 느껴지고, 주말에도 집에만 있으려는 경우가 많아졌습니다.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.left,
                softWrap: true,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: NavigationButtons(
                onBack: () => Navigator.pop(context),
                onNext: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const Week3PracticeScreen(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
