import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutor_design.dart'; // ✅ 주신 디자인 파일
import 'package:gad_app_team/features/2nd_treatment/abc_belief_screen.dart';

/// 🌊 ABC 모델 - A단계 (Activating Event)
/// AbcActivateDesign 스타일 적용 (Tutor형 메모 카드)
class AbcActivateScreen extends StatelessWidget {
  final String? sessionId;
  const AbcActivateScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context) {
    const descriptionText =
        "주말 오후, 날씨가 맑고 공기도 선선해서 오랜만에 자전거를 타려고 공원에 나갔어요.\n"
        "사람들이 삼삼오오 자전거를 타고 있는 모습을 보니 저도 괜히 설레었죠.\n"
        "한참 안 타다가 다시 탈 생각을 하니 조금 긴장되긴 했지만, "
        "‘괜찮아, 천천히 하면 되지’ 하며 자전거를 꺼냈어요.";

    return AbcActivateDesign(
      appBarTitle: 'ABC 모델',
      scenarioImage: 'assets/image/activating event.png',
      descriptionText: descriptionText,

      /// ⬅️ 이전 버튼
      onBack: () => Navigator.pop(context),

      /// ➡️ 다음 단계로 이동 (BeliefScreen)
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AbcBeliefScreen(sessionId: sessionId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
