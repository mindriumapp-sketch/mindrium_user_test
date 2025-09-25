import 'package:flutter/material.dart';
import 'package:gad_app_team/features/menu/education/education_page.dart';

class Week1Screen extends StatelessWidget {
  const Week1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EducationPage(
      title: '1주차 - 불안에 대한 교육',
      jsonPrefixes: [
        'week1_part1_',
        'week1_part2_',
        'week1_part3_',
        'week1_part4_',
        'week1_part5_',
        'week1_part6_',
      ],
    );
  }
}