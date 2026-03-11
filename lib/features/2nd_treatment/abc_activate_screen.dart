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
        "주말 오후, 오랜만에 자전거를 타려고 공원에 나갔어요.\n"
        "사람들이 자전거를 타는 모습을 보니 저도 한번 타보고 싶어졌고,\n"
        "자전거를 꺼내 출발하려는 순간이 바로 이번 상황(A)이에요.";

    return AbcActivateDesign(
      appBarTitle: 'ABC 모델',
      scenarioImage: 'assets/image/activating event.png',
      descriptionText: descriptionText,
      memoHeightFactor: 0.75,

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
