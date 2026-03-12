import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/widgets/q_quiz_card.dart';
import 'package:gad_app_team/widgets/q_jellyfish_notice.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_classification_result_screen.dart';

// edu-sessions 저장용
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';

class Week3ClassificationScreen extends StatefulWidget {
  final String? sessionId;
  const Week3ClassificationScreen({super.key, required this.sessionId});

  @override
  Week3ClassificationScreenState createState() =>
      Week3ClassificationScreenState();
}

class Week3ClassificationScreenState extends State<Week3ClassificationScreen> {
  final List<Map<String, dynamic>> quizSentences = [
    {
      'text': '나는 안전하지 않아',
      'type': 'anxious',
      'wrongReason': '위험을 실제보다 크게 느끼게 해서 불안을 더 키울 수 있는 생각이에요.',
    },
    {
      'text': '무언가 나쁜 일이 일어날 것이다',
      'type': 'anxious',
      'wrongReason': '아직 일어나지 않은 일을 나쁘게 단정하면 걱정이 더 커질 수 있어요.',
    },
    {
      'text': '나쁜 일이 일어나지 않도록 미리 막아야 한다',
      'type': 'anxious',
      'wrongReason': '모든 위험을 완벽히 막아야 한다고 느끼면 마음이 더 긴장될 수 있어요.',
    },
    {
      'text': '사람들이 나를 비웃고 조롱할 것이다',
      'type': 'anxious',
      'wrongReason': '다른 사람의 반응을 부정적으로 단정하면 불안이 더 커질 수 있어요.',
    },
    {
      'text': '나는 실수를 할 것이고, 그 실수는\n돌이킬 수 없을 만큼 심각할 것이다',
      'type': 'anxious',
      'wrongReason': '실수의 결과를 지나치게 크게 해석하면 두려움이 더 심해질 수 있어요.',
    },
    {
      'text': '나는 두려움을 절대 감당할 수 없다',
      'type': 'anxious',
      'wrongReason': '스스로의 감정 대처 능력을 너무 낮게 보면 더 불안해질 수 있어요.',
    },
    {
      'text': '혹시 실수해서 학부모나 학교의\n불만을 살까 봐 걱정이 된다',
      'type': 'anxious',
      'wrongReason': '가능한 일을 실제 위협처럼 크게 느끼게 하는 생각일 수 있어요.',
    },
    {
      'text': '예상치 못한 지출이 생기면\n감당할 수 없을 것이다',
      'type': 'anxious',
      'wrongReason': '어려운 상황을 감당 못 할 것이라고 단정하면 불안이 더 커질 수 있어요.',
    },
    {
      'text': '부모님께 갑자기 큰일이 생기면 어떡하지?',
      'type': 'anxious',
      'wrongReason': '일어나지 않은 미래를 미리 걱정하면 마음이 더 불안해질 수 있어요.',
    },
    {
      'text': '내가 무언가를 완벽히 처리하지 못하면\n큰일이 날 것이다',
      'type': 'anxious',
      'wrongReason': '완벽해야만 괜찮다고 느끼면 부담과 긴장이 더 커질 수 있어요.',
    },
    {
      'text': '내 말이 오해를 불러일으켰을 수 있어',
      'type': 'anxious',
      'wrongReason': '불확실한 상황을 부정적으로 해석하면 걱정이 더 이어질 수 있어요.',
    },
    {
      'text': '대부분의 경우, 실제로는\n나쁜 일이 일어나지 않는다',
      'type': 'healthy',
      'wrongReason': '걱정을 조금 더 현실적으로 바라보게 도와주는 균형 잡힌 생각이에요.',
    },
    {
      'text': '설령 나쁜 일이 일어난다고 해도\n나는 잘 대처할 수 있다',
      'type': 'healthy',
      'wrongReason': '위험만이 아니라 내 대처 능력도 함께 떠올리게 해주는 생각이에요.',
    },
    {
      'text': '나는 생각보다 용기 있고, 대처 능력이 있다',
      'type': 'healthy',
      'wrongReason': '스스로의 힘을 기억하게 해서 불안을 줄이는 데 도움이 되는 생각이에요.',
    },
    {
      'text': '두렵다고 해서 중요한 일을\n포기하지 않아도 된다',
      'type': 'healthy',
      'wrongReason': '두려움이 있어도 행동할 수 있다는 점을 알려주는 건강한 생각이에요.',
    },
    {
      'text': '누구나 실수할 수 있다.\n실수는 인간의 당연한 모습이다',
      'type': 'healthy',
      'wrongReason': '실수를 지나치게 두려워하지 않도록 도와주는 현실적인 생각이에요.',
    },
    {
      'text': '나는 완벽하지 않아도 괜찮다\n(사람들은 완벽한 사람보다는 따뜻하고 친절한 사람을 더 좋아한다)',
      'type': 'healthy',
      'wrongReason': '완벽해야 한다는 부담을 덜어주고 자신을 조금 더 너그럽게 보게 해줘요.',
    },
    {
      'text': '문제 상황은 보통 내가 잘 해결할 수 있다',
      'type': 'healthy',
      'wrongReason': '불안보다 해결 가능성에 더 초점을 맞추게 도와주는 생각이에요.',
    },
    {
      'text': '때로 불안을 느끼는 것은 정상이며\n자연스러운 현상이다',
      'type': 'healthy',
      'wrongReason': '불안을 이상한 것이 아니라 자연스러운 감정으로 이해하게 도와줘요.',
    },
    {
      'text': '예상치 못한 지출이 생기더라도\n감당할 수 있을 것이다',
      'type': 'healthy',
      'wrongReason': '어려움이 생겨도 대처할 수 있다고 보는 데 도움이 되는 생각이에요.',
    },
  ];

