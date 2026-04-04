import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:provider/provider.dart';

/// 보관함 일기 목록 화면
class ArchivedDiaryScreen extends StatefulWidget {
  final String groupId;
  final String groupTitle;
  final String groupContents;
  final int characterId;
  final DateTime createdAt;
  final DateTime archivedAt;

  const ArchivedDiaryScreen({
    super.key,
    required this.groupId,
    required this.groupTitle,
    required this.groupContents,
    required this.characterId,
    required this.createdAt,
    required this.archivedAt,
  });

  @override
  State<ArchivedDiaryScreen> createState() => _ArchivedDiaryScreenState();
}

class _MoveGroupTarget {
  const _MoveGroupTarget({
    required this.groupId,
    required this.title,
    required this.characterId,
  });

  final String groupId;
  final String title;
  final int? characterId;
}

class _ArchivedDiaryScreenState extends State<ArchivedDiaryScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final WorryGroupsApi _worryGroupsApi = WorryGroupsApi(_apiClient);

  List<Map<String, dynamic>> _diaries = [];
  Map<String, String> _activeGroupTitles = {};
  Map<String, int?> _activeGroupCharacters = {};
  final Set<String> _movingDiaryIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadActiveGroupTitles();

      final response = await _apiClient.dio.get(
        '/diaries',
        queryParameters: {'group_id': widget.groupId, 'include_drafts': true},
      );

      final diaries =
          (response.data as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;

      setState(() {
        _diaries = diaries;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message ?? '알 수 없는 오류가 발생했습니다.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '일기를 불러오지 못했습니다: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadActiveGroupTitles() async {
    try {
      final groups = await _worryGroupsApi.listWorryGroups(
        includeArchived: false,
      );

      final titles = <String, String>{};
      final characters = <String, int?>{};
      for (final group in groups) {
        final groupId = group['group_id']?.toString();
        if (groupId == null || groupId.isEmpty) continue;
        titles[groupId] = group['group_title']?.toString() ?? '제목 없음';

        final characterId = group['character_id'];
        if (characterId is int) {
          characters[groupId] = characterId;
        } else if (characterId is num) {
          characters[groupId] = characterId.toInt();
        } else if (characterId != null) {
          characters[groupId] = int.tryParse(characterId.toString());
        } else {
          characters[groupId] = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _activeGroupTitles = titles;
        _activeGroupCharacters = characters;
      });
    } catch (e) {
      debugPrint('❌ 활성 그룹 목록 로드 실패: $e');
    }
  }

  String? _resolveDiaryId(Map<String, dynamic> diary) {
    final diaryId = diary['diary_id'] ?? diary['diaryId'] ?? diary['id'];
    final resolved = diaryId?.toString().trim();
    if (resolved == null || resolved.isEmpty) return null;
    return resolved;
  }

  List<_MoveGroupTarget> _buildMoveTargets() {
    final targets =
        _activeGroupTitles.entries
            .where((entry) => entry.key != widget.groupId)
            .map(
              (entry) => _MoveGroupTarget(
                groupId: entry.key,
                title: entry.value,
                characterId: _activeGroupCharacters[entry.key],
              ),
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    return targets;
  }

  Future<void> _showMoveDiaryDialog(Map<String, dynamic> diary) async {
    final diaryId = _resolveDiaryId(diary);
    if (diaryId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이동할 일기 정보를 찾지 못했습니다.')));
      return;
    }

    final moveTargets = _buildMoveTargets();
    if (moveTargets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이동할 수 있는 다른 그룹이 없습니다.')));
      return;
    }

    final selectedTarget = await showDialog<_MoveGroupTarget>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        _MoveGroupTarget? pendingSelection;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 20,
              ),
              child: SizedBox(
                width: MediaQuery.of(dialogContext).size.width,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE3F2FD),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F4FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Color(0xFF5B9FD3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '일기 이동',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0E2C48),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF6B7A89),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFD8EBFA),
                            width: 1.1,
                          ),
                        ),
                        child: Text(
                          '현재 그룹: ${widget.groupTitle}\n'
                          '옮길 물고기 카드를 선택하면 이 보관함 목록에서 빠집니다.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF35546F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: GridView.builder(
                          shrinkWrap: true,
                          itemCount: moveTargets.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisExtent: 116,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemBuilder: (context, index) {
                            final target = moveTargets[index];
                            return _MoveTargetFishCard(
                              target: target,
                              isSelected:
                                  pendingSelection?.groupId == target.groupId,
                              onTap:
                                  () => setDialogState(
                                    () => pendingSelection = target,
                                  ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF5B9FD3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(
                                  color: Color(0xFF5B9FD3),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  pendingSelection == null
                                      ? null
                                      : () => Navigator.pop(
                                        dialogContext,
                                        pendingSelection,
                                      ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFF5B9FD3),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '이동',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedTarget == null) return;

    await _moveDiaryToGroup(
      diaryId: diaryId,
      targetGroupId: selectedTarget.groupId,
      targetGroupTitle: selectedTarget.title,
    );
  }

  Future<void> _moveDiaryToGroup({
    required String diaryId,
    required String targetGroupId,
    required String targetGroupTitle,
  }) async {
    if (_movingDiaryIds.contains(diaryId)) return;

    setState(() => _movingDiaryIds.add(diaryId));

    try {
      await _diariesApi.updateDiary(diaryId, {'group_id': targetGroupId});

      if (!mounted) return;

      setState(() {
        _diaries =
            _diaries
                .where((diary) => _resolveDiaryId(diary) != diaryId)
                .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일기를 "$targetGroupTitle" 그룹으로 이동했어요.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final message =
          e.response?.data is Map
              ? e.response?.data['detail']?.toString()
              : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? '일기를 다른 그룹으로 이동하지 못했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일기를 다른 그룹으로 이동하지 못했습니다.')));
    } finally {
      if (mounted) {
        setState(() => _movingDiaryIds.remove(diaryId));
      }
    }
  }

  Future<void> _startApplyFlowForDiary(Map<String, dynamic> diary) async {
    final diaryId = diary['diary_id']?.toString().trim() ?? '';
    if (diaryId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택한 일기 정보를 찾을 수 없어요.')));
      return;
    }

    final flow = context.read<ApplyOrSolveFlow>();
    flow.clear();
    flow.setOrigin('apply');
    flow.setDiaryRoute('notification');
    flow.setDiaryId(diaryId);

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/before_sud',
      arguments: {
        ...flow.toArgs(),
        'origin': 'apply',
        'abcId': diaryId,
        'isHomeTodayDiary': false,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '그룹 일기 목록',
        showHome: true,
        confirmOnHome: false,
        confirmOnBack: false,
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
                      colors: [Color(0xAAFFFFFF), Color(0x66FFFFFF)],
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final createdStr = DateFormat(
      'yyyy년 MM월 dd일 HH:mm',
    ).format(widget.createdAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F4FD), Color(0xFFF5FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF5B9FD3), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B9FD3).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 캐릭터와 제목
          Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B9FD3).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/image/character${widget.characterId}.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => const Icon(
                        Icons.catching_pokemon,
                        size: 36,
                        color: Color(0xFF5B9FD3),
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목과 일기 개수를 한 줄로
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.groupTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0E2C48),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B9FD3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_diaries.length}개',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 그룹 설명 (박스 없이 텍스트만)
                    if (widget.groupContents.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.groupContents,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B405C),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 생성일시
          _buildDateRow(Icons.create_outlined, '생성일시', createdStr),
        ],
      ),
    );
  }

  Widget _buildDateRow(IconData icon, String label, String date) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5B9FD3)),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8ABEE3),
            ),
          ),
        ),
        Expanded(
          child: Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B9FD3)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFF1B405C), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadDiaries,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9FD3),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_diaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '작성된 일기가 없습니다.',
              style: TextStyle(
                color: Color(0xFF1B405C),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _diaries.length,
      itemBuilder: (context, index) {
        final diary = _diaries[index];
        return _ExpandableDiaryCard(
          diary: diary,
          characterId: widget.characterId,
          onStartFlow: () => _startApplyFlowForDiary(diary),
          canMove: _buildMoveTargets().isNotEmpty,
          isMoving:
              _resolveDiaryId(diary) != null &&
              _movingDiaryIds.contains(_resolveDiaryId(diary)!),
          onMovePressed: () => _showMoveDiaryDialog(diary),
        );
      },
    );
  }
}

