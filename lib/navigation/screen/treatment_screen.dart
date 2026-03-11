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

    final List<Map<String, String>> weekContents = [
      {
        'title': '1주차',
        'summary': '불안을 이해하고, 이완을 천천히 시작해요',
        'session1Name': '불안에 대한 교육',
        'session1Duration': '약 10분',
        'session2Name': '점진적 이완',
        'session2Duration': '약 20분',
      },
      {
        'title': '2주차',
        'summary': 'ABC로 마음을 기록하고, 이완을 복습해요',
        'session1Name': 'ABC 일기 쓰기',
        'session1Duration': '약 12분',
        'session2Name': '점진적 이완',
        'session2Duration': '약 20분',
      },
      {
        'title': '3주차',
        'summary': '불안한 생각을 구별하고, 긴장 없이 이완해요',
        'session1Name': '생각 구별하는 연습',
        'session1Duration': '약 10분',
        'session2Name': '이완만 하는 이완',
        'session2Duration': '약 10분',
      },
      {
        'title': '4주차',
        'summary': '내 생각을 바꿔보고, 신호에 맞춰 이완해요',
        'session1Name': '내 생각 점검하기',
        'session1Duration': '약 20분',
        'session2Name': '신호 조절 이완',
        'session2Duration': '약 5분',
      },
      {
        'title': '5주차',
        'summary': '불안을 마주하는 행동을 익히고, 움직이며 이완해요',
        'session1Name': '행동 구별하는 연습',
        'session1Duration': '약 10분',
        'session2Name': '차등 이완',
        'session2Duration': '약 10분',
      },
      {
        'title': '6주차',
        'summary': '내 행동을 돌아보고, 움직이며 이완을 복습해요',
        'session1Name': '내 행동 점검하기',
        'session1Duration': '약 20분',
        'session2Name': '차등 이완',
        'session2Duration': '약 10분',
      },
      {
        'title': '7주차',
        'summary': '불안할 때의 행동을 개선하고, 빠르게 이완해요',
        'session1Name': '내 행동 개선하기',
        'session1Duration': '약 20분',
        'session2Name': '신속 이완',
        'session2Duration': '약 2분',
      },
      {
        'title': '8주차',
        'summary': '8주 간의 여정을 정리하고, 빠른 이완을 복습해요',
        'session1Name': '여정 돌아보기',
        'session1Duration': '약 15분',
        'session2Name': '신속 이완',
        'session2Duration': '약 10분',
      },
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
      ),
    );
  }
}
