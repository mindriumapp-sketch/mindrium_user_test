import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/8th_treatment/week8_user_journey_screen.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/eduhome_bg.dart';
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/choice_card_button.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/week8_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/utils/server_datetime.dart';

// ──────────────────────────────────────────────────────────────────────────────
// 모델
class CalendarEvent {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> behaviors;
  final DateTime createdAt;

  CalendarEvent({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.behaviors,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'behaviors': behaviors,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'],
    startDate: parseServerDateTime(json['startDate']) ?? DateTime.now(),
    endDate: parseServerDateTime(json['endDate']) ?? DateTime.now(),
    behaviors: List<String>.from(json['behaviors']),
    createdAt:
        parseServerDateTime(json['createdAt'], fallback: DateTime.now()) ??
        DateTime.now(),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// 화면
class Week8EffectivenessScreen extends StatefulWidget {
  final List<String> checkedBehaviors;

  const Week8EffectivenessScreen({super.key, required this.checkedBehaviors});

  @override
  State<Week8EffectivenessScreen> createState() =>
      _Week8EffectivenessScreenState();
}

class _Week8EffectivenessScreenState extends State<Week8EffectivenessScreen> {
  // 컬러 상수
  static const chipBorderBlue = Color(0xFF6DBEF2);
  static const checkedChipFill = Color(0xFFDDEEFF);

  // 첫 화면(체크된 계획 목록)을 생략하고 바로 질문 시작
  bool _showingCheckedList = false;

  final List<String> _checkedBehaviors = [];
  final Set<String> _removedBehaviors = {};
  int _currentBehaviorIndex = 0;

  // 단계(0: 효과성, 1: 유지)
  int _step = 0;
  bool? _wasEffective;
  bool? _willContinue;

  bool _loading = true;

  // 평가 결과 저장 (behavior -> {was_effective, will_continue})
  final Map<String, Map<String, bool>> _evaluationResults = {};

  // API 클라이언트
  late final ApiClient _apiClient;
  late final Week8Api _week8Api;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(tokens: TokenStorage());
    _week8Api = Week8Api(_apiClient);
    _init();
  }

  Future<void> _init() async {
    _checkedBehaviors
      ..clear()
      ..addAll(widget.checkedBehaviors);
    setState(() => _loading = false);
  }

  String get _currentBehavior => _checkedBehaviors[_currentBehaviorIndex];
  bool get _canNext =>
      _showingCheckedList
          ? true
          : (_step == 0 ? _wasEffective != null : _willContinue != null);

  void _onNext() {
    // 1) 체크된 계획만 보여주던 첫 화면일 때 → 평가 모드로 전환
    if (_showingCheckedList) {
      setState(() {
        _showingCheckedList = false;
        _step = 0;
        _currentBehaviorIndex = 0;
        _wasEffective = null;
        _willContinue = null;
      });
      return;
    }

    // 2) 평가 모드일 때 기존 로직
    if (_step == 0) {
      setState(() {
        _step = 1;
      });
      return;
    }

    // 현재 행동의 평가 결과 저장
    _evaluationResults[_currentBehavior] = {
      'was_effective': _wasEffective ?? false,
      'will_continue': _willContinue ?? false,
    };

    // 유지하기 않음 선택 시 제거 목록에 추가
    if (_willContinue == false) {
      _removedBehaviors.add(_currentBehavior);
    }

    // 다음 행동으로
    if (_currentBehaviorIndex < _checkedBehaviors.length - 1) {
      setState(() {
        _currentBehaviorIndex++;
        _step = 0;
        _wasEffective = null;
        _willContinue = null;
      });
    } else {
      _saveEvaluations();
    }
  }

  void _onBack() {
    // 체크된 계획 화면에서는 그냥 나가기
    if (_showingCheckedList) {
      Navigator.pop(context);
      return;
    }

    // 평가 중인데 유지 단계면 → 효과성 단계로만 한 단계 뒤로
    if (_step == 1) {
      setState(() {
        _step = 0;
        _wasEffective = null;
      });
      return;
    }

    // 그 외에는 나가기
    Navigator.pop(context);
  }

  Future<void> _saveEvaluations() async {
    try {
      // behavior -> chip_id 매핑 가져오기
      final behaviorToChip = Week7AddDisplayScreen.globalBehaviorToChip;
      
      // 평가 결과를 API 형식으로 변환
      final evaluations = _evaluationResults.entries.map((entry) {
        final behavior = entry.key;
        final result = entry.value;
        final chipId = behaviorToChip[behavior]; // null일 수 있음 (새로 추가한 행동)
        
        return {
          'behavior': behavior, // 항상 포함 (chip_id가 없을 때 식별용)
          if (chipId != null) 'chip_id': chipId, // chip_id가 있을 때만 포함
          'was_effective': result['was_effective'] ?? false,
          'will_continue': result['will_continue'] ?? false,
        };
      }).toList();

      final sessionId = await _ensureSessionId();
      await _week8Api.updateEffectiveness(
        sessionId: sessionId,
        effectivenessEvaluations: evaluations,
      );
      
      if (!mounted) return;
      _showDone();
    } catch (e) {
      if (!mounted) return;
      BlueBanner.show(context, '평가 저장에 실패했습니다: $e');
    }
  }

  void _showDone() {
    final keep =
    _checkedBehaviors.where((b) => !_removedBehaviors.contains(b)).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomPopupDesign(
        title: '평가 완료',
        highlightText:
        keep.isEmpty ? '유지할 행동이 없습니다.' : '유지할 행동: ${keep.join(", ")}',
        message: '평가가 완료되었습니다! \n다음 단계로 넘어가겠습니다.',
        negativeText: '닫기',
        positiveText: '다음',
        onNegativePressed: () {
          Navigator.pop(context);
        },
        onPositivePressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const Week8UserJourneyScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
      ),
    );
  }

  Future<String> _ensureSessionId() async {
    if (_sessionId != null && _sessionId!.isNotEmpty) return _sessionId!;

    final existing = await _week8Api.fetchWeek8Session();
    _sessionId =
        existing?['session_id']?.toString() ?? existing?['sessionId']?.toString();
    if (_sessionId != null && _sessionId!.isNotEmpty) return _sessionId!;

    final created = await _week8Api.createWeek8Session(
      totalScreens: 1,
      lastScreenIndex: 1,
      startTime: DateTime.now(),
      completed: false,
    );
    _sessionId =
        created['session_id']?.toString() ?? created['sessionId']?.toString();
    if (_sessionId == null || _sessionId!.isEmpty) {
      throw Exception('8주차 세션 ID를 확인할 수 없습니다.');
    }
    return _sessionId!;
  }

  // ✅ 여기: 공통 진행바 위젯 (이 화면 버전)
  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '질문 ${_currentBehaviorIndex + 1}',
              style: const TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 14,
                color: Color(0xFF356D91),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_currentBehaviorIndex + 1}/${_checkedBehaviors.length}',
              style: const TextStyle(
                fontFamily: 'NotoSansKR',
                fontSize: 14,
                color: Color(0xFF356D91),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_currentBehaviorIndex + 1) / _checkedBehaviors.length,
            backgroundColor: Colors.white,
            valueColor:
            const AlwaysStoppedAnimation<Color>(Color(0xFF74D2FF)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading || _checkedBehaviors.isEmpty) {
      return EduhomeBg(
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(title: '효과성 평가'),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return EduhomeBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: const CustomAppBar(title: '효과성 평가'),
        body: SafeArea(
          child: Column(
            children: [
              // 위쪽 스크롤 영역
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.padding),
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.88,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ 체크된 계획 화면일 때는 진행바 안 보이게
                          if (!_showingCheckedList) ...[
                            _buildProgressBar(),
                            const SizedBox(height: 16),
                          ],

                          // 본문
                          _showingCheckedList
                              ? _checkedListCard()
                              : Column(
                            children: [
                              const SizedBox(height: 12),
                              _questionCard(),
                              const SizedBox(height: 18),
                              SelectableChoiceCardButton(
                                label: '예',
                                backgroundColor: const Color(0xFF329CF1),
                                isSelected:
                                    _step == 0
                                        ? _wasEffective == true
                                        : _willContinue == true,
                                isDimmed:
                                    _step == 0
                                        ? (_wasEffective != null &&
                                            _wasEffective != true)
                                        : (_willContinue != null &&
                                            _willContinue != true),
                                height: 54,
                                onPressed: () {
                                  setState(() {
                                    if (_step == 0) {
                                      _wasEffective = true;
                                    } else {
                                      _willContinue = true;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              SelectableChoiceCardButton(
                                label: '아니오',
                                backgroundColor: const Color(0xFFFDB0B5),
                                isSelected:
                                    _step == 0
                                        ? _wasEffective == false
                                        : _willContinue == false,
                                isDimmed:
                                    _step == 0
                                        ? (_wasEffective != null &&
                                            _wasEffective != false)
                                        : (_willContinue != null &&
                                            _willContinue != false),
                                height: 54,
                                onPressed: () {
                                  setState(() {
                                    if (_step == 0) {
                                      _wasEffective = false;
                                    } else {
                                      _willContinue = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 아래 네비게이션 고정
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
child: NavigationButtons(
                  leftLabel: '이전',
                  rightLabel: '다음',
                  onBack: _onBack,
                  onNext: _canNext ? _onNext : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ quiz_card로 바꾼 질문 카드
  Widget _questionCard() {
    final questionText = _step == 0 ? '효과가 있었나요?' : '앞으로도 유지하실 건가요?';
    return QuizCard(
      noticeText: questionText,
      quizText: _currentBehavior,
      currentIndex: _currentBehaviorIndex + 1,
      totalCount: _checkedBehaviors.length,
    );
  }

  // ✅ 체크된 계획 화면
  Widget _checkedListCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuizCard(
          quizText: '아래 목록을 한 번 보고\n다음을 눌러 효과를 \n평가해볼까요?',
          currentIndex: 0,
        ),
        const SizedBox(height: 30),
        JellyfishBanner(
          message: '이번 주에 실천했던 계획들이에요.',
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _checkedBehaviors.map((b) {
              final removed = _removedBehaviors.contains(b);
              return ConstrainedBox(
                constraints: const BoxConstraints.tightFor(
                  width: 239,
                  height: 52,
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: removed ? Colors.grey[300] : checkedChipFill,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: chipBorderBlue, width: 1),
                      boxShadow: [
                        BoxShadow(
                        color: chipBorderBlue.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    b,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: removed ? Colors.black54 : const Color(0xFF2D3748),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
