import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/widgets/login_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/api/auth_error_messages.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/daycounter.dart';
import 'package:gad_app_team/features/auth/auth_session_helper.dart';

/// 로그인 화면 (기능 로직만)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _routeArgsApplied = false;

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    final dayCounter = context.read<UserDayCounter>();
    final userProvider = context.read<UserProvider>();
    final todayTaskProvider = context.read<TodayTaskProvider>();

    userProvider.reset();
    todayTaskProvider.reset();
    dayCounter.reset();

    final tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    final authApi = AuthApi(client, tokens);

    setState(() => _isLoading = true);
    try {
      final loginMeta = await authApi.login(email: email, password: password);

      await AuthSessionHelper.completeSession(
        userProvider: userProvider,
        dayCounter: dayCounter,
        todayTaskProvider: todayTaskProvider,
        email: email,
      );

      if (!mounted) return;

      if (loginMeta.passwordChangeRecommended) {
        final notice =
            loginMeta.passwordChangeNotice ??
            '비밀번호 변경을 권장합니다. 설정 → 계정 관리에서 변경할 수 있습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }

      final hasSurvey = userProvider.surveyCompleted;
      Navigator.pushReplacementNamed(
        context,
        hasSurvey ? '/home' : '/tutorial',
      );
    } catch (e) {
      await tokens.clear();
      await authApi.logout();
      userProvider.reset();
      todayTaskProvider.reset();
      dayCounter.reset();

      if (kDebugMode) {
        debugPrint('Login failed: ${e.runtimeType}');
      }

      final message = e is DioException
          ? AuthErrorMessages.fromDioException(e, isSignup: false)
          : AuthErrorMessages.loginFailed;
      _showError(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _showForgotPasswordPlaceholder() {
    _showError('비밀번호 찾기 기능은 준비 중입니다.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsApplied) return;
    _routeArgsApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final email = args['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        emailController.text = email;
      }
    }
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
      showPassword: _showPassword,
      isLoading: _isLoading,
      onTogglePasswordVisibility: () {
        setState(() => _showPassword = !_showPassword);
      },
      onLogin: _isLoading ? () {} : _login,
      onSignup: _goToSignup,
      onForgotPassword: _showForgotPasswordPlaceholder,
    );
  }
}
