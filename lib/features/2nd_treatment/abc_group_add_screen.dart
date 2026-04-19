import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/today_task_draft_progress.dart';
import 'package:gad_app_team/data/today_task_progress_sync.dart';

import '../../widgets/custom_appbar.dart';
import '../../widgets/navigation_button.dart';
import '../../data/storage/token_storage.dart';
import '../../data/api/api_client.dart';
import '../../data/api/worry_groups_api.dart';
import '../../data/api/diaries_api.dart';
import '../../data/api/alarm_settings_api.dart';
import '../alarm/alarm_notification_service.dart';
import '../alarm/alarm_settings_sync_helper.dart';
import 'abc_group_character_screen.dart';
import '../../data/apply_solve_provider.dart';
import 'loctime_selection_screen.dart';
import 'week2_final_screen.dart';

class AbcGroupAddScreen extends StatefulWidget {
  final String? label;
  final String? diaryId;
  final String? origin;
  final String? diaryRoute;
  final int? beforeSud;
  final String? sudId;
  final String? diary;
  final String? sessionId;

  const AbcGroupAddScreen({
    super.key,
    this.label,
    this.diaryId,
    this.origin,
    this.diaryRoute,
    this.beforeSud,
    this.sudId,
    this.diary,
    this.sessionId,
  });

  @override
  State<AbcGroupAddScreen> createState() => _AbcGroupAddScreenState();
}

