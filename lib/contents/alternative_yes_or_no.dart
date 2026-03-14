import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/inner_btn_card.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_prompt_content.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';

class AltYesOrNo extends StatelessWidget {
  const AltYesOrNo({super.key});

  @override
  Widget build(BuildContext context) {
    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
    );
    final String? abcId = route.abcId;
    final String origin = route.origin;

    return InnerBtnCardScreen(
      appBarTitle: '대체 생각 진행',
      title: '대체 생각을 작성하시겠어요?',
      backgroundAsset: 'assets/image/eduhome.png',
      primaryText: '예',
      onPrimary: () {
        Navigator.pushNamed(
          context,
          '/apply_alt_thought',
          arguments: route.mergedArgs(
            extra: {'taskId': abcId, 'origin': origin},
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
        message: '예를 누르면 대체 생각 페이지로 이동해요.\n아니오를 누르면 홈으로 돌아가요.',
      ),
    );
  }
}
