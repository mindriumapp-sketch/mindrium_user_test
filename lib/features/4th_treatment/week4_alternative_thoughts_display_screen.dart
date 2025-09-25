import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/features/4th_treatment/week4_after_agreement_screen.dart';

class Week4AlternativeThoughtsDisplayScreen extends StatefulWidget {
  final List<String> alternativeThoughts;
  final String previousB;
  final int beforeSud;
  final List<String> remainingBList;
  final List<String> allBList;
  final List<String>? existingAlternativeThoughts;
  final bool isFromAnxietyScreen;
  final List<String> originalBList;
  final String? abcId;
  final int loopCount;

  const Week4AlternativeThoughtsDisplayScreen({
    super.key,
    required this.alternativeThoughts,
    required this.previousB,
    required this.beforeSud,
    required this.remainingBList,
    required this.allBList,
    this.existingAlternativeThoughts,
    this.isFromAnxietyScreen = false,
    this.originalBList = const [],
    this.abcId,
    this.loopCount = 1,
  });

  @override
  State<Week4AlternativeThoughtsDisplayScreen> createState() =>
      _Week4AlternativeThoughtsDisplayScreenState();
}

class _Week4AlternativeThoughtsDisplayScreenState
    extends State<Week4AlternativeThoughtsDisplayScreen> {
  bool _isNextEnabled = false;
  int _secondsLeft = 5;
  bool _showMainText = true; // 검정 안내문 먼저, 이후 보라 안내문

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
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      if (_secondsLeft > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return false;
        setState(() {
          _secondsLeft--;
        });
        return true;
      } else {
        setState(() {
          _isNextEnabled = true;
        });
        return false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final hasAlt = widget.alternativeThoughts.isNotEmpty;
    final mainText =
        hasAlt
            ? "'${widget.previousB}' 생각에 대해 '${widget.alternativeThoughts.join(', ')} '(이)라는 도움이 되는 생각을 작성해주셨네요. 잘 진행해주시고 계십니다!"
            : "'${widget.previousB}' 생각에 대한\n도움이 되는 생각들을 확인해보세요.";
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      appBar: const CustomAppBar(title: '4주차 - 인지 왜곡 찾기'),
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
                        color: Color(0xFF5B3EFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.alternativeThoughts.isNotEmpty
                          ? "'${widget.previousB}' 생각에 대해 '${widget.alternativeThoughts.join(', ')} '(라)는 도움이 되는 생각을 작성해주셨네요. 잘 진행해주시고 계십니다!"
                          : "'${widget.previousB}' 생각에 대한\n도움이 되는 생각들을 확인해보세요.",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    if (widget.alternativeThoughts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '도움이 되는 생각을 해봤을 때 처음 들었던 불안한 생각을 어느정도 강하게 믿고있으신지 다시 한번 평가해볼게요.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (!_isNextEnabled)
                      Text(
                        '$_secondsLeft초 후에 다음 버튼이 활성화됩니다',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFB0B0B0),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
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
          onNext:
              _isNextEnabled
                  ? () {
                    if (_showMainText) {
                      setState(() => _showMainText = false);
                    } else {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) => Week4AfterAgreementScreen(
                                previousB: widget.previousB,
                                beforeSud: widget.beforeSud,
                                remainingBList: widget.remainingBList,
                                allBList: widget.allBList,
                                alternativeThoughts: _removeDuplicates([
                                  ...?widget.existingAlternativeThoughts,
                                  ...widget.alternativeThoughts,
                                ]),
                                isFromAnxietyScreen: widget.isFromAnxietyScreen,
                                originalBList: widget.originalBList,
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
                  }
                  : null,
        ),
      ),
    );
  }
}
