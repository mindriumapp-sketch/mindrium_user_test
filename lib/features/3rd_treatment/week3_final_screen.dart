import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/round_card.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:provider/provider.dart';

class Week3FinalScreen extends StatelessWidget {
  final String? sessionId;
  const Week3FinalScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 배경색은 Stack에서 처리
      extendBodyBehindAppBar: true,

      appBar: const CustomAppBar(title: '3주차 - Self Talk'),

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
                              horizontal: 30,
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
                                  '오늘도 수고하셨습니다!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '자기이해와 긍정적 자기대화를 실천했어요!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    onNext: () => _showStartDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🧘 이완 교육 다이얼로그 — CustomPopupDesign(확인 단일 버튼)
  Future<void> _showStartDialog(BuildContext context) async {
    final client = ApiClient(tokens: TokenStorage());
    final eduApi = EduSessionsApi(client);
    final relaxApi = RelaxationApi(client);

    try {
      await eduApi.completeWeekSession(
        weekNumber: 3,
        totalStages: 12,
        sessionId: sessionId,
      );
      if (context.mounted) {
        context.read<TodayTaskProvider>().setEducationWeekSessionLocally(
          weekNumber: 3,
          cbtDone: true,
          educationDoneWeek: true,
          lastEducationAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[Week3Final] edu-session 완료 처리 실패: $e');
    }

    bool isRelaxDone = false;
    try {
      isRelaxDone = await relaxApi.isWeekEducationTaskCompleted(3);
    } catch (e) {
      debugPrint('[Week3Final] relaxation 완료 조회 실패: $e');
    }

    if (!context.mounted) return;
    final nav = Navigator.of(context);

    if (isRelaxDone) {
      nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => CustomPopupDesign(
            title: '이완 연습 이어서 하기',
            message: '오늘 학습을 잘 마쳤어요.\n이완 연습까지 이어서 진행해볼까요?',
            positiveText: '이어하기',
            autoPositiveAfter: const Duration(seconds: 10),
            negativeText: null,
            backgroundAsset: null,
            iconAsset: null,
            onPositivePressed: () {
              nav.pop();
              nav.pushReplacementNamed(
                '/relaxation_education',
                arguments: {
                  'sessionId': sessionId,
                  'taskId': 'week3_education',
                  'weekNumber': 3,
                  'mp3Asset': 'week3.mp3',
                  'riveAsset': 'week3.riv',
                },
              );
            },
          ),
    );
  }
}
