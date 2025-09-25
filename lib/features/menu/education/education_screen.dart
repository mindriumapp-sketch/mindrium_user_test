import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/card_container.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/task_tile.dart';

/// 교육 메인 페이지
class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: const CustomAppBar(title: '교육'),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: ListView(
          children: [
            const SizedBox(height: AppSizes.space),
            CardContainer(
              title: '학습 주제',
              child: Column(
                children: [
                  TaskTile(title: '불안이란 무엇인가?', route: '/education1'),
                  TaskTile(title: '불안이 생기는 원리', route: '/education2'),
                  TaskTile(title: '동반되기 쉬운 다른 문제들', route: '/education3'),
                  TaskTile(title: '불안의 치료 방법', route: '/education4'),
                  TaskTile(title: 'Mindrium의 치료 방법', route: '/education5'),
                  TaskTile(title: '자기 이해를 높이는 방법', route: '/education6'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}