import 'package:gad_app_team/utils/text_line_material.dart';

// ✅ 튜토리얼 공용 디자인: 배경/카드/네비게이션 포함
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';

class Week4FinalScreen extends StatelessWidget {
  final List<String>? alternativeThoughts;
  final int? loopCount;

  const Week4FinalScreen({super.key, this.alternativeThoughts, this.loopCount});

  bool _isReviewMode(BuildContext context) {
    final user = context.read<UserProvider>();
    return user.currentWeek > 4 ||
        (user.currentWeek == 4 && user.mainCbtCompleted);
  }

  @override
  Widget build(BuildContext context) {
    final int altCount =
        alternativeThoughts
            ?.where((e) => e.trim().isNotEmpty && e.trim() != 'Not provided')
            .length ??
        0;
    final String resultText = _isReviewMode(context)
        ? altCount > 0
            ? '축하합니다! \n\n이번에도 도움이 되는 생각을 $altCount개 정리해보셨어요. \n반복해서 살펴볼수록 내 생각의 패턴을 더 분명하게 알아차릴 수 있어요.'
            : '축하합니다! \n\n이번에도 내 생각의 흐름을 천천히 살펴보는 시간을 가지셨어요. \n이렇게 한 번 더 돌아보는 것만으로도 충분히 의미 있는 연습이에요.'
        : altCount > 0
            ? '축하합니다! \n\n도움이 되는 생각을 $altCount개 정리해보며, 내 생각의 패턴을 차분히 살펴보셨어요. \n이 과정을 반복할수록 부정적인 사고를 알아차리는 힘이 더 커질 거예요.'
            : '축하합니다! \n\n이번 활동에서 내 생각의 흐름을 천천히 살펴보는 시간을 가지셨어요. \n끝까지 따라와 주신 것만으로도 아주 중요한 연습을 해내신 거예요.';
    final String footerText = _isReviewMode(context)
        ? '도움이 되는 생각을 다시 찾고 정리하는 과정은 매번 조금씩 다르게 느껴질 수 있어요. \n오늘 정리한 내용을 바탕으로 내 생각의 패턴을 한 번 더 차분히 살펴보세요. \n\n수고하셨습니다.'
        : '도움이 되는 생각을 찾는 과정이 처음에는 쉽지 않을 수 있어요. \n조금 더 연습하고, 내 마음을 들여다보는 시간을 가져보면 분명 불안이 줄어들 수 있습니다. \n\n고생하셨습니다.';
    return ApplyDesign(
      appBarTitle: '인지 왜곡 찾기',
      cardTitle: '불안 완화 결과',
      onBack: () => Navigator.pop(context),
      rightLabel: '완료',
      onNext: () async {
        final userProvider = context.read<UserProvider>();
        if (_isReviewMode(context)) {
          final todayTask = context.read<TodayTaskProvider>();
          final shouldShowRelaxLearning =
              todayTask.isTreatmentReviewFlowForWeek(4) &&
              shouldShowCbtToRelaxationTransition(
                currentWeek: userProvider.currentWeek,
                mainRelaxCompleted: userProvider.mainRelaxCompleted,
                weekNumber: 4,
              );
          if (shouldShowRelaxLearning) {
            showCbtToRelaxationDialog(
              context: context,
              weekNumber: 4,
              onMoveNow: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(
                  context,
                  '/relaxation_start',
                  arguments: {
                    'taskId': 'week4_education',
                    'weekNumber': 4,
                    'mp3Asset': 'week4.mp3',
                    'riveAsset': 'week4.riv',
                    'isReviewMode': false,
                  },
                );
              },
              onFinish: () {
                todayTask.clearTreatmentReviewFlow();
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
              },
            );
            return;
          }
          final shouldShowRelaxReview =
              todayTask.isTreatmentReviewFlowForWeek(4) &&
              (userProvider.currentWeek > 4 ||
                  (userProvider.currentWeek == 4 &&
                      userProvider.mainCbtCompleted &&
                      userProvider.mainRelaxCompleted));
          if (shouldShowRelaxReview) {
            showCbtReviewToRelaxationDialog(
              context: context,
              weekNumber: 4,
              onMoveNow: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(
                  context,
                  '/relaxation_start',
                  arguments: {
                    'taskId': 'week4_education',
                    'weekNumber': 4,
                    'mp3Asset': 'week4.mp3',
                    'riveAsset': 'week4.riv',
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
        try {
          await eduApi.completeWeekSession(weekNumber: 4, totalStages: 12);
          await userProvider.refreshProgress();
        } catch (e) {
          debugPrint('[Week4Final] edu-session 완료 처리 실패: $e');
        }

        if (!context.mounted) return;
        final shouldShowTransition = shouldShowCbtToRelaxationTransition(
          currentWeek: userProvider.currentWeek,
          mainRelaxCompleted: userProvider.mainRelaxCompleted,
          weekNumber: 4,
        );
        if (!shouldShowTransition) {
          context.read<TodayTaskProvider>().clearTreatmentReviewFlow();
          Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
          return;
        }

        // ⛳ 팝업을 커스텀 디자인으로 교체 (로직 동일: 닫히면 다음 화면으로 이동)
        showCbtToRelaxationDialog(
          context: context,
          weekNumber: 4,
          onMoveNow: () {
            Navigator.of(context).pop();
            Navigator.pushReplacementNamed(
              context,
              '/relaxation_start',
              arguments: {
                'taskId': 'week4_education',
                'weekNumber': 4,
                'mp3Asset': 'week4.mp3',
                'riveAsset': 'week4.riv',
                'isReviewMode':
                    userProvider.currentWeek > 4 ||
                    (userProvider.currentWeek == 4 &&
                        userProvider.mainRelaxCompleted),
              },
            );
          },
        );
      },

      // 💠 카드 내부 UI (이름/구분선/결과문구 유지)
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/image/congrats.png',
            height: 160,
            filterQuality: FilterQuality.high,
          ),

          // 결과 메시지 (조건 동일)
          Text(
            resultText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
              height: 1.5,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 32),

          // 추가 안내
          Text(
            footerText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
              height: 1.5,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
