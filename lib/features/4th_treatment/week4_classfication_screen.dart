// lib/features/4th_treatment/week4_classification_screen.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'week4_alternative_thoughts.dart';
import 'week4_belief_rating_widgets.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

// ✅ 두 패널 레이아웃 (네가 저장한 파일)
import 'package:gad_app_team/widgets/top_btm_card.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/diaries_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week4ClassificationScreen extends StatefulWidget {
  final List<String> bListInput;
  final List<String> allBList;
  final List<String>? alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4ClassificationScreen({
    super.key,
    required this.bListInput,
    required this.allBList,
    this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  Week4ClassificationScreenState createState() =>
      Week4ClassificationScreenState();
}

class Week4ClassificationScreenState extends State<Week4ClassificationScreen> {
  Map<String, dynamic>? _abcModel;
  bool _isLoading = true;
  String? _error;
  double _sliderValue = 5.0;
  List<String> _bList = [];
  String _currentB = '';
  final Map<String, double> _bScores = {};
  late final ApiClient _client;
  late final DiariesApi _diariesApi;
  String? _diaryId;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _diariesApi = DiariesApi(_client);
    final id = widget.abcId;
    if (id != null && id.isNotEmpty) {
      _fetchDiaryById(id);
    } else {
      _fetchLatestDiary();
    }
  }

  Future<void> _fetchLatestDiary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _diariesApi.listDiaries();
      if (list.isEmpty) {
        setState(() {
          _abcModel = null;
          _isLoading = false;
        });
        return;
      }
      // 가장 최신 선택(시간 필드 + 인덱스 우선)
      // removed unused time helpers (latest 선택은 서버 /latest 사용)

      // keep for reference of time parsing if needed later

      // 최신 = 서버 latest API로 확정
      final Map<String, dynamic> latest = await _diariesApi.getLatestDiary();
      setState(() {
        _abcModel = latest;
        _diaryId =
            (latest['diary_id'] ?? latest['diaryId'] ?? latest['id'])
                ?.toString();
        _isLoading = false;
        _initBList();
      });
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDiaryById(String diaryId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _diariesApi.getDiary(diaryId);
      if (!mounted) return;
      setState(() {
        _abcModel = res;
        _diaryId = (res['diary_id'] ?? res['diaryId'] ?? res['id'])?.toString();
        _isLoading = false;
        _initBList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
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

  List<String> _parseBelief(dynamic raw) {
    final List<Map<String, String?>> entries = [];

    void addEntry(String label, String? chipId) {
      final trimmed = label.trim();
      if (trimmed.isEmpty) return;
      entries.add({'label': trimmed, 'chipId': chipId});
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final chipId =
              item['chip_id']?.toString() ?? item['chipId']?.toString();
          addEntry(_chipLabel(item), chipId);
        } else {
          addEntry(_chipLabel(item), null);
        }
      }
    } else if (raw is Map) {
      final chipId = raw['chip_id']?.toString() ?? raw['chipId']?.toString();
      addEntry(_chipLabel(raw), chipId);
    } else {
      final s = _chipLabel(raw);
      for (final part in s.split(',')) {
        addEntry(part, null);
      }
    }

    return entries.map((e) => e['label'] ?? '').toList();
  }

  void _initBList() {
    // 1) 인자로 받은 목록 우선
    if (widget.bListInput.isNotEmpty) {
      _bList =
          widget.bListInput
              .map((e) => _chipLabel(e).trim())
              .where((e) => e.isNotEmpty)
              .toList();
    }
    // 2) 비어 있으면 모델에서 파싱
    if (_bList.isEmpty && _abcModel != null) {
      _bList = _parseBelief(_abcModel?['belief']);
    }
    // 3) 남은 목록 중 아직 점수 안 준 첫 항목 선택
    final remainB = _bList.where((b) => !_bScores.containsKey(b)).toList();
    if (remainB.isNotEmpty) {
      _currentB = remainB.first;
    } else if (_bList.isNotEmpty) {
      _currentB = _bList.first;
    } else {
      _currentB = '';
    }
    _sliderValue = 5.0;
  }

  void _onNext() {
    // 현재 B가 비어 있으면 보정
    if (_currentB.isEmpty && _bList.isNotEmpty) {
      final firstNonEmpty = _bList.firstWhere(
        (e) => e.trim().isNotEmpty,
        orElse: () => '',
      );
      if (firstNonEmpty.isNotEmpty) _currentB = firstNonEmpty;
    }
    if (_currentB.isNotEmpty) {
      setState(() {
        _bScores[_currentB] = _sliderValue;
      });
    }
    final List<String> remainingBList =
        _bList.where((b) => !_bScores.containsKey(b)).toList();

    final bool isFromAnxietyScreen = widget.isFromAnxietyScreen;

    // 항상 현재 화면에서 로드한 최신 일기의 ID를 사용
    final diaryId =
        _diaryId ??
        _abcModel?['diaryId']?.toString() ??
        _abcModel?['diary_id']?.toString();
    if (diaryId != null && diaryId.isNotEmpty) {}

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => Week4AlternativeThoughtsScreen(
              previousChips: _currentB.isNotEmpty ? [_currentB] : const [],
              remainingBList: remainingBList,
              allBList: widget.allBList,
              existingAlternativeThoughts: widget.existingAlternativeThoughts,
              isFromAnxietyScreen: isFromAnxietyScreen,
              originalBList: widget.allBList,
              abcId: _diaryId ?? widget.abcId,
              loopCount: widget.loopCount,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    // 로딩/에러 상태일 때 보여줄 안전한 위젯들
    final Widget topLoading = const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    );
    final Widget topError =
        (_error == null)
            ? const SizedBox.shrink()
            : SizedBox(
              height: 160,
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            );

    // Top 패널 내용
    Widget buildTopPanel() {
      if (_isLoading) return topLoading;
      if (_error != null) return topError;

      // 데이터 없음 안내
      if ((_abcModel == null ||
          (_currentB.isEmpty && widget.bListInput.isEmpty))) {
        return const SizedBox(
          height: 160,
          child: Center(
            child: Text('최근에 작성한 ABC모델이 없습니다.', style: TextStyle(fontSize: 16)),
          ),
        );
      }

      final displayB = _chipLabel(
        _currentB.isNotEmpty
            ? _currentB
            : (widget.bListInput.isNotEmpty ? widget.bListInput.first : ''),
      );
      final displaySituation = _activationText();
      final totalThoughtCount =
          widget.allBList.isNotEmpty
              ? widget.allBList.length
              : (_bList.isNotEmpty ? _bList.length : widget.bListInput.length);
      final rawCurrentIndex = totalThoughtCount - widget.bListInput.length + 1;
      final currentIndex =
          totalThoughtCount <= 0
              ? 1
              : rawCurrentIndex < 1
              ? 1
              : (rawCurrentIndex > totalThoughtCount
                  ? totalThoughtCount
                  : rawCurrentIndex);

      return Week4BeliefContextPanel(
        title: '상황과 생각을 함께 떠올려보세요',
        subtitle: '$userName님이 적어주신 장면을 보며 지금 이 생각이 얼마나 크게 느껴지는지 살펴볼게요.',
        situationText:
            displaySituation.isNotEmpty
                ? displaySituation
                : '상황 정보를 확인하는 중이에요.',
        beliefText: displayB.isNotEmpty ? displayB : '생각 정보를 확인하는 중이에요.',
        badgeText:
            totalThoughtCount > 0 ? '$currentIndex / $totalThoughtCount' : null,
        footerText: '이 장면을 떠올린 상태에서 아래 슬라이더를 움직여보세요.',
      );
    }

    // Bottom 패널 내용 (슬라이더)
    Widget buildBottomPanel() {
      return Week4BeliefSliderPanel(
        value: _sliderValue,
        onChanged: (v) => setState(() => _sliderValue = v),
      );
    }

    // ===== ApplyDoubleCard 사용: 위/아래 패널 전달 =====
    return ApplyDoubleCard(
      appBarTitle: '인지 왜곡 찾기',
      onBack: () => Navigator.pop(context),
      onNext: _onNext,
      topChild: buildTopPanel(),
      bottomChild: buildBottomPanel(),
      middleBannerText: '지금 믿는 정도를 숫자로 골라주세요.\n가장 가까운 느낌이면 충분해요.',
      pagePadding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
      panelsGap: 10,
      panelPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      height: 112,
      topPadding: 0,
    );
  }
}
