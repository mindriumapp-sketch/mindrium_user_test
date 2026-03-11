import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/session_start.dart';
import 'package:gad_app_team/features/8th_treatment/week8_roadmap_screen.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/week8_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

class Week8Screen extends StatefulWidget {
  final String? sessionId;
  const Week8Screen({super.key, this.sessionId});

  @override
  State<Week8Screen> createState() => _Week8ScreenState();
}

class _Week8ScreenState extends State<Week8Screen> {
  bool _creatingSession = false;
  String? _sessionId;
  String? _userName;
  late final Week8Api _week8Api;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _week8Api = Week8Api(ApiClient(tokens: TokenStorage()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeEnsureWeek8Session();
    });
  }

  Future<void> _maybeEnsureWeek8Session() async {
    if (!mounted) return;
    final user = context.read<UserProvider>();
    if (!user.isUserLoaded) return;
    setState(() => _userName = user.userName);

    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week8Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }
    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      // 기존 세션 사용
      final existing = await _week8Api.fetchWeek8Session();
      final existingId =
          existing?['session_id']?.toString() ??
          existing?['sessionId']?.toString();
      if (existingId != null && existingId.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _creatingSession = false;
          _sessionId = existingId;
        });
        debugPrint('[Week8Screen] 기존 week8 세션 사용: $existingId');
        return;
      }

      const int totalScreens = 10; // 실제 플로우에 맞게 조정

      final res = await _week8Api.createWeek8Session(
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

      debugPrint('[Week8Screen] week8 세션 생성 성공 (id=$_sessionId)');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Week8Screen] week8 세션 처리 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDescription =
        _userName != null
            ? '$_userName님의 8주간 여정을 진심으로 축하드립니다. Mindrium 교육 프로그램을 모두 완료하셨습니다. 이제 불안을 효과적으로 관리할 수 있는 다양한 기법들을 익히셨습니다.\n지금까지 달려온 과정을 미처 인식하지 못할 수도 있지만, 이 모든 성과는 오직 $_userName님께서 스스로 이루어낸 것입니다.'
            : '8주간의 여정을 진심으로 축하드립니다. Mindrium 교육 프로그램을 모두 완료하셨습니다. 이제 불안을 효과적으로 관리할 수 있는 다양한 기법들을 익히셨습니다. 지금까지 달려온 과정을 미처 인식하지 못할 수도 있지만, 이 모든 성과는 오직 당신께서 스스로 이루어낸 것입니다.';

    return SessionStartScreen(
      weekNumber: 8,
      weekTitle: 'Mindrium 교육 프로그램을\n모두 완료하셨습니다!',
      weekDescription: weekDescription,
      nextPageBuilder: () => const Week8RoadmapScreen(),
    );
  }
}

// 8주차 완료 화면 (임시)
class Week8CompletionScreen extends StatelessWidget {
  const Week8CompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: '프로그램 완료'),
      body: const Center(
        child: Text(
          '8주차 프로그램이 완료되었습니다!\n축하합니다!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
