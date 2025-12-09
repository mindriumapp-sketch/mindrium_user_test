// 🌊 Mindrium TreatmentScreen — 단일 오픈 + 자동 unlock 반영
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

import 'package:gad_app_team/features/1st_treatment/week1_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_screen.dart';
import 'package:gad_app_team/features/5th_treatment/week5_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_screen.dart';
import 'package:gad_app_team/features/8th_treatment/week8_screen.dart';
import 'package:gad_app_team/widgets/tap_design_treatment.dart'; // ✅ 디자인 위젯

class TreatmentScreen extends StatelessWidget {
  const TreatmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    // ✅ Splash/Login에서 userProvider.loadUserData 안 탔거나,
    //    토큰 문제 등으로 아직 유저 정보가 없는 극초기/에러 케이스 방어
    if (!user.isUserLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF87CEEB)),
        ),
      );
    }

    // ── 서버에서 내려준 진행도 정보 ──
    const int totalWeeks = 8;

    // last_completed_week: 0~8 범위로 클램핑
    int lastCompleted = user.lastCompletedWeek;
    if (lastCompleted < 0) lastCompleted = 0;
    if (lastCompleted > totalWeeks) lastCompleted = totalWeeks;

    // current_week: 1~8 범위로 클램핑 (혹시 0이나 9 이상이 와도 방어)
    int currentWeek = user.currentWeek;
    if (currentWeek < 1) currentWeek = 1;
    if (currentWeek > totalWeeks) currentWeek = totalWeeks;

    // 완료된 주차 집합 (1~lastCompleted)
    final completedWeeks = <int>{
      for (int w = 1; w <= lastCompleted; w++) w,
    };

    final enabledList = List<bool>.generate(totalWeeks, (i) {
      final weekNo = i + 1;
      return weekNo <= currentWeek;
    });

    final List<Map<String, String>> weekContents = [
      {'title': '1주차', 'subtitle': '점진적 이완 / 불안에 대한 교육'},
      {'title': '2주차', 'subtitle': '점진적 이완 / ABC 모델'},
      {'title': '3주차', 'subtitle': '이완만 하는 이완 / Self Talk'},
      {'title': '4주차', 'subtitle': '신호 조절 이완 / 인지 왜곡 찾기'},
      {'title': '5주차', 'subtitle': '차등 이완 / 불안 직면 vs 회피'},
      {'title': '6주차', 'subtitle': '차등 이완 / 불안 직면 vs 회피'},
      {'title': '7주차', 'subtitle': '신속 이완 / 생활 습관 개선'},
      {'title': '8주차', 'subtitle': '신속 이완 / 인지 재구성'},
    ];

    final List<Widget> weekScreens = const [
      Week1Screen(),
      Week2Screen(),
      Week3Screen(),
      Week4Screen(),
      Week5Screen(),
      Week6Screen(),
      Week7Screen(),
      Week8Screen(),
    ];

    debugPrint(
        "🟦 [TreatmentScreen] lastCompleted=$lastCompleted, currentWeek=$currentWeek");
    debugPrint("🟦 [TreatmentScreen] completedWeeks=$completedWeeks");
    debugPrint("🟦 [TreatmentScreen] enabledList=$enabledList");

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: TreatmentDesign(
        appBarTitle: '',
        weekContents: weekContents,
        weekScreens: weekScreens,
        enabledList: enabledList,
        completedWeeks: completedWeeks,
      ),
    );
  }
}
