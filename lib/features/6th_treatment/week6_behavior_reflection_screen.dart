import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'week6_classfication_screen.dart';
import 'week6_finish_quiz_screen.dart';

class Week6BehaviorReflectionScreen extends StatefulWidget {
  final String selectedBehavior;
  final String behaviorType; // 'face' 또는 'avoid'
  final double shortTermValue; // 단기 슬라이더 값
  final double longTermValue; // 장기 슬라이더 값
  final List<String>? remainingBehaviors; // 남은 행동 목록
  final List<String> allBehaviorList; // 전체 행동 목록
  final List<Map<String, dynamic>>? mismatchedBehaviors; // 일치하지 않은 행동들

  const Week6BehaviorReflectionScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    required this.shortTermValue,
    required this.longTermValue,
    this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
  });

  @override
  State<Week6BehaviorReflectionScreen> createState() =>
      _Week6BehaviorReflectionScreenState();
}

class _Week6BehaviorReflectionScreenState
    extends State<Week6BehaviorReflectionScreen> {
  bool _showMainText = true;
  late List<Map<String, dynamic>> _mismatchedBehaviors;

  @override
  void initState() {
    super.initState();
    _mismatchedBehaviors = List.from(widget.mismatchedBehaviors ?? []);

    // 현재 행동이 일치하지 않는지 확인
    bool isShortTermHigh = widget.shortTermValue == 10;
    bool isLongTermHigh = widget.longTermValue == 10;

    String actualResult;
    if (isShortTermHigh && !isLongTermHigh) {
      actualResult = '불안을 회피하는 행동';
    } else if (!isShortTermHigh && isLongTermHigh) {
      actualResult = '불안을 직면하는 행동';
    } else {
      actualResult = '중립적인 행동';
    }

    String userChoice =
        widget.behaviorType == 'face' ? '불안을 직면하는 행동' : '불안을 회피하는 행동';

    // 사용자 선택과 실제 결과가 다른 경우 일치하지 않은 행동 목록에 추가
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
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    // 분류 로직 (이전 화면과 동일)
    bool isShortTermHigh = widget.shortTermValue == 10;
    bool isLongTermHigh = widget.longTermValue == 10;

    // 실제 분석 결과 (슬라이더 값 기반)
    String actualResult;
    if (isShortTermHigh && !isLongTermHigh) {
      actualResult = '불안을 회피하는 행동';
    } else if (!isShortTermHigh && isLongTermHigh) {
      actualResult = '불안을 직면하는 행동';
    } else {
      actualResult = '중립적인 행동';
    }

    // 사용자가 선택한 분류
    String userChoice =
        widget.behaviorType == 'face' ? '불안을 직면하는 행동' : '불안을 회피하는 행동';

    String mainText;
    String subText;
    String? nextText;

    // 조건별 자연스러운 문장 (모든 조합 커버)
    if (widget.behaviorType == 'avoid' && isShortTermHigh && !isLongTermHigh) {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(라)는 행동에 대해 불안을 회피하는 행동이라고 선택하셨는데, 실제로 이 행동은 불안을 회피하는 쪽에 가까워 보이네요.';
    } else if (widget.behaviorType == 'avoid' &&
        !isShortTermHigh &&
        isLongTermHigh) {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(라)는 행동에 대해 불안을 회피하는 행동이라고 선택하셨지만, 실제로는 불안을 직면하는 쪽에 가까워 보이네요.';
    } else if (widget.behaviorType == 'face' &&
        !isShortTermHigh &&
        isLongTermHigh) {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(라)는 행동에 대해 불안을 직면하는 행동이라고 선택하셨는데, 실제로 이 행동은 불안을 직면하는 쪽에 가까워 보이네요.';
    } else if (widget.behaviorType == 'face' &&
        isShortTermHigh &&
        !isLongTermHigh) {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(라)는 행동에 대해 불안을 직면하는 행동이라고 선택하셨지만, 실제로는 불안을 회피하는 쪽에 가까워 보이네요.';
    } else if (isShortTermHigh && isLongTermHigh) {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(라)는 행동에 대해 불안을 ${userChoice}이라고 선택하셨네요.';
    } else {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(라)는 행동에 대해 불안을 ${userChoice}이라고 선택하셨네요.';
    }
    subText = '이 행동이 과연 나에게 도움이 되는지 다시 한번 더 생각해보아요!';

    // 추가 행동이 있는지 확인
    if (!_showMainText) {
      if (widget.remainingBehaviors != null &&
          widget.remainingBehaviors!.isNotEmpty) {
        nextText = '다음 행동도 계속 진행하겠습니다!';
      } else {
        nextText = '마지막 행동까지 완료했습니다! \n이제 마무리로 모든 행동들을 다시 한번 점검해볼까요?';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '6주차 - 불안 직면 VS 회피'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 48.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$userName님',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5B3EFF),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFF5B3EFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_showMainText)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            subText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      )
                    else ...[
                      if (nextText != null)
                        Text(
                          nextText!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            height: 1.5,
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.left,
                        ),
                    ],
                    const SizedBox(height: 48),
                  ],
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
            if (_showMainText) {
              setState(() => _showMainText = false);
            } else {
              if (widget.remainingBehaviors != null &&
                  widget.remainingBehaviors!.isNotEmpty) {
                // 추가 행동이 있으면 분류 화면으로 이동하여 루프 계속
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week6ClassificationScreen(
                          behaviorListInput: widget.remainingBehaviors!,
                          allBehaviorList: widget.allBehaviorList,
                        ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              } else {
                // 모든 행동을 다 처리했으면 Week6FinishQuizScreen으로 이동
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week6FinishQuizScreen(
                          mismatchedBehaviors: _mismatchedBehaviors,
                        ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
