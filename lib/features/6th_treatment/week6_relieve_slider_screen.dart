import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'week6_relieve_result_screen.dart';

class Week6RelieveSliderScreen extends StatefulWidget {
  final String selectedBehavior;
  final String behaviorType; // 'face' 또는 'avoid'
  final bool isLongTerm; // 단기/장기 구분
  final double? shortTermValue; // 단기 슬라이더 값 (장기일 때만 사용)
  final List<String>? remainingBehaviors; // 남은 행동 목록
  final List<String> allBehaviorList; // 전체 행동 목록
  final List<Map<String, dynamic>>? mismatchedBehaviors; // 일치하지 않은 행동들

  const Week6RelieveSliderScreen({
    super.key,
    required this.selectedBehavior,
    required this.behaviorType,
    this.isLongTerm = false, // 기본값은 단기
    this.shortTermValue, // 단기 슬라이더 값
    this.remainingBehaviors,
    required this.allBehaviorList,
    this.mismatchedBehaviors,
  });

  @override
  State<Week6RelieveSliderScreen> createState() =>
      _Week6RelieveSliderScreenState();
}

class _Week6RelieveSliderScreenState extends State<Week6RelieveSliderScreen> {
  // double _sliderValue = 5.0; // 슬라이더 제거
  int? _selectedValue; // 0: 완화되지 않음, 10: 완화됨

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '6주차 - 불안 직면 VS 회피'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 카드
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/image/question_icon.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$userName님께서 걱정일기에 작성해주신 행동을 보며 진행해주세요.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.selectedBehavior,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 하단 카드
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.isLongTerm
                              ? '위 행동을 하신다면 장기적으로 불안이 완화될 것 같으신가요? 아래 버튼 중 하나를 선택하고 다음을 눌러주세요.'
                              : '위 행동을 하신다면 단기적으로 불안이 완화될 것 같으신가요? 아래 버튼 중 하나를 선택하고 다음을 눌러주세요.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _selectedValue = 0);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _selectedValue == 0
                                          ? const Color(0xFFFF5252)
                                          : Colors.white,
                                  foregroundColor:
                                      _selectedValue == 0
                                          ? Colors.white
                                          : const Color(0xFFFF5252),
                                  side: const BorderSide(
                                    color: Color(0xFFFF5252),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                                child: const Text(
                                  '불안이 완화되지 않음',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _selectedValue = 10);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _selectedValue == 10
                                          ? const Color(0xFF4CAF50)
                                          : Colors.white,
                                  foregroundColor:
                                      _selectedValue == 10
                                          ? Colors.white
                                          : const Color(0xFF4CAF50),
                                  side: const BorderSide(
                                    color: Color(0xFF4CAF50),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                                child: const Text(
                                  '불안이 완화됨',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        if (_selectedValue != null)
                          Text(
                            _selectedValue == 0
                                ? '불안이 완화되지 않음으로 선택하셨습니다.'
                                : '불안이 완화됨으로 선택하셨습니다.',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            NavigationButtons(
              onBack: () => Navigator.pop(context),
              onNext:
                  _selectedValue != null
                      ? () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (_, __, ___) => Week6RelieveResultScreen(
                                  selectedBehavior: widget.selectedBehavior,
                                  behaviorType: widget.behaviorType,
                                  sliderValue: _selectedValue!.toDouble(),
                                  isLongTerm: widget.isLongTerm,
                                  shortTermValue: widget.shortTermValue,
                                  remainingBehaviors: widget.remainingBehaviors,
                                  allBehaviorList: widget.allBehaviorList,
                                  mismatchedBehaviors:
                                      widget.mismatchedBehaviors,
                                ),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
