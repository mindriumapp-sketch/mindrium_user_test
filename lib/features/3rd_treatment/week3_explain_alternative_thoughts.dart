// lib/features/3rd_treatment/week3_explain_alternative_thoughts.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart'; // <-- ApplyDesign
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_alternative_thoughts.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';

class Week3ExplainAlternativeThoughtsScreen extends StatelessWidget {
  final String? sessionId;
  final List<String> chips;

  const Week3ExplainAlternativeThoughtsScreen({
    super.key,
    required this.sessionId,
    required this.chips,
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
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    const mainTextStyle = TextStyle(
      fontSize: 15.5,
      color: Colors.black87,
      fontWeight: FontWeight.w500,
      fontFamily: 'Noto Sans KR',
      height: 1.6,
    );

    /// ApplyDesign 이 전체 레이아웃(배경/앱바/카드/네비)을 처리
    return ApplyDesign(
      appBarTitle: 'Self Talk',
      cardTitle: '대체 생각 배우기',

      // 카드 내부 실제 콘텐츠
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🎓 상단 설명 아이콘 + 문구
          Center(
            child: Column(
              children: [
                Image.asset('assets/image/question_icon.png', width: 36, height: 36),
                const SizedBox(height: 16),
                Text(
                  protectKoreanWords('추가로 작성하신 불안한 상황을 보면서 대체 생각이 무엇인지 배워 볼까요?'),
                  style: TextStyle(
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

          /// 🧠 사용자 입력 강조 문장
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              if (chips.isEmpty)
                TextLine(
                  "$userName님은 (이)라는 일이 일어날 것 같다고 상상했습니다.\n이제 이런 불안한 생각을 조금 더 도움이 되는 생각으로 바꿔볼 수 있을까요?",
                  style: mainTextStyle,
                )
              else ...[
                TextLine.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$userName님은 '),
                      ...chips.map(
                        (e) => WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(right: 4.0, bottom: 2.0),
                            child: highlightedText("'$e'"),
                          ),
                        ),
                      ),
                      const TextSpan(
                        text:
                            " (이)라는 일이 일어날 것 같다고 상상했습니다.\n이제 이런 불안한 생각을 조금 더 도움이 되는 생각으로 바꿔볼 수 있을까요?",
                      ),
                    ],
                    style: mainTextStyle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),

          /// 💬 교육 예시 안내
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: "예를 들어, \n이런 불안한 생각이 있을 수 있어요:\n\n",
                  style: TextStyle(
                    fontSize: 15.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
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
                            child: highlightedText("'말을 버벅거려서 회의를 망칠 것 같다.'"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text: "\n\n이 생각에 대해 다양한 '도움이 되는 생각(대체 생각)'이 있습니다.\n\n",
                ),
                const TextSpan(
                  text: "① 반박 (Refutation): ",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const TextSpan(text: "“말을 버벅거려도 회의를 망치지는 않을 것이다”\n"),
                const TextSpan(
                  text: "② 리프레임 (Reframe): ",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const TextSpan(text: "“중요한 발표이기 때문에 긴장되는 것은 당연하다”\n"),
                const TextSpan(
                  text: "③ 코핑 (Coping): ",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const TextSpan(text: "“버벅거려도 다시 이어갈 수 있다”\n"),
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
              protectKoreanWords("\n이제 위의 예시를 참고해서\n당신만의 대체 생각을 적어볼까요?"),
              style: TextStyle(
                fontSize: 15.5,
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
                fontFamily: 'Noto Sans KR',
                height: 1.6,
              ),
            ),
          )
        ],
      ),

      // 하단 네비게이션
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week3AlternativeThoughtsScreen(
              sessionId: sessionId,
              previousChips: chips,
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
