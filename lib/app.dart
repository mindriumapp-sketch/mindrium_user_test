import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gad_app_team/contents/alternative_yes_or_no.dart';
import 'package:gad_app_team/contents/apply_alternative_thought.dart';
import 'package:gad_app_team/contents/diary_or_relax_or_home.dart';
import 'package:gad_app_team/contents/filtered_diary_select.dart';
import 'package:gad_app_team/contents/diary_yes_or_no.dart';
import 'package:gad_app_team/contents/relax_or_alternative.dart';
import 'package:gad_app_team/contents/relax_yes_or_no.dart';
import 'package:gad_app_team/contents/solve_entry_choice.dart';
import 'package:gad_app_team/features/4th_treatment/week4_abc_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_result_screen.dart';
// import 'package:gad_app_team/features/screen_time/screen_time_page.dart';

//loctime
import 'package:gad_app_team/features/menu/diary/diary_directory_screen.dart';

//treatment
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add_screen.dart';

// Feature imports
import 'package:gad_app_team/features/auth/login_screen.dart';
import 'package:gad_app_team/features/auth/signup_screen.dart';
import 'package:gad_app_team/features/auth/terms_screen.dart';
import 'package:gad_app_team/features/other/before_survey.dart';
import 'package:gad_app_team/features/other/splash_screen.dart';
import 'package:gad_app_team/features/other/tutorial_screen.dart';
import 'package:gad_app_team/features/settings/setting_screen.dart';
import 'package:gad_app_team/features/settings/account/account_management_screen.dart';
import 'package:gad_app_team/features/alarm/alarm_settings_screen.dart';
import 'package:gad_app_team/features/alarm/notification_launch_coordinator.dart';

// Menu imports
import 'package:gad_app_team/features/menu/menu_screen.dart';
import 'package:gad_app_team/features/menu/diary/abc_group.dart';
import 'package:gad_app_team/features/menu/education/education_screen.dart';
import 'package:gad_app_team/features/menu/archive/archive_screen.dart';
import 'package:gad_app_team/features/menu/report/report_screen.dart';
import 'package:gad_app_team/features/menu/education/education1.dart';
import 'package:gad_app_team/features/menu/education/education2.dart';
import 'package:gad_app_team/features/menu/education/education3.dart';
import 'package:gad_app_team/features/menu/education/education4.dart';
import 'package:gad_app_team/features/menu/education/education5.dart';
import 'package:gad_app_team/features/menu/education/education6.dart';
import 'package:gad_app_team/features/menu/education/education7.dart';

import 'package:gad_app_team/features/menu/relaxation/relaxation_start.dart';
import 'package:gad_app_team/features/menu/relaxation/relaxation_noti.dart';
import 'package:gad_app_team/contents/before_sud_screen.dart';
import 'package:gad_app_team/contents/after_sud_screen.dart';

// Navigation screen imports
import 'package:gad_app_team/navigation/screen/home_screen.dart';
import 'package:gad_app_team/navigation/screen/myinfo_screen.dart';
import 'package:gad_app_team/navigation/app_navigator_key.dart';

import 'features/menu/archive/character_battle.dart';
import 'features/menu/archive/sea_archive_page.dart';
import 'features/7th_treatment/week7_add_display_screen.dart';

