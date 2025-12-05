import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/value_start.dart';
import 'package:gad_app_team/features/5th_treatment/week5_guide_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week5Screen extends StatefulWidget {
  final String? sessionId;

  const Week5Screen({
    super.key,
    this.sessionId,
  });

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

    // build 이후에 context.read 쓰려고 post-frame으로 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCreateEduSession();
    });
  }

  Future<void> _maybeCreateEduSession() async {
    if (!mounted) return;

    // ✅ async 전에만 context.read → across async gap 방지
    final user = context.read<UserProvider>();

    // 아직 유저 정보 안 들어왔으면 그냥 패스
    if (!user.isUserLoaded) return;

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

      // ⚠️ 실제 week5 플로우에 맞게 수정 가능
      const int totalScreens = 12;

      // Week3랑 같은 계열이면 이 메소드 있을 가능성 큼
      final res = await eduApi.createWeek3or5Session(
        weekNumber: 5,
        totalScreens: totalScreens,
        lastScreenIndex: 1,        // Week5Screen 진입 시 = 1번 화면
        completed: false,          // 아직 미완료
        startTime: DateTime.now(), // 지금 시간
        endTime: null,
      );

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = res['session_id'];
      });

      debugPrint('[Week5Screen] edu-sessions create 성공 (week=5, id=$_sessionId)');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week5Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueStartScreen(
      weekNumber: 5,
      weekTitle: '불안 직면과 회피에 대해 알아보겠습니다.',
      weekDescription:
      '이번 주차에서는 불안을 직면하는 것과 회피하는 것의 차이점을 배워보겠습니다. 성인 여성의 상황을 예시로 살펴볼게요.',
      nextPageBuilder: () => Week5GuideScreen(
        sessionId: _sessionId,
      ),
    );
  }
}
