import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/5th_treatment/week5_consequence_screen.dart';

class Week5BeliefScreen extends StatelessWidget {
  const Week5BeliefScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '5주차 - 불안 직면 VS 회피'),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/scenario_2.png',
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
                '걱정이 많아지면서 신체적으로도 여러 증상이 나타났습니다. 평소에는 느끼지 못했던 어깨와 목의 뻐근함이 거의 매일 지속되고, 마치 온몸에 힘이 들어간 것처럼 긴장된 상태가 계속됩니다. 밤에는 잠들기까지 1시간 이상 걸릴 때도 있고, 한밤중에 자주 깨거나 자고 나서도 개운하지 않다고 느낍니다.',
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
                      pageBuilder:
                          (_, __, ___) => const Week5ConsequenceScreen(),
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