/// 🌊 Mindrium 메인 앱 클래스 (전역 폰트 NotoSansKR 적용)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      navigatorObservers: [
        notificationLaunchRouteObserver,
        week4RouteObserver,
        week7RouteObserver,
      ],
      debugShowCheckedModeBanner: false,
      title: '마인드리움',
      builder: (context, child) {
        return NotificationLaunchCoordinator(
          child: child ?? const SizedBox.shrink(),
        );
      },

      // ✅ 전역 테마 (NotoSansKR + Material3)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.indigo),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w500, // Medium
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w400, // Regular
            fontSize: 14,
          ),
          titleLarge: TextStyle(
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w700, // Bold
            fontSize: 20,
          ),
          titleMedium: TextStyle(
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w600, // SemiBold
            fontSize: 18,
          ),
          labelLarge: TextStyle(
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // 🌐 다국어 지원
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'), // 한국어
        Locale('en'), // 영어
      ],

      // 🪸 초기 화면
      home: const SplashScreen(),

      // 🧭 라우트 정의 (기존 그대로)
      routes: {
        '/login': (context) => const LoginScreen(),
        '/terms': (context) => const TermsScreen(),
        '/signup': (context) => const SignupScreen(),
        '/tutorial': (context) => const TutorialScreen(),
        '/before_survey': (context) => const BeforeSurveyScreen(),
        '/home': (context) => const HomeScreen(),
        '/home_edu': (_) => const HomeScreen(initialIndex: 1),
        '/home_mindrium': (_) => const HomeScreen(initialIndex: 2),
        '/home_mypage': (_) => const HomeScreen(initialIndex: 3),
        '/home_settings':
            (_) => const HomeScreen(initialIndex: 3), // 설정 제거 → 마이페이지로 리다이렉트
        '/myinfo': (context) => const MyInfoScreen(),
        '/contents': (context) => const ContentScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/account_management': (context) => const AccountManagementScreen(),
        '/alarm_settings': (context) => const AlarmSettingsScreen(),
        '/education': (context) => const EducationScreen(),
        '/education1': (context) => const Education1Page(),
        '/education2': (context) => const Education2Page(),
        '/education3': (context) => const Education3Page(),
        '/education4': (context) => const Education4Page(),
        '/education5': (context) => const Education5Page(),
        '/education6': (context) => const Education6Page(),
        '/education7': (context) => const Education7Page(),
        // '/screen_time': (context) => const ScreenTimePage(),
        '/relaxation_education': (context) {
          final args =
              (ModalRoute.of(context)!.settings.arguments as Map?) ?? {};
          final sessionId = args['sessionId'] as String?;
          final taskId = args['taskId'] as String? ?? 'week1_education';
          final weekNumber = args['weekNumber'] as int? ?? 1;
          final mp3Asset = args['mp3Asset'] as String? ?? 'week1.mp3';
          final riveAsset = args['riveAsset'] as String? ?? 'week1.riv';
          return RelaxationStartScreen(
            sessionId: sessionId,
            taskId: taskId,
            weekNumber: weekNumber,
            mp3Asset: mp3Asset,
            riveAsset: riveAsset,
          );
        },
        '/relaxation_noti': (context) {
          final args =
              (ModalRoute.of(context)!.settings.arguments as Map?) ?? {};
          final taskId = args['taskId'] as String? ?? 'week1_daily';
          final weekNumber = args['weekNumber'] as int?;
          final mp3Asset = args['mp3Asset'] as String? ?? 'week1.mp3';
          final riveAsset = args['riveAsset'] as String? ?? 'week1.riv';
          final nextPage = args['nextPage'] as String? ?? '/home';
          return NotiPlayer(
            taskId: taskId,
            weekNumber: weekNumber,
            mp3Asset: mp3Asset,
            riveAsset: riveAsset,
            nextPage: nextPage,
          );
        },
        '/before_sud': (context) => const BeforeSudRatingScreen(),
        '/solve_entry_choice': (context) => const SolveEntryChoiceScreen(),
        '/after_sud': (context) => const AfterSudRatingScreen(),
        "/diary_relax_home": (context) => const DiaryOrRelaxOrHome(),
        '/diary_yes_or_no': (context) => const DiaryYesOrNo(),
        "/diary_select": (context) => const DiarySelectScreen(),
        "/relax_or_alternative": (context) => const RelaxOrAlternativePage(),
        "/relax_yes_or_no": (context) => const RelaxYesOrNo(),
        "/alt_yes_or_no": (context) => const AltYesOrNo(),
        '/apply_alt_thought':
            (context) => const ApplyAlternativeThoughtScreen(),
        "/abc_group_add": (context) => const AbcGroupAddScreen(),
        '/diary_group': (context) => AbcGroupScreen(),
        '/archive': (context) => ArchiveScreen(),
        '/report': (context) => const ReportScreen(),
        '/abc': (context) {
          final args =
              (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
          int? beforeSud;
          final beforeRaw = args['beforeSud'];
          if (beforeRaw is int) {
            beforeSud = beforeRaw;
          } else if (beforeRaw is num) {
            beforeSud = beforeRaw.toInt();
          }

          return AbcInputScreen(
            showGuide: args['showGuide'] as bool? ?? false,
            isExampleMode: args['isExampleMode'] as bool? ?? false,
            abcId: args['abcId'] as String?,
            origin: args['origin'] as String?,
            diaryRoute: args['diaryRoute'] as String?,
            beforeSud: beforeSud,
            sudId: args['sudId'] as String?,
          );
        },
        '/alt_thought': (context) => const Week4ClassificationResultScreen(),
        '/diary_directory': (context) => DiaryDirectoryScreen(),
        '/battle': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final groupId = args?['groupId']?.toString() ?? '';
          return PokemonBattleDeletePage(groupId: groupId);
        },
        '/archive_sea': (context) => SeaArchivePage(),
      },
    );
  }
}
