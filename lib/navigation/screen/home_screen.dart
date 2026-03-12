import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';
import 'package:gad_app_team/data/api/alarm_settings_api.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

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
  static const MethodChannel _widgetLaunchChannel =
      MethodChannel('mindrium/widget_launch');
  static const EventChannel _widgetLaunchEventChannel =
      EventChannel('mindrium/widget_launch_events');

  int _selectedIndex = 0;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final UserDataApi _userDataApi = UserDataApi(_apiClient);

  bool _permissionsChecked = false;
  Future<void>? _permissionFuture;
  StreamSubscription<dynamic>? _widgetLaunchSubscription;
  bool _checkedInitialWidgetAction = false;
  int? _lastSyncedDiaryCount;
  int? _lastSyncedRelaxationCount;
  late final AlarmSettingsApi _alarmSettingsApi = AlarmSettingsApi(_apiClient);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // ✅ HomeScreen에서는 Provider 데이터 로딩/refresh 안 함
    //    - Splash/Login에서 이미 다 해줬다고 가정
    Future.microtask(() async {
      await _ensureCorePermissions();
      //TODO: 일기 개수 업데이트
      if (mounted) {
        final user = context.read<UserProvider>();
        final dayCounter = context.read<UserDayCounter>();
        await user.loadUserData(dayCounter: dayCounter);
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

  void _startApplyFlow() {
    final completedWeeks = context.read<UserProvider>().lastCompletedWeek;
    final bool canSolve = completedWeeks >= 4;
    if (!canSolve) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('4주차 완료 이후 이용할 수 있어요.')),
      );
      return;
    }

    final flow = context.read<ApplyOrSolveFlow>();
    flow.clear();
    flow.setOrigin('apply');
    flow.setDiaryRoute('solve');
    Navigator.pushNamed(
      context,
      '/before_sud',
      arguments: {
        ...flow.toArgs(),
        'origin': 'apply',
      },
    );
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
    _widgetLaunchSubscription =
        _widgetLaunchEventChannel.receiveBroadcastStream().listen(
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

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startApplyFlow();
    });
  }

  void _syncWidgetStatsIfNeeded(UserProvider user) {
    final diaryCount = user.totalDiaries;
    final relaxationCount = user.totalRelaxations;
    if (_lastSyncedDiaryCount == diaryCount &&
        _lastSyncedRelaxationCount == relaxationCount) {
      return;
    }

    _lastSyncedDiaryCount = diaryCount;
    _lastSyncedRelaxationCount = relaxationCount;

    _widgetLaunchChannel
        .invokeMethod<bool>(
      'updateWidgetStats',
      {
        'diaryCount': diaryCount,
        'relaxationCount': relaxationCount,
      },
    )
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

          // 실제 내용
          SafeArea(child: _buildBody()),

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
      case 4:
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
      final alarms = rows.map(AlarmSetting.fromJson).toList()
        ..sort((a, b) {
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
        _buildTaskSection(),
        const SizedBox(height: 8),
        _buildTrainingSection(),
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

          /// 🤖 오른쪽: 아이콘 (에이전트 / 메뉴)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconCircle(
                icon: Icons.smart_toy_rounded,
                onTap: () => Navigator.pushNamed(context, '/agent_help'),
              ),
              const SizedBox(width: 10),
              _iconCircle(
                icon: Icons.menu_rounded,
                onTap: () => Navigator.pushNamed(context, '/contents'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconCircle({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.black, size: 26),
        ),
      ),
    );
  }

  // ===================== 오늘의 할 일 =====================

  Widget _buildValueGoalCard() {
    final user = context.watch<UserProvider>();
    final dayCounter = context.watch<UserDayCounter>();

    final valueGoal = (user.valueGoal ?? '').trim();
    final hasValueGoal = valueGoal.isNotEmpty;
    final safeValueGoal = hasValueGoal ? valueGoal : '핵심 가치를 설정해 보세요.';
    final dayNo = dayCounter.daysSinceJoin > 0 ? dayCounter.daysSinceJoin : 1;

    return _trainingCard(
      title: '핵심 가치: $safeValueGoal',
      description: '$dayNo일째 목표를 향해 가고 있어요.',
      color: const Color(0xFFEFF7FF),
      trailing: _buildDayCalendar(dayNo),
      onTap: _showValueGoalEditor,
      chipLabel: '수정',
      onChipTap: _showValueGoalEditor,
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

  Future<void> _showValueGoalEditor() async {
    final user = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = TextEditingController(
      text: (user.valueGoal ?? '').trim(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('핵심 가치 수정'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            decoration: const InputDecoration(hintText: '핵심 가치를 입력해 주세요'),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('핵심 가치를 입력해 주세요.')),
                  );
                  return;
                }
                navigator.pop(value);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    try {
      await _userDataApi.updateValueGoal(result);
      if (!mounted) return;
      context.read<UserProvider>().setValueGoalLocally(result);
      messenger.showSnackBar(const SnackBar(content: Text('핵심 가치가 수정되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('핵심 가치 수정 실패: $e')));
    }
  }

  Widget _buildTaskSection() {
    final todayTask = context.watch<TodayTaskProvider>();
    final navigator = Navigator.of(context);

    final user = context.read<UserProvider>();
    final weekNumber = user.currentWeek;

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
            arguments: {
              ...flow.toArgs(),
              'origin': 'daily',
            },
          );
        },
      ),
      _DailyTask(
        title: '이완',
        isDone: todayTask.relaxationDone,
        onTap: () {
          // weekNumber 기반으로 taskId / asset 이름들 구성
          final taskId = 'week${weekNumber}_daily';
          final mp3Asset = 'week$weekNumber.mp3';
          final riveAsset = 'week$weekNumber.riv';

          navigator.pushNamed(
            '/relaxation_noti',
            arguments: {
              'taskId': taskId,
              'weekNumber': weekNumber,
              'mp3Asset': mp3Asset,
              'riveAsset': riveAsset,
              'nextPage': '/home',
            },
          );
        },
      ),
      _DailyTask(
        title: '이번주 교육 활동',
        isDone: todayTask.educationDoneWeek,
        onTap: () {
          final user = context.read<UserProvider>();
          var weekNumber = user.currentWeek; // 1~8이라고 가정

          // 안전하게 인덱스 계산
          var index = weekNumber - 1;
          if (index < 0) index = 0;
          if (index >= weekScreens.length) {
            index = weekScreens.length - 1;
          }

          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => weekScreens[index]));
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

  Widget _buildTrainingSection() {
    // final userProvider = context.read<UserProvider>();
    // final completedWeeks = userProvider.lastCompletedWeek;
    // final bool canSolve = completedWeeks >= 4;
    // const baseColor = Color(0xFFFFE2E8);
    // final cardColor = canSolve ? baseColor : baseColor.withValues(alpha: .55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // _trainingCard(
        //   title: '불안 해결하기',
        //   description: '오늘 불안하신 상황이 있으셨나요? 지금 오늘의 활동을 시작해보세요.',
        //   color: cardColor,
        //   imagePath: 'assets/image/pink1.png',
        //   onTap: () {
        //     if (!canSolve) {
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         const SnackBar(content: Text('4주차 완료 이후 이용할 수 있어요.')),
        //       );
        //       return;
        //     }
        //     final flow = context.read<ApplyOrSolveFlow>();
        //     // 기존 상태 초기화 후 solve 흐름 세팅
        //     flow.clear();
        //     flow.setOrigin('solve');
        //     Navigator.pushNamed(
        //       context,
        //       '/before_sud',
        //       arguments: {
        //         ...flow.toArgs(),
        //         'origin': 'solve',
        //       },
        //     );
        //   },
        // ),

        // const SizedBox(height: 8),
        _trainingCard(
          title: '알림 설정',
          description: '문구...', //TODO: 알림 설정 문구 고민
          color: const Color(0xFFE4F3FF),
          imagePath: 'assets/image/pink2.png',
          onTap: () {
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
    required VoidCallback onTap,
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
