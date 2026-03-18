import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/widgets/passwod_field.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final patientCodeController = TextEditingController();
  final addressController = TextEditingController();

  bool showPassword = false;
  bool showConfirmPassword = false;
  bool isLoading = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _signup() async {
    final email = emailController.text.trim();
    final name = nameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final patientCode = patientCodeController.text.trim();
    final address = addressController.text.trim();

    if (email.isEmpty ||
        name.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        patientCode.isEmpty) {
      _showMessage('이메일, 이름, 비밀번호, 환자코드를 모두 입력해주세요.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final tokens = TokenStorage();
      final client = ApiClient.platformAuth(tokens: tokens);
      final authApi = AuthApi(client, tokens);

      await authApi.signup(
        email: email,
        password: password,
        name: name,
        patientCode: patientCode,
        gender: 'male',
        address: address.isEmpty ? null : address,
      );

      _showMessage('회원가입이 완료되었습니다. 로그인해 주세요.');

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: {
          'email': email,
          'password': password,
        },
      );
    } catch (e) {
      _showMessage('회원가입 실패: $e');
      debugPrint('Signup error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    patientCodeController.dispose();
    addressController.dispose();
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputTextField(
              label: '이메일',
              hintText: '의사가 등록한 이메일과 동일하게 입력',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              fillColor: AppColors.white,
            ),
            const SizedBox(height: AppSizes.space),

            InputTextField(
              label: '이름',
              controller: nameController,
              fillColor: AppColors.white,
            ),
            const SizedBox(height: AppSizes.space),

            PasswordTextField(
              controller: passwordController,
              label: '비밀번호',
              isVisible: showPassword,
              toggleVisibility: () {
                setState(() {
                  showPassword = !showPassword;
                });
              },
            ),
            const SizedBox(height: AppSizes.space),

            PasswordTextField(
              controller: confirmPasswordController,
              label: '비밀번호 확인',
              isVisible: showConfirmPassword,
              toggleVisibility: () {
                setState(() {
                  showConfirmPassword = !showConfirmPassword;
                });
              },
            ),
            const SizedBox(height: AppSizes.space),

            InputTextField(
              label: '환자코드',
              hintText: '의사가 전달한 환자코드 입력',
              controller: patientCodeController,
              fillColor: AppColors.white,
            ),
            const SizedBox(height: 8),

            const Text(
              '플랫폼에서 의사가 등록한 이메일과 동일한 이메일, 그리고 전달받은 환자코드를 입력해야 가입할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: AppSizes.space),

            InputTextField(
              label: '주소(선택)',
              controller: addressController,
              fillColor: AppColors.white,
            ),
            const SizedBox(height: AppSizes.space * 1.5),

            PrimaryActionButton(
              text: isLoading ? '처리 중...' : '회원가입',
              onPressed: isLoading ? null : _signup,
            ),
          ],
        ),
      ),
    );
  }
}
