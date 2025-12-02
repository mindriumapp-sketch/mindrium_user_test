import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:intl/intl.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/menu/menu_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _selectedGroupId;
  late final ApiClient _apiClient;
  List<Map<String, dynamic>> _archivedGroups = [];
  Map<String, int> _diaryCountByGroup = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final tokens = TokenStorage();
    _apiClient = ApiClient(tokens: tokens);
    _loadArchivedGroups();
  }

  Future<void> _loadArchivedGroups() async {
    setState(() => _isLoading = true);
    try {
      // 아카이브된 그룹 목록 조회 (include_archived=true)
      final response = await _apiClient.dio.get(
        '/users/me/worry-groups',
        queryParameters: {'include_archived': true},
      );
      final groups =
          (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint('🔍 전체 그룹 수: ${groups.length}');

      for (var g in groups) {
        debugPrint(
          '📦 그룹: id=${g['group_id']}, title=${g['group_title']}, archived=${g['archived']}',
        );
      }

      final archived = groups.where((g) => g['archived'] == true).toList();
      debugPrint('✅ 아카이브된 그룹 수: ${archived.length}');

      // 보관일 최근순 정렬
      archived.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['archived_at']?.toString() ?? '') ??
            DateTime(0);
        final bDate =
            DateTime.tryParse(b['archived_at']?.toString() ?? '') ??
            DateTime(0);
        return bDate.compareTo(aDate);
      });

      // 각 그룹의 일기 개수 조회
      final Map<String, int> counts = {};
      for (final group in archived) {
        final groupId = group['group_id']?.toString() ?? '';
        if (groupId.isEmpty) continue;

        try {
          final response = await _apiClient.dio.get(
            '/diaries',
            queryParameters: {'group_id': int.tryParse(groupId) ?? 0},
          );
          counts[groupId] = (response.data as List?)?.length ?? 0;
        } catch (e) {
          debugPrint('❌ 그룹 $groupId 일기 개수 조회 실패: $e');
          counts[groupId] = 0;
        }
      }

      setState(() {
        _archivedGroups = archived;
        _diaryCountByGroup = counts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 아카이브 그룹 불러오기 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '걱정 물고기 보관함',
        showHome: true,
        confirmOnHome: false,
        confirmOnBack: false,
        onBack: () {
          Navigator.pop(
            context,
            MaterialPageRoute(builder: (context) => const ContentScreen()),
          );
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🎨 배경
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

          // 📜 본문
          SafeArea(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5B9FD3),
                        strokeWidth: 3,
                      ),
                    )
                    : _archivedGroups.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '걱정 물고기를 보관해보세요 🪸',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;

                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 32 : 16,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 🎯 섹션 타이틀
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
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
                                            color: Colors.black.withValues(alpha: 0.05,),
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
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 🐠 N×N 그리드 (유리병 느낌 카드)
                              _buildGridCards(context: context, isWide: isWide),

                              // 📝 상세 카드 (테두리 유지)
                              if (_selectedGroupId != null)
                                const SizedBox(height: 24),
                              if (_selectedGroupId != null) _buildDetailCard(),

                              const SizedBox(height: 20),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// 🔲 N×N 그리드 레이아웃 (반응형)
  Widget _buildGridCards({
    required BuildContext context,
    required bool isWide,
  }) {
    // 화면 크기에 따라 열 개수 결정
    final crossAxisCount = isWide ? 4 : 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 더 투명한 배경으로 물결 무늬 노출
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.82, // 적당한 가로세로 비율
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: _archivedGroups.length,
        itemBuilder: (context, index) {
          final group = _archivedGroups[index];
          return _buildGlassBottleCard(
            group: group,
            isSelected: _selectedGroupId == group['group_id']?.toString(),
            onTap: () {
              setState(() {
                final groupId = group['group_id']?.toString();
                // 이미 선택된 카드를 다시 클릭하면 토글
                if (_selectedGroupId == groupId) {
                  _selectedGroupId = null;
                } else {
                  _selectedGroupId = groupId;
                }
              });
            },
          );
        },
      ),
    );
  }

  /// 🍶 유리병 느낌 카드 (선택 시 강조 표현 강화)
  Widget _buildGlassBottleCard({
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
          // 🍶 유리병 느낌: 선택 시 더 밝고 선명한 그라데이션
          gradient:
              isSelected
                  ? const LinearGradient(
                    colors: [
                      Color(0xFFE8F4FD), // 밝은 파란색 톤
                      Color(0xFFF0F8FF),
                    ],
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
          // ✨ 선택 시 테두리 추가 + 더 강한 그림자
          border:
              isSelected
                  ? Border.all(color: const Color(0xFF5B9FD3), width: 2.5)
                  : null,
          boxShadow: [
            // 메인 그림자
            BoxShadow(
              color:
                  isSelected
                      ? const Color(0xFF5B9FD3).withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 24 : 16,
              spreadRadius: isSelected ? 2 : 0,
              offset: Offset(0, isSelected ? 10 : 6),
            ),
            // 선택 시 추가 글로우 효과
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
            // 🐟 캐릭터 이미지 (선택 시 스케일 효과)
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
                        // 선택 시 더 밝고 선명한 배경
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
                            isSelected ? null : Colors.white.withValues(alpha: 0.7),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isSelected
                                    ? const Color(0xFF5B9FD3).withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                            blurRadius: isSelected ? 16 : 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/image/character$groupId.png',
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

            // 📝 제목 (선택 시 더 진한 색상)
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📋 상세 카드 (테두리 유지)
  Widget _buildDetailCard() {
    if (_selectedGroupId == null) return const SizedBox.shrink();

    final matches =
        _archivedGroups
            .where((g) => (g['group_id']?.toString() ?? '') == _selectedGroupId)
            .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    final group = matches.first;
    final groupId = group['group_id']?.toString() ?? '';
    final title = group['group_title']?.toString() ?? '';
    final contents = group['group_contents']?.toString() ?? '';
    final archivedAt =
        DateTime.tryParse(group['archived_at']?.toString() ?? '') ??
        DateTime.now();
    final archivedStr = DateFormat('yyyy.MM.dd').format(archivedAt);
    final count = _diaryCountByGroup[groupId] ?? 0;

    return GestureDetector(
      onTap: () {
        // 상세 카드 클릭 시 닫기
        setState(() => _selectedGroupId = null);
      },
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
          // ✅ 테두리 유지
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
            // 🎯 헤더
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 캐릭터 아바타
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
                          color: const Color(0xFF5B9FD3).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/image/character$groupId.png',
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

                // 제목 및 보관일
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

            // 📝 설명
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 📔 일기 CTA
            GestureDetector(
              onTap: () {
                // 일기 목록 화면으로 이동
                Navigator.pushNamed(
                  context,
                  '/diary_directory',
                  arguments: {'groupId': int.tryParse(groupId) ?? 0},
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
}
