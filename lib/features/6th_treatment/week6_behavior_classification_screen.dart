import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/widgets/tutorial_design.dart';

import 'package:gad_app_team/features/6th_treatment/week6_behavior_reflection_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_flow_widgets.dart';

import 'week6_behavior_analysis.dart';
import 'week6_route_utils.dart';

class Week6BehaviorClassificationScreen extends StatelessWidget {
  final String selectedBehavior;
  final String behaviorType;
  final double shortTermValue;
  final double longTermValue;
  final List<String>? remainingBehaviors;
  final List<String> allBehaviorList;
  final List<Map<String, dynamic>>? mismatchedBehaviors;
  final String diaryId;
  final Map<String, dynamic> diary;

  const Week6BehaviorClassificationScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    required this.shortTermValue,
    required this.longTermValue,
    this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
    required this.diaryId,
    required this.diary,
  });

  @override
  Widget build(BuildContext context) {
    final currentBehaviorIndex =
        allBehaviorList.length - (remainingBehaviors?.length ?? 0);
    final insight = Week6BehaviorAnalysis.buildInsight(
      shortTermValue: shortTermValue,
      longTermValue: longTermValue,
    );

    return ApplyDesign(
      appBarTitle: '행동 구분 연습',
      cardTitle: '행동 분류 결과',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          buildWeek6NoAnimationRoute(
            Week6BehaviorReflectionScreen(
              selectedBehavior: selectedBehavior,
              behaviorType: behaviorType,
              shortTermValue: shortTermValue,
              longTermValue: longTermValue,
              remainingBehaviors: remainingBehaviors,
              allBehaviorList: allBehaviorList,
              mismatchedBehaviors: mismatchedBehaviors,
              diaryId: diaryId,
              diary: diary,
            ),
          ),
        );
      },
      rightLabel: '다음',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Week6ProgressHeader(
            stageLabel: '행동 해석',
            currentIndex: currentBehaviorIndex,
            totalCount: allBehaviorList.length,
            title: '이 행동은 이렇게 볼 수 있어요',
            subtitle: '단기/장기 평가를 바탕으로 이 행동이 불안에 어떤 영향을 주는지 간단히 정리했습니다.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Week6StatusPill(
                label: behaviorType == 'face' ? '내 선택: 직면' : '내 선택: 회피',
                backgroundColor:
                    behaviorType == 'face'
                        ? const Color(0xFFE8F7F1)
                        : const Color(0xFFFFF0EF),
                foregroundColor:
                    behaviorType == 'face'
                        ? const Color(0xFF2E7D5B)
                        : const Color(0xFFC6544F),
              ),
              Week6StatusPill(
                label: insight.resultLabel,
                backgroundColor: insight.resultBackground,
                foregroundColor: insight.resultForeground,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Week6InfoCard(
            title: '한 줄 요약',
            subtitle: selectedBehavior,
            icon: Icons.lightbulb_outline_rounded,
            child: Text(
              insight.summary,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF26425F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Week6InfoCard(
            title: '단기적으로는',
            icon: Icons.flash_on_rounded,
            child: Text(
              insight.shortTermInsight,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF355676),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Week6InfoCard(
            title: '장기적으로는',
            icon: Icons.timelapse_rounded,
            child: Text(
              insight.longTermInsight,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF355676),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Week6InfoCard(
            title: '이때 기억하면 좋아요',
            icon: Icons.bookmark_added_outlined,
            child: Week6BulletList(items: insight.reminders),
          ),
        ],
      ),
    );
  }
}
