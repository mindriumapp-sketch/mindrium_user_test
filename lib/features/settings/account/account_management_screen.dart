// 계정 관리 화면: 로그인 방식, 연결된 계정 정보, 비밀번호 변경, 회원 탈퇴
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  bool _forceDialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_forceDialogShown) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['force'] == true) {
      _forceDialogShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showChangePasswordDialog(
          context,
          force: true,
          reason: args['reason'] as String?,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: ModalRoute.of(context)?.settings.arguments is Map &&
            (ModalRoute.of(context)?.settings.arguments as Map)['force'] == true
        ? AppBar(
            title: const Text(
              '계정 관리',
              style: TextStyle(
                color: Color(0xFF1E2F3F),
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Sans KR',
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: const Color(0xFF1E2F3F),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('비밀번호 변경 후 이용할 수 있습니다.')),
                );
              },
            ),
          )
        : const CustomAppBar(
        title: '계정 관리',
        showHome: false,
        confirmOnBack: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_buildAccountInfoCard(context)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard(BuildContext context) {
    final dynamic user = context.watch<UserProvider>();
    final String loginMethod = _resolveLoginMethod(user);
    final bool isLocalSignup = _isLocalSignup(user, loginMethod);
    final String userName = _resolveUserName(user);
    final String userEmail = _resolveUserEmail(user);
    final String linkedAccountInfo = _resolveLinkedAccountInfo(
      loginMethod: loginMethod,
      email: userEmail,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFCFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EDF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계정 정보',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2F3F),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.login_rounded,
            label: '로그인 방식',
            value: loginMethod,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.link_rounded,
            label: '연결 계정 정보',
            value: linkedAccountInfo,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.person_outline_rounded,
            label: '이름',
            value: userName,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: '이메일',
            value: userEmail,
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF3)),
          const SizedBox(height: 18),
          if (isLocalSignup) ...[
            _buildActionRow(
              icon: Icons.lock_outline_rounded,
              title: '비밀번호 변경',
              subtitle: '현재 비밀번호를 새로운 비밀번호로 변경할 수 있어요.',
              onTap: () => _showChangePasswordDialog(context),
            ),
            const SizedBox(height: 10),
          ],
          _buildActionRow(
            icon: Icons.person_remove_outlined,
            title: '회원 탈퇴',
            subtitle: '탈퇴 전에 삭제 정보와 복구 가능 여부를 확인해 주세요.',
            isDestructive: true,
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F7FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF2C4154)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF8A97A3),
                  fontFamily: 'Noto Sans KR',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E2F3F),
                  fontFamily: 'Noto Sans KR',
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color accentColor =
        isDestructive ? const Color(0xFFD85B66) : const Color(0xFF2C4154);
    final Color iconBgColor =
        isDestructive ? const Color(0xFFFFF1F3) : const Color(0xFFF1F7FB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Color(0xFF8A97A3),
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(
                Icons.chevron_right_rounded,
                color:
                    isDestructive
                        ? const Color(0xFFD85B66)
                        : const Color(0xFFA0ACB7),
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context, {
    bool force = false,
    String? reason,
    }) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final currentPasswordFocus = FocusNode();
    final newPasswordFocus = FocusNode();
    final confirmPasswordFocus = FocusNode();
    bool isSubmitting = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? currentPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;

    String? validateCurrentPassword(String value) {
      if (value.trim().isEmpty) return '현재 비밀번호를 입력해주세요.';
      return null;
    }

    String? validateNewPassword(String value) {
      final password = value.trim();
      if (password.isEmpty) return '새 비밀번호를 입력해주세요.';
      final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,20}$');
      if (!regex.hasMatch(password)) {
        return '비밀번호는 8~20자이며, 영문자/숫자/특수문자를 각각 1자 이상 포함해야 합니다.';
      }
      return null;
    }

    String? validateConfirmPassword(String newPassword, String confirmPassword) {
      if (confirmPassword.trim().isEmpty) return '새 비밀번호 확인을 입력해주세요.';
      if (newPassword.trim() != confirmPassword.trim()) {
        return '새 비밀번호가 일치하지 않습니다.';
      }
      return null;
    }

    bool validateAll() {
      final current = currentPasswordController.text;
      final next = newPasswordController.text;
      final confirm = confirmPasswordController.text;
      currentPasswordError = validateCurrentPassword(current);
      newPasswordError = validateNewPassword(next);
      confirmPasswordError = validateConfirmPassword(next, confirm);
      return currentPasswordError == null &&
          newPasswordError == null &&
          confirmPasswordError == null;
    }

    Future<void> submit(StateSetter setDialogState) async {
      final currentPassword = currentPasswordController.text.trim();
      final newPassword = newPasswordController.text.trim();
      setDialogState(() {});
      if (!validateAll()) {
        setDialogState(() {});
        return;
      }

      setDialogState(() => isSubmitting = true);
      try {
        final tokens = TokenStorage();
        final client = ApiClient(tokens: tokens);
        final authApi = AuthApi(client, tokens);
        await authApi.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        await authApi.logout();
        if (!context.mounted) return;

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } on DioException catch (e) {
        final detail =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail ?? '비밀번호 변경에 실패했습니다.')),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호 변경 중 오류가 발생했습니다.')));
      } finally {
        if (context.mounted) {
          setDialogState(() => isSubmitting = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      barrierColor: const Color(0x7A132333),
      builder: (dialogContext) {
        // final bottomInset = MediaQuery.of(dialogContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final String currentPassword = currentPasswordController.text.trim();
            final String newPassword = newPasswordController.text.trim();
            final String confirmPassword = confirmPasswordController.text.trim();
            final bool canSubmit =
                !isSubmitting &&
                currentPassword.isNotEmpty &&
                newPassword.isNotEmpty &&
                confirmPassword.isNotEmpty;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              // child: AnimatedPadding(
              //   duration: const Duration(milliseconds: 180),
              //   curve: Curves.easeOut,
              //   padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFCFFFFFF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE3ECF4)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEAF6FC), Color(0xFFDDF1FA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFD6EAF5)),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 24,
                                color: Color(0xFF2C4154),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              force
                                  ? reason == 'expired'
                                      ? '비밀번호 변경 필요'
                                      : '초기 비밀번호 변경'
                                  : '비밀번호 변경',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E2F3F),
                                fontFamily: 'Noto Sans KR',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          force
                              ? '보안을 위해 비밀번호를 변경한 후 서비스를 이용할 수 있어요.'
                              : '현재 비밀번호 확인 후 새 비밀번호로 변경합니다.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF8A97A3),
                            height: 1.4,
                            fontFamily: 'Noto Sans KR',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordInputField(
                          controller: currentPasswordController,
                          label: '현재 비밀번호',
                          enabled: !isSubmitting,
                          obscureText: obscureCurrent,
                          prefixIcon: Icons.key_rounded,
                          focusNode: currentPasswordFocus,
                          errorText: currentPasswordError,
                          onChanged: (_) {
                            if (currentPasswordError != null) {
                              currentPasswordError = null;
                            }
                            setDialogState(() {});
                          },
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) {
                              currentPasswordError = validateCurrentPassword(
                                currentPasswordController.text,
                              );
                              setDialogState(() {});
                            }
                          },
                          onEditingComplete: () {
                            currentPasswordError = validateCurrentPassword(
                              currentPasswordController.text,
                            );
                            setDialogState(() {});
                          },
                          onToggleVisibility:
                              () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        const SizedBox(height: 10),
                        _buildPasswordInputField(
                          controller: newPasswordController,
                          label: '새 비밀번호',
                          enabled: !isSubmitting,
                          obscureText: obscureNew,
                          prefixIcon: Icons.lock_rounded,
                          focusNode: newPasswordFocus,
                          errorText: newPasswordError,
                          onChanged: (_) {
                            if (newPasswordError != null) {
                              newPasswordError = null;
                            }
                            if (confirmPasswordError != null) {
                              confirmPasswordError = null;
                            }
                            setDialogState(() {});
                          },
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) {
                              newPasswordError = validateNewPassword(
                                newPasswordController.text,
                              );
                              if (confirmPasswordController.text.trim().isNotEmpty) {
                                confirmPasswordError = validateConfirmPassword(
                                  newPasswordController.text,
                                  confirmPasswordController.text,
                                );
                              }
                              setDialogState(() {});
                            }
                          },
                          onEditingComplete: () {
                            newPasswordError = validateNewPassword(
                              newPasswordController.text,
                            );
                            if (confirmPasswordController.text.trim().isNotEmpty) {
                              confirmPasswordError = validateConfirmPassword(
                                newPasswordController.text,
                                confirmPasswordController.text,
                              );
                            }
                            setDialogState(() {});
                          },
                          onToggleVisibility:
                              () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        const SizedBox(height: 10),
                        _buildPasswordInputField(
                          controller: confirmPasswordController,
                          label: '새 비밀번호 확인',
                          enabled: !isSubmitting,
                          obscureText: obscureConfirm,
                          prefixIcon: Icons.verified_user_rounded,
                          focusNode: confirmPasswordFocus,
                          errorText: confirmPasswordError,
                          onChanged: (_) {
                            if (confirmPasswordError != null) {
                              confirmPasswordError = null;
                            }
                            setDialogState(() {});
                          },
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) {
                              confirmPasswordError = validateConfirmPassword(
                                newPasswordController.text,
                                confirmPasswordController.text,
                              );
                              setDialogState(() {});
                            }
                          },
                          onEditingComplete: () {
                            confirmPasswordError = validateConfirmPassword(
                              newPasswordController.text,
                              confirmPasswordController.text,
                            );
                            setDialogState(() {});
                          },
                          textInputAction: TextInputAction.done,
                          onToggleVisibility:
                              () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (!force) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      isSubmitting
                                          ? null
                                          : () => Navigator.of(dialogContext).pop(),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFD6E1EB)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    '취소',
                                    style: TextStyle(
                                      color: Color(0xFF5E6F80),
                                      fontFamily: 'Noto Sans KR',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: canSubmit ? () => submit(setDialogState) : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF63C6EC),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child:
                                    isSubmitting
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Text(
                                          '변경',
                                          style: TextStyle(
                                            fontFamily: 'Noto Sans KR',
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // ),
              ),
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    currentPasswordFocus.dispose();
    newPasswordFocus.dispose();
    confirmPasswordFocus.dispose();
  }

  Widget _buildPasswordInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool enabled,
    required bool obscureText,
    required IconData prefixIcon,
    required String? errorText,
    required ValueChanged<String> onChanged,
    required ValueChanged<bool> onFocusChange,
    required VoidCallback onEditingComplete,
    TextInputAction textInputAction = TextInputAction.next,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: onFocusChange,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            enabled: enabled,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            textInputAction: textInputAction,
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 15.5,
              color: Color(0xFF273A4C),
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(
                color: Color(0xFF8493A1),
                fontFamily: 'Noto Sans KR',
                fontSize: 13.5,
              ),
              prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF5E768A)),
              suffixIcon: IconButton(
                onPressed: enabled ? onToggleVisibility : null,
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                  color: const Color(0xFF7F91A1),
                ),
              ),
              filled: true,
              fillColor: enabled ? const Color(0xFFF5FAFD) : const Color(0xFFEFF4F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDCE7F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText == null ? const Color(0xFFDCE7F0) : Colors.red.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText == null ? const Color(0xFF89D4F5) : Colors.red.shade400,
                  width: 1.6,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 10.8,
              fontWeight: FontWeight.w500,
              fontFamily: 'Noto Sans KR',
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  String _resolveUserName(dynamic user) {
    try {
      final value = user.userName;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}
    return '-';
  }

  String _resolveUserEmail(dynamic user) {
    try {
      final value = user.userEmail;
      if (value is String && value.trim().isNotEmpty) return value.trim();
    } catch (_) {}
    return '-';
  }

  String _resolveLoginMethod(dynamic user) {
    final String? provider = _readProvider(user);
    switch (provider) {
      case 'kakao':
        return '카카오 로그인';
      case 'google':
        return '구글 로그인';
      case 'local':
      case 'email':
        return '이메일 로그인';
      default:
        final email = _resolveUserEmail(user);
        return email != '-' ? '이메일 로그인' : '확인 필요';
    }
  }

  bool _isLocalSignup(dynamic user, String loginMethod) {
    final String? provider = _readProvider(user);
    if (provider == 'local' || provider == 'email') return true;
    if (provider == 'kakao' || provider == 'google') return false;
    return loginMethod == '이메일 로그인';
  }

  String _resolveLinkedAccountInfo({
    required String loginMethod,
    required String email,
  }) {
    switch (loginMethod) {
      case '카카오 로그인':
        return email != '-' ? '카카오 계정 연결됨\n$email' : '카카오 계정 연결됨';
      case '구글 로그인':
        return email != '-' ? '구글 계정 연결됨\n$email' : '구글 계정 연결됨';
      case '이메일 로그인':
        return email != '-' ? email : '이메일 계정 연결됨';
      default:
        return email != '-' ? email : '연결된 계정 정보를 확인해 주세요.';
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text(
                '회원 탈퇴',
                style: TextStyle(fontFamily: 'Noto Sans KR', fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '탈퇴 시 계정 정보가 비활성화되며 복구할 수 없습니다. 계속하려면 비밀번호를 입력해 주세요.',
                    style: TextStyle(fontFamily: 'Noto Sans KR', height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final password = passwordController.text.trim();
                          if (password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('비밀번호를 입력해주세요.')),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            final tokens = TokenStorage();
                            final client = ApiClient(tokens: tokens);
                            final authApi = AuthApi(client, tokens);
                            await authApi.deleteAccount(password: password);
                            if (!context.mounted) return;
                            context.read<UserProvider>().reset();
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                            );
                          } on DioException catch (e) {
                            final detail =
                                e.response?.data is Map
                                    ? e.response?.data['detail']?.toString()
                                    : e.message;
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(detail ?? '회원 탈퇴에 실패했습니다.'),
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('회원 탈퇴 중 오류가 발생했습니다.')),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                          }
                        },
                  child: const Text(
                    '탈퇴',
                    style: TextStyle(color: Color(0xFFD85B66)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    passwordController.dispose();
  }

  String? _readProvider(dynamic user) {
    final List<dynamic Function()> readers = [
      () => user.loginProvider,
      () => user.provider,
      () => user.authProvider,
      () => user.signInProvider,
      () => user.socialProvider,
    ];

    for (final reader in readers) {
      try {
        final value = reader();
        if (value is String && value.trim().isNotEmpty) {
          return value.trim().toLowerCase();
        }
      } catch (_) {}
    }
    return null;
  }
}
