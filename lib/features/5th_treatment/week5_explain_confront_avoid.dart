// lib/features/5th_treatment/week5_explain_confront_avoid.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/features/5th_treatment/week5_imagination.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class Week5ExplainConfrontAvoidScreen extends StatelessWidget {
  final String? sessionId;
  final List<Map<String, dynamic>> quizResults;
  final int correctCount;

  const Week5ExplainConfrontAvoidScreen({
    super.key,
    required this.sessionId,
    required this.quizResults,
    required this.correctCount,
  });

  // 강조 박스
  Widget highlightedText(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF59D).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Noto Sans KR',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainTextStyle = TextStyle(
      fontSize: 15.5,
      color: Colors.black87,
      fontWeight: FontWeight.w500,
      fontFamily: 'Noto Sans KR',
      height: 1.6,
    );

    return ApplyDesign(
      appBarTitle: '행동 구분 연습',
      cardTitle: '불안 직면과 회피 배우기',

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/image/question_icon.png',
                  width: 36,
                  height: 36,
                ),
                const SizedBox(height: 16),
                Text(
                  protectKoreanWords(
                    '불안을 직면하는 행동과 회피하는 행동의 차이를 먼저 배워 볼까요?',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Noto Sans KR',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          TextLine(
            '아래 예시를 읽어본 후, 내가 불안할 때 주로 어떤 행동을 하는지 떠올리고 적어보는 시간을 가질 거예요.',
            style: mainTextStyle,
          ),
          const SizedBox(height: 28),

          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '예를 들어, \n불안을 느낄 때 우리는 이런 두 가지 방식으로 반응할 수 있어요:\n\n',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                const TextSpan(
                  text: '① 불안을 ',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: highlightedText('직면하는 행동'),
                ),
                const TextSpan(
                  text: ': 불안이 있어도 그 상황에 조금씩 머물며 익숙해지고 대처할 수 있다는 경험을 쌓아가는 행동\n\n',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                const TextSpan(
                  text: '② 불안을 ',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: highlightedText('회피하는 행동'),
                ),
                const TextSpan(
                  text: ': 불안을 느끼지 않으려고 상황을 피하거나 빨리 벗어나려 하면서 오히려 불안이 더 오래 이어질 수 있는 행동',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            '예를 들어,',
            style: TextStyle(
              fontSize: 15.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            child: highlightedText("'불편한 모임을 계속 미루거나 빠진다'"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text: '\n→ 불안을 회피하는 행동\n\n',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            child: highlightedText("'부담스러운 모임에 조금씩 참석해본다'"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text: '\n→ 불안을 직면하는 행동\n\n',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
                const TextSpan(
                  text: '처음에는 직면이 더 어렵게 느껴질 수 있지만, 이런 연습이 쌓이면 불안을 견디는 힘을 키우는 데 도움이 될 수 있어요.\n',
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Noto Sans KR',
                  ),
                ),
              ],
              style: const TextStyle(
                fontSize: 15.5,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
          Center(
            child: Text(
              protectKoreanWords(
                '\n이제 위의 예시를 참고해서\n당신이 불안할 때 하는 행동을 적어볼까요?',
              ),
              style: const TextStyle(
                fontSize: 15.5,
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
                fontFamily: 'Noto Sans KR',
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),

      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week5ImaginationScreen(
              sessionId: sessionId,
              quizResults: quizResults,
              correctCount: correctCount,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
