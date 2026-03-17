import 'package:gad_app_team/utils/text_line_material.dart';

import 'package:gad_app_team/widgets/tutorial_design.dart';

import 'package:gad_app_team/features/6th_treatment/week6_finish_quiz_screen.dart';
import 'package:gad_app_team/features/6th_treatment/week6_flow_widgets.dart';
import 'package:gad_app_team/features/6th_treatment/week6_next_behavior_screen.dart';

import 'week6_behavior_analysis.dart';
import 'week6_route_utils.dart';

class Week6BehaviorReflectionScreen extends StatefulWidget {
  final String selectedBehavior;
  final String behaviorType;
  final double shortTermValue;
  final double longTermValue;
  final List<String>? remainingBehaviors;
  final List<String> allBehaviorList;
  final List<Map<String, dynamic>>? mismatchedBehaviors;
  final String diaryId;
  final Map<String, dynamic> diary;

  const Week6BehaviorReflectionScreen({
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
  State<Week6BehaviorReflectionScreen> createState() =>
      _Week6BehaviorReflectionScreenState();
}

class _Week6BehaviorReflectionScreenState
    extends State<Week6BehaviorReflectionScreen> {
  late final List<Map<String, dynamic>> _mismatchedBehaviors;

  @override
  void initState() {
    super.initState();
    _mismatchedBehaviors = List.from(widget.mismatchedBehaviors ?? []);

    final actualResult = Week6BehaviorAnalysis.reflectionResultLabel(
      shortTermValue: widget.shortTermValue,
      longTermValue: widget.longTermValue,
    );
    final userChoice = Week6BehaviorAnalysis.userChoiceLabel(
      widget.behaviorType,
    );

    if (userChoice != actualResult) {
      _mismatchedBehaviors.insert(0, {
        'behavior': widget.selectedBehavior,
        'userChoice': userChoice,
        'actualResult': actualResult,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRemainingBehaviors =
        widget.remainingBehaviors != null &&
        widget.remainingBehaviors!.isNotEmpty;
    final currentBehaviorIndex =
        widget.allBehaviorList.length -
        (widget.remainingBehaviors?.length ?? 0);
    final userChoice = Week6BehaviorAnalysis.userChoiceLabel(
      widget.behaviorType,
    );
    final actualResult = Week6BehaviorAnalysis.reflectionResultLabel(
      shortTermValue: widget.shortTermValue,
      longTermValue: widget.longTermValue,
    );
    final isMatch = Week6BehaviorAnalysis.isReflectionMatch(
      behaviorType: widget.behaviorType,
      actualResultLabel: actualResult,
    );

    final message =
        isMatch
            ? '내가 느낀 방향과 실제 해석이 비슷했어요. 이 행동을 보는 기준이 조금씩 잡혀가고 있어요.'
            : '내 선택과 실제 해석 사이에 차이가 있었어요. 왜 다르게 느껴졌는지 한 번 더 돌아보면 도움이 됩니다.';

    return ApplyDesign(
      appBarTitle: '불안 직면 VS 회피',
      cardTitle: '행동 돌아보기',
      onBack: () => Navigator.pop(context),
      onNext: () {
        if (hasRemainingBehaviors) {
          Navigator.pushReplacement(
            context,
            buildWeek6NoAnimationRoute(
              Week6NextBehaviorScreen(
                remainingBehaviors: widget.remainingBehaviors!,
                allBehaviorList: widget.allBehaviorList,
                mismatchedBehaviors: _mismatchedBehaviors,
                diaryId: widget.diaryId,
                diary: widget.diary,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            buildWeek6NoAnimationRoute(
              Week6FinishQuizScreen(
                mismatchedBehaviors: _mismatchedBehaviors,
                diaryId: widget.diaryId,
                diary: widget.diary,
              ),
            ),
          );
        }
      },
      rightLabel: '다음',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Week6ProgressHeader(
            stageLabel: '행동 돌아보기',
            currentIndex: currentBehaviorIndex,
            totalCount: widget.allBehaviorList.length,
            title: '내가 왜 이렇게 느꼈는지 정리해볼게요',
            subtitle: '지금 행동을 보며 내가 내린 해석과, 다시 살펴본 해석을 한눈에 비교할 수 있어요.',
          ),
          const SizedBox(height: 18),
          Week6InfoCard(
            title: '지금 살펴본 행동',
            subtitle: widget.selectedBehavior,
            icon: Icons.visibility_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Week6StatusPill(
                      label: '내 선택: $userChoice',
                      backgroundColor:
                          widget.behaviorType == 'face'
                              ? const Color(0xFFE8F7F1)
                              : const Color(0xFFFFF0EF),
                      foregroundColor:
                          widget.behaviorType == 'face'
                              ? const Color(0xFF2E7D5B)
                              : const Color(0xFFC6544F),
                    ),
                    Week6StatusPill(
                      label: '다시 보면: $actualResult',
                      backgroundColor:
                          isMatch
                              ? const Color(0xFFE8F3FF)
                              : const Color(0xFFFFF8E7),
                      foregroundColor:
                          isMatch
                              ? const Color(0xFF2C6AA0)
                              : const Color(0xFF9A6B00),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xFF355676),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Week6InfoCard(
            title: '다음으로 이어집니다',
            icon:
                hasRemainingBehaviors
                    ? Icons.arrow_forward_rounded
                    : Icons.fact_check_outlined,
            child: Week6BulletList(
              items:
                  hasRemainingBehaviors
                      ? [
                        '같은 상황에서 이어지는 다음 행동을 살펴볼게요.',
                        '남은 행동도 같은 방식으로 하나씩 정리하면 됩니다.',
                      ]
                      : [
                        '이제 지금까지 본 행동을 한 번 더 빠르게 정리해볼게요.',
                        '마지막 점검을 마치면 회피/직면 행동을 한눈에 볼 수 있어요.',
                      ],
            ),
          ),
        ],
      ),
    );
  }
}