  late List<Map<String, dynamic>> shuffledSentences;
  int currentIndex = 0;
  String? selectedChoice;
  int correctCount = 0;
  List<Map<String, dynamic>> quizResults = [];

  // edu-sessions 저장 중복 방지 플래그
  bool _savedToEduSession = false;

  Week3ClassificationScreenState();

  @override
  void initState() {
    super.initState();
    shuffledSentences = List<Map<String, dynamic>>.from(quizSentences);
    shuffledSentences.shuffle();
  }

  /// 마지막 문항까지 완료되었을 때,
  /// week_number=3 최신 edu-session 에 classification_quiz 저장
  Future<void> _saveWeek3QuizToEduSession() async {
    try {
      final tokens = TokenStorage();
      final access = await tokens.access;

      if (access == null) {
        debugPrint(
          '[Week3Classification] No access token. Skip edu-sessions update.',
        );
        return;
      }

      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      final sessionId = widget.sessionId?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint(
          '[Week3Classification] week3 session has no session_id. Skip update.',
        );
        return;
      }

      // quizResults → ClassificationQuiz JSON으로 변환
      final totalCount = shuffledSentences.length;

      final classificationQuiz = <String, dynamic>{
        'correct_count': correctCount,
        'total_count': totalCount,
        'results':
            quizResults
                .map(
                  (item) => {
                    'text': item['text'],
                    'correct_type': item['correctType'],
                    'user_choice': item['userChoice'],
                    'is_correct': item['isCorrect'],
                    'wrongReason': item['wrongReason'],
                  },
                )
                .toList(),
      };

      await eduApi.updateEduSession(
        sessionId: sessionId,
        classificationQuiz: classificationQuiz,
      );

      debugPrint(
        '[Week3Classification] classification_quiz saved to edu-session ($sessionId)',
      );
    } catch (e, st) {
      debugPrint(
        '[Week3Classification] Failed to save classification_quiz: $e\n$st',
      );
    }
  }

  /// 같은 화면 lifecycle 안에서 한 번만 저장되도록 래핑
  Future<void> _saveWeek3QuizToEduSessionOnce() async {
    if (_savedToEduSession) return;
    _savedToEduSession = true;
    await _saveWeek3QuizToEduSession();
  }

  Future<void> _nextSentence() async {
    final selected = selectedChoice;
    if (selected == null) {
      BlueBanner.show(context, '먼저 답을 선택해 주세요');
      return;
    }

    final current = shuffledSentences[currentIndex];
    final correct = current['type'] == selected;
    if (correct) {
      correctCount++;
    }
    final wrongReasonVal = current['wrongReason'];
    quizResults.add({
      'text': current['text'],
      'correctType': current['type'],
      'userChoice': selected,
      'isCorrect': correct,
      'wrongReason':
          wrongReasonVal is String
              ? wrongReasonVal
              : (wrongReasonVal?.toString() ?? ''),
    });

    if (currentIndex < shuffledSentences.length - 1) {
      setState(() {
        currentIndex++;
        selectedChoice = null;
      });
    } else {
      // 🔹 마지막 문항까지 완료된 시점: edu-sessions 에 저장
      await _saveWeek3QuizToEduSessionOnce();

      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  Week3ClassificationResultScreen(
                    sessionId: widget.sessionId,
                    correctCount: correctCount,
                    quizResults: quizResults,
                  ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  void _selectAnswer(String selected) {
    setState(() {
      selectedChoice = selected;
    });
  }

  Widget _buildSelectableChoiceButton({
    required String label,
    required bool isSelected,
    required bool isDimmed,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    final Color effectiveBackground =
        isDimmed ? const Color(0xFFDCE5EB) : backgroundColor;
    final Color shadowColor =
        isSelected
            ? backgroundColor.withValues(alpha: 0.34)
            : Colors.black.withValues(alpha: 0.08);
    final double scale = isSelected ? 1.0 : 0.985;
    final double borderWidth = isSelected ? 2.0 : 0.0;
    final Color borderColor =
        isSelected ? Colors.white.withValues(alpha: 0.90) : Colors.transparent;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          color: effectiveBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isDimmed ? const Color(0xFF7C8D99) : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Noto Sans KR',
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 직전 문제로 이동하는 메서드
  void _previousSentence() {
    // 0번째보다 큰 경우에만 이전 문제로 돌아감
    if (currentIndex > 0 && quizResults.isNotEmpty) {
      final prevResult = quizResults.removeLast();
      // 직전 문제에서 정답을 맞췄다면 correctCount를 줄여줌
      if (prevResult['isCorrect'] == true) {
        correctCount = correctCount > 0 ? correctCount - 1 : 0;
      }
      setState(() {
        currentIndex--;
        // 직전 문제에서 선택했던 답을 복원
        selectedChoice = prevResult['userChoice'] as String?;
      });
    } else {
      // 첫 번째 문제라면 화면을 나감
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double sidePadding = 20.0;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🌊 배경
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const CustomAppBar(title: 'Self Talk'),

                // 위쪽: 콘텐츠 영역
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),

                        // 🔹 문제 카드
                        QuizCard(
                          quizText: shuffledSentences[currentIndex]['text'],
                          currentIndex: currentIndex + 1,
                          totalCount: shuffledSentences.length,
                        ),
                        const SizedBox(height: 15),

                        // 🔹 해파리 말풍선
                        const JellyfishNotice(),
                        const SizedBox(height: 10),

                        // 🔹 선택 버튼
                        Column(
                          children: [
                            _buildSelectableChoiceButton(
                              label: '도움이 되는 생각',
                              isSelected: selectedChoice == 'healthy',
                              isDimmed:
                                  selectedChoice != null &&
                                  selectedChoice != 'healthy',
                              backgroundColor: const Color(0xFF1FA4F0),
                              onPressed: () => _selectAnswer('healthy'),
                            ),
                            const SizedBox(height: 12),
                            _buildSelectableChoiceButton(
                              label: '도움이 되지 않는 생각',
                              isSelected: selectedChoice == 'anxious',
                              isDimmed:
                                  selectedChoice != null &&
                                  selectedChoice != 'anxious',
                              backgroundColor: const Color(0xFFF3A2AD),
                              onPressed: () => _selectAnswer('anxious'),
                            ),
                          ],
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // 아래: 항상 바닥에 붙는 네비게이션
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
                    leftLabel: '이전',
                    rightLabel: '다음',
                    onBack: _previousSentence, // 여기서 Navigator.pop 대신 호출
                    onNext: () async => _nextSentence(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
