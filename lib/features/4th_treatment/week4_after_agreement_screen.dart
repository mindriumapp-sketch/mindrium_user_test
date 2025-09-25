import 'package:flutter/material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'week4_after_sud_screen.dart';
import 'week4_next_thought_screen.dart';

class Week4AfterAgreementScreen extends StatefulWidget {
  final String previousB;
  final int beforeSud;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String> alternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final List<String>? existingAlternativeThoughts;
  final String? abcId;
  final int loopCount;

  const Week4AfterAgreementScreen({
    super.key,
    required this.previousB,
    required this.beforeSud,
    required this.remainingBList,
    required this.allBList,
    required this.alternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.existingAlternativeThoughts,
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4AfterAgreementScreen> createState() =>
      _Week4AfterAgreementScreenState();
}

class _Week4AfterAgreementScreenState extends State<Week4AfterAgreementScreen> {
  double _sliderValue = 5.0;
  late String _currentB;

  @override
  void initState() {
    super.initState();
    _currentB = widget.previousB;
  }

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
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
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
                        // Image.asset(
                        //   'assets/image/question_icon.png',
                        //   width: 32,
                        //   height: 32,
                        // ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final userName =
                                Provider.of<UserProvider>(
                                  context,
                                  listen: false,
                                ).userName;
                            return Text(
                              '$userName님께서 걱정일기에 작성하신 생각을 보며 진행해주세요.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          (_currentB.isNotEmpty) ? _currentB : '생각이 없습니다.',
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
                        const Text(
                          '도움이 되는 생각을 찾아본 후, 지금은 위 생각에 대해 얼마나 강하게 믿고 계십니까?\n아래 슬라이더를 조정하고 다음을 눌러주세요.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Slider(
                          value: _sliderValue,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: _sliderValue.round().toString(),
                          activeColor: Color.lerp(
                            Color(0xFF4CAF50),
                            Color(0xFFFF5252),
                            _sliderValue / 10,
                          ),
                          inactiveColor: Colors.grey[300],
                          onChanged: (v) => setState(() => _sliderValue = v),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_sliderValue.round()}점',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0점: 전혀 믿지 않음',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '10점: 매우 믿음',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFFF5252),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
              onNext: () {
                // 모든 B를 다룬 경우 → abcId 유무에 따라 분기
                if (widget.remainingBList.isEmpty) {
                  if (widget.abcId != null && widget.abcId!.isNotEmpty) {
                    // ① abcId가 있으면: named route '/after_sud'로 이동 (abcId 전달)
                    Navigator.pushNamed(
                      context,
                      '/after_sud',
                      arguments: {'abcId': widget.abcId},
                    );
                  } else {
                    // ② abcId가 없으면: 기존 로직(Week4AfterSudScreen)으로 이동
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder:
                            (_, __, ___) => Week4AfterSudScreen(
                              beforeSud: widget.beforeSud,
                              currentB: _currentB,
                              remainingBList: widget.remainingBList,
                              allBList: widget.allBList,
                              alternativeThoughts: _removeDuplicates([
                                ...?widget.existingAlternativeThoughts,
                                ...widget.alternativeThoughts,
                              ]),
                              isFromAnxietyScreen: widget.isFromAnxietyScreen,
                              originalBList: widget.originalBList,
                              loopCount: widget.loopCount, // 반드시 전달
                            ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                } else {
                  // 남은 B가 있으면 다음 B로 진행
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder:
                          (_, __, ___) => Week4NextThoughtScreen(
                            remainingBList: widget.remainingBList,
                            beforeSud: widget.beforeSud,
                            allBList: widget.allBList,
                            alternativeThoughts: _removeDuplicates([
                              ...?widget.existingAlternativeThoughts,
                              ...widget.alternativeThoughts,
                            ]),
                            isFromAnxietyScreen: widget.isFromAnxietyScreen,
                            addedAnxietyThoughts: const [],
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
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
