import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutor_design.dart'; // ✅ 방금 주신 디자인 파일
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';

/// 🌊 ABC 모델 - C단계 (Consequence)
class AbcConsequenceScreen extends StatelessWidget {
  final String? sessionId;
  const AbcConsequenceScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context) {
    return AbcActivateDesign(
      appBarTitle: 'ABC 모델',
      scenarioImage: 'assets/image/consequence.png', // ✅ 시각 자료 (원하시는 걸로 교체 가능)
      descriptionText:
          '그 생각이 든 뒤 몸과 마음, 행동에도 변화가 나타났어요.\n'
          '심장이 빨리 뛰고 몸이 긴장됐고(신체), 불안과 두려움이 커졌어요(감정).\n'
          '결국 자전거를 타지 않고 피하게 됐어요(행동). 이것이 결과(C)예요.',
      memoHeightFactor: 0.75,

      /// 🔙 뒤로가기
      onBack: () => Navigator.pop(context),

      /// ⏭ 다음 페이지 이동
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                AbcInputScreen(
                  isExampleMode: false,
                  showGuide: false,
                  sessionId: sessionId,
                ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
