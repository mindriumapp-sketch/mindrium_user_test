import 'package:gad_app_team/utils/text_line_material.dart';

// ✅ 공용 레이아웃
import 'package:gad_app_team/widgets/top_btm_card.dart';

// 다음 화면 (기존 로직 유지)
import 'week4_alternative_thoughts_display_screen.dart';
import 'week4_classfication_result_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:provider/provider.dart';

class Week4AlternativeThoughtsScreen extends StatefulWidget {
  final List<String> previousChips;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String>? existingAlternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final String? abcId;
  final int loopCount;
  final String? origin;
  final dynamic diary;

  const Week4AlternativeThoughtsScreen({
    super.key,
    required this.previousChips,
    required this.remainingBList,
    required this.allBList,
    this.existingAlternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.abcId,
    this.loopCount = 1,
    this.origin,
    this.diary,
  });

  @override
  State<Week4AlternativeThoughtsScreen> createState() =>
      _Week4AlternativeThoughtsScreenState();
}

class _Week4AlternativeThoughtsScreenState
    extends State<Week4AlternativeThoughtsScreen> {
  final TextEditingController _textController = TextEditingController();
  String _draftText = '';
  String _situationText = '';
  late final ApiClient _client;
  late final DiariesApi _diariesApi;

  @override
  void initState() {
    super.initState();
    // 화면에는 현재 작성 중(새로 입력) 대체생각만 보여주고 저장 시 합쳐서 저장
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    _loadSituationText();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ───────────────────── FastAPI/Mongo 저장 ─────────────────────
  Future<void> _saveAlternativeThoughts() async {
    try {
      final current = _currentThoughts();
      final allAlternativeThoughts = _normalizeThoughts([
        ...?widget.existingAlternativeThoughts,
        ...current,
      ]);

      String diaryId;
      if (widget.abcId == null || widget.abcId!.isEmpty) {
        final list = await _diariesApi.listDiaries();
        if (list.isEmpty) return;
        diaryId = (list.first['diary_id'] ?? '').toString();
        if (diaryId.isEmpty) return;
      } else {
        diaryId = widget.abcId!;
      }

      // 대체생각 저장 (diary)
      await _diariesApi.updateDiary(diaryId, {
        'alternative_thoughts': allAlternativeThoughts,
      });
    } catch (e, st) {
      debugPrint('❌ 대체생각 저장 오류: $e');
      debugPrint('❌ Stack trace: $st');
    }
  }

  List<String> _normalizeThoughts(List<String> raw) {
    final out = <String>[];
    final seen = <String>{};

    for (final item in raw) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) {
        out.add(trimmed);
      }
    }

    return out;
  }

  List<String> _currentThoughts() {
    final trimmed = _draftText.trim();
    if (trimmed.isEmpty) return const [];
    return [trimmed];
  }

  bool get _hasDraft => _draftText.trim().isNotEmpty;

  String _chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ?? '').toString();
    }
    return raw.toString();
  }

  String _chipText(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => _chipLabel(e).trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    return _chipLabel(raw).trim();
  }

  String _extractSituationText(Map<String, dynamic>? diary) {
    if (diary == null) return '';
    return _chipText(
      diary['activation'] ??
          diary['activating_events'] ??
          diary['activatingEvent'],
    );
  }

  Future<void> _loadSituationText() async {
    final diaryArg = widget.diary;
    if (diaryArg is Map) {
      final text = _extractSituationText(diaryArg.cast<String, dynamic>());
      if (text.isNotEmpty) {
        setState(() {
          _situationText = text;
        });
        return;
      }
    }

    try {
      Map<String, dynamic> diary;
      if (widget.abcId != null && widget.abcId!.isNotEmpty) {
        diary = await _diariesApi.getDiary(widget.abcId!);
      } else {
        diary = await _diariesApi.getLatestDiary();
      }

      if (!mounted) return;
      setState(() {
        _situationText = _extractSituationText(diary);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[alt_thought] abcId: ${widget.abcId}');
    final currentThought =
        widget.previousChips.isNotEmpty
            ? widget.previousChips.last.trim()
            : (widget.remainingBList.isNotEmpty
                ? widget.remainingBList.first.trim()
                : '');
    final guideText =
        currentThought.isNotEmpty
            ? "'$currentThought'를 조금 더 긍정적으로 바라볼 문장을 적어보세요."
            : '이 생각을 조금 더 긍정적으로 바라볼 문장을 적어보세요.';
    final remainingThoughtCount = widget.remainingBList.length;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ApplyDoubleCard(
        appBarTitle: '인지 왜곡 찾기',

        // ◀◀ 뒤로/다음 (기존 로직 유지)
        onBack: () => Navigator.pop(context),
        onNext:
            _hasDraft
                ? () async {
                  final navigator = Navigator.of(context);
                  final routeArgs =
                      ModalRoute.of(context)?.settings.arguments as Map? ?? {};
                  final flow =
                      context.read<ApplyOrSolveFlow>()..syncFromArgs(routeArgs);
                  final sanitizedFlowArgs =
                      Map<String, dynamic>.from(flow.toArgs())
                        ..remove('beforeSud')
                        ..remove('sudId');
                  final String originArg =
                      (() {
                        final rawOrigin =
                            widget.origin ??
                            routeArgs['origin'] as String? ??
                            flow.origin;
                        return rawOrigin == 'solve' ? 'apply' : rawOrigin;
                      })();
                  final dynamic diaryArg =
                      widget.diary ?? routeArgs['diary'] ?? flow.diary;
                  final String? abcIdArg =
                      widget.abcId ??
                      routeArgs['abcId'] as String? ??
                      flow.diaryId;
                  final currentThoughts = _currentThoughts();
                  final combinedThoughts = _normalizeThoughts([
                    ...?widget.existingAlternativeThoughts,
                    ...currentThoughts,
                  ]);

                  // 저장
                  if (originArg == 'apply') {
                    await _saveAlternativeThoughts();
                  }

                  if (!mounted) return;

                  // 현재 B(생각)
                  final bToShow =
                      widget.previousChips.isNotEmpty
                          ? widget.previousChips.last
                          : (widget.remainingBList.isNotEmpty
                              ? widget.remainingBList.first
                              : '');

                  if (originArg == 'apply') {
                    if (!mounted) return;
                    navigator.pushReplacement(
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) => Week4ClassificationResultScreen(
                              bList: widget.previousChips,
                              remainingBList: widget.remainingBList,
                              allBList: widget.allBList,
                              alternativeThoughts: combinedThoughts,
                              isFromAnxietyScreen: widget.isFromAnxietyScreen,
                              existingAlternativeThoughts:
                                  widget.existingAlternativeThoughts,
                              abcId: abcIdArg ?? widget.abcId,
                              loopCount: widget.loopCount,
                            ),
                        settings: RouteSettings(
                          arguments: {
                            ...sanitizedFlowArgs,
                            if ((abcIdArg ?? widget.abcId) != null)
                              'abcId': (abcIdArg ?? widget.abcId)!,
                            'origin': originArg,
                            if (diaryArg != null) 'diary': diaryArg,
                          },
                        ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                    return;
                  }

                  // 기본 흐름: 표시 화면
                  if (!mounted) return;
                  navigator.push(
                    PageRouteBuilder(
                      pageBuilder:
                          (_, __, ___) => Week4AlternativeThoughtsDisplayScreen(
                            alternativeThoughts: currentThoughts,
                            previousB: bToShow,
                            remainingBList: widget.remainingBList,
                            allBList: widget.allBList,
                            existingAlternativeThoughts:
                                widget.existingAlternativeThoughts,
                            isFromAnxietyScreen: widget.isFromAnxietyScreen,
                            originalBList: widget.originalBList,
                            abcId: widget.abcId ?? abcIdArg,
                            loopCount: widget.loopCount,
                          ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                }
                : null,

        // 레이아웃 옵션 (이전 화면과 동일 톤)
        pagePadding: const EdgeInsets.fromLTRB(28, 10, 28, 10),
        panelsGap: 8,
        panelRadius: 20,
        panelPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        middleNoticeMargin: const EdgeInsets.fromLTRB(0, 2, 0, 10),
        height: 112,
        topPadding: 0,
        bottomPanelBorder: Border.all(
          color: _hasDraft ? const Color(0xFF8FCFE4) : const Color(0xFFD8E5ED),
          width: 1.2,
        ),
        bottomPanelShadows:
            _hasDraft
                ? [
                  BoxShadow(
                    color: const Color(0xFF7DD9E8).withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
                : const [],

        topChild: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '도움이 되는 생각을 적어보는 시간',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '정답을 찾기보다, 지금 생각보다 조금 더 균형 잡힌 문장을 한 문장 적어보세요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF708399),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5FBFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFC9E7F4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDFF4FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.psychology_alt_rounded,
                          color: Color(0xFF2E6EA5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '지금 살펴보는 생각',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF34577A),
                          ),
                        ),
                      ),
                      if (remainingThoughtCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F6EA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '남은 생각 $remainingThoughtCount개',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D4F),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PromptInfoRow(
                    label: '상황',
                    value:
                        _situationText.isNotEmpty
                            ? _situationText
                            : '선택한 일기의 상황을 불러오는 중이에요.',
                  ),
                  const SizedBox(height: 10),
                  _PromptInfoRow(
                    label: '생각',
                    value:
                        currentThought.isNotEmpty
                            ? currentThought
                            : '생각 정보를 확인하는 중이에요.',
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ],
        ),

        // 패널 사이 말풍선
        middleBannerText: '$guideText\n한 문장으로 간단하게 적어도 괜찮아요. 천천히 생각해주세요.',
        // height: 120,
        // topPadding: 20,

        // ─────────────────── 하단 패널 (텍스트 입력) ───────────────────
        bottomChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              minLines: 6,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() {
                  _draftText = value;
                });
              },
              decoration: const InputDecoration(
                hintText:
                    '예: 지금 불안하긴 하지만, 이 상황이 내가 생각하는 만큼 크게 흘러가지는 않을 수 있어.\n차분히 하나씩 해보면 괜찮아질 수 있어.',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8EA1AD),
                  height: 1.6,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(
                fontSize: 16,
                height: 1.7,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _PromptInfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6E86A0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 16,
            height: 1.55,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color:
                emphasize ? const Color(0xFF263C69) : const Color(0xFF395B7F),
          ),
        ),
      ],
    );
  }
}
