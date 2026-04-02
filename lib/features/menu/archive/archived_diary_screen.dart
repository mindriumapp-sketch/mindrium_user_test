import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
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

class _ArchivedDiaryScreenState extends State<ArchivedDiaryScreen> {
  final TokenStorage _tokens = TokenStorage();
  late final ApiClient _apiClient = ApiClient(tokens: _tokens);

  List<Map<String, dynamic>> _diaries = [];
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
        );
      },
    );
  }
}

class _ExpandableDiaryCard extends StatefulWidget {
  final Map<String, dynamic> diary;
  final int characterId;
  final VoidCallback onStartFlow;

  const _ExpandableDiaryCard({
    required this.diary,
    required this.characterId,
    required this.onStartFlow,
  });

  @override
  State<_ExpandableDiaryCard> createState() => _ExpandableDiaryCardState();
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
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE3F2FD)),
                  const SizedBox(height: 16),

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
