import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/features/6th_treatment/week6_classfication_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_flow_widgets.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';

import 'week6_diary_utils.dart';
import 'week6_route_utils.dart';

class Week6NextBehaviorScreen extends StatelessWidget {
  final List<String> remainingBehaviors;
  final List<String> allBehaviorList;
  final List<Map<String, dynamic>>? mismatchedBehaviors;
  final String diaryId;
  final Map<String, dynamic> diary;

  const Week6NextBehaviorScreen({
    super.key,
    required this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
    required this.diaryId,
    required this.diary,
  });

  @override
  Widget build(BuildContext context) {
    final nextBehavior =
        remainingBehaviors.isNotEmpty ? remainingBehaviors.first : '';
    final nextBehaviorIndex =
        allBehaviorList.length - remainingBehaviors.length + 1;
    final activation = Week6DiaryUtils.extractActivation(diary);

    return ApplyDesign(
      appBarTitle: '행동 구분 연습',
      cardTitle: '다음 행동 이어가기',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.pushReplacement(
          context,
          buildWeek6NoAnimationRoute(
            Week6ClassificationScreen(
              behaviorListInput: remainingBehaviors,
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
          Week6ProgressHeader(
            stageLabel: '다음 행동 안내',
            currentIndex: nextBehaviorIndex,
            totalCount: allBehaviorList.length,
            title: '같은 상황의 다음 행동으로 이어갈게요',
            subtitle:
                '방금 살펴본 행동과는 별개로, 같은 상황 안에서 또 다른 반응이 어떻게 나타났는지 차례대로 확인합니다.',
          ),
          const SizedBox(height: 18),
          Week6InfoCard(
            title: '같은 상황 유지하기',
            subtitle: '상황은 그대로 두고, 행동만 바꿔서 살펴보면 더 이해하기 쉬워요.',
            icon: Icons.landscape_outlined,
            child: Text(
              activation.isNotEmpty ? activation : '이때의 상황을 떠올려보세요.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Color(0xFF355676),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Week6InfoCard(
            title: '이어서 볼 다음 행동',
            subtitle: '이제 이 행동을 같은 방식으로 분류하고 평가해볼게요.',
            icon: Icons.trending_flat_rounded,
            child: Text(
              nextBehavior,
              style: const TextStyle(
                fontSize: 17,
                height: 1.55,
                color: Color(0xFF26425F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
