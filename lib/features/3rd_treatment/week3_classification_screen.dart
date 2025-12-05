import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/widgets/q_quiz_card.dart';
import 'package:gad_app_team/widgets/q_jellyfish_notice.dart';
import 'package:gad_app_team/widgets/choice_card_button.dart';
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
  // 🔹 문항 데이터 (원본 그대로)
  final List<Map<String, dynamic>> quizSentences = [
    {'text': '나는 안전하지 않아', 'type': 'anxious'},
    {'text': '무언가 나쁜 일이 일어날 것이다', 'type': 'anxious'},
    {'text': '나쁜 일이 일어나지 않도록 미리 막아야 한다', 'type': 'anxious'},
    {'text': '사람들이 나를 비웃고 조롱할 것이다', 'type': 'anxious'},
    {
      'text': '나는 실수를 할 것이고, 그 실수는\n돌이킬 수 없을 만큼 심각할 것이다',
      'type': 'anxious',
    },
    {'text': '나는 두려움을 절대 감당할 수 없다', 'type': 'anxious'},
    {
      'text': '혹시 실수해서 학부모나 학교의\n불만을 살까 봐 걱정이 된다',
      'type': 'anxious',
    },
    {
      'text': '예상치 못한 지출이 생기면\n감당할 수 없을 것이다',
      'type': 'anxious',
    },
    {'text': '부모님께 갑자기 큰일이 생기면 어떡하지?', 'type': 'anxious'},
    {
      'text': '내가 무언가를 완벽히 처리하지 못하면\n큰일이 날 것이다',
      'type': 'anxious',
    },
    {'text': '내 말이 오해를 불러일으켰을 수 있어', 'type': 'anxious'},
    {
      'text': '대부분의 경우, 실제로는\n나쁜 일이 일어나지 않는다',
      'type': 'healthy',
    },
    {
      'text': '설령 나쁜 일이 일어난다고 해도\n나는 잘 대처할 수 있다',
      'type': 'healthy',
    },
    {
      'text': '나는 생각보다 용기 있고, 대처 능력이 있다',
      'type': 'healthy',
    },
    {
      'text': '두렵다고 해서 중요한 일을\n포기하지 않아도 된다',
      'type': 'healthy',
    },
    {
      'text': '누구나 실수할 수 있다.\n실수는 인간의 당연한 모습이다',
      'type': 'healthy',
    },
    {
      'text':
      '나는 완벽하지 않아도 괜찮다\n(사람들은 완벽한 사람보다는 따뜻하고 친절한 사람을 더 좋아한다)',
      'type': 'healthy',
    },
    {'text': '문제 상황은 보통 내가 잘 해결할 수 있다', 'type': 'healthy'},
    {'text': '때로 불안을 느끼는 것은 정상이며\n자연스러운 현상이다', 'type': 'healthy'},
    {'text': '예상치 못한 지출이 생기더라도\n감당할 수 있을 것이다', 'type': 'healthy'},
  ];

  late List<Map<String, dynamic>> shuffledSentences;
  int currentIndex = 0;
  String? feedback;
  Color? feedbackColor;
  bool answered = false;
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
        'results': quizResults
            .map((item) => {
          'text': item['text'],
          'correct_type': item['correctType'],
          'user_choice': item['userChoice'],
          'is_correct': item['isCorrect'],
        })
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
    if (currentIndex < shuffledSentences.length - 1) {
      setState(() {
        currentIndex++;
        feedback = null;
        feedbackColor = null;
        answered = false;
      });
    } else {
      // 🔹 마지막 문항까지 완료된 시점: edu-sessions 에 저장
      await _saveWeek3QuizToEduSessionOnce();

      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
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

  void _checkAnswer(String selected) {
    if (answered) return;

    final correct = shuffledSentences[currentIndex]['type'] == selected;

    setState(() {
      answered = true;

      if (correct) {
        correctCount++;
        feedback = selected == 'healthy'
            ? '정답! 도움이 되는 생각이에요.'
            : '정답! 도움이 되지 않는 생각이에요.';
        feedbackColor = const Color(0xFF4CAF50);
      } else {
        feedback = selected == 'healthy'
            ? '도움이 되는 생각이라고 하셨군요.\n하지만 이건 도움이 되지 않는 생각쪽에 \n가깝습니다.'
            : '도움이 되지 않는 생각이라고 하셨군요. \n하지만 이건 도움이 되는 생각쪽에 \n가깝습니다.';
        feedbackColor = const Color(0xFFFF5252);
      }

      quizResults.add({
        'text': shuffledSentences[currentIndex]['text'],
        'correctType': shuffledSentences[currentIndex]['type'],
        'userChoice': selected,
        'isCorrect': correct,
      });
    });
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
                const CustomAppBar(title: '3주차 - Self Talk'),

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
                        JellyfishNotice(
                          feedback: feedback,
                          feedbackColor: feedbackColor,
                        ),
                        const SizedBox(height: 10),

                        // 🔹 선택 버튼
                        Column(
                          children: [
                            ChoiceCardButton(
                              type: ChoiceType.helpful,
                              height: 54,
                              onPressed: () => _checkAnswer('healthy'),
                            ),
                            const SizedBox(height: 10),
                            ChoiceCardButton(
                              type: ChoiceType.unhelpful,
                              height: 54,
                              onPressed: () => _checkAnswer('anxious'),
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: NavigationButtons(
                    leftLabel: '이전',
                    rightLabel: '다음',
                    onBack: () => Navigator.pop(context),
                    onNext: () async {
                      if (answered) {
                        await _nextSentence();
                      } else {
                        BlueBanner.show(context, '먼저 답을 선택해 주세요');
                      }
                    },
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
