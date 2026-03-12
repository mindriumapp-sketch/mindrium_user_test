import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/users_api.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/api/auth_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/api/screen_time_api.dart';
import 'package:gad_app_team/data/models/screen_time_summary.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen>
    with WidgetsBindingObserver {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController valueGoalController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isEditing = false;
  bool isLoading = true;
  bool showPasswordFields = false;

  DateTime? createdAt;

  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final UsersApi _usersApi = UsersApi(_apiClient);
  late final UserDataApi _userDataApi = UserDataApi(_apiClient);
  late final AuthApi _authApi = AuthApi(_apiClient, _tokens);
  late final ScreenTimeApi _screenTimeApi = ScreenTimeApi(_apiClient);

  ScreenTimeSummary? _screenTimeSummary;
  bool _screenTimeLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadScreenTimeSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nameController.dispose();
    emailController.dispose();
    valueGoalController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadScreenTimeSummary();
    }
  }

  void _loadUserData() {
    try {
      final userProvider = context.read<UserProvider>();

      nameController.text = userProvider.userName;
      emailController.text = userProvider.userEmail;
      valueGoalController.text = userProvider.valueGoal ?? '';
      createdAt = userProvider.createdAt;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내 정보를 불러오지 못했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadScreenTimeSummary({bool showError = false}) async {
    if (mounted) {
      setState(() => _screenTimeLoading = true);
    }
    try {
      final summary = await _screenTimeApi.fetchSummary();
      if (!mounted) return;
      setState(() {
        _screenTimeSummary = summary;
        _screenTimeLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _screenTimeLoading = false);
      if (showError) {
        final message =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message;
        _showScreenTimeError(message ?? '스크린타임 요약을 불러오지 못했어요.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _screenTimeLoading = false);
      if (showError) {
        _showScreenTimeError('스크린타임 요약을 불러오지 못했어요.');
      }
    }
  }

  void _showScreenTimeError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateUserData() async {
    final navigator = Navigator.of(context);

    setState(() => isLoading = true);

    final trimmedName = nameController.text.trim();
    final valueGoal = valueGoalController.text.trim();
    final currentPw = currentPasswordController.text.trim();
    final newPw = newPasswordController.text.trim();
    final confirmPw = confirmPasswordController.text.trim();

    if (showPasswordFields && currentPw.isEmpty) {
      _showSnack('기존 비밀번호를 입력해야 합니다.');
      setState(() => isLoading = false);
      return;
    }

    if (newPw.isNotEmpty && newPw != confirmPw) {
      _showSnack('새 비밀번호가 일치하지 않습니다.');
      setState(() => isLoading = false);
      return;
    }

    try {
      final userProvider = context.read<UserProvider>();

      if (trimmedName.isNotEmpty && trimmedName != userProvider.userName) {
        await _usersApi.updateMe({'name': trimmedName});
        userProvider.updateUserName(trimmedName);
      }

      if (valueGoal.isNotEmpty && valueGoal != (userProvider.valueGoal ?? '')) {
        await _userDataApi.updateValueGoal(valueGoal);
        userProvider.setValueGoalLocally(valueGoal);
      }

      if (showPasswordFields && newPw.isNotEmpty) {
        await _authApi.changePassword(
          currentPassword: currentPw,
          newPassword: newPw,
        );
        if (!mounted) return;
        _showSnack('비밀번호가 변경되었습니다. 다시 로그인해주세요.');

        await _authApi.logout();
        if (!mounted) return;

        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
        return;
      }

      _showSnack('내 정보가 업데이트되었습니다.');
      setState(() {
        isEditing = false;
        showPasswordFields = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final message =
          e.response?.data is Map
              ? e.response?.data['detail']?.toString()
              : e.message;
      _showSnack('업데이트 실패: ${message ?? '오류가 발생했습니다.'}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('업데이트 실패: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);

    setState(() => isLoading = true);
    try {
      await _authApi.logout();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  int daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return da.difference(db).inDays;
  }

  @override
  Widget build(BuildContext context) {
    const Color deepNavy = Color(0xFF1E2F3F);
    const Color skyBlue = Color(0xFF63C6EC);

    final double maxCardWidth = MediaQuery.of(context).size.width - 32;

    final String joinDateText =
        createdAt != null
            ? DateFormat('yyyy년 MM월 dd일').format(createdAt!)
            : '가입일 정보 없음';

    final userProvider = context.watch<UserProvider>();
    final String displayName =
        nameController.text.trim().isNotEmpty
            ? nameController.text.trim()
            : userProvider.userName;
    final String displayEmail =
        emailController.text.trim().isNotEmpty
            ? emailController.text.trim()
            : userProvider.userEmail;
    final String displayValueGoal =
        valueGoalController.text.trim().isNotEmpty
            ? valueGoalController.text.trim()
            : (userProvider.valueGoal?.trim().isNotEmpty == true
                ? userProvider.valueGoal!.trim()
                : '아직 설정된 핵심 가치가 없어요.');

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '내 정보',
          style: TextStyle(
            color: deepNavy,
            fontWeight: FontWeight.w700,
            fontFamily: 'Noto Sans KR',
          ),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: deepNavy),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.18),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF6FBFE).withValues(alpha: 0.90),
                    const Color(0xFFEDF7FB).withValues(alpha: 0.84),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: SizedBox(
                  width: maxCardWidth,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileOverviewCard(
                            name: displayName,
                            email: displayEmail,
                            valueGoal: displayValueGoal,
                            joinDateText: joinDateText,
                          ),
                          const SizedBox(height: 14),
                          _buildProgressSnapshotCard(
                            streakText:
                                createdAt != null
                                    ? '${daysBetween(DateTime.now(), createdAt!).clamp(0, 999)}일째'
                                    : '기록 준비 중',
                          ),
                          const SizedBox(height: 14),
                          _buildSectionShell(
                            title: '프로필',
                            subtitle: '내 정보와 핵심 가치를 관리해요.',
                            child: Column(
                              children: [
                                _buildPrimaryActionRow(
                                  icon: Icons.edit_outlined,
                                  title: '프로필 수정',
                                  subtitle:
                                      isEditing
                                          ? '현재 편집 모드입니다. 수정 후 저장해 주세요.'
                                          : '이름과 핵심 가치를 수정할 수 있어요.',
                                  badge: isEditing ? '편집 중' : '수정',
                                  onTap:
                                      isLoading
                                          ? null
                                          : () => setState(
                                            () => isEditing = !isEditing,
                                          ),
                                ),
                                if (isEditing) ...[
                                  const SizedBox(height: 12),
                                  _buildFormPanel(
                                    children: [
                                      _buildTextField(
                                        controller: nameController,
                                        label: '이름',
                                        icon: Icons.person_outline,
                                        enabled: !isLoading,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller: emailController,
                                        label: '이메일',
                                        icon: Icons.email_outlined,
                                        enabled: false,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller: valueGoalController,
                                        label: '나의 핵심 가치',
                                        icon: Icons.favorite_outline,
                                        enabled: !isLoading,
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed:
                                              isLoading
                                                  ? null
                                                  : _updateUserData,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: skyBlue,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: const Text(
                                            '프로필 저장',
                                            style: TextStyle(
                                              fontFamily: 'Noto Sans KR',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildSectionShell(
                            title: '리포트',
                            subtitle: '최근 활동과 요약 지표를 확인해요.',
                            child: _buildScreenTimeCard(),
                          ),
                          const SizedBox(height: 14),
                          _buildSectionShell(
                            title: '계정 및 보안',
                            subtitle: '보안 관련 설정을 관리해요.',
                            child: Column(
                              children: [
                                _buildPrimaryActionRow(
                                  icon: Icons.lock_outline,
                                  title: '비밀번호 변경',
                                  subtitle:
                                      showPasswordFields
                                          ? '현재 비밀번호와 새 비밀번호를 입력해 주세요.'
                                          : '비밀번호를 변경하고 계정을 안전하게 관리하세요.',
                                  badge: showPasswordFields ? '열림' : '관리',
                                  onTap:
                                      isLoading
                                          ? null
                                          : () => setState(() {
                                            showPasswordFields =
                                                !showPasswordFields;
                                          }),
                                ),
                                if (showPasswordFields) ...[
                                  const SizedBox(height: 12),
                                  _buildFormPanel(
                                    children: [
                                      _buildTextField(
                                        controller: currentPasswordController,
                                        label: '기존 비밀번호',
                                        icon: Icons.lock_outline,
                                        enabled: !isLoading,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller: newPasswordController,
                                        label: '새 비밀번호',
                                        icon: Icons.lock_reset_outlined,
                                        enabled: !isLoading,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildTextField(
                                        controller: confirmPasswordController,
                                        label: '새 비밀번호 확인',
                                        icon: Icons.verified_user_outlined,
                                        enabled: !isLoading,
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed:
                                              isLoading
                                                  ? null
                                                  : _updateUserData,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: deepNavy,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: const Text(
                                            '비밀번호 변경 적용',
                                            style: TextStyle(
                                              fontFamily: 'Noto Sans KR',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                _buildPrimaryActionRow(
                                  icon: Icons.devices_outlined,
                                  title: '로그인 기기 관리',
                                  subtitle: '추후 등록 기기 및 접속 이력을 확인할 수 있어요.',
                                  badge: '준비 중',
                                ),
                                const SizedBox(height: 10),
                                _buildPrimaryActionRow(
                                  icon: Icons.logout,
                                  title: '로그아웃',
                                  subtitle: '현재 계정에서 안전하게 로그아웃합니다.',
                                  badge: '실행',
                                  onTap: isLoading ? null : _logout,
                                  isDestructive: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildSectionShell(
                            title: '설정 및 지원',
                            subtitle: '추후 세부 화면으로 확장될 영역이에요.',
                            child: Column(
                              children: [
                                _buildPrimaryActionRow(
                                  icon: Icons.notifications_none,
                                  title: '알림 설정',
                                  subtitle: '푸시 알림 시간, 빈도, 수신 여부 관리',
                                  badge: '준비 중',
                                ),
                                const SizedBox(height: 10),
                                _buildPrimaryActionRow(
                                  icon: Icons.bar_chart_rounded,
                                  title: '상세 리포트',
                                  subtitle: '주간/월간 감정 및 수행 변화 리포트 확인',
                                  badge: '준비 중',
                                ),
                                const SizedBox(height: 10),
                                _buildPrimaryActionRow(
                                  icon: Icons.support_agent_outlined,
                                  title: '문의하기',
                                  subtitle: '오류 제보, 이용 문의, 고객 지원 연결',
                                  badge: '준비 중',
                                ),
                                const SizedBox(height: 10),
                                _buildPrimaryActionRow(
                                  icon: Icons.privacy_tip_outlined,
                                  title: '약관 및 개인정보 처리방침',
                                  subtitle: '서비스 정책 및 개인정보 보호 관련 문서',
                                  badge: '보기',
                                ),
                                const SizedBox(height: 10),
                                _buildPrimaryActionRow(
                                  icon: Icons.info_outline,
                                  title: '앱 버전',
                                  subtitle: '현재 버전 1.0.0 (UI placeholder)',
                                  badge: '정보',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOverviewCard({
    required String name,
    required String email,
    required String valueGoal,
    required String joinDateText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: Color(0xFF1E2F3F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2F3F),
                        fontFamily: 'Noto Sans KR',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF728292),
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EFF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '나의 핵심 가치',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF81909D),
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  valueGoal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF31485D),
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '가입일 $joinDateText',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF8A98A4),
              fontFamily: 'Noto Sans KR',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2F3F),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFF728292),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPrimaryActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final Color accent =
        isDestructive ? const Color(0xFFE45B66) : const Color(0xFF1E2F3F);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color:
              isDestructive ? const Color(0xFFFFFAFB) : const Color(0xFFF8FBFD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isDestructive
                    ? const Color(0xFFFFE5E8)
                    : const Color(0xFFE8EEF3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    isDestructive
                        ? const Color(0xFFFFF1F3)
                        : const Color(0xFFEFF7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 21, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.42,
                      color: Color(0xFF728292),
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDestructive
                              ? const Color(0xFFFFF1F3)
                              : const Color(0xFFEFF7FB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent.withValues(alpha: 0.72),
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA9B5BF),
                  size: 21,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPanel({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF3)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildProgressSnapshotCard({required String streakText}) {
    return Row(
      children: [
        Expanded(
          child: _buildSnapshotTile(
            icon: Icons.psychology_alt_outlined,
            label: '현재 프로그램',
            value: 'Self Talk',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSnapshotTile(
            icon: Icons.flag_outlined,
            label: '진행 단계',
            value: '3주차',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSnapshotTile(
            icon: Icons.local_fire_department_outlined,
            label: '연속 참여',
            value: streakText,
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTimeCard() {
    final summary = _screenTimeSummary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '리포트 요약',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1E2F3F),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 12),
          if (_screenTimeLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (summary == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '요약을 불러오지 못했습니다.',
                  style: TextStyle(color: Colors.black54),
                ),
                TextButton(
                  onPressed: () => _loadScreenTimeSummary(showError: true),
                  child: const Text('다시 시도'),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                _metricTile('총 사용 시간', _formatDuration(summary.totalMinutes)),
                const SizedBox(width: 10),
                _metricTile('오늘', _formatDuration(summary.todayMinutes)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metricTile('최근 7일', _formatDuration(summary.weekMinutes)),
                const SizedBox(width: 10),
                _metricTile('기록 횟수', '${summary.sessions}회'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '추후 이 영역에는 주간 감정 변화, 수행률, 자기대화 패턴 요약이 함께 표시될 예정이에요.',
              style: TextStyle(
                fontSize: 12.8,
                height: 1.45,
                color: Color(0xFF7A8895),
                fontFamily: 'Noto Sans KR',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSnapshotTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFCFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EDF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E2F3F)),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8694A0),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2F3F),
              fontFamily: 'Noto Sans KR',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7EDF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8794A0),
                fontFamily: 'Noto Sans KR',
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2F3F),
                fontFamily: 'Noto Sans KR',
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double minutes) {
    final totalSeconds = (minutes * 60).round();
    if (totalSeconds <= 0) return '0초';
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    if (mins > 0 && secs > 0) return '$mins분 $secs초';
    if (mins > 0) return '$mins분';
    return '$secs초';
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: label.contains('비밀번호'),
      style: const TextStyle(
        fontFamily: 'Noto Sans KR',
        fontSize: 16,
        color: Color(0xFF333333),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF004C73)),
        filled: true,
        fillColor: enabled ? const Color(0xFFF5FBFF) : const Color(0xFFEFF7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9EEFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9EEFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF89D4F5), width: 1.6),
        ),
      ),
    );
  }
}
