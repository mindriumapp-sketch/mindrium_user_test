import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/widgets/primary_action_button.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

/// 회원가입 화면 - 이메일, 이름, 전화번호, 비밀번호, 마인드리움코드로 회원가입
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const double _formSpacing = 6;
  static const double _labelSpacing = 4;
  static const double _inlineErrorHeight = 12;
  static const double _formErrorHeight = 16;
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,20}$',
  );
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _phoneRegex = RegExp(r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$');
  static const String _passwordPolicyMessage =
      '비밀번호는 8~20자이며, 영문자/숫자/특수문자를 각각 1자 이상 포함해야 합니다.';

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final patientCodeController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _patientCodeFocusNode = FocusNode();

  bool showPassword = false;
  bool showConfirmPassword = false;
  String? _emailError;
  String? _nameError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _patientCodeError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) _validateFieldOnBlur('email');
    });
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) _validateFieldOnBlur('name');
    });
    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) _validateFieldOnBlur('phone');
    });
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus) _validateFieldOnBlur('password');
    });
    _confirmPasswordFocusNode.addListener(() {
      if (!_confirmPasswordFocusNode.hasFocus) {
        _validateFieldOnBlur('confirmPassword');
      }
    });
    _patientCodeFocusNode.addListener(() {
      if (!_patientCodeFocusNode.hasFocus) _validateFieldOnBlur('patientCode');
    });
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return '이메일을 입력해주세요.';
    if (!_emailRegex.hasMatch(email)) return '이메일 형식이 올바르지 않습니다.';
    return null;
  }

  String? _validateName(String name) {
    if (name.isEmpty) return '이름을 입력해주세요.';
    return null;
  }

  String? _validatePhone(String phone) {
    if (phone.isEmpty) return '전화번호를 입력해주세요.';
    if (!_phoneRegex.hasMatch(phone)) {
      return '전화번호 형식이 올바르지 않습니다. (예: 01012345678)';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return '비밀번호를 입력해주세요.';
    if (!_passwordRegex.hasMatch(password)) return _passwordPolicyMessage;
    return null;
  }

  String? _validateConfirmPassword(String password, String confirmPassword) {
    if (confirmPassword.isEmpty) return '비밀번호 확인을 입력해주세요.';
    if (password != confirmPassword) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  String? _validatePatientCode(String patientCode) {
    if (patientCode.isEmpty) return '마인드리움 코드를 입력해주세요.';
    return null;
  }

  void _validateFieldOnBlur(String fieldKey) {
    setState(() {
      switch (fieldKey) {
        case 'email':
          _emailError = _validateEmail(emailController.text.trim());
          break;
        case 'name':
          _nameError = _validateName(nameController.text.trim());
          break;
        case 'phone':
          _phoneError = _validatePhone(phoneController.text.trim());
          break;
        case 'password':
          _passwordError = _validatePassword(passwordController.text.trim());
          _confirmPasswordError = _validateConfirmPassword(
            passwordController.text.trim(),
            confirmPasswordController.text.trim(),
          );
          break;
        case 'confirmPassword':
          _confirmPasswordError = _validateConfirmPassword(
            passwordController.text.trim(),
            confirmPasswordController.text.trim(),
          );
          break;
        case 'patientCode':
          _patientCodeError = _validatePatientCode(patientCodeController.text.trim());
          break;
      }
      _formError = null;
    });
  }

  void _clearFormErrorOnTyping() {
    if (_formError != null) {
      setState(() {
        _formError = null;
      });
    }
  }

  bool _validateForm({
    required String email,
    required String name,
    required String phone,
    required String password,
    required String confirmPassword,
    required String patientCode,
  }) {
    final emailError = _validateEmail(email);
    final nameError = _validateName(name);
    final phoneError = _validatePhone(phone);
    final passwordError = _validatePassword(password);
    final confirmPasswordError = _validateConfirmPassword(
      password,
      confirmPassword,
    );
    final patientCodeError = _validatePatientCode(patientCode);

    setState(() {
      _emailError = emailError;
      _nameError = nameError;
      _phoneError = phoneError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
      _patientCodeError = patientCodeError;
      _formError = null;
    });

    return [
      emailError,
      nameError,
      phoneError,
      passwordError,
      confirmPasswordError,
      patientCodeError,
    ].every((e) => e == null);
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

    final isValid = _validateForm(
      email: email,
      name: name,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
      patientCode: patientCode,
    );
    if (!isValid) {
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
      setState(() {
        _formError = _signupErrorMessage(e);
      });
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
    _emailFocusNode.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _patientCodeFocusNode.dispose();
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
        toolbarHeight: 50,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.padding,
            4,
            AppSizes.padding,
            8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _formErrorHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      _formError == null
                          ? null
                          : Text(
                            _formError!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 4),
              PrimaryActionButton(text: '회원가입', onPressed: _signup),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.padding,
          8,
          AppSizes.padding,
          88,
        ),
        child: Column(
          children: [
            _buildLabeledInput(
              title: '이메일',
              controller: emailController,
              fillColor: Colors.white,
              hintText: '이메일',
              keyboardType: TextInputType.emailAddress,
              focusNode: _emailFocusNode,
              errorText: _emailError,
              onChanged: (_) => _clearFormErrorOnTyping(),
            ),
            const SizedBox(height: _formSpacing),
            _buildLabeledInput(
              title: '이름',
              controller: nameController,
              fillColor: Colors.white,
              hintText: '이름',
              focusNode: _nameFocusNode,
              errorText: _nameError,
              onChanged: (_) => _clearFormErrorOnTyping(),
            ),
            const SizedBox(height: _formSpacing),

            _buildLabeledInput(
              title: '전화번호',
              controller: phoneController,
              fillColor: Colors.white,
              keyboardType: TextInputType.phone,
              hintText: '예) 01012345678 또는 010-1234-5678',
              focusNode: _phoneFocusNode,
              errorText: _phoneError,
              onChanged: (_) => _clearFormErrorOnTyping(),
            ),

            const SizedBox(height: _formSpacing),
            _buildLabeledPasswordInput(
              title: '비밀번호',
              controller: passwordController,
              hintText: '비밀번호',
              isVisible: showPassword,
              focusNode: _passwordFocusNode,
              errorText: _passwordError,
              toggleVisibility: () {
                setState(() => showPassword = !showPassword);
              },
              onChanged: (_) => _clearFormErrorOnTyping(),
            ),
            const SizedBox(height: _formSpacing),
            _buildLabeledPasswordInput(
              title: '비밀번호 확인',
              controller: confirmPasswordController,
              hintText: '비밀번호 확인',
              isVisible: showConfirmPassword,
              focusNode: _confirmPasswordFocusNode,
              errorText: _confirmPasswordError,
              toggleVisibility: () {
                setState(() => showConfirmPassword = !showConfirmPassword);
              },
              onChanged: (_) => _clearFormErrorOnTyping(),
            ),
            const SizedBox(height: _formSpacing),

            _buildLabeledInput(
              title: '마인드리움 코드',
              controller: patientCodeController,
              fillColor: Colors.white,
              hintText: '병원 또는 플랫폼에서 받은 코드를 입력해주세요.',
              focusNode: _patientCodeFocusNode,
              errorText: _patientCodeError,
              onChanged: (_) => _clearFormErrorOnTyping(),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildLabeledInput({
    required String title,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Color fillColor,
    String? hintText,
    TextInputType? keyboardType,
    String? errorText,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: _labelSpacing),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.padding,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              borderSide: const BorderSide(color: AppColors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              borderSide: const BorderSide(color: AppColors.black12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _inlineErrorHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child:
                errorText == null
                    ? null
                    : Text(
                      errorText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledPasswordInput({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required FocusNode focusNode,
    required VoidCallback toggleVisibility,
    String? errorText,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: _labelSpacing),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: !isVisible,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.padding,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              borderSide: const BorderSide(color: AppColors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              borderSide: const BorderSide(color: AppColors.black12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
              ),
              onPressed: toggleVisibility,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _inlineErrorHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child:
                errorText == null
                    ? null
                    : Text(
                      errorText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

}
