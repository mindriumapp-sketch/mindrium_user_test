import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'week5_classification_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Week5ClassificationScreen extends StatefulWidget {
  const Week5ClassificationScreen({super.key});

  @override
  Week5ClassificationScreenState createState() =>
      Week5ClassificationScreenState();
}

class Week5ClassificationScreenState extends State<Week5ClassificationScreen> {
  // 퀴즈 문장 데이터 (문장, 정답)
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
    {'text': '걱정거리를 ‘생각하지 말자’라고 애써 무시한다.', 'type': 'anxious'},
    // 불안 직면
    {'text': '부담스러운 일정이나 모임을 오랜 시간동안 참석해본다.', 'type': 'healthy'},
    {'text': '불편한 사람과의 만남이나 대화를 짧게라도 시도해본다.', 'type': 'healthy'},
    {'text': '불안한 장소에서 잠시 머물며 몸이 천천히 적응하는 걸 경험한다.', 'type': 'healthy'},
    {'text': '모임에서 간단한 질문을 먼저 하거나, 상대방과 짧은 대화를 시도한다.', 'type': 'healthy'},
    {'text': '불안하더라도 작은 일부터 우선순위를 정해 조금씩 결정을 내린다.', 'type': 'healthy'},
    {'text': '불안할 때 약물 대신 심호흡이나 근육 이완법을 시도해본다.', 'type': 'healthy',},
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

  @override
  void initState() {
    super.initState();
    shuffledSentences = List<Map<String, dynamic>>.from(quizSentences);
    shuffledSentences.shuffle();
  }

  void _nextSentence() {
    setState(() {
      if (currentIndex < shuffledSentences.length - 1) {
        currentIndex++;
        feedback = null;
        feedbackColor = null;
        answered = false;
      } else {
        // 마지막 문장 이후 결과 화면으로 이동
        saveQuizResult(correctCount, quizResults);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    Week5ClassificationResultScreen(
                      correctCount: correctCount,
                      quizResults: quizResults,
                    ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    });
  }

  void _checkAnswer(String selected) {
    if (answered) return;
    final correct = shuffledSentences[currentIndex]['type'] == selected;
    setState(() {
      answered = true;
      if (correct) {
        correctCount++;
        feedback =
            selected == 'healthy'
                ? '정답! 불안을 직면하는 행동이에요.'
                : '정답! 불안을 회피하는 행동이에요.';
        feedbackColor = const Color(0xFF4CAF50); // 초록
      } else {
        feedback =
            selected == 'healthy'
                ? '불안을 직면하는 행동이라고 하셨군요. 하지만 이건 불안을 회피하는 행동쪽에 가깝습니다.'
                : '불안을 회피하는 행동이라고 하셨군요. 하지만 이건 불안을 직면하는 행동쪽에 가깝습니다.';
        feedbackColor = const Color(0xFFFF5252); // 빨강
      }
      // 결과 저장
      quizResults.add({
        'text': shuffledSentences[currentIndex]['text'],
        'correctType': shuffledSentences[currentIndex]['type'],
        'userChoice': selected,
        'isCorrect': correct,
      });
    });
  }

  Future<void> saveQuizResult(
    int correctCount,
    List<Map<String, dynamic>> quizResults,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // 전체 맞은 개수 저장
    await prefs.setInt('week5_classification_correct_count', correctCount);
    // 오답 문항만 추출
    final wrongList =
        quizResults
            .where((item) => item['isCorrect'] == false)
            .map(
              (item) => {
                'text': item['text'],
                'userChoice': item['userChoice'],
                'correctType': item['correctType'],
              },
            )
            .toList();
    await prefs.setString(
      'week5_classification_wrong_list',
      wrongList.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '5주차 - 불안 직면 VS 회피'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 카드
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Question icon above title
                        Image.asset(
                          'assets/image/question_icon.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '불안을 직면하는 행동과 회피하는 행동을\n구분해 볼까요?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // 퀴즈 문장
                        Text(
                          shuffledSentences[currentIndex]['text'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        Text(
                          '${currentIndex + 1}/${shuffledSentences.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 하단 카드
            Expanded(
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "화면에 보이는 생각이 어떠한 행동인지 선택한 후 '다음'버튼을 누르세요.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // 피드백 영역 (고정 높이)
                      SizedBox(
                        height: 56,
                        child:
                            feedback != null
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '💡',
                                      style: TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        feedback!,
                                        style: TextStyle(
                                          color: feedbackColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                                : Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3FE),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: const [
                                      Text(
                                        '💡',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '여기에서 정답을 확인할 수 있어요!',
                                          style: TextStyle(
                                            color: Color(0xFF8888AA),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 140,
                              child: ElevatedButton(
                                onPressed: () => _checkAnswer('healthy'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2962F6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '불안을 직면하는 행동',
                                  style: TextStyle(fontSize: 20),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 140,
                              child: ElevatedButton(
                                onPressed: () => _checkAnswer('anxious'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    226,
                                    86,
                                    86,
                                  ),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '불안을 회피하는 행동',
                                  style: TextStyle(fontSize: 20),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24), // new spacing
            // Removed Spacer to let cards expand directly above navigation buttons.
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext: () {
                if (answered) {
                  _nextSentence();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
