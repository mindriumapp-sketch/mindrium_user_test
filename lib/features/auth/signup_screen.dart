import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/widgets/passwod_field.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

/// 회원가입 화면 - 이메일, 이름, 전화번호, 비밀번호, 환자코드로 회원가입
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,20}$',
  );
  static const String _passwordPolicyMessage =
      '비밀번호는 8~20자이며, 영문자/숫자/특수문자를 각각 1자 이상 포함해야 합니다.';

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final patientCodeController = TextEditingController();

  bool showPassword = false;
  bool showConfirmPassword = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// FastAPI `detail`(문자열 또는 validation 배열)까지 스낵바에 넘기기
  String _signupErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
        }
      }
    }
    return '회원가입 실패: $e';
  }

  Future<void> _signup() async {
    final email = emailController.text.trim();
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final patientCode = patientCodeController.text.trim();

    if ([
      email,
      name,
      phone,
      password,
      confirmPassword,
      patientCode,
    ].any((e) => e.isEmpty)) {
      _showError('이메일, 이름, 전화번호, 비밀번호, 환자코드를 모두 입력해주세요.');
      return;
    }

    if (!_passwordRegex.hasMatch(password)) {
      _showError(_passwordPolicyMessage);
      return;
    }

    if (password != confirmPassword) {
      _showError('비밀번호가 일치하지 않습니다.');
      return;
    }

    try {
      final tokens = TokenStorage();
      final client = ApiClient(tokens: tokens);
      final authApi = AuthApi(client, tokens);

      await authApi.signup(
        email: email,
        password: password,
        name: name,
        phone: phone,
        patientCode: patientCode,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context,).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해 주세요.'))
      );
      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: {'email': email, 'password': password},
      );
    } catch (e, stack) {
      _showError(_signupErrorMessage(e));
      debugPrint('Signup error: $e');
      debugPrint('Stack: $stack');
    }
  }

  @override
  void didChangeDependencies() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      emailController.text = args['email'] ?? '';
      passwordController.text = args['password'] ?? '';
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    patientCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          children: [
            InputTextField(
              controller: emailController,
              fillColor: Colors.white,
              label: '이메일',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSizes.space),
            InputTextField(
              controller: nameController,
              label: '이름',
              fillColor: Colors.white,
            ),
            const SizedBox(height: AppSizes.space),

            InputTextField(
              controller: phoneController,
              label: '전화번호',
              fillColor: Colors.white,
              keyboardType: TextInputType.phone,
              hintText: '예) 01012345678 또는 010-1234-5678',
            ),

            const SizedBox(height: AppSizes.space),
            _buildPasswordPolicy(),
            const SizedBox(height: AppSizes.space),
            PasswordTextField(
              controller: passwordController,
              label: '비밀번호',
              isVisible: showPassword,
              toggleVisibility: () {
                setState(() => showPassword = !showPassword);
              },
            ),
            const SizedBox(height: AppSizes.space),
            PasswordTextField(
              controller: confirmPasswordController,
              label: '비밀번호 확인',
              isVisible: showConfirmPassword,
              toggleVisibility: () {
                setState(() => showConfirmPassword = !showConfirmPassword);
              },
            ),
            const SizedBox(height: AppSizes.space),

            InputTextField(
              controller: patientCodeController,
              label: '환자코드',
              fillColor: Colors.white,
              hintText: '병원 또는 플랫폼에서 받은 코드를 입력해주세요.',
            ),

            const SizedBox(height: AppSizes.space),
            PrimaryActionButton(text: '회원가입', onPressed: _signup),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPolicy() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey300,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '비밀번호 정책',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          SizedBox(height: 6),
          Text('• 8~20자 길이', style: TextStyle(color: Colors.black87)),
          Text(
            '• 영문자, 숫자, 특수문자를 각각 1자 이상 포함',
            style: TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
