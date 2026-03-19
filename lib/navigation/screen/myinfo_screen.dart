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
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/education_week_contents.dart';
import 'package:gad_app_team/data/api/screen_time_api.dart';
import 'package:gad_app_team/features/menu/archive/archived_diary_screen.dart';

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

  List<Map<String, dynamic>> _archivedGroups = [];
  bool _archiveLoading = true;
  String? _selectedArchiveGroupId;

  bool _didSyncEducation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadScreenTimeSummary();
    _loadArchivedGroups();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 교육 탭과 연동: 현재 주차 완료 상태 한 번 동기화
    if (!_didSyncEducation) {
      _didSyncEducation = true;
      final user = context.read<UserProvider>();
      final todayTask = context.read<TodayTaskProvider>();
      if (user.isUserLoaded) {
        todayTask.syncEducationWeekStatus(user.currentWeek);
      }
    }
  }

  Future<void> _loadArchivedGroups() async {
    try {
      final response = await _apiClient.dio.get('/worry-groups/archived');
      final archived =
          (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      archived.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['archived_at']?.toString() ?? '') ??
            DateTime(0);
        final bDate =
            DateTime.tryParse(b['archived_at']?.toString() ?? '') ??
            DateTime(0);
        return bDate.compareTo(aDate);
      });
      if (mounted) {
        setState(() {
          _archivedGroups = archived;
          _archiveLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 아카이브 그룹 불러오기 실패: $e');
      if (mounted) {
        setState(() => _archiveLoading = false);
      }
    }
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
    try {
      await _screenTimeApi.fetchSummary();
    } on DioException catch (e) {
      if (!mounted) return;
      if (showError) {
        final message =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message;
        _showScreenTimeError(message ?? '스크린타임 요약을 불러오지 못했어요.');
      }
    } catch (_) {
      if (!mounted) return;
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

  int daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return da.difference(db).inDays;
  }

  @override
  Widget build(BuildContext context) {
    const Color deepNavy = Color(0xFF1E2F3F);

    final double maxCardWidth = MediaQuery.of(context).size.width - 32;
    final double bottomSafeInset = MediaQuery.of(context).padding.bottom;
    const double extraBottomScrollSpace = 110.0;

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
          '마이페이지',
          style: TextStyle(
            color: deepNavy,
            fontWeight: FontWeight.w700,
            fontFamily: 'Noto Sans KR',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: deepNavy),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(
                Icons.settings_rounded,
                color: deepNavy,
                size: 26,
              ),
              tooltip: '환경설정',
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  bottomSafeInset + extraBottomScrollSpace,
                ),
                child: SizedBox(
                  width: maxCardWidth,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileOverviewCard(
                            name: '안녕하세요, $displayName님',
                            email: displayEmail,
                            valueGoal: displayValueGoal,
                            joinDateText: joinDateText,
                            onEditTap:
                                isLoading
                                    ? null
                                    : () =>
                                        setState(() => isEditing = !isEditing),
                          ),
                          const SizedBox(height: 14),
                          _buildProgressSnapshotCard(
                            userProvider: userProvider,
                            todayTask: context.watch<TodayTaskProvider>(),
                            streakText:
                                createdAt != null
                                    ? '${daysBetween(DateTime.now(), createdAt!).clamp(0, 999)+1}일째'
                                    : '기록 준비 중',
                          ),
                          const SizedBox(height: 14),
                          _buildArchivedWorryFishSection(),
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
    VoidCallback? onEditTap,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2F3F),
                        fontFamily: 'Noto Sans KR',
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '이메일 : ${email.isNotEmpty ? email : '-'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF8B97A3),
                        fontFamily: 'Noto Sans KR',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onEditTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5C6470),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '프로필 수정',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 18),
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
                    onPressed: isLoading ? null : _updateUserData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF63C6EC),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
          ] else ...[
            const SizedBox(height: 18),
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
        ],
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

  Widget _buildProgressSnapshotCard({
    required UserProvider userProvider,
    required TodayTaskProvider todayTask,
    required String streakText,
  }) {
    final recentProgram = EducationProgressDisplay.recentProgram(
      userProvider,
      todayTask,
    );
    final progressStage = EducationProgressDisplay.progressStage(
      userProvider,
      todayTask,
    );

    return Row(
      children: [
        Expanded(
          child: _buildSnapshotTile(
            icon: Icons.psychology_alt_outlined,
            label: '최근 프로그램',
            value: recentProgram,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSnapshotTile(
            icon: Icons.flag_outlined,
            label: '진행 단계',
            value: progressStage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSnapshotTile(
            icon: Icons.local_fire_department_outlined,
            label: '함께한 시간',
            value: streakText,
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedWorryFishSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  '보관된 걱정 물고기',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E2C48),
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF5B9FD3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '총 ${_archivedGroups.length}개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B9FD3),
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_archiveLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Color(0xFF5B9FD3),
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else if (_archivedGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: const Color(0xFF5B9FD3).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '보관된 걱정 그룹이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF1B405C),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '걱정 물고기를 보관해보세요 🪸',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                ],
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.82,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: _archivedGroups.length,
                  itemBuilder: (context, index) {
                    final group = _archivedGroups[index];
                    final groupId = group['group_id']?.toString() ?? '';
                    return _buildWorryFishCard(
                      group: group,
                      isSelected: _selectedArchiveGroupId == groupId,
                      onTap: () {
                        setState(() {
                          if (_selectedArchiveGroupId == groupId) {
                            _selectedArchiveGroupId = null;
                          } else {
                            _selectedArchiveGroupId = groupId;
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
            if (_selectedArchiveGroupId != null) const SizedBox(height: 24),
            if (_selectedArchiveGroupId != null) _buildArchivedDetailCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildWorryFishCard({
    required Map<String, dynamic> group,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final groupId = group['group_id']?.toString() ?? '';
    final title = group['group_title']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? const LinearGradient(
                    colors: [Color(0xFFE8F4FD), Color(0xFFF0F8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected
                  ? Border.all(color: const Color(0xFF5B9FD3), width: 2.5)
                  : null,
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? const Color(0xFF5B9FD3).withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 24 : 16,
              spreadRadius: isSelected ? 2 : 0,
              offset: Offset(0, isSelected ? 10 : 6),
            ),
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF5B9FD3).withValues(alpha: 0.2),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, 0),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Hero(
                  tag: 'character_$groupId',
                  child: AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            isSelected
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFF5FAFF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                : null,
                        color:
                            isSelected
                                ? null
                                : Colors.white.withValues(alpha: 0.7),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isSelected
                                    ? const Color(
                                      0xFF5B9FD3,
                                    ).withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                            blurRadius: isSelected ? 16 : 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/image/character${group['character_id']}.png',
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stack) => Icon(
                              Icons.catching_pokemon,
                              size: 50,
                              color:
                                  isSelected
                                      ? const Color(0xFF5B9FD3)
                                      : Colors.grey.shade400,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isSelected ? 13 : 12.5,
                color:
                    isSelected
                        ? const Color(0xFF0E2C48)
                        : const Color(0xFF4A5568),
                height: 1.3,
                letterSpacing: -0.2,
                fontFamily: 'Noto Sans KR',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedDetailCard() {
    if (_selectedArchiveGroupId == null) return const SizedBox.shrink();

    final matches =
        _archivedGroups
            .where(
              (g) =>
                  (g['group_id']?.toString() ?? '') == _selectedArchiveGroupId,
            )
            .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    final group = matches.first;
    final groupId = group['group_id']?.toString() ?? '';
    final characterId = group['character_id'] ?? 0;
    final title = group['group_title']?.toString() ?? '';
    final contents = group['group_contents']?.toString() ?? '';
    final archivedAt =
        DateTime.tryParse(group['archived_at']?.toString() ?? '') ??
        DateTime.now();
    final archivedStr = DateFormat('yyyy.MM.dd').format(archivedAt);
    final count = group['diary_count'] ?? 0;

    return GestureDetector(
      onTap: () => setState(() => _selectedArchiveGroupId = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFAFDFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF5B9FD3), width: 2.3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B9FD3).withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'detail_character_$groupId',
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB8DAF5), Color(0xFFD4E7F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF5B9FD3,
                          ).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/image/character$characterId.png',
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              size: 32,
                              color: Color(0xFF0E2C48),
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          color: Color(0xFF0E2C48),
                          height: 1.3,
                          letterSpacing: -0.3,
                          fontFamily: 'Noto Sans KR',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD6E2FF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Color(0xFF496AC6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '보관일: $archivedStr',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF496AC6),
                                fontFamily: 'Noto Sans KR',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B9FD3).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      contents.isEmpty ? '저장된 설명이 없습니다.' : contents,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF1B405C),
                        height: 1.58,
                        fontWeight:
                            contents.isEmpty
                                ? FontWeight.w500
                                : FontWeight.w600,
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ArchivedDiaryScreen(
                          groupId: groupId,
                          groupTitle: title,
                          groupContents: contents,
                          characterId: characterId,
                          createdAt:
                              DateTime.tryParse(
                                group['created_at']?.toString() ?? '',
                              ) ??
                              DateTime.now(),
                          archivedAt: archivedAt,
                        ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text(
                      '일기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF566370),
                        fontFamily: 'Noto Sans KR',
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFE8FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count개',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4659C2),
                          fontFamily: 'Noto Sans KR',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFF4659C2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8694A0),
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2F3F),
                  fontFamily: 'Noto Sans KR',
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
