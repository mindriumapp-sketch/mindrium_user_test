import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';

class Week2FinalScreen extends StatefulWidget {
  final String? sessionId;

  const Week2FinalScreen({super.key, this.sessionId});

  @override
  State<Week2FinalScreen> createState() => _Week2FinalScreenState();
}

class _Week2FinalScreenState extends State<Week2FinalScreen> {
  bool _isCompleting = false;

  Future<void> _onNextPressed() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final client = ApiClient(tokens: TokenStorage());
    final eduApi = EduSessionsApi(client);
    final userProvider = context.read<UserProvider>();
    try {
      await eduApi.completeWeekSession(
        weekNumber: 2,
        totalStages: 15,
        sessionId: widget.sessionId,
      );
      await userProvider.refreshProgress();
    } catch (e) {
      debugPrint('[Week2Final] edu-session 완료 처리 실패: $e');
    }

    if (!mounted) return;
    final shouldShowTransition = shouldShowCbtToRelaxationTransition(
      currentWeek: userProvider.currentWeek,
      mainRelaxCompleted: userProvider.mainRelaxCompleted,
      weekNumber: 2,
    );
    if (!shouldShowTransition) {
      Navigator.pushNamedAndRemoveUntil(context, '/home_edu', (_) => false);
      return;
    }

    showCbtToRelaxationDialog(
      context: context,
      onMoveNow: () {
        Navigator.of(context).pop();
        Navigator.pushReplacementNamed(
          context,
          '/relaxation_education',
          arguments: {
            'sessionId': widget.sessionId,
            'taskId': 'week2_education',
            'weekNumber': 2,
            'mp3Asset': 'week2.mp3',
            'riveAsset': 'week2.riv',
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ApplyDesign(
      appBarTitle: 'ABC 모델',
      cardTitle: '불안 일기 작성 완료',
      onBack: () => Navigator.pop(context),
      onNext: _isCompleting ? null : _onNextPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/image/congrats.png',
            height: 160,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 20),
          const Text(
            '수고하셨습니다.\n오늘의 ABC 일기를 완료했어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.5,
              fontFamily: 'Noto Sans KR',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '이제부터 불안을 느낄 때면 차분히 일기를 써 보세요.', // TODO:임시
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3D4C6C),
              height: 1.5,
              fontFamily: 'Noto Sans KR',
            ),
          ),
        ],
      ),
    );
  }
}
