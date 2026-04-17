import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/round_card.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/week7_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:provider/provider.dart';

class Week7FinalScreen extends StatefulWidget {
  final String? sessionId;

  const Week7FinalScreen({super.key, this.sessionId});

  @override
  State<Week7FinalScreen> createState() => _Week7FinalScreenState();
}

class _Week7FinalScreenState extends State<Week7FinalScreen> {
  late final ApiClient _apiClient;
  late final Week7Api _week7Api;
  bool _isCompleting = false;
  String? _sessionId;

  bool _isReviewMode(BuildContext context) {
    final user = context.watch<UserProvider>();
    return user.currentWeek > 7 ||
        (user.currentWeek == 7 && user.mainCbtCompleted);
  }

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(tokens: TokenStorage());
    _week7Api = Week7Api(_apiClient);
    _sessionId = widget.sessionId?.trim();
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      // 💡 배경색은 Stack에서 처리
      extendBodyBehindAppBar: true,

      appBar: const CustomAppBar(title: '생활 습관 개선'),

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
                                  _isReviewMode(context) ? '계획을 다시 점검하셨습니다!' : '계획을 완료하셨습니다!',
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
                                  '건강한 생활 습관을 꾸준히 실천하여\n더 나은 나를 만들어가세요.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ⛵ 네비게이션 버튼 (기존 로직 그대로 유지)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: NavigationButtons(
                    rightLabel: '완료',
                    onBack: () => Navigator.pop(context),
                    onNext:
                        _isCompleting ? null : () => _showStartDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🧘 이완 교육 다이얼로그 — CustomPopupDesign(확인 단일 버튼)
  void _showStartDialog(BuildContext context) async {
    final ctx = context;
    final nav = Navigator.of(ctx);
    final userProvider = ctx.read<UserProvider>();

    if (_isReviewMode(context)) {
      final todayTask = context.read<TodayTaskProvider>();
      final shouldShowRelaxReview =
          todayTask.isTreatmentReviewFlowForWeek(7) &&
          (userProvider.currentWeek > 7 ||
              (userProvider.currentWeek == 7 &&
                  userProvider.mainCbtCompleted &&
                  userProvider.mainRelaxCompleted));
      if (shouldShowRelaxReview) {
        showCbtReviewToRelaxationDialog(
          context: ctx,
          weekNumber: 7,
          onMoveNow: () {
            Navigator.of(ctx).pop();
            nav.pushReplacementNamed(
              '/relaxation_start',
              arguments: {
                'taskId': 'week7_education',
                'weekNumber': 7,
                'mp3Asset': 'week7.mp3',
                'riveAsset': 'week7.riv',
                'isReviewMode': true,
              },
            );
          },
          onFinish: () {
            todayTask.clearTreatmentReviewFlow();
            Navigator.of(ctx).pop();
            nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
          },
        );
        return;
      }

      if (!mounted) return;
      todayTask.clearTreatmentReviewFlow();
      Navigator.of(context).pushNamedAndRemoveUntil('/home_edu', (_) => false);
      return;
    }

    final sessionId = await _ensureSessionId();

    // 완료 상태 저장
    if (!_isCompleting) {
      setState(() => _isCompleting = true);
      try {
        await _week7Api.updateCompletion(
          sessionId: sessionId,
          completed: true,
          endTime: DateTime.now(),
          lastScreenIndex: 1,
          totalScreens: 1,
        );
        await userProvider.refreshProgress();
      } catch (e) {
        debugPrint('7주차 완료 상태 저장 실패: $e');
        // 에러가 발생해도 다음 화면으로 진행
      } finally {
        if (mounted) {
          setState(() => _isCompleting = false);
        }
      }
    }

    if (!mounted || !ctx.mounted) return;

    if (!mounted || !ctx.mounted) return;
    final shouldShowTransition = shouldShowCbtToRelaxationTransition(
      currentWeek: userProvider.currentWeek,
      mainRelaxCompleted: userProvider.mainRelaxCompleted,
      weekNumber: 7,
    );
    if (!shouldShowTransition) {
      context.read<TodayTaskProvider>().clearTreatmentReviewFlow();
      nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
      return;
    }

    showCbtToRelaxationDialog(
      context: ctx,
      weekNumber: 7,
      onMoveNow: () {
        nav.pop();
        nav.pushReplacementNamed(
          '/relaxation_start',
          arguments: {
            'taskId': 'week7_education',
            'weekNumber': 7,
            'mp3Asset': 'week7.mp3',
            'riveAsset': 'week7.riv',
            'isReviewMode':
                userProvider.currentWeek > 7 ||
                (userProvider.currentWeek == 7 &&
                    userProvider.mainRelaxCompleted),
          },
        );
      },
    );
  }

  Future<String> _ensureSessionId() async {
    if (_sessionId != null && _sessionId!.isNotEmpty) return _sessionId!;
    throw Exception('7주차 세션 ID를 확인할 수 없습니다.');
  }
}
