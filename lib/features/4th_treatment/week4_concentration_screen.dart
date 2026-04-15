import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_final_screen.dart';

// ✅ 새 UI 래퍼
import 'package:gad_app_team/widgets/ruled_paragraph.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart'; // ApplyDesign
import 'package:gad_app_team/widgets/blue_banner.dart'; // (선택) 카운트다운 안내
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week4ConcentrationScreen extends StatefulWidget {
  final List<String> bListInput;
  final List<String> allBList;
  final String? abcId;
  final int loopCount;
  final List<String>? existingAlternativeThoughts;
  final List<String>? alternativeThoughts;

  const Week4ConcentrationScreen({
    super.key,
    required this.bListInput,
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

  List<String> _chipList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => _chipLabel(e).trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final label = _chipLabel(raw).trim();
    if (label.isEmpty) return const [];

    return label
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
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
    if (widget.bListInput.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context);
        nav.pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => Week4FinalScreen(
                  alternativeThoughts: [
                    ...?widget.existingAlternativeThoughts,
                    ...?widget.alternativeThoughts,
                  ],
                  loopCount: widget.loopCount,
                ),
          ),
        );
      });
      return const SizedBox.shrink();
    }

    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    const double kRuleWidth = 220;
    final situationText =
        _abcModel != null
            ? _safe(
              _chipText(
                _abcModel?['activation'] ??
                    _abcModel?['activating_events'] ??
                    _abcModel?['activatingEvent'],
              ),
            )
            : '이때의 상황을 떠올려보세요.';
    final inputThoughts =
        widget.bListInput
            .map((e) => _chipLabel(e).trim())
            .where((e) => e.isNotEmpty)
            .toList();
    final modelThoughts = _chipList(_abcModel?['belief']);
    final firstThought =
        inputThoughts.isNotEmpty
            ? inputThoughts.first
            : (modelThoughts.isNotEmpty ? _safe(modelThoughts.first) : '');
    final focusText =
        situationText.isNotEmpty && firstThought.isNotEmpty
            ? '$userName님, "$situationText"(이)라는 상황에서\n"$firstThought"(이)라는 생각이 들었습니다.\n\n그때의 상황에 집중해보세요.'
            : situationText.isNotEmpty
            ? '$userName님, "$situationText"(이)라는 상황을\n천천히 다시 떠올려보세요.'
            : '이때의 상황을 자세히 떠올려보세요.';

    return ApplyDesign(
      appBarTitle: '인지 왜곡 찾기',
      cardTitle: '상황에 집중하기',
      onBack: () => Navigator.pop(context),
      onNext: () {
        if (!_isNextEnabled) {
          BlueBanner.show(context, '$_secondsLeft초 후에 다음 버튼이 활성화됩니다');
          return;
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => Week4ClassificationScreen(
                  bListInput: widget.bListInput,
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
      },

      child:
          _isLoading
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(),
              )
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/image/think_blue.png',
                    height: 160,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 20),
                  RuledParagraph(
                    text: focusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C3C55),
                      height: 1.6,
                    ),
                    lineColor: const Color(0xFFE1E8F0),
                    lineThickness: 1.2,
                    lineGapBelow: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    lineWidth: kRuleWidth,
                  ),
                  if (!_isNextEnabled) ...[
                    const SizedBox(height: 18),
                    Text(
                      '$_secondsLeft초 후에 다음 버튼이 활성화됩니다',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9BA7B4),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
    );
  }
}
