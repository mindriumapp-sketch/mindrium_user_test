import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/4th_treatment/week4_classfication_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_final_screen.dart';
import 'package:gad_app_team/features/4th_treatment/week4_flow_prompt_widgets.dart';

// ✅ 새 UI 래퍼
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

      child: Week4SituationFocusBody(
        title: '그때 상황을 천천히 떠올려볼게요',
        helperText: '$userName님이 적어주신 장면에 잠시만 머물러보세요.',
        situationText: situationText,
        footerText: '상황이 또렷하지 않아도 괜찮아요. 떠오르는 만큼만 천천히 떠올려보세요.',
        isLoading: _isLoading,
        secondsLeft: _isNextEnabled ? null : _secondsLeft,
        waitingText: '$_secondsLeft초 후에 다음으로 넘어갈 수 있어요',
      ),
    );
  }
}
