import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gad_app_team/common/auth_password_policy.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/api/auth_error_messages.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/passwod_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.email, super.key});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _codeError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _validate() {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final codeError =
        code.isEmpty
            ? '인증번호를 입력해주세요.'
            : (!RegExp(r'^\d{6}$').hasMatch(code)
                ? '6자리 숫자 인증번호를 입력해주세요.'
                : null);
    final passwordError = AuthPasswordPolicy.validate(
      password,
      emptyMessage: '새 비밀번호를 입력해주세요.',
    );
    final confirmPasswordError = AuthPasswordPolicy.validateConfirm(
      password,
      confirmPassword,
      emptyMessage: '새 비밀번호 확인을 입력해주세요.',
    );

    setState(() {
      _codeError = codeError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
    });

    return codeError == null &&
        passwordError == null &&
        confirmPasswordError == null;
  }

  Future<void> _resendCode() async {
    if (_isResending || _isSubmitting) return;

    setState(() => _isResending = true);
    try {
      final tokens = TokenStorage();
      final authApi = AuthApi(ApiClient(tokens: tokens), tokens);
      await authApi.requestPasswordReset(widget.email.trim());
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage('인증번호를 다시 보냈습니다. 메일함을 확인해 주세요.');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(AuthErrorMessages.passwordResetRequestFailed(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResending = false);
      _showMessage(AuthErrorMessages.serverError);
    }
  }

  Future<void> _submit() async {
    if (widget.email.trim().isEmpty) {
      _showMessage('이메일 정보가 없습니다. 비밀번호 찾기를 다시 시도해 주세요.');
      return;
    }
    if (!_validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final tokens = TokenStorage();
      final authApi = AuthApi(ApiClient(tokens: tokens), tokens);
      await authApi.verifyPasswordReset(
        email: widget.email.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(AuthErrorMessages.passwordResetVerifyFailed(e));
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
        title: const Text('비밀번호 재설정'),
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
                '인증번호와 새 비밀번호를 입력해 주세요.',
                style: TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.email} 으로 보낸 6자리 인증번호를 입력하세요.\n'
                '인증번호는 10분 동안 유효합니다.',
                style: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 14,
                  color: Color(0xFF5B6573),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              InputTextField(
                controller: _codeController,
                label: '인증번호 (6자리)',
                keyboardType: TextInputType.number,
                enabled: !_isSubmitting,
              ),
              if (_codeError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _codeError!,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PasswordTextField(
                controller: _passwordController,
                label: '새 비밀번호',
                isVisible: _showPassword,
                toggleVisibility: () {
                  setState(() => _showPassword = !_showPassword);
                },
              ),
              if (_passwordError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _passwordError!,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                AuthPasswordPolicy.message,
                style: TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 13,
                  color: Color(0xFF5B6573),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              PasswordTextField(
                controller: _confirmPasswordController,
                label: '새 비밀번호 확인',
                isVisible: _showConfirmPassword,
                toggleVisibility: () {
                  setState(() => _showConfirmPassword = !_showConfirmPassword);
                },
              ),
              if (_confirmPasswordError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _confirmPasswordError!,
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryActionButton(
                text: _isSubmitting ? '변경 중…' : '비밀번호 변경',
                onPressed: _isSubmitting ? () {} : _submit,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isResending || _isSubmitting ? null : _resendCode,
                child: Text(
                  _isResending ? '재전송 중…' : '인증번호 다시 받기',
                  style: const TextStyle(
                    fontFamily: 'NotoSansKR',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
