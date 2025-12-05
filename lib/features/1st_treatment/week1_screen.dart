// week1_screen.dart
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:gad_app_team/features/1st_treatment/week1_value_goal_screen.dart';
import 'package:gad_app_team/features/menu/education/education_screen.dart';


class Week1Screen extends StatefulWidget {
  final String? sessionId;
  const Week1Screen({super.key, this.sessionId});

  @override
  State<Week1Screen> createState() => _Week1ScreenState();
}

class _Week1ScreenState extends State<Week1Screen> {
  bool _creatingSession = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;

    // build 이후에 context.read 사용하려고 post frame으로 미룸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCreateEduSession();
    });
  }

  Future<void> _maybeCreateEduSession() async {
    if (!mounted) return;

    final user = context.read<UserProvider>();

    // 아직 유저 정보 안 들어왔으면 그냥 패스 (Splash에서 다시 들어오면 됨)
    if (!user.isUserLoaded) return;

    // 핵심 가치 없으면 Week1ValueGoalScreen으로 보낼 거라 세션 안 만듦
    final vg = user.valueGoal;
    final hasValueGoal = vg != null && vg.trim().isNotEmpty;
    if (!hasValueGoal) return;

    // 👉 이미 sessionId를 들고 들어온 경우: 새로 만들 필요 없음
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week1Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }

    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      const int totalScreens = 6;

      /// TODO: edu sessions  lastScreenIndex 어떻게 업데이트할지 정해야 함..
      /// 혹시 중요 페이지에서 필드 추가하는 거 외에... 마지막...탈출할 때만 인덱스 업데이트하는 게 가능할지...
      final res = await eduApi.createCommonSession(
        weekNumber: 1,
        totalScreens: totalScreens,
        lastScreenIndex: 1,        // 시작할 때는 1번 화면 기준
        completed: false,          // 시작 시점에는 미완료
        startTime: DateTime.now(), // 지금 시간
        endTime: null,
      );

      final String sessionId = (res['session_id'] as String).trim();

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = sessionId;
      });

      debugPrint('[Week1Screen] edu-sessions create 성공 (week=1)');
    } catch (e) {
      // 실패해도 교육 화면은 그냥 열고, 로그만 남김
      if (!mounted) return;
      debugPrint('[Week1Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    // 유저 정보 자체가 아직이면 로딩
    if (!user.isUserLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final vg = user.valueGoal;
    final hasValueGoal = vg != null && vg.trim().isNotEmpty;

    // 🔹 핵심 가치 없으면: Week1 가치/목표 입력 화면
    if (!hasValueGoal) {
      return Week1ValueGoalScreen(sessionId: _sessionId);
    }

    // 🔹 핵심 가치 있음: 1주차 교육 화면
    return EducationScreen(
      sessionId: _sessionId,
      isRelax: true,
    );
  }
}
