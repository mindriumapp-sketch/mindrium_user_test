import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/6th_treatment/week6_classfication_screen.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

import 'package:gad_app_team/widgets/ruled_paragraph.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';

import 'week6_diary_utils.dart';
import 'week6_route_utils.dart';

class Week6ConcentrationScreen extends StatefulWidget {
  final List<String> behaviorListInput;
  final List<String> allBehaviorList;
  final String diaryId;
  final Map<String, dynamic> diary;

  const Week6ConcentrationScreen({
    super.key,
    required this.behaviorListInput,
    required this.allBehaviorList,
    required this.diaryId,
    required this.diary,
  });

  @override
  State<Week6ConcentrationScreen> createState() =>
      _Week6ConcentrationScreenState();
}

class _Week6ConcentrationScreenState extends State<Week6ConcentrationScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 10;

  void _startCountdown() {
    Future.doWhile(() async {
      if (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          _secondsLeft--;
        });
        return true;
      }

      if (!mounted) return false;
      setState(() {
        _isNextEnabled = true;
      });
      return false;
    });
  }

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    const double kRuleWidth = 220;
    final activation = Week6DiaryUtils.extractActivation(widget.diary);
    final firstBehavior = Week6DiaryUtils.firstBehavior(
      widget.diary,
      fallback: widget.behaviorListInput,
    );

    return ApplyDesign(
      appBarTitle: '불안 직면 VS 회피',
      cardTitle: '상황에 집중하기',
      onBack: () => Navigator.pop(context),
      rightLabel: '다음',
      onNext: () {
        if (!_isNextEnabled) {
          BlueBanner.show(context, '$_secondsLeft초 후에 다음 버튼이 활성화됩니다');
          return;
        }

        Navigator.push(
          context,
          buildWeek6NoAnimationRoute(
            Week6ClassificationScreen(
              behaviorListInput: widget.allBehaviorList,
              allBehaviorList: widget.allBehaviorList,
              diaryId: widget.diaryId,
              diary: widget.diary,
            ),
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
            text:
                activation.isNotEmpty && firstBehavior.isNotEmpty
                    ? '$userName님, "$activation"(이)라는 상황에서\n"$firstBehavior"(이)라고 행동을 하였습니다.\n\n그때의 상황에 집중해보세요.'
                    : '이때의 상황을 자세히 떠올려보세요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3C55),
              height: 1.6,
            ),
            lineColor: const Color(0xFFE1E8F0),
            lineThickness: 1.2,
            lineGapBelow: 8,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            lineWidth: kRuleWidth,
          ),
          const SizedBox(height: 16),
          if (!_isNextEnabled)
            Text(
              '$_secondsLeft초 후에 다음 버튼이 활성화됩니다',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9BA7B4),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
