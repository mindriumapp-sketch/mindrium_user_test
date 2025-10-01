import 'package:flutter/material.dart';
import 'package:gad_app_team/features/menu/education/education_page.dart';
import 'package:gad_app_team/features/1st_treatment/week1_value_goal_screen.dart';
import 'package:gad_app_team/data/user_data_storage.dart';

class Week1Screen extends StatelessWidget {
  const Week1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserDataStorage.hasUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 사용자 데이터가 없으면 가치/목표 입력 화면으로
        if (snapshot.data == false) {
          return const Week1ValueGoalScreen();
        }

        // 사용자 데이터가 있으면 기존 교육 페이지로
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
      },
    );
  }
}
