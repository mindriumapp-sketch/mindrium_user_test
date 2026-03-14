import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/features/4th_treatment/week4_after_agreement_screen.dart';
import 'package:gad_app_team/widgets/ruled_paragraph.dart'; // ✅ 추가

class Week4AlternativeThoughtsDisplayScreen extends StatefulWidget {
  final List<String> alternativeThoughts;
  final String previousB;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String>? existingAlternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final String? abcId;
  final int loopCount;

  const Week4AlternativeThoughtsDisplayScreen({
    super.key,
    required this.alternativeThoughts,
    required this.previousB,
    required this.remainingBList,
    required this.allBList,
    this.existingAlternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4AlternativeThoughtsDisplayScreen> createState() =>
      _Week4AlternativeThoughtsDisplayScreenState();
}

class _Week4AlternativeThoughtsDisplayScreenState
    extends State<Week4AlternativeThoughtsDisplayScreen> {
  List<String> _removeDuplicates(List<String> list) {
    final uniqueList = <String>[];
    for (final item in list) {
      if (!uniqueList.contains(item)) {
        uniqueList.add(item);
      }
    }
    return uniqueList;
  }

  @override
  Widget build(BuildContext context) {
    final hasAlt = widget.alternativeThoughts.isNotEmpty;

    final mainText =
        hasAlt
            ? "'${widget.previousB}' 생각에 대해 \n'${widget.alternativeThoughts.join(', ')}'(이)라는 도움이 되는 생각을 작성해주셨네요. \n\n잘 진행해주시고 계십니다!"
            : "'${widget.previousB}' 생각에 대한 도움이 되는 생각들을 확인해보세요.";

    // BlueWhiteCard에서 쓰던 줄 길이와 비슷하게
    const double kRuleWidth = 220;

    return ApplyDesign(
      appBarTitle: '인지 왜곡 찾기',
      cardTitle: '도움이 되는 생각 점검',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => Week4AfterAgreementScreen(
                  previousB: widget.previousB,
                  remainingBList: widget.remainingBList,
                  allBList: widget.allBList,
                  alternativeThoughts: _removeDuplicates([
                    ...?widget.existingAlternativeThoughts,
                    ...widget.alternativeThoughts,
                  ]),
                  isFromAnxietyScreen: widget.isFromAnxietyScreen,
                  originalBList: widget.originalBList,
                  existingAlternativeThoughts: _removeDuplicates([
                    ...?widget.existingAlternativeThoughts,
                    ...widget.alternativeThoughts,
                  ]),
                  abcId: widget.abcId,
                  loopCount: widget.loopCount,
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Image.asset(
            'assets/image/think_blue.png',
            height: 160,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 20),

          RuledParagraph(
            text: mainText,
            textAlign: TextAlign.center,
            lineWidth: kRuleWidth,
            lineColor: const Color(0xFFE1E8F0),
            lineThickness: 1.2,
            lineGapBelow: 8,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              height: 1.8,
              wordSpacing: 0.8,
              fontFamily: 'Noto Sans KR',
            ),
          ),
        ],
      ),
    );
  }
}
