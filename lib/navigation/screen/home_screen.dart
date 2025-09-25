import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/menu/archive/sea_archive_page.dart';
import 'package:gad_app_team/widgets/activitiy_card.dart';
import 'package:gad_app_team/widgets/progress_card.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:gad_app_team/navigation/navigation.dart';
import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';

import 'package:gad_app_team/widgets/card_container.dart';

import 'treatment_screen.dart';
import 'myinfo_screen.dart';

/// 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const int _kTotalWeeks = 8;
  Future<int>? _completedWeeksFuture;
  static const List<String> _todayTasks = [
    '일일 과제1',
    '일일 과제2',
    '일일 과제3',
    '일일 과제4',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final dayCounter = Provider.of<UserDayCounter>(context, listen: false);
      userProvider.loadUserData(dayCounter: dayCounter);
    });
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: _buildBody(),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _homePage();
      case 1:
        return const TreatmentScreen();
      case 2:
        return const SeaArchivePage();
      // case 3:
      //   return const ReportScreen();
      case 3:
        return const MyInfoScreen();
      default:
        return _homePage();
    }
  }

  Future<int> _loadCompletedWeeks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (snap.data()?['completed_education'] ?? 0) as int;
  }

  Widget _homePage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
        children: [
          _buildHeader(),
          const SizedBox(height: AppSizes.space),
          _buildProgressSection(),
          const SizedBox(height: AppSizes.space),
          _buildTodayTasks(),
          const SizedBox(height: AppSizes.space),
          _buildMindriumSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final userService = context.watch<UserProvider>();
    final dayCounter = context.watch<UserDayCounter>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${userService.userName}님, \n좋은 하루 되세요!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),    
              Text(
                '${dayCounter.daysSinceJoin}일째 되는 날',
                style: const TextStyle(fontSize: AppSizes.fontSize, color: AppColors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Navigator.pushNamed(context, '/contents'),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final dayCounter = context.watch<UserDayCounter>();
    if (!dayCounter.isUserLoaded) return const SizedBox.shrink();

    _completedWeeksFuture ??= _loadCompletedWeeks();

    return FutureBuilder<int>(
      future: _completedWeeksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CardContainer(
            title: '치료 진행 상황',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const CardContainer(
            title: '치료 진행 상황',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('진행 정보를 불러오지 못했어요.'),
            ),
          );
        }

        final completedWeeks = snapshot.data ?? 0;
        final progress = (completedWeeks / _kTotalWeeks).clamp(0.0, 1.0);
        final percentLabel = '${(progress * 100).round()}%';

        return ProgressCard(
          title: '치료 진행 상황',
          progress: progress,
          progressLabel: percentLabel,
          footnote: '$completedWeeks / $_kTotalWeeks 주차 완료',
        );
      },
    );
  }

  Widget _buildMindriumShortcuts({required int completedWeeks}) {
    Widget card({
      required String title,
      required String description,
      required IconData icon,
      required VoidCallback? onTap,
      required bool enabled,
    }) {
      final Color background = enabled ? Colors.white : Colors.grey.shade300;
      final Color primaryText = enabled ? Colors.black : Colors.grey.shade600;
      final Color secondaryText = enabled ? Colors.black87 : Colors.grey.shade600;

      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Container(
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            boxShadow: enabled
                ? const [BoxShadow(color: AppColors.black12, blurRadius: 8)]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: enabled ? AppColors.indigo : Colors.grey),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: secondaryText,
                    ),
                  ),
                  if (!enabled)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '3주차 이상 완료 시 이용 가능',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final bool canApply = completedWeeks >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: card(
                title: '훈련하기',
                description: '주간 프로그램에서 배운 내용을 연습해요.',
                icon: Icons.fitness_center,
                onTap: () => Navigator.pushNamed(context, '/training'),
                enabled: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: card(
                title: '적용하기',
                description: '실제 상황에서 불안을 다뤄봅니다.',
                icon: Icons.psychology,
                onTap: canApply
                    ? () => Navigator.pushNamed(
                          context,
                          '/before_sud',
                          arguments: const {
                            'origin': 'apply',
                            'diary': 'new',
                          },
                        )
                    : null,
                enabled: canApply,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayTasks() {
    return CardContainer(
      title: '오늘의 할일',
      child: Column(
        children: List.generate(_todayTasks.length, (index) {
          final isLast = index == _todayTasks.length - 1;
          return Column(
            children: [
              ActivityCard(
                title: _todayTasks[index],
                icon: Icons.check_box_outline_blank,
                enabled: true,
                onTap: () {},
                margin: const EdgeInsets.all(0),
                showShadow: false,
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMindriumSection() {
    return FutureBuilder<int>(
      future: _completedWeeksFuture ??= _loadCompletedWeeks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CardContainer(
            title: 'Mindrium 빠른 실행',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const CardContainer(
            title: 'Mindrium 빠른 실행',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Mindrium 정보를 불러오지 못했어요.'),
            ),
          );
        }

        return _buildMindriumShortcuts(completedWeeks: snapshot.data ?? 0);
      },
    );
  }

  // Widget _buildReportSummary() {
  //   return FutureBuilder<Map<String, List<_SudEntry>>>(
  //     future: _fetchSudEntries(),
  //     builder: (context, snapshot) {
  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return const CardContainer(
  //           title: '최근 불안감 변화',
  //           child: Center(child: CircularProgressIndicator()),
  //         );
  //       }

  //       if (snapshot.hasError ||
  //           !snapshot.hasData ||
  //           (snapshot.data!['before']!.isEmpty && snapshot.data!['after']!.isEmpty)) {
  //         return const CardContainer(
  //           title: '최근 불안감 변화',
  //           child: Center(child: Text('데이터가 없습니다')),
  //         );
  //       }

  //       final beforeEntries = snapshot.data!['before']!;
  //       final afterEntries  = snapshot.data!['after']!;

  //       final latestBefore = beforeEntries.take(10).toList()
  //         ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  //       final latestAfter = afterEntries.take(10).toList()
  //         ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  //       final timeline = <DateTime>{
  //         ...latestBefore.map((e) => e.createdAt),
  //         ...latestAfter.map((e) => e.createdAt),
  //       }.toList()
  //         ..sort((a, b) => a.compareTo(b));

  //       final beforeSpots = latestBefore
  //           .map((e) => FlSpot(
  //                 timeline.indexOf(e.createdAt).toDouble(),
  //                 e.sud.toDouble(),
  //               ))
  //           .toList()
  //         ..sort((a, b) => a.x.compareTo(b.x));

  //       final afterSpots = latestAfter
  //           .map((e) => FlSpot(
  //                 timeline.indexOf(e.createdAt).toDouble(),
  //                 e.sud.toDouble(),
  //               ))
  //           .toList()
  //         ..sort((a, b) => a.x.compareTo(b.x));

  //       return CardContainer(
  //         title: '최근 불안감 변화 (before 10 / after 10)',
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             SizedBox(
  //               height: 120,
  //               child: LineChart(
  //                 LineChartData(
  //                   minY: -1,
  //                   maxY: 11,
  //                   gridData: FlGridData(
  //                     show: true,
  //                     drawVerticalLine: false,
  //                     horizontalInterval: 2,
  //                     getDrawingHorizontalLine: (value) => FlLine(
  //                       color: AppColors.grey300,
  //                       strokeWidth: 1,
  //                     ),
  //                   ),
  //                   titlesData: FlTitlesData(
  //                     leftTitles: AxisTitles(
  //                       sideTitles: SideTitles(
  //                         showTitles: true,
  //                         interval: 2,
  //                         getTitlesWidget: (value, meta) {
  //                           // Hide 0 and any odd numbers
  //                           if (value % 2 != 0) return const SizedBox.shrink();
  //                           return Text(
  //                             value.toInt().toString(),
  //                             style: const TextStyle(fontSize: 8),
  //                             textAlign: TextAlign.center,
  //                           );
  //                         },
  //                       ),
  //                     ),
  //                     rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //                     topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //                     bottomTitles: AxisTitles(
  //                       sideTitles: SideTitles(
  //                         showTitles: true,
  //                         interval: 1,
  //                         getTitlesWidget: (value, meta) {
  //                           final idx = value.toInt();
  //                           if (idx < 0 || idx >= timeline.length) {
  //                             return const SizedBox.shrink();
  //                           }
  //                           return Text(
  //                             DateFormat('MM/dd\nHH:mm').format(timeline[idx]),
  //                             style: const TextStyle(fontSize: 8),
  //                           );
  //                         },
  //                       ),
  //                     ),
  //                   ),
  //                   borderData: FlBorderData(show: false),
  //                   lineBarsData: [
  //                     LineChartBarData(
  //                       spots: beforeSpots,
  //                       isCurved: true,
  //                       color: Colors.indigo,
  //                       barWidth: 2,
  //                       dotData: FlDotData(show: false),
  //                       belowBarData: BarAreaData(show: false),
  //                     ),
  //                     LineChartBarData(
  //                       spots: afterSpots,
  //                       isCurved: true,
  //                       color: Colors.redAccent,
  //                       barWidth: 2,
  //                       dotData: FlDotData(show: false),
  //                       belowBarData: BarAreaData(show: false),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(height: AppSizes.space),
  //             if (timeline.isNotEmpty)
  //               Text(
  //                 '최근 평균 SUD: '
  //                 '${(
  //                   [...latestBefore, ...latestAfter]
  //                       .map((e) => e.sud)
  //                       .reduce((a, b) => a + b) /
  //                   (latestBefore.length + latestAfter.length)
  //                 ).toStringAsFixed(1)}점',
  //                 style: const TextStyle(color: AppColors.grey),
  //               ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  /// Firestore에서 모든 ABC 문서 하위 before/after SUD 데이터를 모아
  /// 각각 최신순 10개씩 가져와 반환.
  // Future<Map<String, List<_SudEntry>>> _fetchSudEntries() async {
  //   final uid = FirebaseAuth.instance.currentUser?.uid;
  //   if (uid == null) return {'before': [], 'after': []};

  //   // 사용자의 모든 ABC 문서 조회
  //   final abcDocs = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(uid)
  //       .collection('abc_models')
  //       .get();

  //   final beforeEntries = <_SudEntry>[];
  //   final afterEntries  = <_SudEntry>[];

  //   // 각 ABC 문서 하위의 before_sud_result / after_sud_result 수집
  //   for (final abcDoc in abcDocs.docs) {
  //     final beforeSnap = await abcDoc.reference
  //         .collection('before_sud_result')
  //         .orderBy('createdAt', descending: true)
  //         .limit(10)
  //         .get();

  //     final afterSnap = await abcDoc.reference
  //         .collection('after_sud_result')
  //         .orderBy('createdAt', descending: true)
  //         .limit(10)
  //         .get();

  //     beforeEntries.addAll(beforeSnap.docs.map((d) => _SudEntry(
  //           sud: (d.data()['sud'] ?? 0) as int,
  //           createdAt:
  //               (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  //         )));

  //     afterEntries.addAll(afterSnap.docs.map((d) => _SudEntry(
  //           sud: (d.data()['sud'] ?? 0) as int,
  //           createdAt:
  //               (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  //         )));
  //   }

  //   // 최신순 정렬 후 10개씩 제한
  //   beforeEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  //   afterEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  //   return {
  //     'before': beforeEntries.take(10).toList(),
  //     'after' : afterEntries.take(10).toList(),
  //   };
  // }
}

// /// 내부용 SUD 모델
// class _SudEntry {
//   final int sud;
//   final DateTime createdAt;
//   _SudEntry({required this.sud, required this.createdAt});
// }
