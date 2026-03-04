import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/2nd_treatment/abc_guide_screen.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:gad_app_team/widgets/tutorial_design.dart';

// ✅ edu_sessions create용 import
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:provider/provider.dart';
import 'package:gad_app_team/data/user_provider.dart';

/// 🌊 ApplyDesign 스타일이 입혀진 2주차 시작 화면
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
      debugPrint('[Week1Screen] 기존 sessionId 그대로 사용: $_sessionId');
      return;
    }

    if (_creatingSession) return;
    setState(() => _creatingSession = true);

    try {
      final tokens = TokenStorage();
      final client = ApiClient(tokens: tokens);
      final eduApi = EduSessionsApi(client);

      // TODO: 실제 2주차 교육 슬라이드 수에 맞게 totalScreens 수정
      const int totalScreens = 15;

      final res = await eduApi.createCommonSession(
        weekNumber: 2,
        totalScreens: totalScreens,
        lastScreenIndex: 1,        // 시작 시 1번 화면
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
    // 🛡️ Week1 패턴 맞춰서: 유저 정보 극초기 미로딩 방어
    final user = context.watch<UserProvider>();
    if (!user.isUserLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ApplyDesign(
      appBarTitle: '2주차 시작',
      cardTitle: '2주차 시작 ✨',
      onBack: null,
      onNext: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AbcGuideScreen(sessionId: _sessionId)),
        );
      },

      /// 🧾 기존 내용(child) 그대로 유지
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.psychology_alt,
            size: 62,
            color: Color(0xFF3F51B5),
          ),
          const SizedBox(height: 20),
          Text(
            protectKoreanWords('ABC 모델을 통해 불안의 원인을\n분석해보겠습니다.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            protectKoreanWords(
              '이번 주차에서는 불안이 발생하는 상황을 '
              'A(사건), B(생각), C(결과)로 나누어 분석하는 ABC 모델을 배워보겠습니다.\n\n'
              '자전거를 타려고 했을 때의 상황을 예시로 살펴볼게요.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
