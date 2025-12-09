import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'week6_classfication_detail_screen.dart';
import 'week6_imagination.dart';

/// 🌊 6주차 결과 화면 (디자인은 ApplyDesign이 담당)
class Week6ClassificationResultScreen extends StatelessWidget {
  final List<double>? bScores;
  final List<String>? bList;

  const Week6ClassificationResultScreen({super.key, this.bScores, this.bList});

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: '불안 직면 VS 회피',
      cardTitle: '결과를 살펴보기',
      onBack: () => Navigator.pop(context),
      onNext: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => Week6ImaginationScreen(cBehaviorList: bList),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },

      /// 💡 child는 순수 기능 콘텐츠만
      child: Column(
        children: [
          const Text('불안을 직면하는 행동과 회피하는 행동', textAlign: TextAlign.center),
          const SizedBox(height: 16),

          Image.asset(
            'assets/image/nice.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: 180,
          ),

          const SizedBox(height: 32),

          const Text('수고하셨습니다!\n다음 단계로 이동해 주세요.', textAlign: TextAlign.center),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder:
                        (_, __, ___) => Week6ClassificationDetailScreen(
                          bScores: bScores,
                          bList: bList,
                        ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
              child: const Text('자세히 살펴보기'),
            ),
          ),
        ],
      ),
    );
  }
}
