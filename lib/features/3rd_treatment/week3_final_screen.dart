import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/round_card.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:provider/provider.dart';

class Week3FinalScreen extends StatelessWidget {
  final String? sessionId;
  const Week3FinalScreen({super.key, required this.sessionId});

  Future<bool> _isReviewMode(BuildContext context) async {
    final user = context.read<UserProvider>();
    return user.currentWeek > 3 ||
        (user.currentWeek == 3 && user.mainCbtCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 배경색은 Stack에서 처리
      extendBodyBehindAppBar: true,

      appBar: const CustomAppBar(title: '생각 구분 연습'),

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
                                  '불안을 키우는 생각과 도움이 되는 생각을 구분해봤어요. ',
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
                    rightLabel: '완료',
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
    if (await _isReviewMode(context)) {
      final todayTask = context.read<TodayTaskProvider>();
      final user = context.read<UserProvider>();
      final shouldShowRelaxReview =
          todayTask.isTreatmentReviewFlowForWeek(3) &&
          (user.currentWeek > 3 ||
              (user.currentWeek == 3 &&
                  user.mainCbtCompleted &&
                  user.mainRelaxCompleted));
      if (shouldShowRelaxReview) {
        showCbtReviewToRelaxationDialog(
          context: context,
          weekNumber: 3,
          onMoveNow: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacementNamed(
              '/relaxation_start',
              arguments: {
                'sessionId': sessionId,
                'taskId': 'week3_education',
                'weekNumber': 3,
                'mp3Asset': 'week3.mp3',
                'riveAsset': 'week3.riv',
                'isReviewMode': true,
              },
            );
          },
          onFinish: () {
            todayTask.clearTreatmentReviewFlow();
            Navigator.of(context).pop();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home_edu',
              (_) => false,
            );
          },
        );
        return;
      }

      if (!context.mounted) return;
      todayTask.clearTreatmentReviewFlow();
      Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
      return;
    }

    final client = ApiClient(tokens: TokenStorage());
    final eduApi = EduSessionsApi(client);
    final userProvider = context.read<UserProvider>();
    try {
      await eduApi.completeWeekSession(
        weekNumber: 3,
        totalStages: 12,
        sessionId: sessionId,
      );
      await userProvider.refreshProgress();
    } catch (e) {
      debugPrint('[Week3Final] edu-session 완료 처리 실패: $e');
    }

    if (!context.mounted) return;
    final nav = Navigator.of(context);
    final shouldShowTransition = shouldShowCbtToRelaxationTransition(
      currentWeek: userProvider.currentWeek,
      mainRelaxCompleted: userProvider.mainRelaxCompleted,
      weekNumber: 3,
    );

    if (!shouldShowTransition) {
      context.read<TodayTaskProvider>().clearTreatmentReviewFlow();
      nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
      return;
    }

    showCbtToRelaxationDialog(
      context: context,
      weekNumber: 3,
      onMoveNow: () {
        nav.pop();
        nav.pushReplacementNamed(
          '/relaxation_start',
          arguments: {
            'sessionId': sessionId,
            'taskId': 'week3_education',
            'weekNumber': 3,
            'mp3Asset': 'week3.mp3',
            'riveAsset': 'week3.riv',
            'isReviewMode':
                userProvider.currentWeek > 3 ||
                (userProvider.currentWeek == 3 &&
                    userProvider.mainRelaxCompleted),
          },
        );
      },
    );
  }
}
