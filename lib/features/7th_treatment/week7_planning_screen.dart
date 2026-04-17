// File: features/7th_treatment/week7_planning_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_plan_summary_screen.dart';
import 'package:gad_app_team/features/7th_treatment/week7_behavior_type_select_screen.dart';
import 'package:gad_app_team/widgets/behavior_confirm_dialog.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/widgets/eduhome_bg.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';
import 'package:gad_app_team/data/api/user_data_api.dart';
import 'package:gad_app_team/data/api/week7_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

// ─────────────────────────────────────────────
class Week7PlanningScreen extends StatefulWidget {
  final String? sessionId;

  const Week7PlanningScreen({super.key, this.sessionId});

  @override
  State<Week7PlanningScreen> createState() => _Week7PlanningScreenState();
}

class _Week7PlanningScreenState extends State<Week7PlanningScreen> {
  // 레이아웃 상수
  static const double _sidePadding = 34; // 좌우 여백
  static const List<String> _suggestedBehaviors = [
    '호흡 1분 하기',
    '잠깐 산책하기',
    '생각 기록하기',
    '도움 요청하기',
  ];

  // Week7AddDisplayScreen 전역 상태와 싱크될 목록들
  final TextEditingController _newBehaviorController = TextEditingController();
  final List<String> _addedBehaviors = [];
  final List<String> _newBehaviors = [];

  // 사용자 이름/핵심가치
  String? _userName;
  String? _userValueGoal;

  // API 클라이언트
  late final ApiClient _apiClient;
  late final Week7Api _week7Api;
  late final CustomTagsApi _customTagsApi;
  String? _week7SessionId;

