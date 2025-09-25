import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gad_app_team/contents/diary_or_relax_or_home.dart';
import 'package:gad_app_team/contents/filtered_diary_select.dart';
import 'package:gad_app_team/contents/diary_yes_or_no.dart';
import 'package:gad_app_team/contents/filtered_diary_show.dart';
import 'package:gad_app_team/contents/relax_or_alternative.dart';
import 'package:gad_app_team/contents/relax_yes_or_no.dart';
import 'package:gad_app_team/contents/similar_activation.dart';
import 'package:gad_app_team/contents/apply_alternative_thought.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_result_screen.dart';
import 'package:gad_app_team/contents/training_select.dart';

//notification
import 'package:gad_app_team/features/menu/diary/diary_directory_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/notification_selection_screen.dart';

//treatment
import 'package:gad_app_team/features/1st_treatment/week1_screen.dart'; 
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group_add.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_group.dart';

// Feature imports
import 'package:gad_app_team/features/auth/login_screen.dart';
import 'package:gad_app_team/features/auth/signup_screen.dart';
import 'package:gad_app_team/features/auth/terms_screen.dart';
import 'package:gad_app_team/features/other/splash_screen.dart';
import 'package:gad_app_team/features/other/tutorial_screen.dart';
import 'package:gad_app_team/features/other/pretest_screen.dart';
import 'package:gad_app_team/features/settings/setting_screen.dart';

// Menu imports
import 'package:gad_app_team/features/menu/menu_screen.dart';
import 'package:gad_app_team/features/menu/education/education_screen.dart';
import 'package:gad_app_team/features/menu/archive/archive_screen.dart';
import 'package:gad_app_team/features/menu/education/education1.dart';
import 'package:gad_app_team/features/menu/education/education2.dart';
import 'package:gad_app_team/features/menu/education/education3.dart';
import 'package:gad_app_team/features/menu/education/education4.dart';
import 'package:gad_app_team/features/menu/education/education5.dart';
import 'package:gad_app_team/features/menu/education/education6.dart';

import 'package:gad_app_team/features/menu/relaxation/relaxation_screen.dart';
import 'package:gad_app_team/features/menu/relaxation/relaxation_score_screen.dart';
//import 'package:gad_app_team/features/menu/relaxation/breathing_meditation.dart';
import 'package:gad_app_team/features/menu/relaxation/muscle_relaxation.dart';
import 'package:gad_app_team/contents/before_sud_screen.dart';
import 'package:gad_app_team/contents/after_sud_screen.dart';


// Navigation screen imports
import 'package:gad_app_team/navigation/screen/home_screen.dart';
import 'package:gad_app_team/navigation/screen/myinfo_screen.dart';
import 'package:gad_app_team/navigation/screen/report_screen.dart';
import 'package:gad_app_team/navigation/screen/treatment_screen.dart';

import 'features/menu/archive/character_battle.dart';
import 'features/menu/archive/sea_archive_page.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
/// Mindrium 메인 앱 클래스
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: 'Mindrium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.indigo),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'), // 한국어
        Locale('en'), // 영어 (기본값)
      ],
      home: const SplashScreen(),
      routes: {
        // 인증 관련
        '/login': (context) => const LoginScreen(),
        '/terms': (context) => const TermsScreen(),
        '/signup': (context) => const SignupScreen(),

        // 네비게이션
        '/tutorial': (context) => const TutorialScreen(),
        '/pretest': (context) => const PreTestScreen(),
        '/home': (context) => const HomeScreen(),
        '/myinfo': (context) => const MyInfoScreen(),
        '/treatment': (context) => const TreatmentScreen(),
        '/report': (context) => const ReportScreen(),

        // 메뉴
        '/contents': (context) => const ContentScreen(),
        '/settings': (context) => const SettingsScreen(),

        '/training': (context) => const TrainingSelect(),

        '/education': (context) => const EducationScreen(),
        '/education1': (context) => const Education1Page(),
        '/education2': (context) => const Education2Page(),
        '/education3': (context) => const Education3Page(),
        '/education4': (context) => const Education4Page(),
        '/education5': (context) => const Education5Page(),
        '/education6': (context) => const Education6Page(),

        '/breath_muscle_relaxation': (context) => const RelaxationScreen(),
        '/relax': (context) => const RelaxationScreen(),
        //'/breathing_meditation': (context) => const BreathingMeditationPage(), 
        '/muscle_relaxation': (context) => const MuscleRelaxationPage(),
        '/relaxation_score': (context) => const RelaxationScoreScreen(),

        '/before_sud': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          final abcId = args?['abcId'] as String?;
          // if (abcId == null) {
          //   WidgetsBinding.instance.addPostFrameCallback(
          //     (_) => navigatorKey.currentState?.pushReplacementNamed('/home'),
          //   );
          //   return const SizedBox.shrink();
          // }
          return BeforeSudRatingScreen(abcId: abcId);
        },
        '/after_sud': (context) => const AfterSudRatingScreen(),
        "/diary_relax_home": (context) => const DiaryOrRelaxOrHome(),
        '/diary_yes_or_no': (contxt) => const DiaryYesOrNo(),
        "/diary_select": (context) => const DiarySelectScreen(),
        "/diary_show": (context) => const DiaryShowScreen(),
        "/similar_activation": (context) => const SimilarActivationScreen(),
        "/relax_or_alternative": (context) => const RelaxOrAlternativePage(),
        "/relax_yes_or_no": (context) => const RelaxYesOrNo(),

        "/abc_group_add": (context) => const AbcGroupAddScreen(),
        '/diary_group': (context) => AbcGroupScreen(),
        '/archive': (context) => ArchiveScreen(),

        //treatment
        '/week1': (context) => const Week1Screen(),
        '/week2': (context) => const AbcGuideScreen(),
        '/abc': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          final origin = args?['origin'] as String?;
          return AbcInputScreen(showGuide: false, origin: origin);
        },
        '/week4': (context) => const Week4Screen(),
        '/alt_thought': (context) => const Week4ClassificationResultScreen(),
        '/apply_alt_thought': (context) => const ApplyAlternativeThoughtScreen(),

        //notification
        '/noti_select': (context) => NotificationSelectionScreen(),
        '/diary_directory': (context) => NotificationDirectoryScreen(),
        '/battle': (context) => PokemonBattleDeletePage(),
        '/archive_sea': (context) => SeaArchivePage(),

      },
    );
  }
}
