// 환경설정 화면: 앱 설정, 고객지원, 서비스 정보, 계정
import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gad_app_team/features/settings/account/account_management_screen.dart';
import 'package:gad_app_team/features/settings/notification_preferences_screen.dart';
import 'package:gad_app_team/features/settings/terms_policy_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final AuthApi _authApi = AuthApi(_apiClient, _tokens);

  bool _isLoggingOut = false;

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    setState(() => _isLoggingOut = true);
    try {
      await _authApi.logout();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('준비 중입니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '설정',
        confirmOnBack: false,
        confirmOnHome: false,
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
                children: [
                  _buildSectionShell(
                    title: '앱 설정',
                    child: Column(
                      children: [
                        _buildMenuRow(
                          icon: Icons.notifications_none_rounded,
                          title: '리마인더',
                          subtitle: '푸시 알림 수신 여부를 설정할 수 있어요.',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          const NotificationPreferencesScreen(),
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuRow(
                          icon: Icons.tune_rounded,
                          title: '권한 설정',
                          subtitle: '알림, 저장공간 등 앱에서 사용하는 권한을 확인해보세요.',
                          showDivider: false,
                          onTap: () => openAppSettings(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionShell(
                    title: '고객지원',
                    child: Column(
                      children: [
                        _buildMenuRow(
                          icon: Icons.edit_outlined,
                          title: '의견 보내기',
                          subtitle: '불편했던 점이나 개선 의견을 남길 수 있어요.',
                          onTap: _showComingSoon,
                        ),
                        const SizedBox(height: 10),
                        _buildMenuRow(
                          icon: Icons.campaign_outlined,
                          title: '공지사항',
                          subtitle: '서비스 업데이트와 주요 안내를 확인해보세요.',
                          onTap: _showComingSoon,
                        ),
                        const SizedBox(height: 10),
                        _buildMenuRow(
                          icon: Icons.help_outline_rounded,
                          title: '자주 묻는 질문',
                          subtitle: '많이 궁금해하는 질문과 답변을 모아두었어요.',
                          showDivider: false,
                          onTap: _showComingSoon,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionShell(
                    title: '서비스 정보',
                    child: Column(
                      children: [
                        _buildMenuRow(
                          icon: Icons.description_outlined,
                          title: '약관 및 정책',
                          subtitle: '서비스 이용과 관련된 약관 및 정책을 확인할 수 있어요.',
                          onTap:
                              () => Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const TermsPolicyScreen(),
                                  transitionsBuilder: (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOutCubic;
                                    final tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    return SlideTransition(
                                      position: animation.drive(tween),
                                      child: child,
                                    );
                                  },
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuRow(
                          icon: Icons.code_rounded,
                          title: '오픈소스 라이선스',
                          subtitle: '앱에서 사용 중인 오픈소스 라이선스 정보를 확인할 수 있어요.',
                          onTap: _showComingSoon,
                        ),
                        const SizedBox(height: 10),
                        _buildMenuRow(
                          icon: Icons.info_outline_rounded,
                          title: '앱 정보',
                          subtitle: '현재 앱 버전과 기본 정보를 확인할 수 있어요.',
                          showDivider: false,
                          onTap: _showComingSoon,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionShell(
                    title: '계정',
                    child: Column(
                      children: [
                        _buildMenuRow(
                          icon: Icons.manage_accounts_outlined,
                          title: '계정 관리',
                          subtitle: '로그인 방식과 연결된 계정 정보를 확인할 수 있어요.',
                          onTap:
                              () => Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const AccountManagementScreen(),
                                  transitionsBuilder: (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    const begin = Offset(1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOutCubic;
                                    final tween = Tween(
                                      begin: begin,
                                      end: end,
                                    ).chain(CurveTween(curve: curve));
                                    return SlideTransition(
                                      position: animation.drive(tween),
                                      child: child,
                                    );
                                  },
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        _buildMenuRow(
                          icon: Icons.logout_rounded,
                          title: '로그아웃',
                          subtitle: '현재 계정에서 안전하게 로그아웃합니다.',
                          onTap: _isLoggingOut ? null : _logout,
                          isDestructive: true,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoggingOut)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF5B9FD3)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionShell({required String title, required Widget child}) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2F3F),
                fontFamily: 'Noto Sans KR',
              ),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool showDivider = true,
  }) {
    final Color accentColor =
        isDestructive ? const Color(0xFFD85B66) : const Color(0xFF2C4154);
    final Color iconBgColor =
        isDestructive ? const Color(0xFFFFF1F3) : const Color(0xFFF1F7FB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
        child: Column(
          children: [
            Row(
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
            if (showDivider) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE7EDF2)),
            ],
          ],
        ),
      ),
    );
  }
}