  static const Color _bluePrimary = Color(0xFF5DADEC);

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(tokens: TokenStorage());
    _week7Api = Week7Api(_apiClient);
    _customTagsApi = CustomTagsApi(_apiClient);
    _week7SessionId = widget.sessionId?.trim();
    _loadAddedBehaviors();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 복귀 시 전역 상태 동기화
    _loadAddedBehaviors();
  }

  // ───────────────── 로드/세이브/삭제 로직 ─────────────────
  void _loadAddedBehaviors() {
    final globalBehaviors = Week7AddDisplayScreen.globalAddedBehaviors;
    final globalNewBehaviors = Week7AddDisplayScreen.globalNewBehaviors;

    setState(() {
      _addedBehaviors
        ..clear()
        ..addAll(globalBehaviors);
      _newBehaviors
        ..clear()
        ..addAll(globalNewBehaviors);
    });
  }

  Future<void> _loadUserData() async {
    try {
      // UserProvider에서 사용자 이름 가져오기
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _userName = userProvider.userName;
      
      // 핵심 가치는 UserDataApi를 통해 가져오기
      final apiClient = ApiClient(tokens: TokenStorage());
      final userDataApi = UserDataApi(apiClient);
      final valueGoalData = await userDataApi.getValueGoal();
      _userValueGoal = valueGoalData?['value_goal'] as String?;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 실패: $e');
    }
  }

  // ───────────────── 행동 추가/삭제 및 다이얼로그 ─────────────────
  void _addNewBehavior() {
    final behavior = _newBehaviorController.text.trim();
    if (behavior.isNotEmpty) {
      _showAddBehaviorDialog(behavior);
    }
  }

  void _showAddBehaviorDialog(String behavior) {
    final sb = StringBuffer();
    if (_userName != null) {
      sb.writeln('$_userName님, 이 행동을 불안한 상황에서 실천해보시려는군요.');
    } else {
      sb.writeln('이 행동을 불안한 상황에서 실천해보시려는군요.');
    }
    sb.writeln();

    if (_userValueGoal != null) {
      if (_userName != null) {
        sb.writeln('$_userName님께서 소중히 여기는 가치는 "$_userValueGoal"입니다.');
      } else {
        sb.writeln('소중히 여기는 가치는 $_userValueGoal입니다.');
      }
      sb.writeln();
      sb.writeln('이 가치를 실현하기 위해 추가하시는 행동이 도움이 될 것 같다면 추가해주세요.');
      sb.writeln();
      sb.writeln('아니라면 가치에 더 맞도록 조금 바꿔봤을 때 어떤 행동이 더 나을지 생각해보아요.');
    } else {
      sb.writeln('이 행동이 앞으로의 대처에 도움이 될 것 같다면 추가해주세요.');
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) {
        return BehaviorConfirmDialog(
          titleText: '행동 계획 추가',
          highlightText: '"$behavior"',
          messageText: sb.toString(),
          negativeText: '추가하지 않을래요',
          positiveText: '추가할게요',
          onNegativePressed: () {
            Navigator.of(context).pop();
            _newBehaviorController.clear();
          },
          onPositivePressed: () {
            Navigator.of(context).pop();
            _confirmAddBehavior(behavior);
          },
          badgeBgAsset: 'assets/image/popup1.png',
          memoBgAsset: 'assets/image/popup2.png',
        );
      },
    );
  }

  Future<void> _confirmAddBehavior(String behavior) async {
    try {
      final chipId = await _ensureChipIdForBehavior(behavior);
      if (!mounted) return;

      final result = await Navigator.push<String>(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week7BehaviorTypeSelectScreen(
                behavior: behavior,
                chipId: chipId,
                sessionId: _week7SessionId,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );

      if (!mounted) return;

      if (result == 'face') {
        await _addConfrontBehaviorFromPlanning(behavior, chipId);
      } else if (result == 'avoid_added') {
        final updatedAdded = Set<String>.from(
          Week7AddDisplayScreen.globalAddedBehaviors,
        );
        setState(() {
          _addedBehaviors
            ..clear()
            ..addAll(updatedAdded);
          _newBehaviors.remove(behavior);
        });
        BlueBanner.show(context, '"$behavior"이(가) 회피 행동으로 추가되었습니다.');
      }

      _newBehaviorController.clear();
    } catch (e) {
      if (!mounted) return;
      BlueBanner.show(context, '행동 추가를 시작할 수 없습니다: $e');
    }
  }

  Future<void> _removeAddedBehavior(String behavior) async {
    try {
      // chip_id 찾기
      final behaviorToChip = Week7AddDisplayScreen.globalBehaviorToChip;
      final chipId = behaviorToChip[behavior];
      
      if (chipId != null) {
        // 백엔드에서 삭제
        final sessionId = await _ensureWeek7Session();
        await _week7Api.deleteClassificationItem(
          sessionId: sessionId,
          chipId: chipId,
        );
      }

      // 전역 상태 업데이트
      final newGlobalBehaviors = Set<String>.from(_addedBehaviors)..remove(behavior);
      Week7AddDisplayScreen.updateGlobalAddedBehaviors(newGlobalBehaviors);

      if (mounted) {
        setState(() {
          _addedBehaviors.remove(behavior);
        });
        BlueBanner.show(context, '"$behavior"이(가) 목록에서 제거되었습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      BlueBanner.show(context, '제거에 실패했습니다: $e');
    }
  }

  void _removeNewBehavior(String behavior) {
    final newGlobalBehaviors = List<String>.from(_newBehaviors)..remove(behavior);
    Week7AddDisplayScreen.updateGlobalNewBehaviors(newGlobalBehaviors);

    setState(() {
      _newBehaviors.remove(behavior);
    });

    BlueBanner.show(context, '행동이 제거되었습니다.');
  }

  Future<String> _ensureChipIdForBehavior(String behavior) async {
    final label = behavior.trim();
    if (label.isEmpty) {
      throw Exception('행동명이 비어 있습니다.');
    }

    final existingMap = Week7AddDisplayScreen.globalBehaviorToChip;
    final existingChip = existingMap[label];
    if (existingChip != null && existingChip.isNotEmpty) {
      return existingChip;
    }

    final tags = await _customTagsApi.listCustomTags(chipType: 'CA');
    for (final tag in tags) {
      final text = (tag['text'] ?? tag['label'])?.toString().trim();
      final chipId = tag['chip_id']?.toString();
      if (text == label && chipId != null && chipId.isNotEmpty) {
        Week7AddDisplayScreen.registerGlobalBehaviorToChip(label, chipId);
        return chipId;
      }
    }

    final created = await _customTagsApi.createCustomTag(
      label: label,
      type: 'CA',
    );
    final chipId =
        (created['chip_id'] ?? created['_id'])?.toString().trim();
    if (chipId == null || chipId.isEmpty) {
      throw Exception('chip_id 생성 실패');
    }
    Week7AddDisplayScreen.registerGlobalBehaviorToChip(label, chipId);
    return chipId;
  }

  Future<void> _addConfrontBehaviorFromPlanning(
    String behavior,
    String chipId,
  ) async {
    final sessionId = await _ensureWeek7Session();
    await _week7Api.upsertClassificationItem(
      sessionId: sessionId,
      chipId: chipId,
      label: behavior,
      classification: 'confront',
    );

    final updatedAdded = Set<String>.from(_addedBehaviors)..add(behavior);
    Week7AddDisplayScreen.updateGlobalAddedBehaviors(updatedAdded);
    Week7AddDisplayScreen.registerGlobalBehaviorToChip(behavior, chipId);

    if (!mounted) return;
    setState(() {
      _addedBehaviors
        ..clear()
        ..addAll(updatedAdded);
      _newBehaviors.remove(behavior);
    });
    BlueBanner.show(context, '"$behavior"이(가) 직면 행동으로 추가되었습니다.');
  }

  Future<String> _ensureWeek7Session() async {
    if (_week7SessionId != null && _week7SessionId!.isNotEmpty) {
      return _week7SessionId!;
    }
    throw Exception('7주차 세션 ID를 확인할 수 없습니다.');
  }

  // ───────────────── UI ─────────────────
  @override
  Widget build(BuildContext context) {
    return EduhomeBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: const CustomAppBar(title: '계획 세우기'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, bottom: 32),
            child: Column(
              children: [
                _buildPlanOverviewSection(),
                const SizedBox(height: 14),
                _buildHealthyHabitsSection(),
                const SizedBox(height: 14),
                _buildSuggestionSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
child: NavigationButtons(
            leftLabel: '이전',
            rightLabel: '다음',
            onBack: () => Navigator.pop(context),
            onNext: () {
              final planned = <String>[];
              for (final behavior in [..._addedBehaviors, ..._newBehaviors]) {
                if (!planned.contains(behavior)) {
                  planned.add(behavior);
                }
              }
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (_, __, ___) => Week7PlanSummaryScreen(
                        plannedBehaviors: planned,
                        sessionId: _week7SessionId,
                      ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────
  // 상단 요약 카드
  Widget _buildPlanOverviewSection() {
    final totalCount = _addedBehaviors.length + _newBehaviors.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2EEF8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF5DADEC), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '불안이 올라오면 바로 할 행동을 미리 정해두세요.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D4D67),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    label: '선택한 행동',
                    value: '$totalCount개',
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _PlanStatHintChip(
                    label: '추천',
                    value: '3개 이상',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCDE5FA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4F6D86),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1F4D77),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // 상단 행동 계획 카드
  Widget _buildHealthyHabitsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA1CEDF).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '불안 상황 행동 계획',
              style: TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B3A57),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '한 주 동안 불안한 상황에서\n어떤 행동을 하고 싶은지 적어보세요.',
              style: TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 14,
                color: Color(0xFF356D91),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_addedBehaviors.isNotEmpty) ...[
                    const Text(
                      '추가된 행동들',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._addedBehaviors.map((behavior) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 234, 245, 252),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF33A4F0).withValues(alpha: 0.28),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF33A4F0),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                behavior,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeAddedBehavior(behavior),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  if (_addedBehaviors.isEmpty && _newBehaviors.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8EBFB)),
                      ),
                      child: const Text(
                        '아직 등록된 행동이 없어요.\n작게 시작할 수 있는 행동 1개부터 추가해보세요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4D6C86),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const Text(
                    '행동 추가',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '불안한 상황이 왔을 때 실제로 할 행동을 구체적으로 적어보세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A8FA3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newBehaviorController,
                          decoration: InputDecoration(
                            hintText: '불안한 상황에서 하고 싶은 행동을 입력하세요',
                            hintStyle: const TextStyle(
                              color: Color(0xFFA0AEC0),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _bluePrimary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _addNewBehavior,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bluePrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_newBehaviors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._newBehaviors.map((behavior) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xF0F6FBFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.28),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle,
                              color: Color(0xFF2196F3),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                behavior,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeNewBehavior(behavior),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '빠른 추가 추천',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF36556F),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedBehaviors.map((behavior) {
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    _newBehaviorController.text = behavior;
                    _addNewBehavior();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF7FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFCFE5F8)),
                    ),
                    child: Text(
                      behavior,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF33506A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newBehaviorController.dispose();
    super.dispose();
  }
}

class _PlanStatHintChip extends StatelessWidget {
  final String label;
  final String value;

  const _PlanStatHintChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1EAF3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6D8194),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4F6578),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
