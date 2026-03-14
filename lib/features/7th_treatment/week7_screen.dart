import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/session_start.dart';
import 'package:gad_app_team/features/7th_treatment/week7_add_display_screen.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/week7_api.dart';
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
  late final Week7Api _week7Api;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _week7Api = Week7Api(ApiClient(tokens: TokenStorage()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeEnsureWeek7Session();
    });
  }

  Future<void> _maybeEnsureWeek7Session() async {
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
      // 1) 기존 세션 있는지 확인
      final existing = await _week7Api.fetchWeek7Session();
      final existingId =
          existing?['session_id']?.toString() ??
          existing?['sessionId']?.toString();
      if (existingId != null && existingId.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _sessionId = existingId;
          _creatingSession = false;
        });
        debugPrint('[Week7Screen] 기존 week7 세션 사용: $existingId');
        return;
      }

      const int totalScreens = 10; // 실제 플로우에 맞게 조정

      // 2) 없으면 새로 생성
      final res = await _week7Api.createWeek7Session(
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

      debugPrint('[Week7Screen] week7 세션 생성 성공 (id=$_sessionId)');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week7Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionStartScreen(
      weekNumber: 7,
      weekTitle: '생활 습관을 개선해보겠습니다.',
      weekDescription:
          '이번 주차에서는 일상생활에서 \n불안을 관리할 수 있는 생활 습관을 개선해보겠습니다. \nTo do list를 통해 체계적으로 관리해보세요.',
      nextPageBuilder: () => Week7AddDisplayScreen(),
    );
  }
}
