// lib/features/4th_treatment/week4_after_agreement_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/widgets/top_btm_card.dart'; // ✅ 두 패널 레이아웃
import 'package:gad_app_team/data/user_provider.dart'; // 사용자 이름
import 'week4_after_sud_screen.dart';
import 'week4_next_thought_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/api/custom_tags_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:dio/dio.dart';

class Week4AfterAgreementScreen extends StatefulWidget {
  final String previousB;
  final int beforeSud;
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
    required this.beforeSud,
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
  }

  // 점수에 따른 컬러 (Week4ClassificationScreen 스타일)
  Color get _trackColor =>
      _sliderValue <= 2
          ? Colors.green
          : (_sliderValue >= 8 ? Colors.red : Colors.amber);

  List<String> _removeDuplicates(List<String> list) {
    final uniqueList = <String>[];
    for (final item in list) {
      if (!uniqueList.contains(item)) uniqueList.add(item);
    }
    return uniqueList;
  }

  // ────────────── Top 패널 UI ──────────────
  Widget _buildTopPanel() {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 35),
        Text(
          '$userName님께서 걱정일기에 작성하신 생각을 보며 진행해주세요.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8796B8),
            letterSpacing: 1.2,
            fontFamily: 'Noto Sans KR',
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 30),
        Text(
          (_currentB.isNotEmpty) ? _currentB : '생각이 없습니다.',
          style: TextStyle(
            fontSize: 20,
            height: 1.35,
            wordSpacing: 1.4,
            fontWeight: FontWeight.w800,
            fontFamily: 'Noto Sans KR',
            color: Color(0xFF263C69),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 35),
      ],
    );
  }

  // ────────────── Bottom 패널 UI (슬라이더) ──────────────
  Widget _buildBottomPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 큰 숫자
        Text(
          '${_sliderValue.round()}',
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: _trackColor,
          ),
        ),
        const SizedBox(height: 8),
        // 커스텀 슬라이더(분위기 동일)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: const RoundedRectSliderTrackShape(),
            trackHeight: 12,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
              elevation: 2,
              pressedElevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            activeTrackColor: _trackColor,
            inactiveTrackColor: _trackColor.withValues(alpha: 0.25),
            thumbColor: _trackColor,
            overlayColor: _trackColor.withValues(alpha: 0.25),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _sliderValue,
            min: 0,
            max: 10,
            divisions: 10,
            label: _sliderValue.round().toString(),
            activeColor: _trackColor,
            inactiveColor: _trackColor.withValues(alpha: 0.25),
            onChanged: (v) => setState(() => _sliderValue = v),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0점: 전혀 믿지 않음',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '10점: 매우 믿음',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ────────────── onNext 로직 (원본 그대로 유지) ──────────────
  Future<void> _handleNext() async {
    await _saveRealOddnessAfter();
    if (!mounted) return;

    // 모든 B를 다룬 경우 → abcId 유무에 따라 분기
    if (widget.remainingBList.isEmpty) {
      if (widget.abcId != null && widget.abcId!.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => Week4AfterSudScreen(
                  beforeSud: widget.beforeSud,
                  currentB: _currentB,
                  remainingBList: widget.remainingBList,
                  allBList: widget.allBList,
                  alternativeThoughts: _removeDuplicates([
                    ...?widget.existingAlternativeThoughts,
                    ...widget.alternativeThoughts,
                  ]),
                  isFromAnxietyScreen: widget.isFromAnxietyScreen,
                  originalBList: widget.originalBList,
                  loopCount: widget.loopCount,
                  abcId: widget.abcId,
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else {
        // ② abcId가 없으면: 기존 로직(Week4AfterSudScreen)으로 이동
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => Week4AfterSudScreen(
                  beforeSud: widget.beforeSud,
                  currentB: _currentB,
                  remainingBList: widget.remainingBList,
                  allBList: widget.allBList,
                  alternativeThoughts: _removeDuplicates([
                    ...?widget.existingAlternativeThoughts,
                    ...widget.alternativeThoughts,
                  ]),
                  isFromAnxietyScreen: widget.isFromAnxietyScreen,
                  originalBList: widget.originalBList,
                  loopCount: widget.loopCount,
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    } else {
      // 남은 B가 있으면 다음 B로 진행
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week4NextThoughtScreen(
                remainingBList: widget.remainingBList,
                beforeSud: widget.beforeSud,
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

    final beforeOdd =
        beforeOddFromLog ?? _sliderValue.round().clamp(0, 10);
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
          (latest['diary_id'] ?? latest['diaryId'] ?? latest['id'])
              ?.toString();
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
            final chipId =
                b['chip_id']?.toString() ?? b['chipId']?.toString();
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
      middleBannerText:
          '지금은 위 생각에 대해 얼마나 \n강하게 믿고 계시나요? 아래 슬라이더를 조정하고 [ 다음 ]을 눌러주세요.',

      // 스타일(필요시 조정)
      pagePadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
      panelsGap: 2,
      panelRadius: 20,
      panelPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    );
  }
}
