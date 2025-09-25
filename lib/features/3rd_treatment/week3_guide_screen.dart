import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_belief_screen.dart';

class Week3GuideScreen extends StatefulWidget {
  const Week3GuideScreen({super.key});

  @override
  State<Week3GuideScreen> createState() => _Week3GuideScreenState();
}

class _Week3GuideScreenState extends State<Week3GuideScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '3주차 - Self Talk'),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/scenario_1.png',
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
                '이 여성은 34살의 초등학교 교사입니다. 그녀는 최근 6개월 동안, 거의 매일 특별한 이유 없이 불안하고 걱정이 많아졌다고 말합니다. 예를 들어, 수업 준비를 할 때마다 혹시 실수를 해서 학부모나 학교 측의 불만을 살까 봐 걱정이 되고, 동료 교사와 나눈 말 한마디가 오해로 이어지지는 않았을까 반복해서 떠올리며 신경이 쓰입니다. 또 부모님의 건강이 갑자기 나빠지지는 않을지, 갑작스러운 지출이 생기면 감당할 수 있을지 등의 생각이 끊임없이 머릿속을 맴돌며 불안을 키웁니다. 본인도 이런 걱정이 비현실적이고 과도하다는 걸 알고 있지만, 마음을 놓기가 힘들다고 털어놓습니다.',
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
                      pageBuilder: (_, __, ___) => const Week3BeliefScreen(),
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