class _AbcGroupAddScreenState extends State<AbcGroupAddScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final WorryGroupsApi _worryGroupsApi = WorryGroupsApi(_apiClient);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final AlarmSettingsApi _alarmSettingsApi = AlarmSettingsApi(_apiClient);
  final AlarmNotificationService _alarmService = AlarmNotificationService.instance;

  String? _selectedGroupId;
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _worryGroupsApi.listWorryGroups(
        includeArchived: false,
      );
      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 그룹 목록 로드 실패: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 그룹 상세 정보는 백엔드에서 이미 집계해준
  /// diary_count / avg_sud 를 그대로 사용
  Future<Map<String, dynamic>> _loadGroupDetails(String groupId) async {
    final group = _groups.firstWhere(
      (g) => g['group_id']?.toString() == groupId,
      orElse: () => <String, dynamic>{},
    );

    if (group.isEmpty) {
      return {'group': <String, dynamic>{}, 'diaryCount': 0, 'avgScore': 0.0};
    }

    final diaryCountRaw = group['diary_count'];
    final avgSudRaw = group['avg_sud'];

    final diaryCount =
        diaryCountRaw is num
            ? diaryCountRaw.toInt()
            : int.tryParse('$diaryCountRaw') ?? 0;
    final avgScore =
        avgSudRaw is num
            ? avgSudRaw.toDouble()
            : double.tryParse('$avgSudRaw') ?? 0.0;

    return {'group': group, 'diaryCount': diaryCount, 'avgScore': avgScore};
  }

  bool get _shouldContinueTherapyFlow =>
      (widget.origin == 'apply' || widget.origin == 'daily') &&
      widget.diaryId != null;

  String? _resolveDiaryRoute() {
    final route = widget.diaryRoute?.trim();
    if (route != null && route.isNotEmpty) {
      return route;
    }
    if (widget.origin == 'daily') {
      return 'today_task';
    }
    if (widget.origin == 'apply' || widget.origin == 'solve') {
      return 'solve';
    }
    return null;
  }

  double? _readDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  TimeOfDay? _parseTimeOfDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _maybeOfferSolveLocTimeAlarm(String? diaryRoute) async {
    if (!mounted) return;
    if (diaryRoute != 'solve') return;

    final diaryId = widget.diaryId;
    if (diaryId == null || diaryId.isEmpty) return;

    Map<String, dynamic>? locTime;
    try {
      locTime = await _diariesApi.getLocTime(diaryId);
    } catch (e) {
      debugPrint('⚠️ 일기 loc_time 조회 실패: $e');
      return;
    }

    if (!mounted || locTime == null) return;

    final timeOfDay = _parseTimeOfDay(locTime['time']?.toString());
    final latitude = _readDouble(locTime['latitude']);
    final longitude = _readDouble(locTime['longitude']);
    if (timeOfDay == null || latitude == null || longitude == null) return;

    final locationAddressRaw =
        (locTime['location_desc'] ?? locTime['location'])?.toString().trim();
    final resolvedAddress =
        (locationAddressRaw != null && locationAddressRaw.isNotEmpty)
            ? locationAddressRaw
            : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

    final localizations = MaterialLocalizations.of(context);
    final formattedTime = localizations.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    final shouldSet = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => CustomPopupDesign(
            title: '알림 설정',
            
            message:
                '마지막에 기록한 위치/시간으로 알림을 설정할까요?\n'
                '주소: $resolvedAddress\n'
                '시간: $formattedTime',
            positiveText: '설정',
            negativeText: '아니오',
            backgroundAsset: null,
            iconAsset: null,
            onPositivePressed: () => Navigator.pop(dialogCtx, true),
            onNegativePressed: () => Navigator.pop(dialogCtx, false),
          ),
    );
    if (shouldSet != true || !mounted) return;

    final alarmId = 'solve_loctime_$diaryId';
    final alarmLabel =
        (widget.label?.trim().isNotEmpty ?? false)
            ? '${widget.label!.trim()} 알림'
            : 'Mindrium 알림';

    try {
      final newAlarm = AlarmSetting(
        id: alarmId,
        hour: timeOfDay.hour,
        minute: timeOfDay.minute,
        label: alarmLabel,
        enabled: true,
        weekdays: const [1, 2, 3, 4, 5, 6, 7],
        vibration: true,
        locationEnabled: true,
        latitude: latitude,
        longitude: longitude,
        location: null,
        locationAddress: resolvedAddress,
        locationRadiusMeters: 100,
      );

      await AlarmSettingsSyncHelper.upsertAndSync(
        api: _alarmSettingsApi,
        alarm: newAlarm,
        service: _alarmService,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치/시간 알림이 설정되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 설정 저장에 실패했습니다: $e')));
    }
  }

  Future<void> _navigateAfterGroupSelection() async {
    if (!mounted) return;

    if (!_shouldContinueTherapyFlow) {
      final hasExplicitDiaryRoute = widget.diaryRoute?.trim().isNotEmpty == true;
      if (!hasExplicitDiaryRoute) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Week2FinalScreen(sessionId: widget.sessionId),
          ),
        );
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      return;
    }

    final normalizedOrigin = widget.origin == 'solve' ? 'apply' : widget.origin;
    final resolvedDiaryRoute = _resolveDiaryRoute();
    final flow =
        context.read<ApplyOrSolveFlow>()..syncFromArgs({
          'origin': normalizedOrigin,
          'diaryRoute': resolvedDiaryRoute,
          'diaryId': widget.diaryId,
          'beforeSud': widget.beforeSud,
          'sudId': widget.sudId,
          'diary': widget.diary,
        });
    flow.setOrigin(normalizedOrigin);
    flow.setDiaryRoute(resolvedDiaryRoute);
    flow.setDiaryId(widget.diaryId);
    if (widget.beforeSud != null) flow.setBeforeSud(widget.beforeSud);
    if (widget.sudId != null) flow.setSudId(widget.sudId);

    final args = <String, dynamic>{
      ...flow.toArgs(),
      'diaryId': widget.diaryId,
      if (widget.beforeSud != null) 'beforeSud': widget.beforeSud,
      if (widget.diary != null) 'diary': widget.diary,
      if (normalizedOrigin != null) 'origin': normalizedOrigin,
      if (widget.sudId != null) 'sudId': widget.sudId,
    };

    debugPrint('[Group_add] origin=$normalizedOrigin');

    await _maybeOfferSolveLocTimeAlarm(resolvedDiaryRoute);
    if (!mounted) return;

    if (normalizedOrigin == 'apply') {
      final userProvider = context.read<UserProvider>();
      final week = userProvider.lastCompletedWeek;
      if (!mounted) return;
      final route = week >= 4 ? '/relax_or_alternative' : '/relax_yes_or_no';
      Navigator.pushReplacementNamed(context, route, arguments: args);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> group) {
    final titleCtrl = TextEditingController(text: group['group_title']);
    final contentsCtrl = TextEditingController(text: group['group_contents']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFAFDFF), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A5B9FD3),
                blurRadius: 20,
                offset: Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B9FD3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "그룹 편집",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Color(0xFF0E2C48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3F2FD), width: 2),
                ),
                child: TextField(
                  controller: titleCtrl,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    labelText: '제목',
                    labelStyle: TextStyle(
                      color: Color(0xFF5B9FD3),
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3F2FD), width: 2),
                ),
                child: TextField(
                  controller: contentsCtrl,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    labelText: '설명',
                    labelStyle: TextStyle(
                      color: Color(0xFF5B9FD3),
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _worryGroupsApi.updateWorryGroup(
                            group['group_id']?.toString() ?? '',
                            groupTitle: titleCtrl.text,
                            groupContents: contentsCtrl.text,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadGroups();
                          }
                        } catch (e) {
                          debugPrint('❌ 그룹 수정 실패: $e');
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        '수정',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B9FD3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => AbcGroupCharacterScreen(
                  groups: _groups,
                  sessionId: widget.sessionId,
                ),
          ),
        );

        if (result == true && mounted) {
          debugPrint('🔄 그룹 추가 완료, 목록 새로고침');
          _loadGroups();
        }
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF5B9FD3).withValues(alpha: 0.4),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B9FD3).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF5B9FD3).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 32,
                color: Color(0xFF5B9FD3),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '추가하기',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF0E2C48),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required Map<String, dynamic> group,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final characterIdStr = group['character_id']?.toString() ?? '1';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? const LinearGradient(
                    colors: [Color(0xFFE0F2FF), Color(0xFFF0F9FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected
                  ? Border.all(color: const Color(0xFF5B9FD3), width: 2.5)
                  : Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? const Color(0xFF5B9FD3).withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 24 : 16,
              spreadRadius: isSelected ? 2 : 0,
              offset: Offset(0, isSelected ? 10 : 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: isSelected ? 0.6 : 0.4),
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, -2),
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
                child: AnimatedScale(
                  scale: isSelected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          isSelected
                              ? const LinearGradient(
                                colors: [Color(0xFFFFFFFF), Color(0xFFF5FAFF)],
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
                      'assets/image/character$characterIdStr.png',
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
            const SizedBox(height: 10),
            Text(
              group['group_title'] ?? '',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    final navigator = Navigator.of(context);
    final resolvedDiaryRoute = (widget.diaryRoute ?? '').trim();

    // today_task는 기존 예외 유지:
    // LocTimeSelectionScreen -> AbcGroupAddScreen 을 push로 탔을 가능성이 있으니
    // 여기서는 그냥 pop으로 이전 화면(기존 흐름) 복귀.
    if (resolvedDiaryRoute == 'today_task') {
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
      return;
    }

    // 일반 2nd treatment 흐름:
    // pop으로 돌아가지 말고, 같은 diaryId를 들고
    // LocTimeSelectionScreen(autoOpenMapOnEntry: true)로 명시 복귀.
    final diaryId = widget.diaryId;
    if (diaryId == null || diaryId.isEmpty) {
      // 여기 오면 안 되는 케이스지만, 방어적으로 처리.
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      navigator.pushNamedAndRemoveUntil('/home', (_) => false);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LocTimeSelectionScreen(
          abcId: diaryId,
          label: widget.label,
          origin: widget.origin,
          diaryRoute: widget.diaryRoute,
          sessionId: widget.sessionId,
          sudId: widget.sudId,
          beforeSud: widget.beforeSud,
          locationConsent: true,
          autoOpenMapOnEntry: true,
          autoNavigateGroupOnEntry: false,
        ),
      ),
    );
  }

  void _showWorryGroupHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final maxDialogHeight = MediaQuery.of(dialogContext).size.height * 0.78;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFAFDFF), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A5B9FD3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            color: Color(0xFF5B9FD3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '걱정 그룹이란?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0E2C48),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF6B7A89),
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD8EBFA),
                          width: 1.4,
                        ),
                      ),
                      child: const Text(
                        '걱정 그룹은 비슷한 걱정들을 한곳에 모아 관리하는 묶음이에요.\n'
                        '예를 들면 "시험 걱정", "친구 관계 걱정", "건강 걱정"처럼 주제별로 나눌 수 있어요.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF35546F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHelpSection(
                      icon: Icons.lightbulb_outline_rounded,
                      title: '이렇게 생각하면 쉬워요',
                      body:
                          '비슷한 상황에서 반복되는 걱정이라면 같은 그룹으로 묶어보세요. '
                          '주제가 다르거나 감정이 다르게 느껴지면 새 그룹으로 나누는 것이 좋아요.',
                    ),
                    const SizedBox(height: 12),
                    _buildHelpSection(
                      icon: Icons.check_circle_outline_rounded,
                      title: '이 화면에서 하는 일',
                      body:
                          '기존 그룹을 선택해 이어서 기록하거나, 왼쪽의 추가 버튼으로 새로운 걱정 그룹을 만들 수 있어요.',
                    ),
                    const SizedBox(height: 12),
                    _buildHelpSection(
                      icon: Icons.tips_and_updates_outlined,
                      title: '그룹 이름 팁',
                      body:
                          '나중에 다시 봐도 바로 이해되는 이름이 좋아요. '
                          '예: "발표 전 긴장", "친구와의 오해", "건강 검사 결과 걱정"',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B9FD3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F2FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF5B9FD3), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E2C48),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A6174),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: '걱정 그룹 선택',
          centerTitle: true,
          onBack: _handleBackNavigation,
          extraIcon: Icons.help_outline_rounded,
          onExtraPressed: _showWorryGroupHelpDialog,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image/eduhome.png', fit: BoxFit.cover),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xCCFFFFFF), Color(0x88FFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF5B9FD3),
                                  strokeWidth: 3,
                                ),
                              )
                              : GridView.count(
                                padding: const EdgeInsets.all(16),
                                crossAxisCount: 3,
                                childAspectRatio: 0.82,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: ClampingScrollPhysics(),
                                ),
                                children: [
                                  _buildAddCard(),
                                  for (final group in _groups)
                                    Builder(
                                      builder: (_) {
                                        final groupIdStr =
                                            group['group_id']?.toString() ?? '';
                                        final isSelected =
                                            _selectedGroupId == groupIdStr;
                                        return _buildGroupCard(
                                          group: group,
                                          isSelected: isSelected,
                                          onTap: () {
                                            setState(
                                              () =>
                                                  _selectedGroupId = groupIdStr,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                ],
                              ),
                    ),
                    if (_selectedGroupId != null) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 240,
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: _loadGroupDetails(_selectedGroupId!),
                          builder: (ctx, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF5B9FD3),
                                  strokeWidth: 3,
                                ),
                              );
                            }

                            if (snapshot.hasError || !snapshot.hasData) {
                              return const Center(
                                child: Text('그룹 정보를 불러오는 중 오류가 발생했습니다.'),
                              );
                            }

                            final details = snapshot.data!;
                            final data =
                                details['group'] as Map<String, dynamic>;
                            final count = details['diaryCount'] as int;
                            final avgScore = details['avgScore'] as double;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFAFDFF),
                                    Color(0xFFFFFFFF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF5B9FD3),
                                  width: 2.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF5B9FD3,
                                    ).withValues(alpha: 0.18),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${data['group_title']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                            color: Color(0xFF0E2C48),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap:
                                            () =>
                                                _showEditDialog(context, data),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF5B9FD3,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: Color(0xFF5B9FD3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF6FAFF),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text(
                                                '불안 점수',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF566370),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${avgScore.toStringAsFixed(1)}/10',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF7E57C2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF6FAFF),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text(
                                                '일기',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF566370),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$count개',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF5C6BC0),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF6FAFF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: SingleChildScrollView(
                                        child: Text(
                                          data['group_contents'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF1B405C),
                                            height: 1.6,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: NavigationButtons(
                leftLabel: '이전',
                rightLabel: '저장',
                onBack: _isSubmitting ? null : _handleBackNavigation,
                onNext:
                    (_selectedGroupId == null ||
                            widget.diaryId == null ||
                            _isSubmitting)
                        ? null
                        : () async {
                          setState(() => _isSubmitting = true);
                          try {
                            final isTodayTaskDraft =
                                _resolveDiaryRoute() == 'today_task';
                            debugPrint(
                              '🔵 그룹 업데이트 시작: diaryId=${widget.diaryId}, groupId=$_selectedGroupId',
                            );

                            // ✅ 백엔드 diaries 스키마: group_id(문자열)
                            await _diariesApi.updateDiary(widget.diaryId!, {
                              'group_id': _selectedGroupId,
                              if (isTodayTaskDraft)
                                'draft_progress':
                                    TodayTaskDraftProgress.groupCompleted,
                            });

                            if (isTodayTaskDraft && context.mounted) {
                              await syncTodayTaskDraftState(
                                context,
                                progress: TodayTaskDraftProgress.groupCompleted,
                                diaryId: widget.diaryId,
                              );
                              if (!context.mounted) return;
                            }

                            debugPrint(
                              '✅ 일기 그룹 할당 완료: diaryId=${widget.diaryId}, groupId=$_selectedGroupId',
                            );
                            if (!context.mounted) return;
                            await _navigateAfterGroupSelection();
                          } on DioException catch (e, stackTrace) {
                            debugPrint(
                              '❌ 일기 그룹 할당 DioException: ${e.response?.statusCode}',
                            );
                            debugPrint('Response data: ${e.response?.data}');
                            debugPrint('Request: PUT /diaries/${widget.diaryId}');
                            debugPrint('Body: {group_id: $_selectedGroupId}');
                            debugPrint('Error message: ${e.message}');
                            debugPrint('Stack trace: $stackTrace');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '그룹 할당 실패: ${e.response?.data ?? e.message}',
                                ),
                              ),
                            );
                            return;
                          } catch (e, stackTrace) {
                            debugPrint('❌ 일기 그룹 할당 실패: $e');
                            debugPrint('Stack trace: $stackTrace');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('그룹 할당 실패: $e')),
                            );
                            return;
                          } finally {
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                            } else {
                              _isSubmitting = false;
                            }
                          }
                        },
              )
            ),
          ),
        ),
      ),
    );
  }
}
