import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/common/constants.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_input_screen.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';

/// 🌊 Mindrium ApplyDesign 스타일로 리디자인된 실제 작성 시작 화면
class AbcRealStartScreen extends StatelessWidget {
  const AbcRealStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '2주차 - ABC 모델',
      cardTitle: '잘하셨어요!',
      onBack: () {
        Navigator.pop(context);
      },
      onNext: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AbcInputScreen(showGuide: false),
          ),
        );
      },
      rightLabel: '작성하기',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          const Icon(Icons.edit_note, size: 68, color: AppColors.indigo),
          const SizedBox(height: 24),
          const Text(
            '실제로 작성해볼까요?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            protectKoreanWords('이제 실제로 나의 사례를 떠올리며\n걱정일기를 작성해보세요.'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.6,
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          /// 💡 안내문
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.indigo,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    protectKoreanWords('실제 사례를 적으며 나만의 패턴을 이해해보세요.'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.indigo,
                      height: 1.4,
                      fontFamily: 'Noto Sans KR',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
