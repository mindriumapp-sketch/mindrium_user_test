import 'package:gad_app_team/utils/text_line_material.dart';

// ✅ 튜토리얼 공용 디자인: 배경/카드/네비게이션 포함
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';

class Week4FinalScreen extends StatelessWidget {
  final List<String>? alternativeThoughts;
  final int? loopCount;

  const Week4FinalScreen({
    super.key,
    this.alternativeThoughts,
    this.loopCount,
  });

  @override
  Widget build(BuildContext context) {
    final int altCount =
        alternativeThoughts
            ?.where((e) => e.trim().isNotEmpty && e.trim() != 'Not provided')
            .length ??
        0;
    final String resultText =
        altCount > 0
            ? '축하합니다! \n\n도움이 되는 생각을 $altCount개 정리해보며, 내 생각의 패턴을 차분히 살펴보셨어요. \n이 과정을 반복할수록 부정적인 사고를 알아차리는 힘이 더 커질 거예요.'
            : '축하합니다! \n\n이번 활동에서 내 생각의 흐름을 천천히 살펴보는 시간을 가지셨어요. \n끝까지 따라와 주신 것만으로도 아주 중요한 연습을 해내신 거예요.';

    final String footerText =
        '도움이 되는 생각을 찾는 과정이 처음에는 쉽지 않을 수 있어요. \n조금 더 연습하고, 내 마음을 들여다보는 시간을 가져보면 분명 불안이 줄어들 수 있습니다. \n\n고생하셨습니다.';

    return ApplyDesign(
      appBarTitle: '인지 왜곡 찾기',
      cardTitle: '불안 완화 결과',
      onBack: () => Navigator.pop(context),
      onNext: () async {
        final client = ApiClient(tokens: TokenStorage());
        final eduApi = EduSessionsApi(client);
        final relaxApi = RelaxationApi(client);

        try {
          await eduApi.completeWeekSession(weekNumber: 4, totalStages: 12);
          if (context.mounted) {
            context.read<TodayTaskProvider>().setEducationWeekSessionLocally(
              weekNumber: 4,
              cbtDone: true,
              educationDoneWeek: true,
              lastEducationAt: DateTime.now(),
            );
          }
        } catch (e) {
          debugPrint('[Week4Final] edu-session 완료 처리 실패: $e');
        }

        bool isRelaxDone = false;
        try {
          isRelaxDone = await relaxApi.isWeekEducationTaskCompleted(4);
        } catch (e) {
          debugPrint('[Week4Final] relaxation 완료 조회 실패: $e');
        }

        if (!context.mounted) return;
        if (isRelaxDone) {
          Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
          return;
        }

        // ⛳ 팝업을 커스텀 디자인으로 교체 (로직 동일: 닫히면 다음 화면으로 이동)
        showCbtToRelaxationDialog(
          context: context,
          onMoveNow: () {
            Navigator.of(context).pop();
            Navigator.pushReplacementNamed(
              context,
              '/relaxation_education',
              arguments: {
                'taskId': 'week4_education',
                'weekNumber': 4,
                'mp3Asset': 'week4.mp3',
                'riveAsset': 'week4.riv',
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
