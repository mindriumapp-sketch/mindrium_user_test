import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutor_design.dart';
import 'package:gad_app_team/features/5th_treatment/week5_practice_screen.dart';

/// 💬 5주차 - 불안 직면 VS 회피 (메모시트 디자인 적용)
class Week5ConsequenceScreen extends StatelessWidget {
  final String? sessionId;
  const Week5ConsequenceScreen({super.key, required this.sessionId});
  String get _description =>
      '수업 중에도 쉽게 피로를 느끼고, 가슴이 갑갑하거나 속이 울렁거리는 증상이 가끔 나타납니다.\n\n'
          '집중력도 눈에 띄게 떨어져서 수업 자료를 준비하다가도 멍하니 시간을 보내는 일이 잦아졌고,\n'
          '동료나 가족과 대화를 나눌 때도 예민하게 반응하거나 감정 기복이 커졌다는 이야기를 듣게 되었습니다.\n\n'
          '점점 친구들을 만나는 것도 부담스럽게 느껴지고, 주말에도 집에만 있으려는 경우가 많아졌습니다.';
  @override
  Widget build(BuildContext context) {
    return AbcActivateDesign(
      appBarTitle: '불안 직면 VS 회피',
      scenarioImage: 'assets/image/scenario_3.png',
      descriptionText: _description,
      memoHeightFactor: 0.75,
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week5PracticeScreen(sessionId: sessionId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
