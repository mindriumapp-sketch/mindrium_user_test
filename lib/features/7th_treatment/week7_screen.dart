import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/value_start.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week7Screen extends StatefulWidget {
  final String? sessionId;
  const Week7Screen({super.key, this.sessionId});

  @override
  State<Week7Screen> createState() => _Week7ScreenState();
}

class _Week7ScreenState extends State<Week7Screen> {
  bool _creatingSession = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCreateEduSession();
    });
  }

  Future<void> _maybeCreateEduSession() async {
    if (!mounted) return;
    final user = context.read<UserProvider>();
    if (!user.isUserLoaded) return;

    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week7Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }
    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final access = await tokens.access;
      if (access == null) {
        debugPrint('[Week7Screen] access token 없음 → edu-session 생성 스킵');
        setState(() => _creatingSession = false);
        return;
      }

      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      const int totalScreens = 10; // 실제 플로우에 맞게 조정

      final res = await eduApi.createCommonSession(
        weekNumber: 7,
        totalScreens: totalScreens,
        lastScreenIndex: 1,
        completed: false,
        startTime: DateTime.now(),
        endTime: null,
      );

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = (res['session_id'] as String?)?.trim();
      });

      debugPrint('[Week7Screen] edu-sessions create 성공 (week=7, id=$_sessionId)');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week7Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueStartScreen(
      weekNumber: 7,
      weekTitle: '생활 습관을 개선해보겠습니다.',
      weekDescription:
          '이번 주차에서는 일상생활에서 \n불안을 관리할 수 있는 생활 습관을 개선해보겠습니다. \nTo do list를 통해 체계적으로 관리해보세요.',
      nextPageBuilder: () => Week7AddDisplayScreen(),
    );
  }
}
