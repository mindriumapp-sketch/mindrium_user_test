import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/api/auth_error_messages.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final emailError =
        email.isEmpty
            ? '이메일을 입력해주세요.'
            : (!_emailRegex.hasMatch(email) ? '이메일 형식이 올바르지 않습니다.' : null);

    setState(() {
      _emailError = emailError;
    });
    if (emailError != null) return;

    setState(() {
      _emailError = null;
      _isSubmitting = true;
    });
    try {
      final tokens = TokenStorage();
      final authApi = AuthApi(ApiClient(tokens: tokens), tokens);
      await authApi.requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pushNamed(
        '/reset_password',
        arguments: {'email': email},
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _emailError = AuthErrorMessages.passwordResetRequestFailed(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(AuthErrorMessages.serverError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.indigo,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '가입한 이메일을 입력해 주세요.',
                style: TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '등록된 이메일이면 6자리 인증번호를 메일로 보내드립니다.',
                style: TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 14,
                  color: Color(0xFF5B6573),
                ),
              ),
              const SizedBox(height: 24),
              InputTextField(
                controller: _emailController,
                label: '이메일',
                keyboardType: TextInputType.emailAddress,
                enabled: !_isSubmitting,
              ),
              if (_emailError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _emailError!,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryActionButton(
                text: _isSubmitting ? '전송 중…' : '인증번호 받기',
                onPressed: _isSubmitting ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