class _ExpandableDiaryCard extends StatefulWidget {
  final Map<String, dynamic> diary;
  final int characterId;
  final VoidCallback onStartFlow;
  final bool canMove;
  final bool isMoving;
  final VoidCallback onMovePressed;

  const _ExpandableDiaryCard({
    required this.diary,
    required this.characterId,
    required this.onStartFlow,
    required this.canMove,
    required this.isMoving,
    required this.onMovePressed,
  });

  @override
  State<_ExpandableDiaryCard> createState() => _ExpandableDiaryCardState();
}

class _MoveTargetFishCard extends StatelessWidget {
  const _MoveTargetFishCard({
    required this.target,
    required this.isSelected,
    required this.onTap,
  });

  final _MoveGroupTarget target;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
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
                      Colors.white.withValues(alpha: 0.82),
                      Colors.white.withValues(alpha: 0.68),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          borderRadius: BorderRadius.circular(18),
          border:
              isSelected
                  ? Border.all(color: const Color(0xFF5B9FD3), width: 2.2)
                  : Border.all(color: const Color(0xFFE3F2FD), width: 1.1),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? const Color(0xFF5B9FD3).withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 220),
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
                              : Colors.white.withValues(alpha: 0.78),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isSelected
                                  ? const Color(
                                    0xFF5B9FD3,
                                  ).withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.04),
                          blurRadius: isSelected ? 14 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/image/character${target.characterId ?? 1}.png',
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => Icon(
                            Icons.catching_pokemon,
                            size: 34,
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
            const SizedBox(height: 6),
            Text(
              target.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: isSelected ? 11.5 : 11,
                color:
                    isSelected
                        ? const Color(0xFF0E2C48)
                        : const Color(0xFF4A5568),
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDiaryCardState extends State<_ExpandableDiaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final diary = widget.diary;
    final characterId = widget.characterId;

    final diaryId = diary['diary_id']?.toString() ?? '';
    final createdAt = diary['created_at']?.toString() ?? '';
    final dateStr =
        createdAt.isNotEmpty
            ? DateFormat('yyyy.MM.dd HH:mm').format(DateTime.parse(createdAt))
            : '';

    final latestSud = diary['latest_sud'];
    final sudStr = latestSud != null ? latestSud.toString() : '-';

    // activation.label을 제목으로 사용
    final activation = diary['activation'];
    final title =
        activation is Map
            ? (activation['label']?.toString() ?? '제목 없음')
            : '제목 없음';

    // 일기 내용 데이터
    final belief = diary['belief'] as List?;
    final consequencePhysical = diary['consequence_physical'] as List?;
    final consequenceEmotion = diary['consequence_emotion'] as List?;
    final consequenceAction = diary['consequence_action'] as List?;

    // 디버그: 데이터 확인
    debugPrint('📝 일기 ID: $diaryId');
    debugPrint('  activation: $activation');
    debugPrint('  belief 개수: ${belief?.length ?? 0}');
    debugPrint('  belief 데이터: $belief');
    debugPrint('  consequencePhysical 개수: ${consequencePhysical?.length ?? 0}');
    debugPrint('  consequenceEmotion 개수: ${consequenceEmotion?.length ?? 0}');
    debugPrint('  consequenceAction 개수: ${consequenceAction?.length ?? 0}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _isExpanded ? const Color(0xFF5B9FD3) : const Color(0xFFE3F2FD),
          width: _isExpanded ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _isExpanded
                    ? const Color(0xFF5B9FD3).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.06),
            blurRadius: _isExpanded ? 16 : 12,
            offset: Offset(0, _isExpanded ? 6 : 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더 (항상 표시)
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF5FAFF),
                        border: Border.all(
                          color: const Color(0xFFE3F2FD),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        'assets/image/character$characterId.png',
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              size: 24,
                              color: Color(0xFF5B9FD3),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0E2C48),
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Color(0xFF5B9FD3),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5B9FD3),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF5B9FD3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '불안 점수',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5B9FD3),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sudStr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0E2C48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF5B9FD3),
                    ),
                  ],
                ),

                // 펼쳐진 내용
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE3F2FD)),
                  const SizedBox(height: 12),

                  // 믿음 (Belief)
                  if (belief != null && belief.isNotEmpty)
                    _buildSection('믿음', belief, Icons.psychology_outlined),

                  // 신체 결과 (Physical)
                  if (consequencePhysical != null &&
                      consequencePhysical.isNotEmpty)
                    _buildSection(
                      '신체 반응',
                      consequencePhysical,
                      Icons.favorite_outline,
                    ),

                  // 감정 결과 (Emotion)
                  if (consequenceEmotion != null &&
                      consequenceEmotion.isNotEmpty)
                    _buildSection(
                      '감정',
                      consequenceEmotion,
                      Icons.mood_outlined,
                    ),

                  // 행동 결과 (Action)
                  if (consequenceAction != null && consequenceAction.isNotEmpty)
                    _buildSection(
                      '행동',
                      consequenceAction,
                      Icons.directions_run_outlined,
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onStartFlow,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('일기에 대해 도움이 되는 생각 해보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2F6FA1),
                        side: const BorderSide(color: Color(0xFF9CC5E8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          widget.canMove && !widget.isMoving
                              ? widget.onMovePressed
                              : null,
                      icon:
                          widget.isMoving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(widget.canMove ? '다른 그룹으로 이동' : '이동할 그룹 없음'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2F6FA1),
                        side: const BorderSide(color: Color(0xFF9CC5E8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String sectionTitle, List items, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF5B9FD3)),
              const SizedBox(width: 8),
              Text(
                sectionTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0E2C48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                items.map((item) {
                  final label =
                      item is Map ? (item['label']?.toString() ?? '') : '';
                  if (label.isEmpty) return const SizedBox.shrink();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5FAFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD6E2FF)),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF496AC6),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
