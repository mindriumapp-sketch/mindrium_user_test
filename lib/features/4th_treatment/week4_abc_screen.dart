import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/4th_treatment/week4_concentration_screen.dart';
import 'package:gad_app_team/widgets/blue_white_card.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';

class Week4AbcScreen extends StatefulWidget {
  final String? abcId;
  final int loopCount;

  const Week4AbcScreen({super.key, this.abcId, this.loopCount = 1});

  @override
  State<Week4AbcScreen> createState() => _Week4AbcScreenState();
}

class _Week4AbcScreenState extends State<Week4AbcScreen> {
  late final ApiClient _client;
  late final DiariesApi _diariesApi;

  List<_DiarySelectionItem> _diaryOptions = const [];
  _DiarySelectionItem? _selectedDiary;
  bool _isLoading = true;
  String? _error;
  bool _showFloatingGuide = true;

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
              .where((item) => item.canUseInWeek4)
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

  void _toggleDiary(_DiarySelectionItem diary) {
    setState(() {
      _selectedDiary = _selectedDiary?.id == diary.id ? null : diary;
    });
  }

  PageRouteBuilder<void> _instantRoute(Widget child) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _handleNext() {
    final selectedDiary = _selectedDiary;
    if (selectedDiary == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('진행할 걱정일기를 먼저 선택해 주세요.')));
      return;
    }

    if (selectedDiary.beliefItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('B(생각) 데이터가 없습니다.')));
      return;
    }

    Navigator.push(
      context,
      _instantRoute(
        Week4ConcentrationScreen(
          bListInput: selectedDiary.beliefItems,
          allBList: selectedDiary.beliefItems,
          abcId: selectedDiary.id,
          loopCount: widget.loopCount,
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

    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child:
              _selectedDiary == null
                  ? const _SelectionPlaceholderCard()
                  : _SelectedDiaryPreviewCard(
                    key: ValueKey(_selectedDiary!.id),
                    diary: _selectedDiary!,
                    userName: userName,
                  ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: '최근 작성한 걱정일기',
          subtitle: '한 번 탭하면 선택되고, 이후에는 이 일기 속 생각들을 하나씩 차례대로 살펴봐요.',
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _diaryOptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final diary = _diaryOptions[index];
            return _DiaryListItemCard(
              diary: diary,
              isSelected: diary.id == _selectedDiary?.id,
              onTap: () => _toggleDiary(diary),
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
      appBar: const CustomAppBar(title: '인지 왜곡 찾기'),
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
                        horizontal: 34,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                BlueWhiteCard(
                                  maxWidth: maxCardWidth,
                                  title: '걱정 일기 선택',
                                  titleStyle: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF263C69),
                                  ),
                                  outerColor: Colors.transparent,
                                  outerRadius: 22,
                                  outerExpand: EdgeInsets.zero,
                                  innerColor: Colors.white,
                                  innerRadius: 20,
                                  innerPadding: const EdgeInsets.fromLTRB(
                                    28,
                                    26,
                                    28,
                                    26,
                                  ),
                                  dividerColor: const Color(0xFFE8EDF4),
                                  dividerWidth: 240,
                                  titleTopGap: 10,
                                  child: _buildMainCardBody(context),
                                ),
                                Positioned(
                                  top: -22,
                                  right: -6,
                                  child: _SelectionGuideToggle(
                                    diaryCount: _diaryOptions.length,
                                    isVisible: _showFloatingGuide,
                                    onToggle:
                                        () => setState(
                                          () =>
                                              _showFloatingGuide =
                                                  !_showFloatingGuide,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
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
  final String id;
  final String activation;
  final List<String> beliefItems;
  final String beliefText;
  final String physicalText;
  final String emotionText;
  final String behaviorText;
  final DateTime? createdAt;
  final bool isAutoGenerated;

  const _DiarySelectionItem({
    required this.id,
    required this.activation,
    required this.beliefItems,
    required this.beliefText,
    required this.physicalText,
    required this.emotionText,
    required this.behaviorText,
    required this.createdAt,
    required this.isAutoGenerated,
  });

  bool get canUseInWeek4 =>
      id.isNotEmpty && !isAutoGenerated && beliefItems.isNotEmpty;

  bool get hasConsequence =>
      physicalText.isNotEmpty ||
      emotionText.isNotEmpty ||
      behaviorText.isNotEmpty;

  String get title => activation.isEmpty ? '(제목 없음)' : activation;

  String get beliefPreview => beliefText.isEmpty ? '생각 정보 없음' : beliefText;

  String get listDateLabel {
    final date = createdAt;
    if (date == null) return '작성일 정보 없음';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String get previewDateLabel {
    final date = createdAt;
    if (date == null) return '';
    return '${date.year}년 ${date.month}월 ${date.day}일에 작성된 걱정일기';
  }

  String narrative(String userName) {
    final clauses = <String>[];
    if (physicalText.isNotEmpty) {
      clauses.add('신체적으로 "$physicalText" 증상이 나타났습니다');
    }
    if (emotionText.isNotEmpty) {
      clauses.add('"$emotionText" 감정을 느끼셨습니다');
    }
    if (behaviorText.isNotEmpty) {
      clauses.add('"$behaviorText" 행동을 하였습니다');
    }

    final consequenceText =
        clauses.isEmpty ? '' : ' 그 결과 ${clauses.join(', ')}.';

    return '$userName님은 "$title" 상황에서 "$beliefText" 생각을 하였습니다.$consequenceText';
  }

  static _DiarySelectionItem? fromMap(Map<String, dynamic> raw) {
    final id = _resolveDiaryId(raw);
    if (id == null || id.isEmpty) return null;

    final activation = _safeText(
      _chipText(
        raw['activation'] ?? raw['activating_events'] ?? raw['activatingEvent'],
      ),
    );
    final beliefItems = _parseBeliefToList(raw['belief']);

    return _DiarySelectionItem(
      id: id,
      activation: activation,
      beliefItems: beliefItems,
      beliefText: _safeText(_chipText(raw['belief'])),
      physicalText: _safeText(
        _chipText(raw['consequence_physical'] ?? raw['consequence_p']),
      ),
      emotionText: _safeText(
        _chipText(raw['consequence_emotion'] ?? raw['consequence_e']),
      ),
      behaviorText: _safeText(
        _chipText(
          raw['consequence_action'] ??
              raw['consequence_behavior'] ??
              raw['consequence_b'],
        ),
      ),
      createdAt: _parseCreatedAt(raw['created_at'] ?? raw['createdAt']),
      isAutoGenerated: activation.startsWith('자동 생성 일기'),
    );
  }

  static String? _resolveDiaryId(Map<String, dynamic> raw) {
    return (raw['diary_id'] ?? raw['diaryId'] ?? raw['id'])?.toString();
  }

  static DateTime? _parseCreatedAt(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static String _chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ?? '').toString();
    }
    return raw.toString();
  }

  static String _chipText(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => _chipLabel(e).trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    return _chipLabel(raw).trim();
  }

  static List<String> _parseBeliefToList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => _chipLabel(e).trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final s = _chipLabel(raw);
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _safeText(String text) {
    try {
      return String.fromCharCodes(text.runes);
    } catch (_) {
      return '';
    }
  }
}

class _SelectionGuideToggle extends StatelessWidget {
  final int diaryCount;
  final bool isVisible;
  final VoidCallback onToggle;

  const _SelectionGuideToggle({
    required this.diaryCount,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final guideText =
        diaryCount > 0
            ? '이번 활동에 사용할 걱정일기 하나를 골라주세요.\n선택한 뒤에는 내용을 먼저 읽어보고, 그 안에 있는 생각들을 하나씩 순서대로 살펴보게 됩니다.'
            : '이번 활동에 사용할 걱정일기를 불러오고 있어요.\n잠시 후 목록에서 하나를 골라 진행해보세요.';

    return SizedBox(
      width: 312,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 12,
            right: 54,
            child: IgnorePointer(
              ignoring: !isVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: isVisible ? Offset.zero : const Offset(0.05, -0.03),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  opacity: isVisible ? 1 : 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 228),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDDEAF5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.tips_and_updates_outlined,
                                  size: 16,
                                  color: Color(0xFF356D91),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    '가이드',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2A587A),
                                    ),
                                  ),
                                ),
                                Text(
                                  isVisible ? '탭해서 닫기' : '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(
                                      0xFF7A8EA3,
                                    ).withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              guideText,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B6984),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 26,
                        right: -9,
                        child: CustomPaint(
                          size: const Size(14, 16),
                          painter: _SelectionGuideTailPainter(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 84,
                height: 84,
                child: Image.asset(
                  'assets/image/jellyfish_smart.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionGuideTailPainter extends CustomPainter {
  final Color color;

  _SelectionGuideTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height * 0.5)
          ..lineTo(0, size.height)
          ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.08), 2.0, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _DiaryListItemCard extends StatelessWidget {
  final _DiarySelectionItem diary;
  final bool isSelected;
  final VoidCallback onTap;

  const _DiaryListItemCard({
    required this.diary,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF4FF) : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF5B9FD3) : const Color(0xFFD7E6F5),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF5B9FD3).withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : const [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          diary.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B405C),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
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
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    diary.listDateLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C7C90),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      diary.beliefPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4E6178),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color:
                    isSelected
                        ? const Color(0xFF5B9FD3)
                        : const Color(0xFF9CB4CA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDiaryPreviewCard extends StatelessWidget {
  final _DiarySelectionItem diary;
  final String userName;

  const _SelectedDiaryPreviewCard({
    super.key,
    required this.diary,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEAF7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B9FD3).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: '선택한 일기 미리보기',
            subtitle: '내용을 먼저 읽어본 뒤, 이 일기 안의 생각들을 하나씩 차례대로 살펴보게 돼요.',
          ),
          if (diary.previewDateLabel.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  diary.previewDateLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/image/question_icon.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(height: 16),
                const Text(
                  '선택한 걱정일기를 먼저 함께 살펴볼게요.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5EDF5)),
            ),
            child: Text(
              diary.narrative(userName),
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xFF25384C),
                fontWeight: FontWeight.w500,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionPlaceholderCard extends StatelessWidget {
  const _SelectionPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4D9DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: const [
          Text(
            '아직 선택한 일기가 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5E6873),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '목록에서 일기를 고르면 문장형 미리보기가 나타나고,\n선택한 일기 속 생각들을 순서대로 진행하게 돼요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF7A848F),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
