import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_prompt_content.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:gad_app_team/widgets/inner_btn_card.dart';

class SolveEntryChoiceScreen extends StatelessWidget {
  const SolveEntryChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
    );
    final int? beforeSud = route.beforeSud;
    final String origin = route.origin;

    return InnerBtnCardScreen(
      appBarTitle: '상황 선택',
      title: '어떤 방식으로\n상황을 선택하시겠어요?',
      primaryText: '기존 일기에서 선택',
      onPrimary: () {
        Navigator.pushNamed(
          context,
          '/diary_select',
          arguments: route.mergedArgs(
            extra: {
              'origin': origin,
              if (beforeSud != null) 'beforeSud': beforeSud,
            },
          ),
        );
      },
      secondaryText: '새 일기 작성',
      onSecondary: () {
        Navigator.pushNamed(
          context,
          '/abc',
          arguments: route.mergedArgs(
            extra: {
              'origin': origin,
              'abcId': null,
              if (beforeSud != null) 'beforeSud': beforeSud,
            },
          ),
        );
      },
      backgroundAsset: 'assets/image/eduhome.png',
      child: const ApplyFlowPromptContent(
        showIllustration: false,
        message: '기존 일기를 선택하면 현재 불안 점수를 저장 후 바로 다음 단계로 이동해요.',
      ),
    );
  }
}
