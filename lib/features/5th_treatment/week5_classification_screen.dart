import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'week5_classification_result_screen.dart';

// edu-sessions 저장용
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';

// 프리젠테이션 위젯
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';

class Week5ClassificationScreen extends StatefulWidget {
  final String? sessionId;
  const Week5ClassificationScreen({super.key, required this.sessionId});

  @override
  State<Week5ClassificationScreen> createState() =>
      _Week5ClassificationScreenState();
}

class _Week5ClassificationScreenState extends State<Week5ClassificationScreen> {
  /// 불안 회피(anxious) vs 불안 직면(healthy) 문항 데이터
  final List<Map<String, dynamic>> quizSentences = [
    // 회피 행동 (anxious)
    {
      'text': '부담스러운 일정이나 모임을 계속 미루거나 빠진다.',
      'type': 'anxious',
      'wrongReason': '불편함을 피하면 당장은 편할 수 있지만, 불안이 계속 유지될 수 있어요.',
    },
    {
      'text': '불편한 사람과의 만남이나 대화를 계속 피한다.',
      'type': 'anxious',
      'wrongReason': '불안을 줄이기 위해 관계를 피하면 긴장이 줄어들 기회를 놓칠 수 있어요.',
    },
    {
      'text': '불안한 장소에 가더라도 빨리 떠날 생각만 한다.',
      'type': 'anxious',
      'wrongReason': '불안한 상황에 머물기보다 바로 벗어나려 하면 익숙해질 기회가 줄어들 수 있어요.',
    },
    {
      'text': '불안감에서 벗어나려고 스마트폰이나 TV에 지나치게 몰두한다.',
      'type': 'anxious',
      'wrongReason': '불안을 다른 것으로 덮으려 하면 마음이 스스로 진정되는 경험을 하기 어려워질 수 있어요.',
    },
    {
      'text': '모임이나 대화 중 말하는 것을 최소화한다.',
      'type': 'anxious',
      'wrongReason': '말을 줄이는 방식은 불안을 피하는 데는 도움이 되지만, 자신감을 키우는 데는 방해가 될 수 있어요.',
    },
    {
      'text': '중요한 결정을 불안 때문에 계속 미룬다.',
      'type': 'anxious',
      'wrongReason': '결정을 미루면 잠시 편할 수 있지만, 불안이 더 오래 이어질 수 있어요.',
    },
    {
      'text': '불안을 느낄 때마다 진정제나 두통약 등에 의존한다.',
      'type': 'anxious',
      'wrongReason': '외부 도움에만 의존하면 스스로 불안을 견디는 힘을 기르기 어려울 수 있어요.',
    },
    {
      'text': '발표나 회의 시 원고에만 집중하며 대화는 최소화한다.',
      'type': 'anxious',
      'wrongReason': '실수를 피하려고 지나치게 통제하면 오히려 상황에 자연스럽게 적응하기 어려워질 수 있어요.',
    },
    {
      'text': '불안을 덜기 위해 휴대폰이나 작은 물건을 계속 만지작거린다.',
      'type': 'anxious',
      'wrongReason': '이런 행동은 잠깐 안정을 줄 수 있지만, 불안을 직접 견디는 연습을 줄일 수 있어요.',
    },
    {
      'text': '불안한 생각이 떠오르면 다른 일로 주의를 돌려 생각을 차단한다.',
      'type': 'anxious',
      'wrongReason': '생각을 바로 밀어내려 하면 오히려 더 신경 쓰이게 될 수 있어요.',
    },
    {
      'text': '"생각하지 말자"고 애써 무시한다.',
      'type': 'anxious',
      'wrongReason': '불안을 억지로 지우려 하면 그 생각이 더 크게 느껴질 수 있어요.',
    },

    // 직면 행동 (healthy)
    {
      'text': '부담스러운 일정이나 모임에 오랜 시간 참석해본다.',
      'type': 'healthy',
      'wrongReason': '조금 불편하더라도 머물러보는 경험은 불안이 줄어드는 데 도움이 될 수 있어요.',
    },
    {
      'text': '불편한 사람과의 만남이나 대화를 짧게라도 시도해본다.',
      'type': 'healthy',
      'wrongReason': '작게라도 직접 마주해보는 행동은 회피보다 자신감을 키우는 데 도움이 돼요.',
    },
    {
      'text': '불안한 장소에서 잠시 머물며 몸이 적응하는 걸 경험한다.',
      'type': 'healthy',
      'wrongReason': '바로 피하지 않고 잠시 머무르면 불안이 자연스럽게 낮아질 수 있다는 걸 배우게 돼요.',
    },
    {
      'text': '모임에서 간단한 질문을 먼저 하거나 짧은 대화를 시도한다.',
      'type': 'healthy',
      'wrongReason': '작은 시도부터 해보는 것은 불안을 직면하는 건강한 연습이 될 수 있어요.',
    },
    {
      'text': '불안하더라도 작은 일부터 우선순위를 정해 조금씩 결정을 내린다.',
      'type': 'healthy',
      'wrongReason': '불안이 있어도 행동을 이어가는 방식은 회피를 줄이는 데 도움이 돼요.',
    },
    {
      'text': '불안할 때 약물 대신 심호흡이나 근육 이완법을 시도한다.',
      'type': 'healthy',
      'wrongReason': '스스로 긴장을 조절해보는 연습은 불안을 견디는 힘을 키우는 데 도움이 될 수 있어요.',
    },
    {
      'text': '발표나 회의 시 미리 준비한 내용에서 벗어나 조금씩 자유롭게 말한다.',
      'type': 'healthy',
      'wrongReason': '완벽하게 통제하기보다 조금씩 직접 해보는 경험이 불안을 줄이는 데 도움이 돼요.',
    },
    {
      'text': '불안한 생각이 들면 그것을 간단히 적어보고 현실적인지 점검한다.',
      'type': 'healthy',
      'wrongReason': '생각을 피하지 않고 점검해보는 태도는 불안을 더 균형 있게 바라보게 도와줘요.',
    },
    {
      'text': '걱정거리를 명확하게 적고 가능한 대체 생각을 간략히 정리한다.',
      'type': 'healthy',
      'wrongReason': '불안을 정리하고 다시 바라보는 과정은 회피보다 직면에 더 가까운 건강한 방식이에요.',
    },
  ];

