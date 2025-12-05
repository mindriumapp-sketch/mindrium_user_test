import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_practice_screen.dart';
import 'package:gad_app_team/widgets/tutor_design.dart'; // ✅ AbcActivateDesign import

/// 💬 3주차 - Self Talk (결과 시나리오)
/// AbcActivateDesign 스타일 적용
class Week3ConsequenceScreen extends StatelessWidget {
  final String? sessionId;

  const Week3ConsequenceScreen({super.key, required this.sessionId});
  String get _description =>
      '수업 중에도 쉽게 피로를 느끼고, 가슴이 갑갑하거나 속이 울렁거리는 증상이 가끔 나타납니다.\n\n'
          '집중력도 눈에 띄게 떨어져서 수업 자료를 준비하다가도 멍하니 시간을 보내는 일이 잦아졌고,\n'
          '동료나 가족과 대화를 나눌 때도 예민하게 반응하거나 감정 기복이 커졌다는 이야기를 듣게 되었습니다.\n\n'
          '점점 친구들을 만나는 것도 부담스럽게 느껴지고, 주말에도 집에만 있으려는 경우가 많아졌습니다.';

  @override
  Widget build(BuildContext context) {
    return AbcActivateDesign(
      appBarTitle: '3주차 - Self Talk',         // ✅ 주차 제목 주입
      scenarioImage: 'assets/image/scenario_3.png', // ✅ 실제 결과 이미지 경로 지정
      descriptionText: _description,
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week3PracticeScreen(sessionId: sessionId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
