import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/features/menu/menu_screen.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/worry_groups_api.dart';
import 'package:gad_app_team/utils/server_datetime.dart';

/// ----------------------
/// DiaryDirectoryScreen
/// ----------------------
class DiaryDirectoryScreen extends StatefulWidget {
  const DiaryDirectoryScreen({super.key});

  @override
  State<DiaryDirectoryScreen> createState() => _DiaryDirectoryScreenState();
}

class _DiaryDirectoryScreenState extends State<DiaryDirectoryScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);
  late final DiariesApi _diariesApi = DiariesApi(_apiClient);
  late final WorryGroupsApi _worryGroupsApi = WorryGroupsApi(_apiClient);

  /// 일기 전체 목록 (백엔드 응답 정규화한 형태)
  List<Map<String, dynamic>> _diaries = [];

  /// 그룹 ID(uuid) -> 제목
  Map<String, String> _groupTitles = {};

  /// 그룹 ID(uuid) -> character_id
  Map<String, int?> _groupCharacters = {};

  /// 보관함이 아닌 active 그룹 ID(uuid) 집합
  Set<String> _activeGroupIds = {};

  /// 선택된 그룹 ID(uuid). null이면 "전체 그룹" 의미
  String? _selectedGroupId;

  /// 이동 처리 중인 diary_id 집합
  final Set<String> _movingDiaryIds = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // arguments로 groupId 받아서 초기 필터 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['groupId'] != null) {
        setState(() {
          _selectedGroupId = args['groupId'].toString();
        });
      }
    });

    Future.microtask(_loadDiaries);
  }

  /// worry_groups에서 그룹 메타정보(제목, character_id, activeGroupIds) 한 번에 로드
  Future<void> _loadGroupMeta() async {
    try {
      final groups = await _worryGroupsApi.listWorryGroups(
        includeArchived: false,
      );

      final titles = <String, String>{};
      final characters = <String, int?>{};
      final activeIds = <String>{};

      for (final group in groups) {
        final id = group['group_id'];
        if (id == null) continue;

        final idStr = id.toString();
        activeIds.add(idStr);

        final title = group['group_title']?.toString() ?? '제목 없음';
        titles[idStr] = title;

        final ch = group['character_id'];
        if (ch is int) {
          characters[idStr] = ch;
        } else if (ch != null) {
          characters[idStr] = int.tryParse(ch.toString());
        } else {
          characters[idStr] = null;
        }
      }

      if (mounted) {
        setState(() {
          _groupTitles = titles;
          _groupCharacters = characters;
          _activeGroupIds = activeIds;
        });
      }
    } catch (e) {
      debugPrint('❌ 그룹 메타 로드 실패: $e');
    }
  }

  /// "전체 그룹" + 개별 그룹 ID(uuid) 리스트
  List<String?> _extractGroupIds() {
    final sorted = _groupTitles.keys.toList()..sort();
    return [null, ...sorted];
  }

  Future<void> _loadDiaries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // worry_groups 메타 먼저 로드 (제목, 캐릭터, activeGroupIds)
      await _loadGroupMeta();

      final rawEntries = await _diariesApi.listDiaries();

      // 응답 정규화
      final normalized =
          rawEntries.map((e) {
            final map = Map<String, dynamic>.from(e);

            // group_id를 항상 String(uuid)로 통일
            final g = map['group_id'];
            if (g != null) {
              map['group_id'] = g.toString();
            }

            // created_at / updated_at은 카드에서 사용 시 필요하면 그때 parse
            return map;
          }).toList();

      if (!mounted) return;

      setState(() {
        _diaries = normalized;
        // 선택된 그룹이 있어도 자동 초기화는 하지 않고 그대로 둔다.
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data is Map
                ? e.response?.data['detail']?.toString()
                : e.message ?? '알 수 없는 오류가 발생했습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '일기를 불러오지 못했습니다: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _resolveDiaryId(Map<String, dynamic> entry) {
    final diaryId = entry['diary_id'] ?? entry['diaryId'] ?? entry['id'];
    final resolved = diaryId?.toString().trim();
    if (resolved == null || resolved.isEmpty) return null;
    return resolved;
  }

  List<MapEntry<String, String>> _buildMoveTargets(String currentGroupId) {
    final entries =
        _groupTitles.entries
            .where((entry) => entry.key != currentGroupId)
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  Future<void> _showMoveDiaryDialog(Map<String, dynamic> entry) async {
    final diaryId = _resolveDiaryId(entry);
    final currentGroupId = entry['group_id']?.toString();

    if (diaryId == null || currentGroupId == null || currentGroupId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이동할 일기 정보를 찾지 못했습니다.')));
      return;
    }

    final moveTargets = _buildMoveTargets(currentGroupId);
    if (moveTargets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이동할 수 있는 다른 그룹이 없습니다.')));
      return;
    }

    final currentGroupTitle = _groupTitles[currentGroupId] ?? '현재 그룹';

    final selectedTarget = await showDialog<MapEntry<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        MapEntry<String, String>? pendingSelection;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                            Icons.swap_horiz_rounded,
                            color: Color(0xFF5B9FD3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '일기 이동',
                            style: TextStyle(
                              fontSize: 20,
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
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD8EBFA),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '현재 그룹: $currentGroupTitle\n옮길 그룹을 선택해주세요.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF35546F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: Column(
                          children:
                              moveTargets.map((target) {
                                final isSelected =
                                    pendingSelection?.key == target.key;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap:
                                        () => setDialogState(
                                          () => pendingSelection = target,
                                        ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? const Color(0xFFE9F5FF)
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF5B9FD3)
                                                  : const Color(0xFFE3F2FD),
                                          width: isSelected ? 1.8 : 1.1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              target.value,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    isSelected
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                color: const Color(0xFF0E2C48),
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            color: const Color(0xFF5B9FD3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF5B9FD3)),
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
                        const SizedBox(width: 12),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
            );
          },
        );
      },
    );

    if (selectedTarget == null) return;

    await _moveDiaryToGroup(
      diaryId: diaryId,
      targetGroupId: selectedTarget.key,
      targetGroupTitle: selectedTarget.value,
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
            _diaries.map((entry) {
              if (_resolveDiaryId(entry) != diaryId) return entry;
              return {...entry, 'group_id': targetGroupId};
            }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: '일기 목록',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  /// 자동 생성 일기 여부 (걱정일기 없이 위치만으로 생성된 더미 일기)
  bool _isAutoGeneratedDiary(Map<String, dynamic> entry) {
    final activation = entry['activation'];
    final label =
        activation is Map
            ? activation['label']?.toString() ?? ''
            : activation?.toString() ?? '';

    // DiaryYesOrNo._handleNo 에서 생성하는 패턴:
    // '자동 생성 일기 \n주소: ...'
    return label.startsWith('자동 생성 일기');
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B9FD3)),
      );
    }
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadDiaries, child: const Text('다시 시도')),
        ],
      );
    }
    if (_diaries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDiaries,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                '작성된 일기가 없습니다.',
                style: TextStyle(color: Color(0xFF1B405C), fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    // 보관함이 아닌 그룹에 속한 일기만 표시.
    // group_id == null 인 일기는 "없는 것"으로 간주하여 제외.
    // + 자동 생성 일기(위치 기반 더미)는 목록에서 숨김.
    final activeDiaries =
        _diaries.where((d) {
          final gid = d['group_id'];
          if (gid == null) return false; // group 없는 일기: 제외
          if (_isAutoGeneratedDiary(d)) return false; // 자동 생성 일기 숨김
          return _activeGroupIds.contains(gid);
        }).toList();

    final filtered =
        _selectedGroupId == null
            ? activeDiaries
            : activeDiaries
                .where((d) => d['group_id'] == _selectedGroupId)
                .toList();

    return RefreshIndicator(
      onRefresh: _loadDiaries,
      child: Column(
        children: [
          _GroupFilter(
            selectedGroupId: _selectedGroupId,
            groupIds: _extractGroupIds(),
            groupTitles: _groupTitles,
            diaries: activeDiaries,
            totalDiaries: activeDiaries.length,
            onSelected: (value) {
              setState(() => _selectedGroupId = value);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                filtered.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.only(bottom: 24, top: 40),
                      children: [
                        Center(
                          child: Text(
                            _selectedGroupId == null
                                ? '작성된 일기가 없습니다.'
                                : '선택한 그룹에는 작성된 일기가 없습니다.',
                            style: const TextStyle(
                              color: Color(0xFF1B405C),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final gid = entry['group_id']?.toString();
                        final characterId =
                            gid != null ? _groupCharacters[gid] : null;

                        return _DiaryCard(
                          entry: entry,
                          characterId: characterId,
                          groupTitle:
                              gid != null
                                  ? _groupTitles[gid] ?? '알 수 없는 그룹'
                                  : null,
                          canMove:
                              gid != null && _buildMoveTargets(gid).isNotEmpty,
                          isMoving:
                              _resolveDiaryId(entry) != null &&
                              _movingDiaryIds.contains(_resolveDiaryId(entry)!),
                          onMovePressed: () => _showMoveDiaryDialog(entry),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// 그룹 필터 칩 영역
/// ----------------------
class _GroupFilter extends StatelessWidget {
  final List<String?> groupIds;
  final Map<String, String> groupTitles;
  final List<Map<String, dynamic>> diaries;
  final int totalDiaries;
  final String? selectedGroupId;
  final ValueChanged<String?> onSelected;

  const _GroupFilter({
    required this.groupIds,
    required this.groupTitles,
    required this.diaries,
    required this.totalDiaries,
    required this.selectedGroupId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_outlined, color: Color(0xFF5B9FD3)),
                  SizedBox(width: 8),
                  Text(
                    '그룹 필터',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E2C48),
                    ),
                  ),
                ],
              ),
              Text(
                '${diaries.length}/$totalDiaries',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B9FD3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                groupIds.map((id) {
                  final bool selected = id == selectedGroupId;
                  final groupDiaryCount =
                      id == null
                          ? diaries.length
                          : diaries.where((d) => d['group_id'] == id).length;
                  final label =
                      id == null
                          ? '전체 그룹 ($groupDiaryCount)'
                          : '${groupTitles[id] ?? '그룹 #$id'} ($groupDiaryCount)';

                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => onSelected(id),
                    selectedColor: const Color(0xFF5B9FD3),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF1B405C),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// 일기 카드
/// ----------------------
class _DiaryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int? characterId;
  final String? groupTitle;
  final bool canMove;
  final bool isMoving;
  final VoidCallback onMovePressed;

  const _DiaryCard({
    required this.entry,
    required this.characterId,
    required this.groupTitle,
    required this.canMove,
    required this.isMoving,
    required this.onMovePressed,
  });

  List<String> _chipLabels(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map) {
              final label = e['label'];
              return label?.toString();
            }
            return e?.toString();
          })
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy.MM.dd HH:mm');

    // created_at 파싱 (이미 DateTime이면 그대로 사용)
    final createdRaw = entry['created_at'];
    final DateTime? createdAt = parseServerDateTime(createdRaw);
    final created = createdAt != null
        ? formatter.format(createdAt)
        : '-';

    // activation DiaryChip → label 추출
    final activationRaw = entry['activation'];
    final activationLabel =
        activationRaw is Map
            ? (activationRaw['label']?.toString() ?? '')
            : activationRaw?.toString() ?? '';

    // 칩 리스트들 label 추출
    final beliefLabels = _chipLabels(entry['belief']);
    final physicalLabels = _chipLabels(entry['consequence_physical']);
    final emotionLabels = _chipLabels(entry['consequence_emotion']);
    final actionLabels = _chipLabels(entry['consequence_action']);

    // latest_sud (int 또는 double 가능)
    final num? latestSud = entry['latest_sud'] as num?;

    // 위치/시간 단건 정규화 (구 alarms 배열 fallback 지원)
    final rawLocTime = entry['loc_time'] ?? entry['alarms'];
    Map<String, dynamic>? locTimeEntry;
    if (rawLocTime is Map) {
      locTimeEntry = rawLocTime.map((k, v) => MapEntry(k.toString(), v));
    } else if (rawLocTime is List && rawLocTime.isNotEmpty) {
      final mapped =
          rawLocTime
              .whereType<Map>()
              .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
              .toList()
              .cast<Map<String, dynamic>>();
      if (mapped.isNotEmpty) {
        locTimeEntry = mapped.last;
      }
    }
    final bool locAutoFilled = entry['loc_auto_filled'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFB8DAF5),
            backgroundImage:
                characterId != null
                    ? AssetImage('assets/image/character$characterId.png')
                    : null,
            child:
                characterId == null
                    ? const Icon(Icons.help_outline, color: Color(0xFF0E2C48))
                    : null,
          ),
          title: Text(
            activationLabel.isNotEmpty ? activationLabel : '(빈 제목)',
            style: const TextStyle(
              color: Color(0xFF0E2C48),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              created,
              style: const TextStyle(color: Color(0xFF1B405C), fontSize: 14),
            ),
          ),
          children: [
            _SudScoreBar(latestSud: latestSud),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3F2FD), width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '현재 그룹',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B9FD3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          groupTitle ?? '알 수 없는 그룹',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E2C48),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: canMove && !isMoving ? onMovePressed : null,
                    icon:
                        isMoving
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.swap_horiz_rounded),
                    label: Text(canMove ? '다른 그룹으로 이동' : '이동할 그룹 없음'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF417CAF),
                      side: const BorderSide(color: Color(0xFF90CAF9)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              icon: Icons.psychology_outlined,
              title: '생각 (Belief)',
              child: Text(
                beliefLabels.isEmpty ? '-' : beliefLabels.join(', '),
                style: const TextStyle(color: Color(0xFF1B405C)),
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              icon: Icons.local_hospital_outlined,
              title: '신체 반응',
              child: Text(
                physicalLabels.isEmpty ? '-' : physicalLabels.join(', '),
                style: const TextStyle(color: Color(0xFF1B405C)),
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              icon: Icons.mood_outlined,
              title: '감정 반응',
              child: Text(
                emotionLabels.isEmpty ? '-' : emotionLabels.join(', '),
                style: const TextStyle(color: Color(0xFF1B405C)),
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              icon: Icons.directions_walk_outlined,
              title: '행동 반응',
              child: Text(
                actionLabels.isEmpty ? '-' : actionLabels.join(', '),
                style: const TextStyle(color: Color(0xFF1B405C)),
              ),
            ),
            const SizedBox(height: 12),
            _AlarmSection(locTimeEntry: locTimeEntry),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              icon: Icons.location_on_outlined,
              title: (!locAutoFilled) ? '위치 기록' : '작성 위치',
              child: Text(
                entry['loc_time']?.location_label,
                style:
                const TextStyle(color: Color(0xFF1B405C)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------
/// SUD 요약 막대 (latest_sud 기준)
/// ----------------------
class _SudScoreBar extends StatelessWidget {
  final num? latestSud;
  const _SudScoreBar({required this.latestSud});

  @override
  Widget build(BuildContext context) {
    double score = (latestSud ?? 0).toDouble();
    if (score < 0) score = 0;
    if (score > 10) score = 10;

    final ratio = score / 10.0;
    final color =
        Color.lerp(const Color(0xFF4CAF50), const Color(0xFFF44336), ratio)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '주관적 불안점수 (최근 기준)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0E2C48),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${score.toStringAsFixed(1)} / 10',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// 알람 섹션
/// ----------------------
class _AlarmSection extends StatelessWidget {
  final Map<String, dynamic>? locTimeEntry;

  const _AlarmSection({required this.locTimeEntry});

  @override
  Widget build(BuildContext context) {
    if (locTimeEntry == null) {
      return _buildSection(
        context: context,
        icon: Icons.access_time_outlined,
        title: '위치/시간 정보',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '설정된 위치/시간이 없습니다.',
              style: TextStyle(color: Color(0xFF1B405C)),
            ),
          ],
        ),
      );
    }

    return _buildSection(
      context: context,
      icon: Icons.alarm_on_outlined,
      title: '위치/시간 정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (_) {
              final map = locTimeEntry!;
              final location =
                  map['location'] ??
                  map['location_desc'] ??
                  map['address_name'] ??
                  map['addressName'] ??
                  '-';
              final time = map['time'] ?? map['scheduledTime'] ?? '-';

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4A8CCB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      Icons.location_on_outlined,
                      '위치',
                      location.toString(),
                    ),
                    const SizedBox(height: 6),
                    _infoRow(Icons.access_time_outlined, '시간', time.toString()),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// 공통 섹션 & row 유틸
/// ----------------------
Widget _buildSection({
  required BuildContext context,
  required IconData icon,
  required String title,
  required Widget child,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF90CAF9), width: 1.2),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(icon, color: const Color(0xFF5B9FD3), size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0E2C48),
            fontSize: 14,
          ),
        ),
        children: [child],
      ),
    ),
  );
}

Widget _infoRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF5B9FD3)),
      const SizedBox(width: 6),
      Text(
        '$label: ',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0E2C48),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1B405C)),
        ),
      ),
    ],
  );
}
