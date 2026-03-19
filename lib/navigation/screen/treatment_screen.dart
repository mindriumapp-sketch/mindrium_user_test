// 🌊 Mindrium TreatmentScreen — 단일 오픈 + 자동 unlock 반영
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';

import 'package:gad_app_team/features/1st_treatment/week1_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_screen.dart';
import 'package:gad_app_team/features/5th_treatment/week5_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_screen.dart';
import 'package:gad_app_team/features/8th_treatment/week8_screen.dart';
import 'package:gad_app_team/data/education_week_contents.dart';
import 'package:gad_app_team/widgets/treatment_design.dart';

class TreatmentScreen extends StatefulWidget {
  const TreatmentScreen({super.key});

  @override
  State<TreatmentScreen> createState() => _TreatmentScreenState();
}

class _TreatmentScreenState extends State<TreatmentScreen> {
  static const int _kTotalWeeks = 8;
  static const double _kEstimatedCardExtent = 126.0;

  final ScrollController _scrollController = ScrollController();

  bool _didAutoScroll = false;
  final Set<int> _expandedWeeks = <int>{};
  int? _expandedInitWeek;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _tryAutoScrollToCurrentWeek(int currentWeek) {
    if (_didAutoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didAutoScroll || !_scrollController.hasClients) return;
      if (_scrollController.position.userScrollDirection !=
          rendering.ScrollDirection.idle) {
        return;
      }

      final viewportHeight = _scrollController.position.viewportDimension;
      final targetCardTop = (currentWeek - 1) * _kEstimatedCardExtent;
      final targetOffset =
          targetCardTop - (viewportHeight * 0.4) + (_kEstimatedCardExtent / 2);

      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );

      _didAutoScroll = true;
      _scrollController.animateTo(
        clampedOffset.toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleWeekExpanded(int weekNo) {
    setState(() {
      if (_expandedWeeks.contains(weekNo)) {
        _expandedWeeks.remove(weekNo);
      } else {
        _expandedWeeks.add(weekNo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final todayTask = context.watch<TodayTaskProvider>();

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
    const int totalWeeks = _kTotalWeeks;

    // last_completed_week: 0~8 범위로 클램핑
    int lastCompleted = user.lastCompletedWeek;
    if (lastCompleted < 0) lastCompleted = 0;
    if (lastCompleted > totalWeeks) lastCompleted = totalWeeks;

    // current_week: 1~8 범위로 클램핑 (혹시 0이나 9 이상이 와도 방어)
    int currentWeek = user.currentWeek;
    if (currentWeek < 1) currentWeek = 1;
    if (currentWeek > totalWeeks) currentWeek = totalWeeks;

    // 완료된 주차 집합 (1~lastCompleted)
    final completedWeeks = <int>{for (int w = 1; w <= lastCompleted; w++) w};
    final cbtCompletedWeeks = <int>{
      for (int w = 1; w <= lastCompleted; w++) w,
      if (todayTask.isCbtDoneWeek(currentWeek)) currentWeek,
    };
    final relaxationCompletedWeeks = <int>{
      for (int w = 1; w <= lastCompleted; w++) w,
      if (todayTask.isRelaxationDoneWeek(currentWeek)) currentWeek,
    };

    // TODO: 나중에 진짜 잠금 로직 쓰고 싶으면 여기서 currentWeek 기준으로 enabled 계산
    // final enabledList = List<bool>.generate(totalWeeks, (i) {
    //   final weekNo = i + 1;
    //   return weekNo <= currentWeek;
    // });

    // 🔹 지금은 임시로 모두 오픈
    final List<bool> enabledList = List<bool>.filled(totalWeeks, true);

    final weekContents = educationWeekContents;

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
      "🟦 [TreatmentScreen] lastCompleted=$lastCompleted, currentWeek=$currentWeek",
    );
    debugPrint("🟦 [TreatmentScreen] completedWeeks=$completedWeeks");
    debugPrint("🟦 [TreatmentScreen] enabledList=$enabledList");

    if (_expandedInitWeek != currentWeek) {
      _expandedInitWeek = currentWeek;
      _expandedWeeks.add(currentWeek); // 기본은 현재 주차 펼침, 이후 사용자가 닫기 가능
    }

    _tryAutoScrollToCurrentWeek(currentWeek);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: TreatmentDesign(
        appBarTitle: '',
        currentWeek: currentWeek,
        lastCompleted: lastCompleted,
        weekContents: weekContents,
        weekScreens: weekScreens,
        enabledList: enabledList,
        completedWeeks: completedWeeks,
        cbtCompletedWeeks: cbtCompletedWeeks,
        relaxationCompletedWeeks: relaxationCompletedWeeks,
        expandedWeeks: _expandedWeeks,
        onToggleWeek: _toggleWeekExpanded,
        scrollController: _scrollController,
        unlockAllWeeks: true,
      ),
    );
  }
}
