import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/data/user_provider.dart'; // 추가
import 'week3_alternative_thoughts.dart';

class Week3ExplainAlternativeThoughtsScreen extends StatelessWidget {
  final List<String> chips;
  const Week3ExplainAlternativeThoughtsScreen({super.key, required this.chips});

  Widget highlightedText(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF59D).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '3주차 - Self Talk'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.7, // 카드 최대 높이 제한
              maxWidth: 500,
            ),
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/image/question_icon.png',
                              width: 32,
                              height: 32,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '추가로 작성하신 불안한 상황을 보면서\n대체 생각이 무엇인지 배워 볼까요?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "$userName님은 "),
                            if (chips.isNotEmpty)
                              ...chips.map(
                                (e) => WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: 4.0,
                                      bottom: 2.0,
                                    ),
                                    child: highlightedText("'$e'"),
                                  ),
                                ),
                              ),
                            TextSpan(
                              text:
                                  "(이)라는 일이 일어날 것 같다고 상상했습니다.\n이제 이런 불안한 생각을 조금 더 도움이 되는 생각으로 바꿔볼 수 있을까요?",
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 교육 예시 안내
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "예를 들어, 이런 불안한 생각이 있을 수 있어요:\n",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 4.0),
                                child: highlightedText(
                                  "'말을 버벅거려서 회의를 망칠 것 같다.'",
                                ),
                              ),
                            ),
                            TextSpan(
                              text:
                                  "\n\n위 예시 생각에 대해 아래와 같이 다양한 도움이 되는 생각(대체 생각)이 있습니다.\n\n",
                            ),
                            TextSpan(
                              text: "① 반박(Refutation): ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            TextSpan(text: "“말을 버벅거려도 회의를 망치지는 않을 것이다”\n"),
                            TextSpan(
                              text: "② 리프레임(Reframe): ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            TextSpan(text: "“중요한 발표이기 때문에 긴장되는 것은 당연하다”\n"),
                            TextSpan(
                              text: "③ 코핑(Coping): ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            TextSpan(text: "“버벅거려도 다시 이어갈 수 있다”\n"),
                            TextSpan(
                              text: "\n이제 위에 제시된 방법을 참고해서 도움이 되는 생각을 적어볼까요?",
                              style: TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: NavigationButtons(
          onBack: () => Navigator.pop(context),
          onNext: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (_, __, ___) => Week3AlternativeThoughtsScreen(
                      previousChips: chips, // chips는 이전 화면에서 전달받은 불안한 생각 리스트
                    ),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        ),
      ),
    );
  }
}
