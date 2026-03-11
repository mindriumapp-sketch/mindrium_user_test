import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/widgets/login_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/daycounter.dart';

/// 로그인 화면 (기능 로직만)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    // ⬇️ await 전에 Provider 뽑기
    final dayCounter = context.read<UserDayCounter>();
    final userProvider = context.read<UserProvider>();
    final todayTaskProvider = context.read<TodayTaskProvider>();

    // 새 로그인 시도 전에 상태 초기화
    userProvider.reset();
    todayTaskProvider.reset();
    dayCounter.reset();

    final tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    final authApi = AuthApi(client, tokens);

    try {
      // 1) 로그인 → 토큰 저장
      await authApi.login(email: email, password: password);

      // 2) 유저 정보 + 진행도 로딩 (/users/me + /users/me/progress)
      await userProvider.loadUserData(dayCounter: dayCounter);

      // 3) 오늘의 할 일 로딩 ( /users/me/todaytask )
      await todayTaskProvider.loadTodayTask();
      // 4) 현재 주차 세션 완료 상태 선동기화(교육 탭 플리커 방지)
      await todayTaskProvider.syncEducationWeekStatus(userProvider.currentWeek);

      // 5) SharedPreferences (기존 로직 유지)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('uid', userProvider.userId);
      await prefs.setString(
        'email',
        userProvider.userEmail.isNotEmpty ? userProvider.userEmail : email,
      );

      if (!mounted) return;

      // 6) 설문 여부 보고 분기
      final hasSurvey = userProvider.surveyCompleted;
      Navigator.pushReplacementNamed(
        context,
        hasSurvey ? '/home' : '/tutorial',
      );
    } catch (e) {
      // 로그인 전체 플로우 실패 → 토큰 + 상태 정리
      await tokens.clear();
      userProvider.reset();
      todayTaskProvider.reset();
      dayCounter.reset();

      _showError('로그인 실패: ${e is Exception ? e.toString() : '오류'}');

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/terms',
        arguments: {'email': email, 'password': password},
      );
    }
  }

  void _goToSignup() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    Navigator.pushNamed(
      context,
      '/terms',
      arguments: {'email': email, 'password': password},
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginDesign(
      emailController: emailController,
      passwordController: passwordController,
      onLogin: _login,
      onSignup: _goToSignup,
    );
  }
}
