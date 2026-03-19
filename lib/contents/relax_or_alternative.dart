// 🔹 Mindrium: 다음 단계 선택 화면 (RelaxOrAlternativePage)
// 사용자가 불안 평가(SUD) 이후, 다음으로 ‘이완 활동’을 할지 ‘대체 생각 작성’을 할지 선택하는 분기 화면
// 연결 흐름:
//   BeforeSudRatingScreen → RelaxOrAlternativePage
//     ├─ “이완 활동” → /relaxation_noti (이완 오디오 재생 화면)
//     └─ “대체 생각 작성” → /apply_alt_thought (대체 사고 적용 화면)
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_prompt_content.dart';
import 'package:gad_app_team/contents/apply_flow/apply_flow_route_data.dart';
import 'package:gad_app_team/widgets/inner_btn_card.dart';

class RelaxOrAlternativePage extends StatelessWidget {
  const RelaxOrAlternativePage({super.key});

  @override
  Widget build(BuildContext context) {
    final route = ApplyFlowRouteData.read(
      context,
      rawArgs: ModalRoute.of(context)?.settings.arguments,
    );
    final String? abcId = route.abcId;
    final String? sudId = route.sudId;
    final int? beforeSud = route.beforeSud;
    final dynamic diary = route.diary;
    final String origin = route.origin;

    return InnerBtnCardScreen(
      appBarTitle: '다음 단계 선택',
      title: '어떤 활동을 진행하시겠어요?',
      backgroundAsset: 'assets/image/eduhome.png',
      primaryText: '이완 활동',
      onPrimary: () {
        Navigator.pushNamed(
          context,
          '/relaxation_noti',
          arguments: route.mergedArgs(
            extra: {
              'taskId': abcId,
              'mp3Asset': 'noti.mp3',
              'riveAsset': 'noti.riv',
              'nextPage': '/home',
              'origin': origin,
              'beforeSud': beforeSud,
              'sudId': sudId,
            },
            includeDiary: true,
          ),
        );
      },
      secondaryText: '대체 생각 작성',
      onSecondary: () {
        debugPrint(
          '[relax_or_alternative] abcId=$abcId, sud=$beforeSud, diary=$diary',
        );
        Navigator.pushNamed(
          context,
          '/apply_alt_thought',
          arguments: route.mergedArgs(
            extra: {
              'abcId': abcId,
              'beforeSud': beforeSud,
              'sudId': sudId,
              'origin': origin,
            },
            includeDiary: true,
          ),
        );
      },
      child: const ApplyFlowPromptContent(),
    );
  }
}
