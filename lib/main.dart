import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';

import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:gad_app_team/app.dart'; // Mindrium 전체 라우팅 포함
import 'package:gad_app_team/features/screen_time/screen_time_tracker.dart';
import 'package:gad_app_team/features/alarm/alarm_notification_service.dart';

/// 🌊 Mindrium 앱 시작점 (Provider 초기화)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Rive 초기화
  await RiveNative.init();

  // ✅ 저장된 알람 스케줄 복구
  final alarmService = AlarmNotificationService.instance;
  await alarmService.initialize();
  await alarmService.syncFromStorage();
 
  // ✅ 전역 Provider 구성
  final rootApp = MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UserDayCounter()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => TodayTaskProvider()),
      ChangeNotifierProvider(create: (_) => ApplyOrSolveFlow()),
    ],
    child: const MyApp(),
  );

  runApp(ScreenTimeAutoTracker(child: rootApp));
}
