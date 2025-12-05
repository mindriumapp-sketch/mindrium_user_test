import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'week5_classification_result_screen.dart';
// edu-sessions 저장용
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';

// 분리한 프리젠테이션 위젯
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';
import 'package:gad_app_team/widgets/choice_card_button.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

class Week5ClassificationScreen extends StatefulWidget {
  final String? sessionId;
  const Week5ClassificationScreen({super.key, required this.sessionId});

  @override
  Week5ClassificationScreenState createState() =>
      Week5ClassificationScreenState();
}

class Week5ClassificationScreenState extends State<Week5ClassificationScreen> {
  final List<Map<String, dynamic>> quizSentences = [
    // 불안 회피
    {'text': '부담스러운 일정이나 모임을 계속 미루거나 빠진다.', 'type': 'anxious'},
    {'text': '불편한 사람과의 만남이나 대화를 계속 피한다.', 'type': 'anxious'},
    {'text': '불안한 장소에 가더라도 빨리 떠날 생각만 한다.', 'type': 'anxious'},
    {'text': '불안감에서 벗어나려고 스마트폰이나 TV 등 즉각적인 자극에 지나치게 몰두한다.', 'type': 'anxious'},
    {'text': '모임이나 대화 중 질문에 대답을 짧게 하거나 말하는 것을 최소화한다.', 'type': 'anxious'},
    {'text': '중요한 결정을 불안 때문에 계속 미룬다.', 'type': 'anxious'},
    {'text': '불안을 느낄 때마다 자주 약(진정제, 두통약 등)에 의존한다.', 'type': 'anxious'},
    {'text': '발표나 회의 시 항상 원고나 자료에만 집중하며 대화는 최소화한다.', 'type': 'anxious'},
    {'text': '불안을 덜기 위해 휴대폰이나 작은 물건을 계속 만지작거린다.', 'type': 'anxious'},
    {'text': '불안한 생각이 떠오르면 즉시 다른 일로 주의를 돌려 생각을 차단한다.', 'type': 'anxious'},
    {'text': '걱정거리를 "생각하지 말자"라고 애써 무시한다.', 'type': 'anxious'},
    // 불안 직면
    {'text': '부담스러운 일정이나 모임을 오랜 시간동안 참석해본다.', 'type': 'healthy'},
    {'text': '불편한 사람과의 만남이나 대화를 짧게라도 시도해본다.', 'type': 'healthy'},
    {'text': '불안한 장소에서 잠시 머물며 몸이 천천히 적응하는 걸 경험한다.', 'type': 'healthy'},
    {'text': '모임에서 간단한 질문을 먼저 하거나, 상대방과 짧은 대화를 시도한다.', 'type': 'healthy'},
    {'text': '불안하더라도 작은 일부터 우선순위를 정해 조금씩 결정을 내린다.', 'type': 'healthy'},
    {'text': '불안할 때 약물 대신 심호흡이나 근육 이완법을 시도해본다.', 'type': 'healthy'},
    {'text': '발표나 회의 시 미리 준비한 내용에서 벗어나 조금씩 자유롭게 말한다.', 'type': 'healthy'},
    {'text': '불안한 생각이 들면 그것을 간단히 적어보고 현실적인지 점검한다.', 'type': 'healthy'},
    {'text': '걱정거리를 명확하게 적어보고 가능한 대체 생각을 간략히 정리한다.', 'type': 'healthy'},
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

  @override
  void initState() {
    super.initState();
    shuffledSentences = List<Map<String, dynamic>>.from(quizSentences);
    shuffledSentences.shuffle();
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
        await _saveWeek5QuizToEduSessionOnce();

        if (!mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                Week5ClassificationResultScreen(
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
            ? '정답! 불안을 직면하는 행동이에요.'
            : '정답! 불안을 회피하는 행동이에요.';
        feedbackColor = const Color(0xFF4CAF50);
      } else {
        feedback = selected == 'healthy'
            ? '불안을 직면하는 행동이라고 하셨군요.\n하지만 이건 불안을 회피하는 행동 쪽에\n가깝습니다.'
            : '불안을 회피하는 행동이라고 하셨군요.\n하지만 이건 불안을 직면하는 행동 쪽에\n가깝습니다.';
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

  /// 마지막 문항까지 완료되었을 때,
  /// week_number=5 최신 edu-session 에 classification_quiz 저장
  Future<void> _saveWeek5QuizToEduSession() async {
    try {
      final tokens = TokenStorage();
      final access = await tokens.access;

      if (access == null) {
        debugPrint(
          '[Week5Classification] No access token. Skip edu-sessions update.',
        );
        return;
      }

      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      final sessionId = widget.sessionId?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint(
          '[Week5Classification] week5 session has no session_id. Skip update.',
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
        '[Week5Classification] classification_quiz saved to edu-session ($sessionId)',
      );
    } catch (e, st) {
      debugPrint(
        '[Week5Classification] Failed to save classification_quiz: $e\n$st',
      );
    }
  }

  /// 같은 화면 lifecycle 안에서 한 번만 저장되도록 래핑
  Future<void> _saveWeek5QuizToEduSessionOnce() async {
    if (_savedToEduSession) return;
    _savedToEduSession = true;
    await _saveWeek5QuizToEduSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 배경 이미지 설정
      body: Stack(
        children: [
          // 🌊 반투명 배경
          Opacity(
            opacity: 0.65,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // 🌟 실제 콘텐츠
          SafeArea(
            child: Column(
              children: [
                const CustomAppBar(title: '5주차 - 불안 직면 VS 회피'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 4,
                          child: QuizCard(
                            quizText: shuffledSentences[currentIndex]['text'],
                            currentIndex: currentIndex + 1,
                            totalCount: shuffledSentences.length,
                          ),
                        ),
                        const SizedBox(height: 12),
                        JellyfishNotice(
                          feedback: feedback,
                          feedbackColor: feedbackColor,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: Column(
                            children: [
                              Expanded(
                                child: ChoiceCardButton(
                                  type: ChoiceType.healthy,
                                  onPressed: () => _checkAnswer('healthy'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ChoiceCardButton(
                                  type: ChoiceType.anxious,
                                  onPressed: () => _checkAnswer('anxious'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        NavigationButtons(
                          onBack: () => Navigator.pop(context),
                          onNext: () async {
                            if (answered) {
                              await _nextSentence();
                            } else {
                              BlueBanner.show(context, '답변을 선택해주세요!');
                            }
                          },
                        ),
                      ],
                    ),
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
