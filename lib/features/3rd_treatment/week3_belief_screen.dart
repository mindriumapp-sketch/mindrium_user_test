import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_consequence_screen.dart';
import 'package:gad_app_team/widgets/tutor_design.dart'; // ✅ AbcActivateDesign import

/// 💬 3주차 - Self Talk (신체적 반응 시나리오)
/// AbcActivateDesign 스타일 적용 (이미지 + 텍스트 + 네비게이션 버튼)
class Week3BeliefScreen extends StatelessWidget {
  final String? sessionId;

  const Week3BeliefScreen({super.key, required this.sessionId});

  String get _description =>
      "걱정이 많아지면서 신체적으로도 여러 증상이 나타났습니다.\n\n"
          "평소에는 느끼지 못했던 어깨와 목의 뻐근함이 거의 매일 지속되고,\n"
          "마치 온몸에 힘이 들어간 것처럼 긴장된 상태가 계속됩니다.\n\n"
          "밤에는 잠들기까지 1시간 이상 걸릴 때도 있고, 한밤중에 자주 깨거나\n"
          "자고 나서도 개운하지 않다고 느낍니다.";

  @override
  Widget build(BuildContext context) {
    return AbcActivateDesign(
      appBarTitle: '3주차 - Self Talk',
      scenarioImage: 'assets/image/scenario_2.png', // ✅ 실제 상황 이미지 경로 지정
      descriptionText: _description,
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week3ConsequenceScreen(sessionId: sessionId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
