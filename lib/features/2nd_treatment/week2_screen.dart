import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart'; // ✅ ApplyDesign 위젯 불러오기

/// 🌊 ApplyDesign 스타일이 입혀진 2주차 시작 화면
class Week2Screen extends StatelessWidget {
  const Week2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;

    return ApplyDesign(
      appBarTitle: '2주차 - 시작하기',
      cardTitle: '2주차 시작 ✨',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AbcGuideScreen()),
        );
      },

      /// 🧾 기존 내용(child) 그대로 유지
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_alt, size: 62, color: Color(0xFF3F51B5)),
          const SizedBox(height: 20),
          Text(
            protectKoreanWords('ABC 모델을 통해 불안의 원인을\n분석해보겠습니다.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            protectKoreanWords('이번 주차에서는 불안이 발생하는 상황을 A(사건), B(생각), C(결과)로 나누어 분석하는 ABC 모델을 배워보겠습니다.\n\n'
            '자전거를 타려고 했을 때의 상황을 예시로 살펴볼게요.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
