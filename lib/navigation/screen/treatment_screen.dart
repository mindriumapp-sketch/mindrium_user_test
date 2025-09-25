import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─── Core ───────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Project ────────────────────────────────────────────────────────────
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/widgets/activitiy_card.dart';

// ─── Feature Screens ────────────────────────────────────────────────────
import 'package:gad_app_team/features/1st_treatment/week1_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_screen.dart';
import 'package:gad_app_team/features/5th_treatment/week5_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_screen.dart';

/// Mindrium 치료 프로그램 메인 화면
class TreatmentScreen extends StatelessWidget {
  const TreatmentScreen({super.key});

  Future<Map<String, int>> _loadUserProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'completed': 0, 'weekByDays': 0};

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final completed = (snap.data()?['completed_education'] ?? 0) as int;

    final dayCounter = UserDayCounter(); // new instance for calc only
    final weekByDays = dayCounter.daysSinceJoin ~/ 7;

    return {'completed': completed, 'weekByDays': weekByDays};
  }

  @override
  Widget build(BuildContext context) {
    // 주차별 콘텐츠 정보
    final List<Map<String, String>> weekContents = [
      {'title': '1주차', 'subtitle': 'Progressive Relaxation / 불안에 대한 교육'},
      {'title': '2주차', 'subtitle': 'Progressive Relaxation / ABC 모델'},
      {'title': '3주차', 'subtitle': 'Release-only Relaxation / Self Talk'},
      {'title': '4주차', 'subtitle': 'Cue-Controlled Relaxation / 인지 왜곡 찾기'},
      {'title': '5주차', 'subtitle': 'Differential Relaxation / 불안 직면 vs 회피'},
      {'title': '6주차', 'subtitle': 'Differential Relaxation / 불안 직면 vs 회피'},
      {'title': '7주차', 'subtitle': 'Rapid Relaxation / 생활 습관 개선'},
      {'title': '8주차', 'subtitle': 'Rapid Relaxation / 인지 재구성'},
    ];

    // 주차별 연결된 화면 (추후 주차별로 추가 가능)
    final List<Widget> weekScreens = const [
      Week1Screen(), // 1주차
      AbcGuideScreen(), // 2주차
      Week3Screen(), // 3주차
      Week4Screen(),
      Week5Screen(),
      Week6Screen(),
      Week7Screen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: ListView(
        children: [
          // 제목 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Mindrium 교육 프로그램',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  '주차 별 프로그램을 진행해 주세요',
                  style: TextStyle(
                    fontSize: AppSizes.fontSize,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: AppSizes.space),
              ],
            ),
          ),

          // // 진행 상황 카드
          // _buildProgressCard(context),
          // const SizedBox(height: AppSizes.space),

          // 주차별 카드 리스트 (completed_education 기반)
          FutureBuilder<Map<String, int>>(
            future: _loadUserProgress(),
            builder: (context, snap) {
              final userDayCounter = context.watch<UserDayCounter>();
              if (!userDayCounter.isUserLoaded) return const SizedBox();
              if (!snap.hasData) return const SizedBox();

              // final completed = snap.data!['completed']!;

              // final days = userDayCounter.daysSinceJoin;
              // final weekByDays = (days ~/ 7);

              return Column(
                children: List.generate(weekContents.length, (index) {
                  // final isEnabled = index <= completed && index <= weekByDays;
                  final isEnabled = true;
                  return Column(
                    children: [
                      ActivityCard(
                        title: weekContents[index]['title']!,
                        subtitle: weekContents[index]['subtitle']!,
                        enabled: isEnabled,
                        titleFontWeight: FontWeight.bold,
                        onTap: !isEnabled
                            ? null
                            : () {
                                if (index == 1) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AbcInputScreen(),
                                    ),
                                  );
                                } else if (index < weekScreens.length) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => weekScreens[index],
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: AppSizes.space/2),
                    ],
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
