// 🔹 Mindrium: 이완 활동 진행 여부 확인 화면 (RelaxYesOrNo)
// DiaryYesOrNo와 동일한 InnerBtnCardScreen 기반 디자인 적용
// 사용자가 ‘이완 활동’을 지금 진행할지 여부를 선택하는 간단한 분기 화면
// 연결 흐름:
//   RelaxOrAlternativePage → RelaxYesOrNo
//     ├─ “예” → /relaxation_noti (이완 오디오 재생 화면)
//     └─ “아니오” → /home (메인 홈 화면)
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_prompt_content.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:gad_app_team/widgets/inner_btn_card.dart';

class RelaxYesOrNo extends StatelessWidget {
  const RelaxYesOrNo({super.key});

  @override
  Widget build(BuildContext context) {
    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
    );
    final String? abcId = route.abcId;
    final String? sudId = route.sudId;
    final int? beforeSud = route.beforeSud;
    final String origin = route.origin;

    return InnerBtnCardScreen(
      appBarTitle: '이완 활동 진행',
      title: '이완 활동을 진행하시겠어요? \n"아니오"를 누르면 홈 화면으로 돌아가요.',
      backgroundAsset: 'assets/image/eduhome.png',
      primaryText: '예',
      onPrimary: () {
        Navigator.pushNamed(
          context,
          '/relaxation_noti',
          arguments: route.mergedArgs(
            extra: {
              'taskId': abcId,
              'mp3Asset': 'noti.mp3',
              'riveAsset': 'noti.riv',
              'nextPage': '/relaxation_score',
              'origin': origin,
              'beforeSud': beforeSud,
              'sudId': sudId,
            },
            includeDiary: true,
          ),
        );
      },
      // “아니오” 버튼 → 홈 복귀
      secondaryText: '아니오',
      onSecondary: () {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      },
      // 카드 내부 본문
      child: const ApplyFlowPromptContent(
        message: '예를 누르면 이완 활동 페이지로 이동해요.\n아니오를 누르면 홈으로 돌아가요.',
      ),
    );
  }
}
