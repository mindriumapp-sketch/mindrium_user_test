import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_after_sud_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_skip_choice_screen.dart';

// ✅ 새 UI 래퍼
import 'package:gad_app_team/widgets/tutorial_design.dart'; // ApplyDesign
import 'package:gad_app_team/widgets/blue_banner.dart';      // (선택) 카운트다운 안내
import 'package:gad_app_team/widgets/ruled_paragraph.dart';  // ← 여기 추가
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week4ConcentrationScreen extends StatefulWidget {
  final List<String> bListInput;
  final int beforeSud;
  final List<String> allBList;
  final String? abcId;
  final int loopCount;
  final List<String>? existingAlternativeThoughts;
  final List<String>? alternativeThoughts;

  const Week4ConcentrationScreen({
    super.key,
    required this.bListInput,
    required this.beforeSud,
    required this.allBList,
    this.abcId,
    this.loopCount = 1,
    this.existingAlternativeThoughts,
    this.alternativeThoughts,
  });

  @override
  State<Week4ConcentrationScreen> createState() =>
      _Week4ConcentrationScreenState();
}

class _Week4ConcentrationScreenState extends State<Week4ConcentrationScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 10;
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  bool _showSituation = true; // 상황(검정) → 안내(보라) 순서
  late final ApiClient _client;
  late final DiariesApi _diariesApi;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    _startCountdown();

    final id = widget.abcId;
    if (id != null && id.isNotEmpty) {
      _fetchAbcModelById(id);
    } else {
      _fetchLatestAbcModel();
    }
  }

  /// 최신(가장 최근 createdAt) ABC 모델 1건을 불러온다.
  Future<void> _fetchLatestAbcModel() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final latest = await _diariesApi.getLatestDiary();
      if (!mounted) return;

      setState(() {
        _abcModel = latest;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 특정 abcId 의 ABC 모델 문서를 불러온다.
  Future<void> _fetchAbcModelById(String abcId) async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final diary = await _diariesApi.getDiary(abcId);
      if (!mounted) return;

      setState(() {
        _abcModel = diary;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _chipLabel(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return (raw['label'] ?? '').toString();
    }
    if (raw is String) {
      final s = raw;
      // Handle "{label: xxx, chip_id: ...}" or "label: xxx" formatted strings
      final match = RegExp(r'label\s*[:=]\s*([^,}]+)').firstMatch(s);
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

  String _safe(String text) {
    try {
      return String.fromCharCodes(text.runes);
    } catch (_) {
      return '';
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      if (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          _secondsLeft--;
        });
        return true;
      } else {
        setState(() {
          _isNextEnabled = true;
        });
        return false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Week4ConcentrationScreen bListInput: ${widget.bListInput}');
    debugPrint('Week4ConcentrationScreen bListInput.isEmpty: ${widget.bListInput.isEmpty}');
    debugPrint('Week4ConcentrationScreen bListInput.length: ${widget.bListInput.length}');

    if (widget.bListInput.isEmpty) {
      debugPrint('bListInput이 비어있음 - 도움이 되는 생각 작성 여부에 따라 분기');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.existingAlternativeThoughts?.isNotEmpty == true ||
            widget.alternativeThoughts?.isNotEmpty == true) {
          debugPrint('도움이 되는 생각을 작성함 - Week4AfterSudScreen으로 이동');
          final nav = Navigator.of(context);
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => Week4AfterSudScreen(
                beforeSud: widget.beforeSud,
                currentB: '',
                remainingBList: const [],
                allBList: widget.allBList,
                alternativeThoughts: widget.existingAlternativeThoughts ?? [],
                isFromAnxietyScreen: false,
                originalBList: widget.allBList,
                loopCount: widget.loopCount,
              ),
            ),
          );
        } else {
          debugPrint('도움이 되는 생각을 작성하지 않음 - Week4SkipChoiceScreen으로 이동');
          final nav = Navigator.of(context);
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => Week4SkipChoiceScreen(
                allBList: widget.allBList,
                beforeSud: widget.beforeSud,
                remainingBList: const [],
                isFromAfterSud: false,
                existingAlternativeThoughts: widget.existingAlternativeThoughts ?? [],
                abcId: widget.abcId,
                loopCount: widget.loopCount,
              ),
            ),
          );
        }
      });
      return const SizedBox.shrink();
    }

    final userName =
        Provider.of<UserProvider>(context, listen: false).userName;
    final currentThought =
        widget.bListInput.isNotEmpty ? _chipLabel(widget.bListInput[0]).trim() : '';

    // BlueWhiteCard에서 쓰던 밑줄 길이를 그대로 사용하고 싶으면 이 값 유지
    const double kRuleWidth = 220;

    return ApplyDesign(
      appBarTitle: '인지 왜곡 찾기',
      cardTitle: '상황에 집중하기',
      onBack: () => Navigator.pop(context),
      onNext: () {
        if (!_isNextEnabled) {
          BlueBanner.show(context, '$_secondsLeft초 후에 다음 버튼이 활성화됩니다');
          return;
        }
        if (_showSituation) {
          setState(() => _showSituation = false);
        } else {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => Week4ClassificationScreen(
                bListInput: widget.bListInput,
                beforeSud: widget.beforeSud,
                allBList: widget.allBList,
                abcId: widget.abcId,
                loopCount: widget.loopCount,
                alternativeThoughts: [
                  ...?widget.existingAlternativeThoughts,
                  ...?widget.alternativeThoughts,
                ],
                existingAlternativeThoughts: [
                  ...?widget.existingAlternativeThoughts,
                  ...?widget.alternativeThoughts,
                ],
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      },

      // ===== 카드 내부 본문(UI만 변경: RuledParagraph 적용) =====
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Image.asset(
            'assets/image/think_blue.png',
            height: 160,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            )
          else ...[
            // 중앙 문구를 줄노트 스타일로 표시
            RuledParagraph(
              text: _showSituation
                  ? (_abcModel != null
                      ? "$userName님,\n'${_safe(_chipText(_abcModel?['activation'] ?? _abcModel?['activating_events'] ?? _abcModel?['activatingEvent']))}' (이)라는 상황을 잠시 집중해보겠습니다."
                      : '이때의 상황을 자세하게 집중해 보세요.')
                  : (_abcModel != null &&
                          _abcModel!['belief'] != null &&
                          _abcModel!['belief'].toString().isNotEmpty
                      ? "다음 생각인 '${_safe(currentThought)}'에 대해 얼마나 강하게 믿고 계신지 알아볼게요."
                      : '위 생각에 대해 어느 정도 믿음을 가지고 있는지 알아볼게요.'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700, 
                color: Color(0xFF2C3C55),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
              lineColor: const Color(0xFFE1E8F0),
              lineThickness: 1.2,
              lineGapBelow: 8,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              lineWidth: kRuleWidth,
            ),

            const SizedBox(height: 16),
          ],

          if (!_isNextEnabled)
            Text(
              '$_secondsLeft초 후에 다음 버튼이 활성화됩니다',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9BA7B4),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
