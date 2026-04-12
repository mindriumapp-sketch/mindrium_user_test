import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
// import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/round_card.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/week8_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week8FinalScreen extends StatefulWidget {
  const Week8FinalScreen({super.key});

  @override
  State<Week8FinalScreen> createState() => _Week8FinalScreenState();
}

class _Week8FinalScreenState extends State<Week8FinalScreen> {
  late final ApiClient _apiClient;
  late final Week8Api _week8Api;
  bool _isSavingCompletion = false;
  String? _sessionId;
  static const int _totalScreens = 10;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(tokens: TokenStorage());
    _week8Api = Week8Api(_apiClient);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 배경색은 Stack에서 처리
      extendBodyBehindAppBar: true,

      appBar: const CustomAppBar(title: '인지 재구성'),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌊 Mindrium 공통 배경 (ApplyDesign 스타일)
          Container(
            color: Colors.white,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ───────── 결과 카드 (Week5 스타일 적용)
                          RoundCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 36,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🎉 축하/결과 이미지
                                Image.asset(
                                  'assets/image/congrats.png', // 필요 시 nice.png로 교체 가능 (로직 영향 없음)
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 22),

                                // 🔢 결과 텍스트
                                Text(
                                  '수고하셨습니다!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '8주간의 여정을 완주하셨습니다!\n앞으로도 꾸준히 자신을 돌보세요!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                              ]
                            )
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                // ⛵ 네비게이션 버튼 (기존 로직 그대로 유지)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
child: NavigationButtons(
                    onBack: () => Navigator.pop(context),
                    // onNext: () => _showStartDialog(context),
                    onNext: _isSavingCompletion ? null : _saveCompletionAndExit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompletionAndExit() async {
    if (_isSavingCompletion) return;
    setState(() => _isSavingCompletion = true);

    try {
      final sessionId = await _ensureSessionId();
      await _week8Api.updateCompletion(
        sessionId: sessionId,
        completed: true,
        endTime: DateTime.now(),
        lastScreenIndex: _totalScreens,
        totalScreens: _totalScreens,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home_edu',
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      BlueBanner.show(context, '8주차 완료 상태 저장에 실패했습니다: $e');
      setState(() => _isSavingCompletion = false);
    }
  }

  Future<String> _ensureSessionId() async {
    if (_sessionId != null && _sessionId!.isNotEmpty) return _sessionId!;

    final existing = await _week8Api.fetchWeek8Session();
    _sessionId =
        existing?['session_id']?.toString() ?? existing?['sessionId']?.toString();
    if (_sessionId != null && _sessionId!.isNotEmpty) return _sessionId!;

    final created = await _week8Api.createWeek8Session(
      totalScreens: _totalScreens,
      lastScreenIndex: 1,
      startTime: DateTime.now(),
      completed: false,
    );
    _sessionId =
        created['session_id']?.toString() ?? created['sessionId']?.toString();

    if (_sessionId == null || _sessionId!.isEmpty) {
      throw Exception('8주차 세션 ID를 확인할 수 없습니다.');
    }
    return _sessionId!;
  }
}
