import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/inner_btn_card.dart';
import 'package:gad_app_team/data/apply_solve_provider.dart';
import 'package:provider/provider.dart';

class SolveEntryChoiceScreen extends StatelessWidget {
  const SolveEntryChoiceScreen({super.key});

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final flow = context.read<ApplyOrSolveFlow>()..syncFromArgs(args, notify: false);
    final int? beforeSud = flow.beforeSud ?? _asInt(args['beforeSud']);
    final String origin = flow.origin;

    return InnerBtnCardScreen(
      appBarTitle: '상황 선택',
      title: '어떤 방식으로\n상황을 선택하시겠어요?',
      primaryText: '기존 일기에서 선택',
      onPrimary: () {
        Navigator.pushNamed(
          context,
          '/diary_select',
          arguments: {
            ...flow.toArgs(),
            'origin': origin,
            if (beforeSud != null) 'beforeSud': beforeSud,
          },
        );
      },
      secondaryText: '새 일기 작성',
      onSecondary: () {
        Navigator.pushNamed(
          context,
          '/abc',
          arguments: {
            ...flow.toArgs(),
            'origin': origin,
            'abcId': null,
            if (beforeSud != null) 'beforeSud': beforeSud,
          },
        );
      },
      backgroundAsset: 'assets/image/eduhome.png',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '기존 일기를 선택하면 해당 일기에 현재 불안 점수를 저장하고\n바로 다음 단계로 이동합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF626262),
            height: 1.7,
            fontFamily: 'Noto Sans KR',
          ),
        ),
      ),
    );
  }
}
