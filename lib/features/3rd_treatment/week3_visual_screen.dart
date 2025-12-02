// lib/features/3rd_treatment/week3_visual_screen.dart

import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_final_screen.dart';
import 'package:gad_app_team/widgets/thought_card.dart';        // ThoughtCard / ThoughtType
import 'package:gad_app_team/widgets/detail_popup.dart';        // 자세히 보기 팝업
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week3VisualScreen extends StatefulWidget {
  final List<String> previousChips;    // 도움이 되지 않는 생각
  final List<String> alternativeChips; // 도움이 되는 생각
  final List<Map<String, dynamic>>? quizResults; // 퀴즈 결과
  final int? correctCount; // 정답 개수

  const Week3VisualScreen({
    super.key,
    required this.previousChips,
    required this.alternativeChips,
    this.quizResults,
    this.correctCount,
  });

  @override
  State<Week3VisualScreen> createState() => _Week3VisualScreenState();
}

class _Week3VisualScreenState extends State<Week3VisualScreen> {
  late final ApiClient _client;
  late final EduSessionsApi _eduSessionsApi;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _eduSessionsApi = EduSessionsApi(_client);
  }

  Future<void> _saveSession() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // 퀴즈 결과 변환
      Map<String, dynamic>? classificationQuiz;
      if (widget.quizResults != null && widget.quizResults!.isNotEmpty && widget.correctCount != null) {
        final wrongList = widget.quizResults!
            .where((item) => item['isCorrect'] == false)
            .map((item) => {
                  'text': item['text'],
                  'user_choice': item['userChoice'],
                  'correct_type': item['correctType'],
                })
            .toList();

        classificationQuiz = {
          'correct_count': widget.correctCount,
          'total_count': widget.quizResults!.length,
          'results': widget.quizResults!.map((r) => {
                'text': r['text'],
                'correct_type': r['correctType'],
                'user_choice': r['userChoice'],
                'is_correct': r['isCorrect'],
              }).toList(),
          'wrong_list': wrongList,
        };
      }

      await _eduSessionsApi.createWeek3or5Session(
        weekNumber: 3,
        totalScreens: 3,
        lastScreenIndex: 3,
        completed: true,
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        negativeItems: widget.previousChips,
        positiveItems: widget.alternativeChips,
        classificationQuiz: classificationQuiz,
      );
    } catch (e) {
      // 에러 발생 시에도 팝업은 표시
      debugPrint('세션 저장 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // 공통: 전체 칩 자세히 보기
  void _showChipsPopup({
    required String title,
    required List<String> chips,
    required ThoughtType thoughtType,
  }) {
    showDialog(
      context: context,
      builder: (_) => DetailPopup(
        title: title,
        positiveText: '돌아가기',
        negativeText: null,
        onPositivePressed: () => Navigator.pop(context),
        child: chips.isEmpty
            ? const Text(
          '입력된 항목이 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            color: Color(0xFF356D91),
          ),
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: chips.map((text) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ThoughtBubble(
                text: text,
                type: thoughtType,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 상단 패널: 도움이 되는 생각
  Widget _buildTopPanel() {
    return _buildThoughtSection(
      title: '도움이 되는 생각',
      chips: widget.alternativeChips,
      thoughtType: ThoughtType.helpful,
    );
  }

  // 하단 패널: 도움이 되지 않는 생각
  Widget _buildBottomPanel() {
    return _buildThoughtSection(
      title: '도움이 되지 않는 생각',
      chips: widget.previousChips,
      thoughtType: ThoughtType.unhelpful,
    );
  }

  /// chips가 3개 초과일 때는 3개만 보여주고 '자세히 보기'
  Widget _buildThoughtSection({
    required String title,
    required List<String> chips,
    required ThoughtType thoughtType,
  }) {
    final bool needMore = chips.length > 3;
    final List<String> preview = needMore ? chips.sublist(0, 3) : chips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThoughtCard(
          title: title,
          pills: preview,
          thoughtType: thoughtType,
          titleSize: 18,
          titleWeight: FontWeight.w600,
        ),
        if (needMore) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => _showChipsPopup(
                title: title,
                chips: chips,
                thoughtType: thoughtType,
              ),
              child: const Text(
                '자세히 보기',
                style: TextStyle(
                  color: Color(0xFF626262),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double horizontalPadding = 24.0;
    const double panelRadius = 20.0;
    const double gapBetweenPanels = 24.0;
    final double maxWidth =
    size.width - 48 > 980 ? 980 : size.width - 48;

    return Scaffold(
      extendBody: true, // ✅ bottomNavigationBar 뒤까지 확장
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: '3주차 - Self Talk',
        confirmOnBack: false,
        showHome: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🌊 옅은 바다 배경
            Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),

            // 🧩 내용 영역
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    bottomInset + 120, // 아래 버튼 자리 확보
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 상단 카드 (도움이 되는 생각)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(panelRadius),
                            boxShadow: [
                              BoxShadow(
                                color:
                                Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(
                              20, 18, 20, 18),
                          child: _buildTopPanel(),
                        ),

                        const SizedBox(height: gapBetweenPanels),

                        // 하단 카드 (도움이 되지 않는 생각)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(panelRadius),
                            boxShadow: [
                              BoxShadow(
                                color:
                                Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(
                              20, 18, 20, 18),
                          child: _buildBottomPanel(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ✅ 화면 맨 아래 고정 네비게이션 버튼
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: NavigationButtons(
              leftLabel: '이전',
              rightLabel: '다음',
              onBack: () => Navigator.pop(context),
              onNext: () async {
                final nav = Navigator.of(context);
                await _saveSession();
                if (!mounted) return;
                nav.push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => Week3FinalScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}
