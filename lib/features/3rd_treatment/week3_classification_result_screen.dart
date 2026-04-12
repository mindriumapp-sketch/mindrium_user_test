import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_classification_detail_screen.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_explain_alternative_thoughts.dart';

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

      appBar: const CustomAppBar(title: '생각 구분 연습'),

      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF7FF), Color(0xFFF7FCFF)],
              ),
            ),
          ),

          Opacity(
            opacity: 0.18,
            child: Image.asset(
              'assets/image/eduhome.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.80),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.85),
                                width: 1.3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 30,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 108,
                                    height: 108,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(
                                        0xFF19C37D,
                                      ).withValues(alpha: 0.10),
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/image/congrats.png',
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F7FB),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '분류 연습 완료',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4F6475),
                                        fontFamily: 'Noto Sans KR',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '$correctCount개의 문항을 맞혔어요!',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                      color: Color(0xFF1F2D3D),
                                      fontFamily: 'Noto Sans KR',
                                    ),
                                  ),
                                  // const SizedBox(height: 10),
                                  // const Text(
                                  //   '도움이 되는 생각과 도움이 되지 않는 생각을\n차분히 다시 살펴보며 연습을 이어가보세요.',
                                  //   textAlign: TextAlign.center,
                                  //   style: TextStyle(
                                  //     fontSize: 14,
                                  //     fontWeight: FontWeight.w500,
                                  //     height: 1.6,
                                  //     color: Color(0xFF5B7083),
                                  //     fontFamily: 'Noto Sans KR',
                                  //   ),
                                  // ),
                                  const SizedBox(height: 22),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF19C37D,
                                      ).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF19C37D,
                                        ).withValues(alpha: 0.16),
                                      ),
                                    ),
                                    child: Row(
                                      children: const [
                                        // Icon(
                                        //   Icons.check_circle_rounded,
                                        //   color: Color(0xFF19C37D),
                                        //   size: 20,
                                        // ),
                                        // SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '선택한 20문항의 내용을 확인하면서\n도움이 되는 생각의 특징을 다시 살펴 보세요.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              height: 1.45,
                                              color: Color(0xFF2D5B4F),
                                              fontFamily: 'Noto Sans KR',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
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
                                            builder:
                                                (_) =>
                                                    Week3ClassificationDetailScreen(
                                                      quizResults: quizResults,
                                                    ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: const Color(
                                          0xFF263C69,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        '선택한 내용 자세히 보기',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Noto Sans KR',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
                    onBack: () => Navigator.pop(context),
                    onNext: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (_, __, ___) =>
                                  Week3ExplainAlternativeThoughtsScreen(
                                    sessionId: sessionId,
                                    chips: const [],
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
