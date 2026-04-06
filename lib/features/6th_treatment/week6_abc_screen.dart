import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/features/6th_treatment/week6_concentration_screen.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

import 'week6_diary_utils.dart';
import 'week6_route_utils.dart';

class Week6AbcScreen extends StatefulWidget {
  final String? abcId;

  const Week6AbcScreen({super.key, this.abcId});

  @override
  State<Week6AbcScreen> createState() => _Week6AbcScreenState();
}

class _Week6AbcScreenState extends State<Week6AbcScreen> {
  late final ApiClient _client;
  late final DiariesApi _diariesApi;

  List<_DiarySelectionItem> _diaryOptions = const [];
  _DiarySelectionItem? _selectedDiary;
  String? _expandedDiaryId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    _fetchDiaryOptions();
  }

  Future<void> _fetchDiaryOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final diaries = await _diariesApi.listDiaries();
      final options =
          diaries
              .map(_DiarySelectionItem.fromMap)
              .whereType<_DiarySelectionItem>()
              .where((item) => item.canUseInWeek6)
              .toList()
            ..sort((a, b) {
              final aDate = a.createdAt;
              final bDate = b.createdAt;
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

      _DiarySelectionItem? selected;
      final preferredId = widget.abcId;
      if (preferredId != null && preferredId.isNotEmpty) {
        for (final item in options) {
          if (item.id == preferredId) {
            selected = item;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _diaryOptions = options;
        _selectedDiary = selected;
        _expandedDiaryId = selected?.id;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  void _selectDiary(_DiarySelectionItem diary) {
    setState(() {
      _selectedDiary = diary;
    });
  }

  void _toggleDiaryExpanded(_DiarySelectionItem diary) {
    setState(() {
      _expandedDiaryId = _expandedDiaryId == diary.id ? null : diary.id;
    });
  }

  void _handleNext() {
    final selectedDiary = _selectedDiary;
    if (selectedDiary == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('진행할 걱정일기를 먼저 선택해 주세요.')));
      return;
    }

    if (selectedDiary.behaviorItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('행동 데이터가 없습니다.')));
      return;
    }

    Navigator.push(
      context,
      buildWeek6NoAnimationRoute(
        Week6ConcentrationScreen(
          behaviorListInput: selectedDiary.behaviorItems,
          allBehaviorList: selectedDiary.behaviorItems,
          diaryId: selectedDiary.id,
          diary: selectedDiary.raw,
        ),
      ),
    );
  }

  Widget _buildMainCardBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    if (_diaryOptions.isEmpty) {
      return const Center(
        child: Text('선택할 수 있는 걱정일기가 없습니다.', style: TextStyle(fontSize: 16)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SelectionHeaderCard(
          title: '걱정 일기 선택',
          subtitle: '모든 일기를 최신 작성 순으로 보여드려요.\n카드를 탭하면 선택되고, 오른쪽 화살표를 누르면 세부 내용을 펼쳐볼 수 있어요.',
        ),
        if (_selectedDiary != null) ...[
          const SizedBox(height: 14),
          _SelectedDiaryNoticeCard(diary: _selectedDiary!),
        ],
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _diaryOptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final diary = _diaryOptions[index];
            return _DiaryListItemCard(
              diary: diary,
              isSelected: diary.id == _selectedDiary?.id,
              isExpanded: diary.id == _expandedDiaryId,
              onTap: () => _selectDiary(diary),
              onExpandTap: () => _toggleDiaryExpanded(diary),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxCardWidth = MediaQuery.of(context).size.width - 48;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: '행동 구분 연습'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        child: _buildMainCardBody(context),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
                    rightLabel: '다음',
                    onBack: () => Navigator.pop(context),
                    onNext: _handleNext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiarySelectionItem {
  final Map<String, dynamic> raw;
  final String id;
  final String activation;
  final List<String> beliefItems;
  final List<String> physicalItems;
  final List<String> emotionItems;
  final List<String> behaviorItems;
  final DateTime? createdAt;
  final bool isAutoGenerated;

  const _DiarySelectionItem({
    required this.raw,
    required this.id,
    required this.activation,
    required this.beliefItems,
    required this.physicalItems,
    required this.emotionItems,
    required this.behaviorItems,
    required this.createdAt,
    required this.isAutoGenerated,
  });

  bool get canUseInWeek6 =>
      id.isNotEmpty && !isAutoGenerated && behaviorItems.isNotEmpty;

  String get title => activation.isEmpty ? '(상황 정보 없음)' : activation;

  String get listDateLabel {
    final date = createdAt;
    if (date == null) return '작성일 정보 없음';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static _DiarySelectionItem? fromMap(Map<String, dynamic> raw) {
    final id = Week6DiaryUtils.resolveDiaryId(raw);
    if (id == null || id.isEmpty) return null;

    final activation = Week6DiaryUtils.extractActivation(raw);

    return _DiarySelectionItem(
      raw: Map<String, dynamic>.from(raw),
      id: id,
      activation: activation,
      beliefItems: Week6DiaryUtils.chipList(raw['belief']),
      physicalItems: Week6DiaryUtils.chipList(
        raw['consequence_physical'] ?? raw['consequence_p'],
      ),
      emotionItems: Week6DiaryUtils.chipList(
        raw['consequence_emotion'] ?? raw['consequence_e'],
      ),
      behaviorItems: Week6DiaryUtils.extractBehaviorList(raw),
      createdAt: Week6DiaryUtils.parseCreatedAt(
        raw['created_at'] ?? raw['createdAt'],
      ),
      isAutoGenerated: activation.startsWith('자동 생성 일기'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B405C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5F6F82),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectionHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SelectionHeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E8F7), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _SectionHeader(title: title, subtitle: subtitle),
    );
  }
}

class _DiaryListItemCard extends StatelessWidget {
  final _DiarySelectionItem diary;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onExpandTap;

  const _DiaryListItemCard({
    required this.diary,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    required this.onExpandTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isSelected || isExpanded
                  ? const Color(0xFF5B9FD3)
                  : const Color(0xFFE3F2FD),
          width: isSelected ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isSelected
                    ? const Color(0xFF5B9FD3).withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.07),
            blurRadius: isSelected ? 18 : 12,
            offset: Offset(0, isSelected ? 8 : 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                          if (isSelected) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5B9FD3),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '선택됨',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            diary.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0E2C48),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 15,
                                color: Color(0xFF5B9FD3),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  diary.listDateLabel,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF5B9FD3),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onExpandTap,
                      splashRadius: 20,
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF5B9FD3),
                        size: 32,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState:
                      isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE3F2FD), height: 1),
                      const SizedBox(height: 18),
                      _DiaryDetailSection(
                        title: '믿음',
                        icon: Icons.psychology_alt_outlined,
                        items: diary.beliefItems,
                      ),
                      const SizedBox(height: 18),
                      _DiaryDetailSection(
                        title: '신체 반응',
                        icon: Icons.favorite_border_rounded,
                        items: diary.physicalItems,
                      ),
                      const SizedBox(height: 18),
                      _DiaryDetailSection(
                        title: '감정',
                        icon: Icons.mood_outlined,
                        items: diary.emotionItems,
                      ),
                      const SizedBox(height: 18),
                      _DiaryDetailSection(
                        title: '행동',
                        icon: Icons.directions_run_rounded,
                        items: diary.behaviorItems,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDiaryNoticeCard extends StatelessWidget {
  final _DiarySelectionItem diary;

  const _SelectedDiaryNoticeCard({required this.diary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB9D8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B9FD3).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E7DB2),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '선택한 일기: ${diary.title}',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B405C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryDetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _DiaryDetailSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF5B9FD3)),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0E2C48),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              visibleItems.isEmpty
                  ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFD6E2FF)),
                      ),
                      child: const Text(
                        '기록 없음',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF91A1B5),
                        ),
                      ),
                    ),
                  ]
                  : visibleItems
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5FAFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFD6E2FF)),
                          ),
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF496AC6),
                            ),
                          ),
                        ),
                      )
                      .toList(),
        ),
      ],
    );
  }
}
