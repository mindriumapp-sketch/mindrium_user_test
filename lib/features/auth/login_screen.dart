import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gad_app_team/widgets/input_text_field.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';

/// 로그인 화면: 이메일과 비밀번호로 인증
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

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('uid', user.uid);

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/tutorial',
        arguments: {
          'uid': user.uid,
          'email': user.email,
          'userData': userDoc.data(),
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _handleLoginError(e.code, email, password);
    } catch (e) {
      _showError('알 수 없는 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  void _handleLoginError(String code, String email, String password) {
    switch (code) {
      case 'user-not-found':
        Navigator.pushNamed(context, '/terms', arguments: {
          'email': email,
          'password': password,
        });
        break;
      case 'wrong-password':
        _showError('비밀번호가 잘못되었습니다.');
        break;
      case 'invalid-email':
        _showError('유효하지 않은 이메일 형식입니다.');
        break;
      case 'user-disabled':
        _showError('해당 계정은 비활성화되었습니다.');
        break;
      case 'too-many-requests':
        _showError('로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.');
        break;
      case 'operation-not-allowed':
        _showError('이메일/비밀번호 로그인이 비활성화되어 있습니다.');
        break;
      default:
        _showError('로그인 실패: $code');
    }
  }

  void _goToSignup() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    Navigator.pushNamed(context, '/terms', arguments: {
      'email': email,
      'password': password,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSizes.space),
              Center(
                child: Image.asset(
                  'assets/image/logo.png',
                  height: 160,
                  width: 160,
                ),
              ),
              const SizedBox(height: AppSizes.space),
              InputTextField(
                controller: emailController,
                fillColor:Colors.white,
                label: '이메일',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSizes.space),
              InputTextField(
                controller: passwordController,
                fillColor:Colors.white,
                label: '비밀번호',
                obscureText: true,
              ),
              const SizedBox(height: AppSizes.space),

              PrimaryActionButton(
                text: '로그인',
                onPressed: _login,
              ),

              TextButton(
                onPressed: _goToSignup,
                child: const Text('회원가입')
              ),
            ],
          ),
        ),
      ),
    );
  }
}