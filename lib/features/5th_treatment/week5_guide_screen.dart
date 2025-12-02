import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/5th_treatment/week5_belief_screen.dart';
import 'package:gad_app_team/widgets/tutor_design.dart'; // ✅ AbcActivateDesign import

/// 🌊 Mindrium 스타일 - 5주차 불안 직면 VS 회피 (사례 소개)
class Week5GuideScreen extends StatelessWidget {
  const Week5GuideScreen({super.key});

  String get _description =>
      '이 여성은 34살의 초등학교 교사입니다.\n'
          '그녀는 최근 6개월 동안, 거의 매일 특별한 이유 없이 불안하고 걱정이 많아졌다고 말합니다.\n\n'
          '예를 들어, 수업 준비를 할 때마다 혹시 실수를 해서 학부모나 학교 측의 불만을 살까 봐 걱정이 되고,\n'
          '동료 교사와 나눈 말 한마디가 오해로 이어지지는 않았을까 반복해서 떠올리며 신경이 쓰입니다.\n\n'
          '또 부모님의 건강이 갑자기 나빠지지는 않을지, 갑작스러운 지출이 생기면 감당할 수 있을지 등의 생각이\n'
          '끊임없이 머릿속을 맴돌며 불안을 키웁니다.\n\n'
          '본인도 이런 걱정이 비현실적이고 과도하다는 걸 알고 있지만, 마음을 놓기가 힘들다고 털어놓습니다.';

  @override
  Widget build(BuildContext context) {
    return AbcActivateDesign(
      appBarTitle: '5주차 - 불안 직면 VS 회피',         // ✅ 주차 제목 주입
      scenarioImage: 'assets/image/scenario_1.png',    // 기존 이미지 재사용
      descriptionText: _description,                   // 본문
      memoHeightFactor: 0.75,                          // 필요시 조정 가능
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
