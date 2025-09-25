import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'week6_relieve_slider_screen.dart';
import 'week6_behavior_classification_screen.dart';

class Week6RelieveResultScreen extends StatefulWidget {
  final String selectedBehavior;
  final String behaviorType; // 'face' 또는 'avoid'
  final double sliderValue; // 슬라이더 값
  final bool isLongTerm; // 단기/장기 구분
  final double? shortTermValue; // 단기 슬라이더 값 (장기일 때만 사용)
  final List<String>? remainingBehaviors; // 남은 행동 목록
  final List<String> allBehaviorList; // 전체 행동 목록
  final List<Map<String, dynamic>>? mismatchedBehaviors; // 일치하지 않은 행동들

  const Week6RelieveResultScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    required this.sliderValue,
    this.isLongTerm = false, // 기본값은 단기
    this.shortTermValue, // 단기 슬라이더 값
    this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
  });

  @override
  State<Week6RelieveResultScreen> createState() =>
      _Week6RelieveResultScreenState();
}

class _Week6RelieveResultScreenState extends State<Week6RelieveResultScreen> {
  bool _showMainText = true;

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    String mainText;
    String subText;

    bool isHighRelief = widget.sliderValue == 10; // 10이면 완화됨, 0이면 완화되지 않음
    String timePeriod = widget.isLongTerm ? '장기' : '단기';

    if (widget.behaviorType == 'face') {
      if (isHighRelief) {
        mainText =
            '방금 보셨던 "${widget.selectedBehavior}"(이)라는 행동을 하게 되면\n$timePeriod적으로 불안이 많이 완화된다고 생각하시는군요.';
        subText =
            widget.isLongTerm
                ? '잘 따라오고 계십니다! 이제 위 행동이 어떤 유형에 속하는지 알아보겠습니다.'
                : '이번에는 위 행동이 장기적으로 얼마나 불안을 완화할 수 있는지 알아볼게요!';
      } else {
        mainText =
            '방금 보셨던 "${widget.selectedBehavior}"(이)라는 행동을 하게 되면\n$timePeriod적으로 불안이 적게 완화된다고 생각하시는군요.';
        subText =
            widget.isLongTerm
                ? '잘 따라오고 계십니다! 이제 위 행동이 어떤 유형에 속하는지 알아보겠습니다.'
                : '이번에는 위 행동이 장기적으로 얼마나 불안을 완화할 수 있는지 알아볼게요!';
      }
    } else {
      if (isHighRelief) {
        mainText =
            '방금 보셨던 "${widget.selectedBehavior}"(이)라는 행동을 하게 되면\n$timePeriod적으로 불안이 많이 완화된다고 생각하시는군요.';
        subText =
            widget.isLongTerm
                ? '잘 따라오고 계십니다! 이제 위 행동이 어떤 유형에 속하는지 알아보겠습니다.'
                : '이번에는 위 행동이 장기적으로 얼마나 불안을 완화할 수 있는지 알아볼게요!';
      } else {
        mainText =
            '방금 보셨던 "${widget.selectedBehavior}"(이)라는 행동을 하게 되면\n$timePeriod적으로 불안이 적게 완화된다고 생각하시는군요.';
        subText =
            widget.isLongTerm
                ? '잘 따라오고 계십니다! 이제 위 행동이 어떤 유형에 속하는지 알아보겠습니다.'
                : '이번에는 위 행동이 장기적으로 얼마나 불안을 완화할 수 있는지 알아볼게요!';
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
                      )
                    else
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
              if (widget.isLongTerm && widget.shortTermValue != null) {
                // 장기 결과에서 다음 버튼을 누르면 분류 결과 화면으로 이동
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week6BehaviorClassificationScreen(
                          selectedBehavior: widget.selectedBehavior,
                          behaviorType: widget.behaviorType,
                          shortTermValue: widget.shortTermValue!,
                          longTermValue: widget.sliderValue,
                          remainingBehaviors: widget.remainingBehaviors,
                          allBehaviorList: widget.allBehaviorList,
                          mismatchedBehaviors: widget.mismatchedBehaviors,
                        ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              } else {
                // 단기 결과에서 다음 버튼을 누르면 장기 슬라이더로 이동
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week6RelieveSliderScreen(
                          selectedBehavior: widget.selectedBehavior,
                          behaviorType: widget.behaviorType,
                          isLongTerm: true, // 장기 슬라이더로 이동
                          shortTermValue: widget.sliderValue, // 단기 값 전달
                          remainingBehaviors: widget.remainingBehaviors,
                          allBehaviorList: widget.allBehaviorList,
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
