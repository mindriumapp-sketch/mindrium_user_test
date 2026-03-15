// 계정 관리 화면: 로그인 방식, 연결된 계정 정보, 비밀번호 변경, 회원 탈퇴
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
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
          onPressed: () => Navigator.pop(context),
        ),
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
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
          _buildActionRow(
            icon: Icons.person_remove_outlined,
            title: '회원 탈퇴',
            subtitle: '탈퇴 전에 삭제 정보와 복구 가능 여부를 확인해 주세요.',
            isDestructive: true,
            onTap: () {},
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
