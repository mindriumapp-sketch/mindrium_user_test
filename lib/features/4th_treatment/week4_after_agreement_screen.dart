// lib/features/4th_treatment/week4_after_agreement_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/widgets/top_btm_card.dart'; // ✅ 두 패널 레이아웃
import 'package:gad_app_team/data/user_provider.dart'; // 사용자 이름
import 'week4_final_screen.dart';
import 'week4_next_thought_screen.dart';
import 'week4_belief_rating_widgets.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:dio/dio.dart';

class Week4AfterAgreementScreen extends StatefulWidget {
  final String previousB;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String> alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4AfterAgreementScreen({
    super.key,
    required this.previousB,
    required this.remainingBList,
    required this.allBList,
    required this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4AfterAgreementScreen> createState() =>
      _Week4AfterAgreementScreenState();
}

class _Week4AfterAgreementScreenState extends State<Week4AfterAgreementScreen> {
  double _sliderValue = 5.0;
  late String _currentB;
  late final ApiClient _client;
  late final DiariesApi _diariesApi;
  late final CustomTagsApi _customTagsApi;
  final Map<String, String> _labelToChipId = {};
  String? _resolvedDiaryId;
  Map<String, dynamic>? _abcModel;
  bool _didReadArgs = false;

  @override
  void initState() {
    super.initState();
    _currentB = widget.previousB;
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    _customTagsApi = CustomTagsApi(_client);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _resolvedDiaryId = widget.abcId ?? args?['abcId']?.toString();
    _loadDiaryContext();
  }

  List<String> _removeDuplicates(List<String> list) {
    final uniqueList = <String>[];
    for (final item in list) {
      if (!uniqueList.contains(item)) uniqueList.add(item);
    }
    return uniqueList;
  }

  Future<void> _loadDiaryContext() async {
    final diaryId = await _resolveDiaryId();
    if (!mounted || diaryId == null || diaryId.isEmpty) return;

    try {
      final diary = await _diariesApi.getDiary(diaryId);
      if (!mounted) return;
      setState(() {
        _abcModel = diary;
      });
    } catch (_) {}
  }

  String _chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ?? '').toString();
    }
    if (raw is String) {
      final match = RegExp(r'label\s*[:=]\s*([^,}]+)').firstMatch(raw);
      if (match != null) return match.group(1)?.trim() ?? '';
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

  String _activationText() {
    return _chipText(
      _abcModel?['activation'] ??
          _abcModel?['activating_events'] ??
          _abcModel?['activatingEvent'],
    );
  }

  // ────────────── Top 패널 UI ──────────────
  Widget _buildTopPanel() {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final displaySituation = _activationText();
    final totalThoughtCount = widget.allBList.length;
    final rawCurrentIndex = totalThoughtCount - widget.remainingBList.length;
    final currentIndex =
        totalThoughtCount <= 0
            ? 1
            : rawCurrentIndex < 1
            ? 1
            : (rawCurrentIndex > totalThoughtCount
                ? totalThoughtCount
                : rawCurrentIndex);

    return Week4BeliefContextPanel(
      title: '방금 적은 도움이 되는 생각을 떠올려보세요',
      subtitle: '$userName님이 떠올린 도움이 되는 생각 뒤에, 지금 이 생각이 얼마나 약해졌는지 다시 살펴볼게요.',
      situationText:
          displaySituation.isNotEmpty ? displaySituation : '상황 정보를 확인하는 중이에요.',
      beliefText:
          _currentB.trim().isNotEmpty ? _currentB.trim() : '생각 정보를 확인하는 중이에요.',
      badgeText:
          totalThoughtCount > 0 ? '$currentIndex / $totalThoughtCount' : null,
      footerText: '도움이 되는 생각을 떠올린 뒤 지금 믿는 정도를 골라주세요.',
    );
  }

  // ────────────── Bottom 패널 UI (슬라이더) ──────────────
  Widget _buildBottomPanel() {
    return Week4BeliefSliderPanel(
      value: _sliderValue,
      onChanged: (v) => setState(() => _sliderValue = v),
    );
  }

  // ────────────── onNext 로직 (원본 그대로 유지) ──────────────
  Future<void> _handleNext() async {
    await _saveRealOddnessAfter();
    if (!mounted) return;

    // 모든 B를 다룬 경우 → abcId 유무에 따라 분기
    if (widget.remainingBList.isEmpty) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week4FinalScreen(
                alternativeThoughts: _removeDuplicates([
                  ...?widget.existingAlternativeThoughts,
                  ...widget.alternativeThoughts,
                ]),
                loopCount: widget.loopCount,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      // 남은 B가 있으면 다음 B로 진행
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week4NextThoughtScreen(
                remainingBList: widget.remainingBList,
                allBList: widget.allBList,
                alternativeThoughts: _removeDuplicates([
                  ...?widget.existingAlternativeThoughts,
                  ...widget.alternativeThoughts,
                ]),
                isFromAnxietyScreen: widget.isFromAnxietyScreen,
                addedAnxietyThoughts: const [],
                existingAlternativeThoughts: _removeDuplicates([
                  ...?widget.existingAlternativeThoughts,
                  ...widget.alternativeThoughts,
                ]),
                abcId: widget.abcId,
                loopCount: widget.loopCount,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  Future<void> _saveRealOddnessAfter() async {
    final diaryId = await _resolveDiaryId();
    if (diaryId == null || diaryId.isEmpty || _currentB.isEmpty) return;

    final belief = _currentB.trim();
    if (belief.isEmpty) return;

    await _hydrateChipCache(diaryId);
    final chipId = await _ensureChipId(belief);
    if (chipId == null || chipId.isEmpty) return;

    // 기존 로그에서 before_odd / altThought 추출
    int? beforeOddFromLog;
    List<String> existingAlts = [];
    try {
      final logs = await _customTagsApi.listRealOddnessLogs(
        chipId: chipId,
        diaryId: diaryId,
      );
      if (logs.isNotEmpty) {
        final last = logs.last;
        final b = last['before_odd'];
        if (b is num) beforeOddFromLog = b.round().clamp(0, 10);
        final alt = last['alternative_thought']?.toString();
        // 이미 after_odd 있고, 대체생각 동일하면 다시 저장하지 않음
        final after = last['after_odd'];
        if (after is num) {
          final mergedCheck = _mergeAltThoughts(existingAlts).join('\n');
          final lastAlt = alt ?? '';
          if (lastAlt == mergedCheck) {
            return;
          }
        }
      }
    } catch (_) {}

    final beforeOdd = beforeOddFromLog ?? _sliderValue.round().clamp(0, 10);
    final altThought = _mergeAltThoughts(existingAlts).join('\n');

    try {
      await _customTagsApi.createRealOddnessLog(
        chipId: chipId,
        diaryId: diaryId,
        beforeOdd: beforeOdd,
        afterOdd: _sliderValue.round().clamp(0, 10),
        alternativeThought: altThought,
      );
    } on DioException catch (e) {
      debugPrint(
        '⚠️ RealOddness 저장 실패 (after, $belief): '
        '${e.response?.data ?? e.message}',
      );
    } catch (e) {
      debugPrint('⚠️ RealOddness 저장 실패 (after, $belief): $e');
    }
  }

  Future<String?> _resolveDiaryId() async {
    if (_resolvedDiaryId != null && _resolvedDiaryId!.isNotEmpty) {
      return _resolvedDiaryId;
    }
    if (widget.abcId != null && widget.abcId!.isNotEmpty) {
      _resolvedDiaryId = widget.abcId;
      return _resolvedDiaryId;
    }
    try {
      final latest = await _diariesApi.getLatestDiary();
      _resolvedDiaryId =
          (latest['diary_id'] ?? latest['diaryId'] ?? latest['id'])?.toString();
    } catch (_) {}
    return _resolvedDiaryId;
  }

  Future<void> _hydrateChipCache(String diaryId) async {
    try {
      final diary = await _diariesApi.getDiary(diaryId);
      final beliefs = diary['belief'];
      if (beliefs is List) {
        for (final b in beliefs) {
          if (b is Map) {
            final label = (b['label'] ?? '').toString().trim();
            final chipId = b['chip_id']?.toString() ?? b['chipId']?.toString();
            if (label.isNotEmpty && chipId != null && chipId.isNotEmpty) {
              _labelToChipId.putIfAbsent(label, () => chipId);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final tags = await _customTagsApi.listCustomTags(chipType: 'B');
      for (final tag in tags) {
        final label = (tag['text'] ?? tag['label'])?.toString().trim();
        final chipId = tag['chip_id']?.toString();
        if (label != null &&
            label.isNotEmpty &&
            chipId != null &&
            chipId.isNotEmpty) {
          _labelToChipId.putIfAbsent(label, () => chipId);
        }
      }
    } catch (_) {}
  }

  Future<String?> _ensureChipId(String belief) async {
    String? chipId = _labelToChipId[belief];
    if (chipId != null && chipId.isNotEmpty) return chipId;

    try {
      final created = await _customTagsApi.createCustomTag(
        label: belief,
        type: 'B',
      );
      chipId = (created['chip_id'] ?? created['_id'])?.toString();
      if (chipId != null && chipId.isNotEmpty) {
        _labelToChipId[belief] = chipId;
      }
    } catch (e) {
      debugPrint('⚠️ 태그 생성 실패 ($belief): $e');
    }
    return chipId;
  }

  List<String> _mergeAltThoughts(List<String> existing) {
    final merged = <String>[];
    void addAll(Iterable<String> items) {
      for (final t in items) {
        final v = t.trim();
        if (v.isEmpty) continue;
        if (!merged.contains(v)) merged.add(v);
      }
    }

    addAll(existing);
    addAll(widget.alternativeThoughts);
    addAll(widget.existingAlternativeThoughts ?? const []);

    if (merged.isEmpty) {
      merged.add('Not provided');
    } else if (merged.length > 1) {
      merged.removeWhere((e) => e == 'Not provided');
    }
    return merged;
  }

  // ────────────── 화면 구성: ApplyDoubleCard 사용 ──────────────
  @override
  Widget build(BuildContext context) {
    return ApplyDoubleCard(
      appBarTitle: '인지 왜곡 찾기',
      onBack: () => Navigator.pop(context),
      onNext: () async => _handleNext(),

      // 상단/하단 패널
      topChild: _buildTopPanel(),
      bottomChild: _buildBottomPanel(),

      // 패널 사이 말풍선 안내
      middleBannerText: '도움이 되는 생각을 떠올리며,\n지금 믿는 정도를 다시 골라주세요.',

      // 스타일(필요시 조정)
      pagePadding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
      panelsGap: 10,
      panelRadius: 20,
      panelPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      height: 112,
      topPadding: 0,
    );
  }
}
