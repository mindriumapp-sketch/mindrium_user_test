import 'package:flutter/material.dart';
import 'package:gad_app_team/features/menu/education/education_page.dart';

class Week1RelaxationTextScreen extends StatelessWidget {
  const Week1RelaxationTextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EducationPage(
      title: '1주차 - 점진적 근육 이완',
      jsonPrefixes: [
        'week1_relaxation_',
      ],
      isRelax: true,
    );
  }
}