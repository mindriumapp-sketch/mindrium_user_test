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
    final completedWeeksFuture = _completedWeeksFuture ??= _loadCompletedWeeks();

    return SafeArea(
      child: FutureBuilder<int>(
        future: completedWeeksFuture,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
            children: [
              _buildHeader(),
              const SizedBox(height: AppSizes.space),
              _buildProgressSection(snapshot),
              const SizedBox(height: AppSizes.space),
              _buildTodayTasks(),
              const SizedBox(height: AppSizes.space),
              _buildMindriumSection(snapshot),
            ],
          );
        },
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

  Widget _buildProgressSection(AsyncSnapshot<int> snapshot) {
    final dayCounter = context.watch<UserDayCounter>();
    if (!dayCounter.isUserLoaded) return const SizedBox.shrink();

    const title = '치료 진행 상황';
    const errorMessage = '진행 정보를 불러오지 못했어요.';

    return _buildAsyncSection(
      snapshot: snapshot,
      title: title,
      errorMessage: errorMessage,
      onData: (completedWeeks) {
        final progress = (completedWeeks / _kTotalWeeks).clamp(0.0, 1.0);
        final percentLabel = '${(progress * 100).round()}%';

        return ProgressCard(
          title: title,
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
            boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 8)],
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
                onTap: () => Navigator.pushNamed(
                          context,
                          '/before_sud',
                          arguments: const {
                            'origin': 'apply',
                            'diary': 'new',
                          },
                        ),
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
                margin: EdgeInsets.zero,
                showShadow: false,
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildAsyncSection({
    required AsyncSnapshot<int> snapshot,
    required String title,
    required String errorMessage,
    required Widget Function(int) onData,
  }) {
    if (snapshot.connectionState != ConnectionState.done) {
      return CardContainer(
        title: title,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError) {
      return CardContainer(
        title: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(errorMessage),
        ),
      );
    }

    return onData(snapshot.data ?? 0);
  }

  Widget _buildMindriumSection(AsyncSnapshot<int> snapshot) {
    final completedWeeks = snapshot.data ?? 0;

    return _buildMindriumShortcuts(completedWeeks: completedWeeks);
  }
}
