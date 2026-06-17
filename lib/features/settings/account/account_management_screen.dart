// 계정 관리 화면: 로그인 방식, 연결된 계정 정보, 비밀번호 변경, 회원 탈퇴
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,20}$',
  );
  static const String _passwordPolicyMessage =
      '비밀번호는 8~20자이며, 영문자/숫자/특수문자를 각각 1자 이상 포함해야 합니다.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
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

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
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
      if (!_passwordRegex.hasMatch(password)) return _passwordPolicyMessage;
      return null;
    }

    String? validateConfirmPassword(
      String newPassword,
      String confirmPassword,
    ) {
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

    Future<void> submit(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final currentPassword = currentPasswordController.text.trim();
      final newPassword = newPasswordController.text.trim();
      if (!validateAll()) {
        setDialogState(() {});
        return;
      }

      setDialogState(() => isSubmitting = true);
      var dialogClosed = false;
      try {
        final tokens = TokenStorage();
        final client = ApiClient(tokens: tokens);
        final authApi = AuthApi(client, tokens);
        await authApi.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        await authApi.logout();
        if (!context.mounted || !dialogContext.mounted) return;

        dialogClosed = true;
        Navigator.of(dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.')),
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } on DioException catch (e) {
        final detail =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message;
        if (detail == 'Current password is incorrect') {
          if (dialogContext.mounted) {
            setDialogState(() {
              currentPasswordError = '현재 비밀번호가 올바르지 않습니다.';
              isSubmitting = false;
            });
          }
          return;
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(detail ?? '비밀번호 변경에 실패했습니다.')));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호 변경 중 오류가 발생했습니다.')));
      } finally {
        if (!dialogClosed && dialogContext.mounted) {
          setDialogState(() => isSubmitting = false);
        }
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final String currentPassword =
                currentPasswordController.text.trim();
            final String newPassword = newPasswordController.text.trim();
            final String confirmPassword =
                confirmPasswordController.text.trim();
            final bool canSubmit =
                !isSubmitting &&
                currentPassword.isNotEmpty &&
                newPassword.isNotEmpty &&
                confirmPassword.isNotEmpty;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              title: const Text(
                '비밀번호 변경',
                style: TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2F3F),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '현재 비밀번호 확인 후 새 비밀번호로 변경합니다.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6E7F8F),
                        height: 1.4,
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordInputField(
                      controller: currentPasswordController,
                      label: '현재 비밀번호',
                      enabled: !isSubmitting,
                      obscureText: obscureCurrent,
                      prefixIcon: Icons.key_rounded,
                      errorText: currentPasswordError,
                      onChanged: (_) {
                        if (currentPasswordError != null) {
                          currentPasswordError = null;
                        }
                        setDialogState(() {});
                      },
                      onEditingComplete: () {
                        currentPasswordError = validateCurrentPassword(
                          currentPasswordController.text,
                        );
                        setDialogState(() {});
                        FocusScope.of(dialogContext).nextFocus();
                      },
                      onToggleVisibility:
                          () => setDialogState(
                            () => obscureCurrent = !obscureCurrent,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordInputField(
                      controller: newPasswordController,
                      label: '새 비밀번호',
                      enabled: !isSubmitting,
                      obscureText: obscureNew,
                      prefixIcon: Icons.lock_rounded,
                      errorText: newPasswordError,
                      helperText: '영문자, 숫자, 특수문자 포함 8~20자',
                      onChanged: (_) {
                        if (newPasswordError != null) {
                          newPasswordError = null;
                        }
                        if (confirmPasswordError != null) {
                          confirmPasswordError = null;
                        }
                        setDialogState(() {});
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
                        FocusScope.of(dialogContext).nextFocus();
                      },
                      onToggleVisibility:
                          () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordInputField(
                      controller: confirmPasswordController,
                      label: '새 비밀번호 확인',
                      enabled: !isSubmitting,
                      obscureText: obscureConfirm,
                      prefixIcon: Icons.verified_user_rounded,
                      errorText: confirmPasswordError,
                      onChanged: (_) {
                        if (confirmPasswordError != null) {
                          confirmPasswordError = null;
                        }
                        setDialogState(() {});
                      },
                      onEditingComplete: () {
                        confirmPasswordError = validateConfirmPassword(
                          newPasswordController.text,
                          confirmPasswordController.text,
                        );
                        setDialogState(() {});
                        FocusScope.of(dialogContext).unfocus();
                      },
                      textInputAction: TextInputAction.done,
                      onToggleVisibility:
                          () => setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed:
                      canSubmit
                          ? () => submit(dialogContext, setDialogState)
                          : null,
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
                          : const Text('변경'),
                ),
              ],
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Widget _buildPasswordInputField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required bool obscureText,
    required IconData prefixIcon,
    required String? errorText,
    required ValueChanged<String> onChanged,
    required VoidCallback onEditingComplete,
    String? helperText,
    TextInputAction textInputAction = TextInputAction.next,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      textInputAction: textInputAction,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const [AutofillHints.password],
      style: const TextStyle(
        fontFamily: 'Noto Sans KR',
        fontSize: 15,
        color: Color(0xFF273A4C),
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        errorText: errorText,
        errorMaxLines: 3,
        labelStyle: const TextStyle(
          color: Color(0xFF6E7F8F),
          fontFamily: 'Noto Sans KR',
          fontSize: 13.5,
        ),
        prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF5E768A)),
        suffixIcon: IconButton(
          tooltip: obscureText ? '비밀번호 보기' : '비밀번호 숨기기',
          onPressed: enabled ? onToggleVisibility : null,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: const Color(0xFF7F91A1),
          ),
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FBFD) : const Color(0xFFEFF4F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE7F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE7F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF89D4F5), width: 1.6),
        ),
      ),
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
                style: TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.w700,
                ),
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
                  onPressed:
                      isSubmitting
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed:
                      isSubmitting
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
                                const SnackBar(
                                  content: Text('회원 탈퇴가 완료되었습니다.'),
                                ),
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
                                  const SnackBar(
                                    content: Text('회원 탈퇴 중 오류가 발생했습니다.'),
                                  ),
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
