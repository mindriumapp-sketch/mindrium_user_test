import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutor_design.dart'; // ✅ AbcActivateDesign == TutorDesign
import 'package:gad_app_team/features/2nd_treatment/abc_consequence_screen.dart';

/// 🌊 ABC 모델 - B단계 (Belief)
/// AbcActivateDesign (TutorDesign) 스타일 적용
class AbcBeliefScreen extends StatelessWidget {
  final String? sessionId;
  const AbcBeliefScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context) {
    const descriptionText =
        "페달을 밟으려는 순간 균형이 살짝 흔들리자,\n"
        "‘넘어질 것 같아’, ‘또 다치면 어떡하지?’라는 생각이 들었어요.\n"
        "예전에 넘어졌던 기억이 떠오르면서 불안한 생각(B)이 더 커졌어요.";

    return AbcActivateDesign(
      appBarTitle: 'ABC 모델',
      descriptionText: descriptionText,
      scenarioImage: 'assets/image/belief.png',
      memoHeightFactor: 0.75,
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AbcConsequenceScreen(sessionId: sessionId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
