import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/session_start.dart';
import 'package:gad_app_team/features/6th_treatment/week6_abc_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week6Screen extends StatefulWidget {
  final String? sessionId;
  final bool isReviewMode;

  const Week6Screen({super.key, this.sessionId, this.isReviewMode = false});

  @override
  State<Week6Screen> createState() => _Week6ScreenState();
}

class _Week6ScreenState extends State<Week6Screen> {
  bool _creatingSession = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isReviewMode) {
        _maybeCreateEduSession();
      }
    });
  }

  Future<void> _maybeCreateEduSession() async {
    if (!mounted) return;
    final user = context.read<UserProvider>();
    if (!user.isUserLoaded) return;
    if (widget.isReviewMode) return;

    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week6Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }
    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final access = await tokens.access;
      if (access == null) {
        debugPrint('[Week6Screen] access token 없음 → edu-session 생성 스킵');
        setState(() => _creatingSession = false);
        return;
      }

      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      const int totalStages = 12;

      final res = await eduApi.createCommonSession(
        weekNumber: 6,
        totalStages: totalStages,
        lastStageIndex: 1,
        completed: false,
        startTime: DateTime.now(),
        endTime: null,
      );

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = (res['session_id'] as String?)?.trim();
      });

      debugPrint(
        '[Week6Screen] edu-sessions create 성공 (week=6, id=$_sessionId)',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week6Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final String? abcId = args['abcId'] as String?;
    final weekDescription =
        widget.isReviewMode
            ? '6주차에서는 내 행동을 점검하고 불안에 도움이 되도록 바꾸는 연습을 했어요. 작성한 걱정일기의 내용을 바탕으로 복습해보겠습니다.'
            : '이번 주차에서는 내 행동을 점검하고 불안에 도움이 되도록 바꿔보겠습니다. 작성한\n걱정일기의 내용을 살펴볼게요.';

    return SessionStartScreen(
      weekNumber: 6,
      isReviewMode: widget.isReviewMode,
      weekTitle: '걱정일기 속 행동을 점검해보겠습니다.',
      weekDescription: weekDescription,
      nextPageBuilder: () => Week6AbcScreen(abcId: abcId),
    );
  }
}
