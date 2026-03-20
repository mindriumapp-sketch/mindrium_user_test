import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/features/session_start.dart';

// ✅ edu_sessions create용 import
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

/// 🌊 2주차 시작 화면 (핵심 가치 + 활동 안내)
class Week2Screen extends StatefulWidget {
  final String? sessionId;
  const Week2Screen({super.key, this.sessionId});

  @override
  State<Week2Screen> createState() => _Week2ScreenState();
}

class _Week2ScreenState extends State<Week2Screen> {
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

    // ✅ async 이전에만 context.read 사용 → "across async gap" 경고 대상 아님
    final user = context.read<UserProvider>();

    // 아직 유저 정보 안 들어왔으면 그냥 패스
    if (!user.isUserLoaded) return;

    // 이미 이 위젯 생명주기에서 한 번 만들었으면 또 안 함
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      debugPrint('[Week2Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }

    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      // TODO: 실제 2주차 교육 슬라이드 수에 맞게 totalStages 수정
      const int totalStages = 15;

      final res = await eduApi.createCommonSession(
        weekNumber: 2,
        totalStages: totalStages,
        lastStageIndex: 1, // 시작 시 1번 화면
        completed: false, // 시작 시점에는 미완료
        startTime: DateTime.now(), // 지금 시간
        endTime: null,
      );

      final String sessionId = (res['session_id'] as String).trim();

      if (!mounted) return;
      setState(() {
        _creatingSession = false;
        _sessionId = sessionId;
      });

      debugPrint('[Week2Screen] edu-sessions create 성공 (week=2)');
    } catch (e) {
      // 실패해도 그냥 로그만 남기고 UI는 그대로 진행
      if (!mounted) return;
      debugPrint('[Week2Screen] edu-sessions create 실패: $e');
      setState(() => _creatingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionStartScreen(
      weekNumber: 2,
      weekTitle: 'ABC 모델을 통해\n불안을 기록해보겠습니다.',
      weekDescription:
          '이번 주차에서는 불안이 발생하는 상황을 A(사건), B(생각), C(결과)로 나누어 분석하는 ABC 모델을 배워보겠습니다.',
      mergeValueAndGuide: true,
      nextPageBuilder: () => AbcGuideScreen(sessionId: _sessionId),
    );
  }
}
