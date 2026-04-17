import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/session_start.dart';
import 'package:gad_app_team/features/5th_treatment/week5_classification_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week5Screen extends StatefulWidget {
  final String? sessionId;
  final bool isReviewMode;

  const Week5Screen({super.key, this.sessionId, this.isReviewMode = false});

  @override
  State<Week5Screen> createState() => _Week5ScreenState();
}

class _Week5ScreenState extends State<Week5Screen> {
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

    // ✅ async 전에만 context.read → across async gap 방지
    final user = context.read<UserProvider>();

    // 아직 유저 정보 안 들어왔으면 그냥 패스
    if (!user.isUserLoaded) return;
    if (widget.isReviewMode) return;

    // 이미 sessionId 있으면 그대로 사용
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week5Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }

    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final access = await tokens.access;
      if (access == null) {
        debugPrint('[Week5Screen] access token 없음 → edu-session 생성 스킵');
        setState(() => _creatingSession = false);
        return;
      }

      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      // ValueStart → Classification → Result → Explain → Imagination → ConfrontAnxiety → Visual → 이완
      const int totalStages = 8;

      // Week3랑 같은 계열이면 이 메소드 있을 가능성 큼
      final res = await eduApi.createWeek3or5Session(
        weekNumber: 5,
        totalStages: totalStages,
        lastStageIndex: 1, // Week5Screen 진입 시 = 1번 화면
        completed: false, // 아직 미완료
        startTime: DateTime.now(), // 지금 시간
        endTime: null,
      );

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = res['session_id'];
      });

      debugPrint(
        '[Week5Screen] edu-sessions create 성공 (week=5, id=$_sessionId)',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week5Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDescription =
        widget.isReviewMode
            ? '5주차에서는 불안을 직면하는 것과 회피하는 것의 차이를 배웠어요.\n이번에는 그 내용을 복습해보겠습니다.'
            : '이번 주차에서는 불안을 직면하는 것과\n회피하는 것의 차이점을 구분해보겠습니다.';

    return SessionStartScreen(
      weekNumber: 5,
      isReviewMode: widget.isReviewMode,
      weekTitle: '불안 직면과 회피에 대해 알아보겠습니다.',
      weekDescription: weekDescription,
      nextPageBuilder: () => Week5ClassificationScreen(sessionId: _sessionId),
    );
  }
}
