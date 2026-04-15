import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_draft_progress.dart';
import 'package:gad_app_team/data/today_task_progress_sync.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';
import 'package:gad_app_team/data/api/alarm_settings_api.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/widget_tutorial/home_widget_tutorial_controller.dart';
import 'package:gad_app_team/features/widget_tutorial/home_widget_tutorial_dialog.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';

import 'package:gad_app_team/navigation/navigation.dart';
import 'package:gad_app_team/features/menu/archive/sea_archive_page.dart';
import 'package:gad_app_team/features/menu/report/report_screen.dart';
import 'package:gad_app_team/navigation/screen/myinfo_screen.dart';
import 'package:gad_app_team/navigation/screen/treatment_screen.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_visualization_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const MethodChannel _widgetLaunchChannel = MethodChannel(
    'mindrium/widget_launch',
  );
  static const EventChannel _widgetLaunchEventChannel = EventChannel(
    'mindrium/widget_launch_events',
  );
  static const String _week2LockedMessage = '2주차 교육 완료 후 이용할 수 있어요.';
  static const String _alarmCardEnabledTitle = '불안 완화 알림';
  static const String _alarmCardDisabledTitle = '불안 완화 알림 (잠금)';
  static const String _alarmCardEnabledDescription =
      '불안을 자주 느끼는 시간/위치에 알림을 설정해 보세요.';
  static const String _alarmCardDisabledDescription = _week2LockedMessage;
  static const Color _alarmCardBaseColor = Color(0xFFFCF8E2);

  int _selectedIndex = 0;
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  final HomeWidgetTutorialController _widgetTutorialController =
      HomeWidgetTutorialController();

  bool _permissionsChecked = false;
  bool _hasRequiredPermissions = false;
  bool _isCheckingPermissions = true;
  bool _didResolveRequiredPermissionState = false;
  Future<void>? _permissionFuture;
  StreamSubscription<dynamic>? _widgetLaunchSubscription;
  bool _checkedInitialWidgetAction = false;
  bool _pendingWidgetApplyLaunch = false;
  bool _isStartingPendingWidgetApply = false;
  int? _lastSyncedDiaryCount;
  int? _lastSyncedRelaxationCount;
  int? _lastSyncedCompletedWeeks;
  late final AlarmSettingsApi _alarmSettingsApi = AlarmSettingsApi(_apiClient);

  Future<bool?> _showResumeTodayTaskDraftDialog(
    TodayTaskDraftSnapshot snapshot,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return CustomPopupDesign(
          title: '이어서 하시겠습니까?',
          highlightText: snapshot.stageDescription,
          message: '이어서 진행할 수도 있고, 처음부터 다시 시작할 수도 있어요.',
          positiveText: '이어서',
          negativeText: '처음부터',
          onPositivePressed: () => Navigator.pop(dialogCtx, true),
          onNegativePressed: () => Navigator.pop(dialogCtx, false),
        );
      },
    );
  }

  Future<bool> _discardTodayTaskDraft(String? diaryId) async {
    final trimmedDiaryId = diaryId?.trim();
    if (trimmedDiaryId == null || trimmedDiaryId.isEmpty) {
      await TodayTaskDraftProgressStore.clear();
      return true;
    }

    try {
      await _diariesApi.deleteTodayTaskDraft(trimmedDiaryId);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        if (!mounted) return false;
        final detail =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('작성 중인 일기를 초기화하지 못했습니다: $detail')),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('작성 중인 일기를 초기화하지 못했습니다: $e')));
      return false;
    }

    await TodayTaskDraftProgressStore.clear();
    return true;
  }

  Future<void> _startFreshTodayTaskDiary({String? discardDiaryId}) async {
    final flow = context.read<ApplyOrSolveFlow>();
    if (!await _discardTodayTaskDraft(discardDiaryId)) {
      return;
    }
    if (!mounted) return;

    prepareTodayTaskDiaryFlow(flow);
    await syncTodayTaskDraftState(
      context,
      progress: TodayTaskDraftProgress.none,
      allowLower: true,
      diaryDone: false,
    );
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/before_sud',
      arguments: buildTodayTaskDiaryArgs(flow),
    );
  }

  void _applyTodayTaskDraftToFlow(
    ApplyOrSolveFlow flow,
    TodayTaskDraftSnapshot draft,
  ) {
    if (draft.diaryId != null && draft.diaryId!.isNotEmpty) {
      flow.setDiaryId(draft.diaryId);
    }
    flow.setDraftProgress(draft.progress);
    if (draft.beforeSud != null) flow.setBeforeSud(draft.beforeSud);
    if (draft.sudId != null) flow.setSudId(draft.sudId);
  }

  Widget _buildTodayTaskDraftVisualization(
    TodayTaskDraftSnapshot draft, {
    bool autoNavigateGroupOnEntryAfterLocTime = false,
  }) {
    return AbcVisualizationScreen(
      activatingChips: draft.activatingChips,
      beliefChips: draft.beliefChips,
      physicalChips: draft.physicalChips,
      emotionChips: draft.emotionChips,
      behaviorChips: draft.behaviorChips,
      isExampleMode: false,
      origin: 'daily',
      diaryRoute: todayTaskDiaryRoute,
      abcId: draft.diaryId,
      beforeSud: draft.beforeSud,
      sudId: draft.sudId,
      autoNavigateToLocTimeOnOpen: true,
      autoNavigateGroupOnEntryAfterLocTime:
          autoNavigateGroupOnEntryAfterLocTime,
    );
  }

  Future<void> _resumeTodayTaskDiary(TodayTaskDraftSnapshot draft) async {
    final flow = context.read<ApplyOrSolveFlow>();
    prepareTodayTaskDiaryFlow(flow);
    _applyTodayTaskDraftToFlow(flow, draft);

    await TodayTaskDraftProgressStore.save(
      progress: draft.progress,
      diaryId: draft.diaryId,
    );

    if (!mounted) return;

    if (draft.progress >= TodayTaskDraftProgress.locTimeRecorded) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => _buildTodayTaskDraftVisualization(
                draft,
                autoNavigateGroupOnEntryAfterLocTime: true,
              ),
        ),
      );
      return;
    }

    if (draft.progress >= TodayTaskDraftProgress.diaryWritten) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _buildTodayTaskDraftVisualization(draft),
        ),
      );
      return;
    }

    if (draft.progress >= TodayTaskDraftProgress.anxietyEvaluated) {
      Navigator.pushNamed(
        context,
        '/before_sud',
        arguments: buildTodayTaskDiaryArgs(
          flow,
          diaryId: draft.diaryId,
          beforeSud: draft.beforeSud,
          sudId: draft.sudId,
          autoNavigateToAbc: true,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/before_sud',
      arguments: buildTodayTaskDiaryArgs(flow),
    );
  }

  Future<void> _startOrResumeTodayTaskDiary() async {
    final todayTask = context.read<TodayTaskProvider>();
    TodayTaskDraftSnapshot? draft;
    try {
      final rawDraft = await _diariesApi.getLatestTodayTaskDraft();
      if (rawDraft != null) {
        draft = TodayTaskDraftSnapshot.fromMap(rawDraft);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final detail =
          e.response?.data is Map
              ? e.response?.data['detail']?.toString()
              : e.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('작성 중인 일기를 불러오지 못했습니다: $detail')));
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('작성 중인 일기를 불러오지 못했습니다: $e')));
      return;
    }

    if (draft == null) {
      if (todayTask.diaryDone) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('오늘의 일기는 이미 완료했어요.')));
        return;
      }
      await _startFreshTodayTaskDiary();
      return;
    }

    final shouldResume = await _showResumeTodayTaskDraftDialog(draft);
    if (!mounted || shouldResume == null) return;

    if (!shouldResume) {
      await _startFreshTodayTaskDiary(discardDiaryId: draft.diaryId);
      return;
    }

    await _resumeTodayTaskDiary(draft);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _widgetLaunchSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRequiredPermissionState();
    }
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
      arguments: {
        ...flow.toArgs(),
        'origin': 'apply',
        'isHomeTodayDiary': false,
      },
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
    } on MissingPluginException {
      debugPrint('초기 위젯 액션 채널이 아직 등록되지 않았습니다.');
    } on PlatformException catch (e) {
      debugPrint('초기 위젯 액션 조회 실패: ${e.message}');
    } catch (e) {
      debugPrint('초기 위젯 액션 조회 실패: $e');
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
          SafeArea(top: _selectedIndex != 2, child: _buildBody()),

          // 네비게이션 바
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomNavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
            ),
          ),
          if (_didResolveRequiredPermissionState && !_hasRequiredPermissions)
            Positioned.fill(
              child: _buildRequiredPermissionBlocker(
                isChecking: _isCheckingPermissions,
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
        return const ReportScreen();
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

    _permissionsChecked = true;
    await _refreshRequiredPermissionState();
  }

  Future<void> _refreshRequiredPermissionState() async {
    if (!mounted) return;
    setState(() => _isCheckingPermissions = true);

    final location = await Permission.locationWhenInUse.status;
    final notification = await Permission.notification.status;
    final hasAllRequired = location.isGranted && notification.isGranted;

    if (!mounted) return;
    setState(() {
      _hasRequiredPermissions = hasAllRequired;
      _isCheckingPermissions = false;
      _didResolveRequiredPermissionState = true;
    });
  }

  Future<void> _requestRequiredPermissionsFromBlocker() async {
    setState(() => _isCheckingPermissions = true);

    var locationStatus = await Permission.locationWhenInUse.status;
    var notificationStatus = await Permission.notification.status;

    if (!locationStatus.isGranted) {
      locationStatus = await Permission.locationWhenInUse.request();
    }
    if (!notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
    }

    await AlarmNotificationService.instance.requestPermissions();
    await _refreshRequiredPermissionState();

    if (!_hasRequiredPermissions && mounted) {
      final shouldOpenSettings =
          locationStatus.isPermanentlyDenied ||
          notificationStatus.isPermanentlyDenied ||
          locationStatus.isRestricted ||
          notificationStatus.isRestricted;

      if (shouldOpenSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('권한이 시스템에서 차단되어 있어요. 앱 설정에서 허용해 주세요.'),
            action: SnackBarAction(label: '설정 열기', onPressed: openAppSettings),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한 팝업에서 위치/알림을 모두 허용해 주세요.')),
      );
    }
  }

  Widget _buildRequiredPermissionBlocker({required bool isChecking}) {
    return ColoredBox(
      color: const Color(0xEFFFFFFF),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 30,
                color: Color(0xFF2C4154),
              ),
              const SizedBox(height: 10),
              const Text(
                '필수 권한이 필요해요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2F3F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '마인드리움 진행을 위해\n위치/알림 권한을 모두 허용해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF5F6B76),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      isChecking
                          ? null
                          : _requestRequiredPermissionsFromBlocker,
                  child:
                      isChecking
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('권한 허용하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    if (_didResolveRequiredPermissionState && _hasRequiredPermissions) {
      _widgetTutorialController.scheduleIfEligible(
        context: context,
        completedWeeks: user.lastCompletedWeek,
        userId: user.userId,
      );
    }
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
          _buildTempWidgetGuideButton(),
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
    final dayNo = dayCounter.daysSinceJoin;

    return _trainingCard(
      description: hasValueGoal ? '' : '핵심 가치를 설정해 보세요.',
      color: const Color(0xFFFFFFFF),
      trailing: _buildDayCalendar(dayNo),
      title: '핵심 가치',
      bodyTopWidget:
          hasValueGoal
              ? RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: '$dayNo일째 '),
                    TextSpan(
                      text: '"$valueGoal"',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1E2F3F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '을(를) 향해 가고 있어요.'),
                  ],
                ),
              )
              : null,
    );
  }

  String _formatDayCalendarLabel(int dayNo) {
    if (dayNo < 100) return '$dayNo일차';
    final weekNo = ((dayNo - 1) ~/ 7) + 1;
    return '$weekNo주차';
  }

  String _formatDayCalendarUnit(int dayNo) {
    return dayNo < 100 ? 'DAY' : 'WEEK';
  }

  Widget _buildDayCalendar(int dayNo) {
    return SizedBox(
      width: 64,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 뒤 종이
          Positioned(
            left: 4,
            right: 4,
            bottom: 2,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD7E6F5)),
              ),
            ),
          ),

          // 메인 본체
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA9CFF5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF74B8F4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _formatDayCalendarUnit(dayNo),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: dayNo < 100 ? 0.4 : 0.2,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Text(
                      _formatDayCalendarLabel(dayNo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF263C69),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 핀 2개
          const Positioned(top: 0, left: 16, child: _CalendarPin()),
          const Positioned(top: 0, right: 16, child: _CalendarPin()),
        ],
      ),
    );
  }

  Widget _buildTaskSection({
    required UserProvider user,
    required TodayTaskProvider todayTask,
  }) {
    final todayTasks = _buildTodayTasks(user: user, todayTask: todayTask);

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
          _buildTaskList(todayTasks),
        ],
      ),
    );
  }

  List<_DailyTask> _buildTodayTasks({
    required UserProvider user,
    required TodayTaskProvider todayTask,
  }) {
    return [
      ..._buildDiarySequenceTasks(todayTask),
      _buildRelaxationTask(
        weekNumber: user.currentWeek,
        isDone: todayTask.relaxationDone,
      ),
    ];
  }

  List<_DailyTask> _buildDiarySequenceTasks(TodayTaskProvider todayTask) {
    final steps = [
      _DiaryTaskDefinition(title: '불안 평가', isDone: todayTask.diaryAnxietyDone),
      _DiaryTaskDefinition(title: 'ABC 작성', isDone: todayTask.diaryAbcDone),
      _DiaryTaskDefinition(
        title: '위치/시간 설정',
        isDone: todayTask.diaryLocTimeDone,
      ),
      _DiaryTaskDefinition(title: '그룹 선택', isDone: todayTask.diaryGroupDone),
    ];
    final currentIndex = _resolveCurrentDiaryTaskIndex(steps);

    return List.generate(steps.length, (index) {
      final step = steps[index];
      return _DailyTask(
        title: step.title,
        isDone: step.isDone,
        isCurrent: !step.isDone && currentIndex == index,
        connectToPrevious: index > 0,
        connectToNext: index < steps.length - 1,
        onTap: _startOrResumeTodayTaskDiary,
      );
    });
  }

  int _resolveCurrentDiaryTaskIndex(List<_DiaryTaskDefinition> steps) {
    final firstPendingIndex = steps.indexWhere((step) => !step.isDone);
    if (firstPendingIndex >= 0) {
      return firstPendingIndex;
    }
    return steps.length - 1;
  }

  _DailyTask _buildRelaxationTask({
    required int weekNumber,
    required bool isDone,
  }) {
    return _DailyTask(
      title: '$weekNumber주차 이완 복습',
      isDone: isDone,
      onTap: () => _openRelaxationTask(weekNumber),
    );
  }

  void _openRelaxationTask(int weekNumber) {
    final taskId = 'daily_review';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => CustomPopupDesign(
            title: '이완 음성 안내 시작',
            message: '잠시 후, 이완을 위한 음성 안내가 시작됩니다. 주변 소리와 음량을 조절해보세요.',
            positiveText: '확인',
            negativeText: null,
            backgroundAsset: null,
            iconAsset: null,
            onPositivePressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(
                '/relaxation_noti',
                arguments: {
                  'taskId': taskId,
                  'weekNumber': weekNumber,
                  'mp3Asset': 'week$weekNumber.mp3',
                  'riveAsset': 'week$weekNumber.riv',
                  'nextPage': '/home',
                },
              );
            },
          ), // TODO: 흰페이지의 이완에서 올려도 되려나 이거
    );
  }

  Widget _buildTaskList(List<_DailyTask> tasks) {
    final sequenceCount = tasks.takeWhile((task) => task.isSequenceTask).length;
    final sequenceTasks = tasks.take(sequenceCount).toList(growable: false);
    final remainingTasks = tasks.skip(sequenceCount).toList(growable: false);

    return Column(
      children: [
        if (sequenceTasks.isNotEmpty) ...[
          _buildConnectedSequenceList(sequenceTasks),
          const SizedBox(height: 10),
        ],
        ...List.generate(remainingTasks.length, (index) {
          final isLast = index == remainingTasks.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: _buildTaskCard(remainingTasks[index], showConnector: false),
          );
        }),
      ],
    );
  }

  double _taskHeightFor(_DailyTask task) => task.isSequenceTask ? 60.0 : 54.0;

  double _iconTopFor(_DailyTask task) => task.isSequenceTask ? 8.0 : 4.0;

  Widget _buildConnectedSequenceList(List<_DailyTask> tasks) {
    const connectorColor = Color(0xFF9BC9EE);

    final totalHeight = tasks.fold<double>(
      0,
      (sum, task) => sum + _taskHeightFor(task),
    );

    double offsetY = 0;
    final centers = tasks
        .map((task) {
          final center = offsetY + _iconTopFor(task) + 24;
          offsetY += _taskHeightFor(task);
          return center;
        })
        .toList(growable: false);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            top: centers.first,
            bottom: totalHeight - centers.last,
            left: 25,
            child: Container(width: 2, color: connectorColor),
          ),
          Column(
            children:
                tasks
                    .map((task) => _buildTaskCard(task, showConnector: false))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(_DailyTask task, {bool showConnector = true}) {
    final isDone = task.isDone;
    final onTap = isDone ? null : task.onTap;
    final taskHeight = _taskHeightFor(task);
    final iconTop = _iconTopFor(task);
    final connectorSplit = taskHeight / 2;
    final imagePath =
        isDone ? 'assets/image/finish.png' : 'assets/image/progressing1.png';
    final bgColor =
        isDone
            ? const Color(0xFFDFF2FF)
            : task.isCurrent
            ? const Color(0xFFE2E8F0)
            : const Color(0xFFE2E8F0);
    final connectorColor = const Color(0xFF9BC9EE);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: taskHeight,
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: taskHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showConnector &&
                      (task.connectToPrevious || task.connectToNext))
                    Positioned(
                      top: task.connectToPrevious ? 0 : connectorSplit,
                      bottom: task.connectToNext ? 0 : connectorSplit,
                      left: 25,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: connectorColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  Positioned(
                    top: iconTop,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDone ? const Color(0xFF96A1AC) : Colors.black,
                  fontWeight:
                      task.isCurrent ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
    final alarmIconColor =
        canUseAlarmSettings ? Colors.black : const Color(0xFF8898A7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _trainingCard(
          titleLeading: Icon(
            Icons.notifications_none_rounded,
            size: 22,
            color: alarmIconColor,
          ),
          title:
              canUseAlarmSettings
                  ? _alarmCardEnabledTitle
                  : _alarmCardDisabledTitle,
          description:
              canUseAlarmSettings
                  ? _alarmCardEnabledDescription
                  : _alarmCardDisabledDescription,
          color: alarmCardColor,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 40,
            color: alarmIconColor,
          ),
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
    String? title,
    required String description,
    required Color color,
    Widget? titleLeading,
    String? imagePath,
    Widget? trailing,
    String? chipLabel,
    VoidCallback? onChipTap,
    Widget? bodyTopWidget,
    VoidCallback? onTap,
  }) {
    final bool hasChip = chipLabel != null && chipLabel.isNotEmpty;
    final Widget? accessory =
        trailing ??
        (imagePath == null
            ? null
            : Image.asset(imagePath, width: 80, fit: BoxFit.contain));

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
                      if (titleLeading != null) ...[
                        titleLeading,
                        const SizedBox(width: 8),
                      ],
                      if (title != null)
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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
                  if (description.trim().isNotEmpty) ...[
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
                ],
              ),
            ),
            if (accessory != null) ...[const SizedBox(width: 12), accessory],
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
  final bool isCurrent;
  final bool connectToPrevious;
  final bool connectToNext;
  final VoidCallback? onTap;

  const _DailyTask({
    required this.title,
    required this.isDone,
    this.isCurrent = false,
    this.connectToPrevious = false,
    this.connectToNext = false,
    this.onTap,
  });

  bool get isSequenceTask => connectToPrevious || connectToNext;
}

class _DiaryTaskDefinition {
  final String title;
  final bool isDone;

  const _DiaryTaskDefinition({required this.title, required this.isDone});
}

class _CalendarPin extends StatelessWidget {
  const _CalendarPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF8A98A8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8EEF5), width: 0.8),
      ),
    );
  }
}
