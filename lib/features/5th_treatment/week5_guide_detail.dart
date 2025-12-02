import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutor_design.dart';
import 'package:gad_app_team/features/5th_treatment/week5_belief_screen.dart';

/// 🌊 Mindrium 스타일 - 5주차 불안 직면 VS 회피 (사례 소개 2단계)
class Week5GuideDetailScreen extends StatelessWidget {
  const Week5GuideDetailScreen({super.key});

  String get _description =>
      '동료 교사와 나눈 말이 오해로 이어지지는 않았을까 신경이 쓰입니다. 또 부모님의 건강이 갑자기 나빠지지는 않을지, 갑작스러운 지출이 생기면 감당할 수 있을지 등의 생각이 머릿속을 맴돌며 불안을 키웁니다. 이런 걱정이 비현실적이고 과도하다는 걸 알고 있지만, 마음을 놓기가 힘들다고 털어놓습니다.';

  @override
  Widget build(BuildContext context) {
    return AbcActivateDesign(
      appBarTitle: '5주차 - 불안 직면 VS 회피 (2)',
      scenarioImage: 'assets/image/scenario_1.png',
      descriptionText: _description,
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const Week5BeliefScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
    );
  }
}
