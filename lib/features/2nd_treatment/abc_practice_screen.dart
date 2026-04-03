import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';

@Deprecated('The ABC practice page was removed. Go directly to AbcInputScreen.')
class AbcPracticeScreen extends StatelessWidget {
  final String? sessionId;
  const AbcPracticeScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context) {
    return AbcInputScreen(
      isExampleMode: true,
      showGuide: false,
      sessionId: sessionId,
    );
  }
}
