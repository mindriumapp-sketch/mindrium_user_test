import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/widgets/tutorial_design.dart';

import 'week6_flow_widgets.dart';
import 'week6_route_utils.dart';
import 'week6_relieve_slider_screen.dart';

class Week6NextRelieveScreen extends StatelessWidget {
  final String selectedBehavior;
  final String behaviorType;
  final double sliderValue;
  final List<String>? remainingBehaviors;
  final List<String> allBehaviorList;
  final String diaryId;
  final Map<String, dynamic> diary;
  final List<Map<String, dynamic>>? mismatchedBehaviors;

  const Week6NextRelieveScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    required this.sliderValue,
    this.remainingBehaviors,
    required this.allBehaviorList,
    required this.diaryId,
    required this.diary,
    this.mismatchedBehaviors,
  });

  @override
  Widget build(BuildContext context) {
    final choiceLabel =
        behaviorType == 'face' ? '직면하는 행동으로 분류했어요' : '회피하는 행동으로 분류했어요';
    final choiceColor =
        behaviorType == 'face'
            ? const Color(0xFFE8F7F1)
            : const Color(0xFFFFF0EF);
    final choiceTextColor =
        behaviorType == 'face'
            ? const Color(0xFF2E7D5B)
            : const Color(0xFFC6544F);

    return ApplyDesign(
      appBarTitle: '불안 직면 VS 회피',
      cardTitle: '불안 완화 단계',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          buildWeek6NoAnimationRoute(
            Week6RelieveSliderScreen(
              selectedBehavior: selectedBehavior,
              behaviorType: behaviorType,
              remainingBehaviors: remainingBehaviors,
              allBehaviorList: allBehaviorList,
              diaryId: diaryId,
              diary: diary,
              mismatchedBehaviors: mismatchedBehaviors,
            ),
          ),
        );
      },
      rightLabel: '다음',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Week6InfoCard(
            title: '지금 보고 있는 행동',
            subtitle: '다음 두 단계에서는 이 행동만 기준으로 판단해요.',
            icon: Icons.psychology_alt_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Week6StatusPill(
                  label: choiceLabel,
                  backgroundColor: choiceColor,
                  foregroundColor: choiceTextColor,
                ),
                const SizedBox(height: 12),
                Text(
                  selectedBehavior,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.55,
                    color: Color(0xFF26425F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Week6InfoCard(
            title: '이어서 하게 될 일',
            subtitle: '한 번에 하나씩만 답하면 돼요.',
            icon: Icons.route_rounded,
            child: Week6BulletList(
              items: [
                '먼저 단기적으로 얼마나 불안이 줄어드는지 살펴봐요.',
                '그다음 장기적으로 도움이 되는지도 이어서 볼게요.',
              ],
            ),
          ),
        ],
      ),
    );
  }
}
