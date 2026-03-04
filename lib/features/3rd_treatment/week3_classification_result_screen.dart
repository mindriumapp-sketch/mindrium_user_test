import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/round_card.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_classification_detail_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_imagination.dart';

class Week3ClassificationResultScreen extends StatelessWidget {
  final int correctCount;
  final String? sessionId;
  final List<Map<String, dynamic>> quizResults;

  const Week3ClassificationResultScreen({
    super.key,
    required this.sessionId,
    required this.correctCount,
    required this.quizResults,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 배경색은 Stack에서 처리
      extendBodyBehindAppBar: true,

      appBar: const CustomAppBar(title: 'Self Talk'),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌊 Mindrium 공통 배경 (ApplyDesign 스타일)
          Container(
            color: Colors.white,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ───────── 결과 카드 (Week5 스타일 적용)
                          RoundCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 36,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🎉 축하/결과 이미지
                                Image.asset(
                                  'assets/image/congrats.png', // 필요 시 nice.png로 교체 가능 (로직 영향 없음)
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 22),

                                // 🔢 결과 텍스트
                                Text(
                                  '20개의 문항 중\n$correctCount개 맞았어요!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // 🔍 선택한 내용 확인 버튼 (기존 로직 유지 + 빈 결과 가드 유지)
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () {
                                      // ✅ 빈 결과 가드 (기존 BlueBanner 로직 유지)
                                      if (quizResults.isEmpty) {
                                        BlueBanner.show(
                                          context,
                                          '표시할 결과가 없어요. 퀴즈를 먼저 진행해 주세요.',
                                        );
                                        return;
                                      }

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              Week3ClassificationDetailScreen(
                                                quizResults: quizResults,
                                              ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      foregroundColor:
                                      const Color(0x7F263C69),
                                    ),
                                    child: const Text(
                                      '클릭하여 선택한 내용을 확인해보세요.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.39,
                                        fontFamily: 'Noto Sans KR',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ───────── 아래 안내 문구/기존 카드 내용은 요청대로 제거(주석 처리)
                          /*
                          BlueWhiteCard(
                            maxWidth: screenWidth * 0.92,
                            title: '도움이 되는 생각과\n도움이 되지 않는 생각',
                            ...
                          );

                          Container(
                            padding: const EdgeInsets.all(12),
                            ...
                            child: Text(
                              '잘하셨어요 👏 이번 결과를 바탕으로\n도움이 되는 생각을 계속 연습해볼까요?',
                              ...
                            ),
                          );
                          */
                        ],
                      ),
                    ),
                  ),
                ),

                // ⛵ 네비게이션 버튼 (기존 로직 그대로 유지)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
child: NavigationButtons(
                    onBack: () => Navigator.pop(context),
                    onNext: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => Week3ImaginationScreen(
                            sessionId: sessionId,
                          ),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
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
