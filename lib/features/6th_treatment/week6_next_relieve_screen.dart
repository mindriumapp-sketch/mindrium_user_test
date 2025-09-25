import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'week6_relieve_slider_screen.dart';

class Week6NextRelieveScreen extends StatefulWidget {
  final String selectedBehavior;
  final String behaviorType; // 'face' 또는 'avoid'
  final double sliderValue; // 슬라이더 값 추가
  final List<String>? remainingBehaviors; // 남은 행동 목록
  final List<String> allBehaviorList; // 전체 행동 목록

  const Week6NextRelieveScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    required this.sliderValue,
    this.remainingBehaviors,
    required this.allBehaviorList,
  });

  @override
  State<Week6NextRelieveScreen> createState() => _Week6NextRelieveScreenState();
}

class _Week6NextRelieveScreenState extends State<Week6NextRelieveScreen> {
  bool _showMainText = true;

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    String mainText;
    String subText;

    if (widget.behaviorType == 'face') {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(이)라는 행동을 불안을 직면하는 행동이라고 선택하셨네요.';
      subText = '불안을 직면하는 행동이라고 생각을 해봤을 때 단기적으로 얼마나 불안을 완화할 수 있는지 알아볼게요!';
    } else {
      mainText =
          '방금 보셨던 "${widget.selectedBehavior}"(이)라는 행동을 불안을 회피하는 행동이라고 선택하셨네요.';
      subText = '불안을 회피하는 행동이라고 생각을 해봤을 때 단기적으로 얼마나 불안을 완화할 수 있는지 알아볼게요!';
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
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (_, __, ___) => Week6RelieveSliderScreen(
                        selectedBehavior: widget.selectedBehavior,
                        behaviorType: widget.behaviorType,
                        remainingBehaviors: widget.remainingBehaviors,
                        allBehaviorList: widget.allBehaviorList,
                      ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
