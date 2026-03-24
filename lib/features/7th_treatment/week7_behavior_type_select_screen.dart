import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/quiz_card.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';
import 'package:gad_app_team/features/6th_treatment/week6_flow_widgets.dart';
import 'package:gad_app_team/features/7th_treatment/week7_reason_input_screen.dart';

class Week7BehaviorTypeSelectScreen extends StatefulWidget {
  final String behavior;
  final String chipId;

  const Week7BehaviorTypeSelectScreen({
    super.key,
    required this.behavior,
    required this.chipId,
  });

  @override
  State<Week7BehaviorTypeSelectScreen> createState() =>
      _Week7BehaviorTypeSelectScreenState();
}

class _Week7BehaviorTypeSelectScreenState
    extends State<Week7BehaviorTypeSelectScreen> {
  String? _selectedType;

  void _onNext() {
    if (_selectedType == null) return;

    if (_selectedType == 'face') {
      Navigator.pop(context, 'face');
      return;
    }

    Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => Week7ReasonInputScreen(
              behavior: widget.behavior,
              chipId: widget.chipId,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ).then((added) {
      if (!mounted) return;
      if (added == true) {
        Navigator.pop(context, 'avoid_added');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                const CustomAppBar(title: '생활 습관 개선'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        QuizCard(
                          noticeText: '추가한 행동',
                          quizText: widget.behavior,
                          currentIndex: 1,
                          totalCount: 1,
                        ),
                        const SizedBox(height: 10),
                        Transform.translate(
                          offset: const Offset(16, 0),
                          child: JellyfishNotice(
                            feedback:
                                '위 행동이 불안을 직면하는 행동인지,\n회피하는 행동인지 선택해주세요.',
                            feedbackColor: Colors.grey.shade600,
                          ),
                        ),
                        Week6BehaviorTypeSelector(
                          selectedType: _selectedType,
                          onSelected: (type) {
                            setState(() => _selectedType = type);
                          },
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
                    onNext: _selectedType == null ? null : _onNext,
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

