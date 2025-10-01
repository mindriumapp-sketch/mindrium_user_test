import 'package:flutter/material.dart';
import 'package:gad_app_team/features/value_start.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';

class Week2Screen extends StatelessWidget {
  const Week2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueStartScreen(
      weekNumber: 2,
      weekTitle: 'ABC 모델을 통해 불안의 원인을 분석해보겠습니다.',
      weekDescription:
          '이번 주차에서는 불안이 발생하는 상황을 A(사건), B(생각), C(결과)로 나누어 분석하는 ABC 모델을 배워보겠습니다. 자전거를 타려고 했을 때의 상황을 예시로 살펴볼게요.',
      nextPageBuilder: () => const AbcGuideScreen(),
    );
  }
}
