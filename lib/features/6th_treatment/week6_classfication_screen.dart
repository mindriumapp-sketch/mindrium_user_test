import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';

import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/q_jellyfish_notice.dart';

import 'week6_flow_widgets.dart';
import 'week6_next_relieve_screen.dart';
import 'week6_route_utils.dart';

class Week6ClassificationScreen extends StatefulWidget {
  final List<String> behaviorListInput;
  final List<String> allBehaviorList;
  final String diaryId;
  final Map<String, dynamic> diary;
  final List<Map<String, dynamic>>? mismatchedBehaviors;

  const Week6ClassificationScreen({
    super.key,
    required this.behaviorListInput,
    required this.allBehaviorList,
    required this.diaryId,
    required this.diary,
    this.mismatchedBehaviors,
  });

  @override
  State<Week6ClassificationScreen> createState() =>
      _Week6ClassificationScreenState();
}

class _Week6ClassificationScreenState extends State<Week6ClassificationScreen> {
  late final List<String> _behaviorList;
  late final Map<String, dynamic> _diary;
  late String _currentBehavior;

  final Map<String, double> _behaviorScores = {};

  @override
  void initState() {
    super.initState();
    _diary = Map<String, dynamic>.from(widget.diary);
    _behaviorList = List<String>.from(widget.behaviorListInput);
    _currentBehavior =
        _behaviorList.isNotEmpty ? _behaviorList.first : '행동이 없습니다.';
  }

  void _onSelectBehaviorType(String type) {
    if (_currentBehavior.isEmpty) return;

    setState(() {
      _behaviorScores[_currentBehavior] = (type == 'face') ? 0.0 : 10.0;
    });
  }

  String? _selectedTypeForCurrentBehavior() {
    final score = _behaviorScores[_currentBehavior];
    if (score == 0.0) return 'face';
    if (score == 10.0) return 'avoid';
    return null;
  }

  void _onNext() {
    if (!_behaviorScores.containsKey(_currentBehavior)) return;

    final currentIndex = widget.allBehaviorList.indexOf(_currentBehavior);
    List<String> remainingBehaviors = [];
    if (currentIndex >= 0 && currentIndex < widget.allBehaviorList.length - 1) {
      remainingBehaviors = widget.allBehaviorList.sublist(currentIndex + 1);
    }

    Navigator.push(
      context,
      buildWeek6NoAnimationRoute(
        Week6NextRelieveScreen(
          selectedBehavior: _currentBehavior,
          behaviorType:
              _behaviorScores[_currentBehavior] == 0.0 ? 'face' : 'avoid',
          sliderValue: 5.0,
          remainingBehaviors:
              remainingBehaviors.isNotEmpty ? remainingBehaviors : null,
          allBehaviorList: widget.allBehaviorList,
          diaryId: widget.diaryId,
          diary: _diary,
          mismatchedBehaviors: widget.mismatchedBehaviors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double sidePadding = 20.0;
    final userName = Provider.of<UserProvider>(context, listen: false).userName;
    final hasBehavior =
        _behaviorList.isNotEmpty && _currentBehavior != '행동이 없습니다.';
    final currentBehaviorIndex =
        widget.allBehaviorList.length - widget.behaviorListInput.length + 1;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Opacity(
            opacity: 0.35,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const CustomAppBar(title: '행동 구분 연습'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: 12,
                    ),
                    child:
                        !hasBehavior
                            ? const Center(
                              child: Text(
                                '선택한 일기의 행동 정보가 없습니다.',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                QuizCard(
                                  noticeText: '$userName님께서 작성한 행동',
                                  quizText: _currentBehavior,
                                  currentIndex: currentBehaviorIndex,
                                  totalCount: widget.allBehaviorList.length,
                                ),
                                const SizedBox(height: 10),
                                JellyfishNotice(
                                  feedback:
                                      '위 행동이 불안을 직면하는 행동인지, \n회피하는 행동인지 선택해주세요.',
                                  feedbackColor: Colors.grey.shade600,
                                ),
                                Week6BehaviorTypeSelector(
                                  selectedType:
                                      _selectedTypeForCurrentBehavior(),
                                  onSelected: _onSelectBehaviorType,
                                ),
                                const Spacer(),
                              ],
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
                    leftLabel: '이전',
                    rightLabel: '다음',
                    onBack: () => Navigator.pop(context),
                    onNext:
                        _behaviorScores.containsKey(_currentBehavior)
                            ? _onNext
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