  final List<Map<String, dynamic>> shuffledSentences = [];
  int currentIndex = 0;
  String? selectedChoice;
  int correctCount = 0;
  List<Map<String, dynamic>> quizResults = [];
  bool _savedToEduSession = false;

  @override
  void initState() {
    super.initState();
    // 문제를 무작위로 섞습니다.
    shuffledSentences
      ..clear()
      ..addAll(List<Map<String, dynamic>>.from(quizSentences));
    shuffledSentences.shuffle();
  }

  /// 답을 선택할 때 호출: 선택 상태만 갱신
  void _selectAnswer(String selected) {
    setState(() {
      selectedChoice = selected;
    });
  }

  /// 이전 문제로 이동: 퀴즈 결과를 롤백하고 상태를 되돌립니다.
  void _previousSentence() {
    if (currentIndex > 0 && quizResults.isNotEmpty) {
      final prevResult = quizResults.removeLast();
      if (prevResult['isCorrect'] == true) {
        correctCount = correctCount > 0 ? correctCount - 1 : 0;
      }
      setState(() {
        currentIndex--;
        selectedChoice = prevResult['userChoice'] as String?;
      });
    } else {
      Navigator.pop(context);
    }
  }

  /// 다음 문제로 이동: 답이 선택되지 않았다면 BlueBanner로 안내,
  /// 선택되었다면 결과를 저장하고 다음 문제 혹은 결과 화면으로 이동합니다.
  Future<void> _nextSentence() async {
    final choice = selectedChoice;
    if (choice == null) {
      BlueBanner.show(context, '답변을 선택해주세요!');
      return;
    }
    final current = shuffledSentences[currentIndex];
    final bool correct = current['type'] == choice;
    // 정답 수 증가
    if (correct) correctCount++;
    // 결과 저장
    final wrongReasonVal = current['wrongReason'];
    quizResults.add({
      'text': current['text'],
      'correctType': current['type'],
      'userChoice': choice,
      'isCorrect': correct,
      'wrongReason':
          wrongReasonVal is String
              ? wrongReasonVal
              : (wrongReasonVal?.toString() ?? ''),
    });

    // 다음 문제 또는 결과 화면으로 이동
    if (currentIndex < shuffledSentences.length - 1) {
      setState(() {
        currentIndex++;
        selectedChoice = null;
      });
    } else {
      await _saveWeek5QuizToEduSessionOnce();
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => Week5ClassificationResultScreen(
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

  /// edu-session 저장: 마지막 문제까지 완료한 뒤 한 번만 저장하도록 합니다.
  Future<void> _saveWeek5QuizToEduSession() async {
    try {
      final tokens = TokenStorage();
      final access = await tokens.access;
      if (access == null) {
        debugPrint('[Week5Classification] No access token. Skip update.');
        return;
      }
      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);
      final sessionId = widget.sessionId?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint('[Week5Classification] No session ID. Skip update.');
        return;
      }
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
        '[Week5Classification] classification_quiz saved to ($sessionId)',
      );
    } catch (e, st) {
      debugPrint('[Week5Classification] Failed to save quiz: $e\n$st');
    }
  }

  Future<void> _saveWeek5QuizToEduSessionOnce() async {
    if (_savedToEduSession) return;
    _savedToEduSession = true;
    await _saveWeek5QuizToEduSession();
  }

  /// 3주차와 동일한 선택 버튼 UI: 선택하면 색상이 유지되고 그림자가 강해집니다.
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
        isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.transparent;

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
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDimmed ? const Color(0xFF7C8D99) : Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Noto Sans KR',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double sidePadding = 20.0;
    return Scaffold(
      body: Stack(
        children: [
          // 반투명 배경 이미지
          Opacity(
            opacity: 0.65,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const CustomAppBar(title: '행동 구분 연습'),
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
                        // 문제 카드
                        QuizCard(
                          quizText: shuffledSentences[currentIndex]['text'],
                          currentIndex: currentIndex + 1,
                          totalCount: shuffledSentences.length,
                        ),
                        const SizedBox(height: 15),
                        JellyfishNotice(
                          feedback:
                              '위 행동이 불안을 직면하는 행동인지, 회피하는 행동인지 선택한 후 [다음]을 눌러주세요.',
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 10),
                        // 선택 버튼 두 개
                        Column(
                          children: [
                            _buildSelectableChoiceButton(
                              label: '불안 직면',
                              isSelected: selectedChoice == 'healthy',
                              isDimmed:
                                  selectedChoice != null &&
                                  selectedChoice != 'healthy',
                              backgroundColor: const Color(0xFF1FA4F0),
                              onPressed: () => _selectAnswer('healthy'),
                            ),
                            const SizedBox(height: 12),
                            _buildSelectableChoiceButton(
                              label: '불안 회피',
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
                // 하단 네비게이션: 이전/다음
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
                    leftLabel: '이전',
                    rightLabel: '다음',
                    onBack: _previousSentence,
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
