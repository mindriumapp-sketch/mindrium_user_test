import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';
import 'package:gad_app_team/data/api/alarm_settings_api.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/widget_tutorial/home_widget_tutorial_controller.dart';
import 'package:gad_app_team/features/widget_tutorial/home_widget_tutorial_dialog.dart';

import 'package:gad_app_team/navigation/navigation.dart';
import 'package:gad_app_team/features/menu/archive/sea_archive_page.dart';
import 'package:gad_app_team/navigation/screen/myinfo_screen.dart';
import 'package:gad_app_team/navigation/screen/treatment_screen.dart';
import 'package:gad_app_team/features/1st_treatment/week1_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/week2_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_screen.dart';
import 'package:gad_app_team/features/5th_treatment/week5_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_screen.dart';
import 'package:gad_app_team/features/8th_treatment/week8_screen.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _widgetLaunchChannel = MethodChannel(
    'mindrium/widget_launch',
  );
  static const EventChannel _widgetLaunchEventChannel = EventChannel(
    'mindrium/widget_launch_events',
  );
  static const String _week2LockedMessage = '2주차 교육 완료 후 이용할 수 있어요.';
  static const String _alarmCardEnabledTitle = '알림 설정';
  static const String _alarmCardDisabledTitle = '알림 설정 (잠금)';
  static const String _alarmCardEnabledDescription =
      '규칙적인 루틴을 위해 알림 시간을 설정해 보세요.';
  static const String _alarmCardDisabledDescription = _week2LockedMessage;
  static const Color _alarmCardBaseColor = Color(0xFFE4F3FF);
  static const List<Widget> _weekScreens = [
    Week1Screen(),
    Week2Screen(),
    Week3Screen(),
    Week4Screen(),
    Week5Screen(),
    Week6Screen(),
    Week7Screen(),
    Week8Screen(),
  ];

  int _selectedIndex = 0;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  final HomeWidgetTutorialController _widgetTutorialController =
      HomeWidgetTutorialController();

  bool _permissionsChecked = false;
  Future<void>? _permissionFuture;
  StreamSubscription<dynamic>? _widgetLaunchSubscription;
  bool _checkedInitialWidgetAction = false;
  bool _pendingWidgetApplyLaunch = false;
  bool _isStartingPendingWidgetApply = false;
  int? _lastSyncedDiaryCount;
  int? _lastSyncedRelaxationCount;
  int? _lastSyncedCompletedWeeks;
  late final AlarmSettingsApi _alarmSettingsApi = AlarmSettingsApi(_apiClient);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // ✅ HomeScreen에서는 Provider 데이터 로딩/refresh 안 함
    //    - Splash/Login에서 이미 다 해줬다고 가정
    Future.microtask(() async {
      await _ensureCorePermissions();
      if (mounted) {
        final user = context.read<UserProvider>();
        final dayCounter = context.read<UserDayCounter>();
        await user.loadUserData(dayCounter: dayCounter);
        _tryStartPendingWidgetApplyLaunch();
      }
    });
    _listenWidgetLaunchEvents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialWidgetLaunchAction();
    });
  }

  @override
  void dispose() {
    _widgetLaunchSubscription?.cancel();
    super.dispose();
  }

  void _onDestinationSelected(int index) =>
      setState(() => _selectedIndex = index);

  void _showWeek2LockedSnackBar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_week2LockedMessage)));
  }

  Future<void> _showWidgetTutorialFromTempButton() async {
    await HomeWidgetTutorialDialog.show(
      context,
      steps: HomeWidgetTutorialController.tutorialSteps,
    );
  }

  void _startApplyFlow() {
    final completedWeeks = context.read<UserProvider>().lastCompletedWeek;
    final bool canSolve =
        completedWeeks >= HomeWidgetTutorialController.unlockWeek;
    if (!canSolve) {
      _showWeek2LockedSnackBar();
      return;
    }

    final flow = context.read<ApplyOrSolveFlow>();
    flow.clear();
    flow.setOrigin('apply');
    flow.setDiaryRoute('solve');
    Navigator.pushNamed(
      context,
      '/before_sud',
      arguments: {...flow.toArgs(), 'origin': 'apply'},
    );
  }

  void _tryStartPendingWidgetApplyLaunch() {
    if (!mounted ||
        !_pendingWidgetApplyLaunch ||
        _isStartingPendingWidgetApply) {
      return;
    }

    final user = context.read<UserProvider>();
    if (user.isLoadingUser || !user.isUserLoaded) {
      return;
    }

    _pendingWidgetApplyLaunch = false;
    _isStartingPendingWidgetApply = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isStartingPendingWidgetApply = false;
      if (!mounted) return;
      _startApplyFlow();
    });
  }

  Future<void> _handleInitialWidgetLaunchAction() async {
    if (_checkedInitialWidgetAction) return;
    _checkedInitialWidgetAction = true;

    try {
      final action = await _widgetLaunchChannel.invokeMethod<String>(
        'getInitialLaunchAction',
      );
      _handleWidgetLaunchAction(action);
    } on PlatformException catch (e) {
      debugPrint('초기 위젯 액션 조회 실패: ${e.message}');
    }
  }

  void _listenWidgetLaunchEvents() {
    _widgetLaunchSubscription = _widgetLaunchEventChannel
        .receiveBroadcastStream()
        .listen(
          (dynamic event) {
            final action = event?.toString();
            _handleWidgetLaunchAction(action);
          },
          onError: (Object error) {
            debugPrint('위젯 액션 스트림 수신 실패: $error');
          },
        );
  }

  void _handleWidgetLaunchAction(String? action) {
    if (!mounted) return;
    final normalizedAction = action?.trim();
    if (normalizedAction != 'start_apply') return;

    _pendingWidgetApplyLaunch = true;

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    _tryStartPendingWidgetApplyLaunch();
  }

  void _syncWidgetStatsIfNeeded(UserProvider user) {
    final diaryCount = user.totalDiaries;
    final relaxationCount = user.totalRelaxations;
    final completedWeeks = user.lastCompletedWeek;
    if (_lastSyncedDiaryCount == diaryCount &&
        _lastSyncedRelaxationCount == relaxationCount &&
        _lastSyncedCompletedWeeks == completedWeeks) {
      return;
    }

    _lastSyncedDiaryCount = diaryCount;
    _lastSyncedRelaxationCount = relaxationCount;
    _lastSyncedCompletedWeeks = completedWeeks;

    _widgetLaunchChannel
        .invokeMethod<bool>('updateWidgetStats', {
          'diaryCount': diaryCount,
          'relaxationCount': relaxationCount,
          'completedWeeks': completedWeeks,
        })
        .catchError((Object error) {
          debugPrint('위젯 통계 동기화 실패: $error');
          return false;
        });
  }

  // ===================== build =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 배경: eduhome.png + 반투명 오버레이
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 실제 내용 (Mindrium 탭은 status bar까지 배경 덮음)
          SafeArea(
            top: _selectedIndex != 2,
            child: _buildBody(),
          ),

          // 네비게이션 바
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomNavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
            ),
          ),
        ],
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
      case 3:
        return const MyInfoScreen();
      default:
        return _homePage();
    }
  }

  // ===================== 권한 처리 =====================

  Future<void> _ensureCorePermissions() {
    return _permissionFuture ??= _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (_permissionsChecked) return;

    final perms = <Permission>[
      Permission.locationWhenInUse,
      Permission.notification,
    ];

    for (final perm in perms) {
      if (!await perm.isGranted) {
        await perm.request();
      }
    }

    // 알림 관련(플러그인/플랫폼) 권한은 홈 화면에서 선요청.
    await AlarmNotificationService.instance.requestPermissions();
    await _syncAlarmSchedulesBestEffort();
    AlarmNotificationService.instance.handlePendingNotificationTap();

    _permissionsChecked = true;
  }

  Future<void> _syncAlarmSchedulesBestEffort() async {
    final service = AlarmNotificationService.instance;
    try {
      final rows = await _alarmSettingsApi.listAlarmSettings();
      final alarms =
          rows.map(AlarmSetting.fromJson).toList()..sort((a, b) {
            final aMinutes = a.hour * 60 + a.minute;
            final bMinutes = b.hour * 60 + b.minute;
            if (aMinutes != bMinutes) return aMinutes.compareTo(bMinutes);
            return a.id.compareTo(b.id);
          });
      await service.saveAlarms(alarms);
    } catch (e) {
      debugPrint('알림 설정 서버 동기화 실패(로컬 fallback): $e');
      try {
        await service.syncFromStorage();
      } catch (fallbackError) {
        debugPrint('알림 설정 로컬 동기화 실패: $fallbackError');
      }
    }
  }

  // ===================== 홈 탭 =====================

  Widget _homePage() {
    final user = context.watch<UserProvider>();
    final todayTask = context.watch<TodayTaskProvider>();

    // 1️⃣ 홈에 필요한 최소 데이터가 아직 로딩 중일 때 → 로딩 스피너
    if ((user.isLoadingUser && !user.isUserLoaded) ||
        (todayTask.isLoading && !todayTask.isLoaded)) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2️⃣ 로딩은 끝났는데, 아직 한 번도 제대로 못 불러온 상태에서 에러 → 에러 메시지
    if ((user.hasError && !user.isUserLoaded) ||
        (todayTask.hasError && !todayTask.isLoaded)) {
      return const Center(child: Text('홈 정보를 불러오지 못했어요.'));
    }

    // 3️⃣ 여기까지 왔으면 최소 한 번은 유저 + todayTask가 로딩된 상태
    _syncWidgetStatsIfNeeded(user);
    _widgetTutorialController.scheduleIfEligible(
      context: context,
      completedWeeks: user.lastCompletedWeek,
      userId: user.userId,
    );
    _tryStartPendingWidgetApplyLaunch();

    debugPrint(
      'currentWeek: ${user.currentWeek}, '
      'doneCount: ${user.lastCompletedWeek}, ',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildValueGoalCard(),
        const SizedBox(height: 8),
        _buildTaskSection(user: user, todayTask: todayTask),
        const SizedBox(height: 8),
        _buildTrainingSection(completedWeeks: user.lastCompletedWeek),
      ],
    );
  }

  // ===================== 헤더 =====================

  Widget _buildHeader() {
    final user = context.watch<UserProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// 👤 왼쪽: 사용자 인사 + 가입일
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 💬 “OOO님 환영합니다!”
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontFamily: 'Noto Sans KR',
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: '안녕하세요,\n'),
                      TextSpan(text: '${user.userName}님 환영합니다!'),
                    ],
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          _buildTempWidgetGuideButton()
        ],
      ),
    );
  }

  Widget _buildTempWidgetGuideButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: _showWidgetTutorialFromTempButton,
        icon: const Icon(Icons.help_outline_rounded, size: 18),
        label: const Text('위젯 가이드'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1B3A57),
          backgroundColor: const Color(0xFFF2F8FF),
          side: const BorderSide(color: Color(0xFFBFD8EE)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  // Widget _iconCircle({required IconData icon, required VoidCallback onTap}) {
  //   return Material(
  //     color: Colors.transparent,
  //     child: InkWell(
  //       onTap: onTap,
  //       borderRadius: BorderRadius.circular(23),
  //       child: Container(
  //         width: 46,
  //         height: 46,
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           shape: BoxShape.circle,
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withValues(alpha: 0.1),
  //               blurRadius: 5,
  //               offset: const Offset(2, 2),
  //             ),
  //           ],
  //         ),
  //         child: Icon(icon, color: Colors.black, size: 26),
  //       ),
  //     ),
  //   );
  // }

  // ===================== 오늘의 할 일 =====================

  Widget _buildValueGoalCard() {
    final user = context.watch<UserProvider>();
    final dayCounter = context.watch<UserDayCounter>();

    final valueGoal = (user.valueGoal ?? '').trim();
    final hasValueGoal = valueGoal.isNotEmpty;
    final dayNo = dayCounter.daysSinceJoin > 0 ? dayCounter.daysSinceJoin : 1;

    return _trainingCard(
      title: '핵심 가치',
      description:
          hasValueGoal ? '$dayNo일째 $valueGoal를 향해 가고 있어요.' : '핵심 가치를 설정해 보세요.',
      color: const Color(0xFFFFFFFF),
      trailing: _buildDayCalendar(dayNo),
    );
  }

  Widget _buildDayCalendar(int dayNo) {
    return Container(
      width: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA9CFF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF74B8F4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'DAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$dayNo일차',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF263C69),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection({
    required UserProvider user,
    required TodayTaskProvider todayTask,
  }) {
    final navigator = Navigator.of(context);
    final weekNumber = user.currentWeek;

    final List<_DailyTask> todayTasks = [
      _DailyTask(
        title: '오늘의 일기 작성',
        isDone: todayTask.diaryDone,
        onTap: () {
          final flow = context.read<ApplyOrSolveFlow>();
          flow.clear();
          flow.setOrigin('daily');
          flow.setDiaryRoute('today_task');
          Navigator.pushNamed(
            context,
            '/before_sud',
            arguments: {...flow.toArgs(), 'origin': 'daily'},
          );
        },
      ),
      _DailyTask(
        title: '이번주 이완 복습',
        isDone: todayTask.relaxationDone,
        onTap: () {
          final taskId = 'week${weekNumber}_daily';
          final assets = _resolveRelaxationAssets(weekNumber);

          navigator.pushNamed(
            '/relaxation_noti',
            arguments: {
              'taskId': taskId,
              'weekNumber': weekNumber,
              'mp3Asset': assets['mp3Asset']!,
              'riveAsset': assets['riveAsset']!,
              'nextPage': '/home',
            },
          );
        },
      ),
      _DailyTask(
        title: '이번주 교육 활동',
        isDone: todayTask.educationDoneWeek,
        onTap: () {
          final selectedWeek = user.currentWeek; // 1~8이라고 가정

          // 안전하게 인덱스 계산
          var index = selectedWeek - 1;
          if (index < 0) index = 0;
          if (index >= _weekScreens.length) {
            index = _weekScreens.length - 1;
          }

          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => _weekScreens[index]));
        },
      ),
    ];

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 할 일',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...todayTasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTaskCard(t),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _resolveRelaxationAssets(int weekNumber) {
    // 주차별 에셋 도입 전까지 공통 에셋을 사용한다.
    switch (weekNumber) {
      default:
        return const {'mp3Asset': 'noti.mp3', 'riveAsset': 'noti.riv'};
    }
  }

  Widget _buildTaskCard(_DailyTask task) {
    final isDone = task.isDone;
    final imagePath =
        isDone ? 'assets/image/finish.png' : 'assets/image/progressing.png';
    final bgColor = isDone ? const Color(0xFFFFE5E9) : const Color(0xFFD9F3FF);

    return InkWell(
      onTap: task.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
            padding: const EdgeInsets.all(10),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 교육/훈련 섹션 =====================

  Widget _buildTrainingSection({required int completedWeeks}) {
    final canUseAlarmSettings =
        completedWeeks >= HomeWidgetTutorialController.unlockWeek;
    final alarmCardColor =
        canUseAlarmSettings
            ? _alarmCardBaseColor
            : _alarmCardBaseColor.withValues(alpha: .55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _trainingCard(
          title:
              canUseAlarmSettings
                  ? _alarmCardEnabledTitle
                  : _alarmCardDisabledTitle,
          description:
              canUseAlarmSettings
                  ? _alarmCardEnabledDescription
                  : _alarmCardDisabledDescription,
          color: alarmCardColor,
          imagePath: 'assets/image/pink2.png',
          onTap: () {
            if (!canUseAlarmSettings) {
              _showWeek2LockedSnackBar();
              return;
            }
            Navigator.pushNamed(context, '/alarm_settings');
          },
        ),
      ],
    );
  }

  Widget _trainingCard({
    required String title,
    required String description,
    required Color color,
    String? imagePath,
    Widget? trailing,
    String? chipLabel,
    VoidCallback? onChipTap,
    Widget? bodyTopWidget,
    VoidCallback? onTap,
  }) {
    final bool hasChip = chipLabel != null && chipLabel.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: _WhiteCard(
        color: color,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (hasChip)
                        InkWell(
                          onTap: onChipTap,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFA6CDEF),
                              ),
                            ),
                            child: Text(
                              chipLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A5D8F),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (bodyTopWidget != null) ...[
                    const SizedBox(height: 8),
                    bodyTopWidget,
                  ],
                  const SizedBox(height: 10),
                  Text(
                    protectKoreanWords(description),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ??
                (imagePath == null
                    ? const SizedBox.shrink()
                    : Image.asset(imagePath, width: 80, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }
}

// ===================== 서브 위젯 =====================

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _WhiteCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DailyTask {
  final String title;
  final bool isDone;
  final VoidCallback? onTap;

  const _DailyTask({required this.title, required this.isDone, this.onTap});
}
