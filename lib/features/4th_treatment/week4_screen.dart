import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/session_start.dart';
import 'package:gad_app_team/features/4th_treatment/week4_abc_screen.dart';

class Week4Screen extends StatefulWidget {
  final int loopCount;

  const Week4Screen({super.key, this.loopCount = 1});

  @override
  State<Week4Screen> createState() => _Week4ScreenState();
}

class _Week4ScreenState extends State<Week4Screen> {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId = args['abcId'] as String?;

    return SessionStartScreen(
      weekNumber: 4,
      weekTitle: '걱정일기 속 생각을 점검해보겠습니다.',
      weekDescription:
          '이번 주차에서는 내 생각을 점검하고 불안에 도움이 되도록 바꿔보겠습니다. 작성하신\n걱정일기의 내용을 살펴볼게요.',
      nextPageBuilder:
          () => Week4AbcScreen(abcId: abcId, loopCount: widget.loopCount),
    );
  }
}
