import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/round_card.dart';
import 'package:gad_app_team/widgets/jellyfish_notice.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/week7_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:provider/provider.dart';

class Week7FinalScreen extends StatefulWidget {
  const Week7FinalScreen({super.key});

  @override
  State<Week7FinalScreen> createState() => _Week7FinalScreenState();
}

class _Week7FinalScreenState extends State<Week7FinalScreen> {
  late final ApiClient _apiClient;
  late final Week7Api _week7Api;
  late final RelaxationApi _relaxationApi;
  bool _isCompleting = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(tokens: TokenStorage());
    _week7Api = Week7Api(_apiClient);
    _relaxationApi = RelaxationApi(_apiClient);
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
                                  'assets/image/congrats.png',
                                  width: 126,
                                  height: 126,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 18),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9F7FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '7주차 행동 계획 완료',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D6F96),
                                      fontFamily: 'Noto Sans KR',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 🔢 결과 텍스트
                                Text(
                                  '이번 주 계획을 세웠어요!\n정말 잘하셨어요',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                    color: Colors.black87,
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '한 주 동안 완벽하게 하려고 하기보다,\n불안한 순간마다 한 번씩 실천해보아요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.45,
                                    color: Color(0xFF2F3E4E),
                                    fontFamily: 'Noto Sans KR',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const JellyfishNotice(
                            feedback: '작게 시작해도 괜찮아요.\n불안한 상황에서 내가 정한 행동을\n차근차근 실천해봅시다!',
                            feedbackColor: Color(0xFF35546D),
                            textAlign: TextAlign.left,
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
    String sessionId;
    try {
      sessionId = await _ensureSessionId();
    } catch (e) {
      debugPrint('[Week7Final] session_id 확보 실패: $e');
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('세션 정보를 불러오지 못했습니다. 다시 시도해주세요.')),
        );
      }
      return;
    }

    // 완료 상태 저장
    if (!_isCompleting) {
      setState(() => _isCompleting = true);
      try {
        await _week7Api.updateCompletion(
          sessionId: sessionId,
          completed: true,
          endTime: DateTime.now(),
          lastScreenIndex: 0,
          totalScreens: 1,
        );
        if (ctx.mounted) {
          ctx.read<TodayTaskProvider>().setEducationWeekSessionLocally(
            weekNumber: 7,
            cbtDone: true,
            educationDoneWeek: true,
            lastEducationAt: DateTime.now(),
          );
        }
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

    bool isRelaxDone = false;
    try {
      isRelaxDone = await _relaxationApi.isWeekEducationTaskCompleted(7);
    } catch (e) {
      debugPrint('[Week7Final] relaxation 완료 조회 실패: $e');
    }

    if (!mounted || !ctx.mounted) return;
    if (isRelaxDone) {
      nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
      return;
    }

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder:
          (_) => CustomPopupDesign(
            title: '이완 연습 이어서 하기',
            message: '오늘 학습을 잘 마쳤어요.\n이완 연습까지 이어서 진행해볼까요?',
            positiveText: '이어하기',
            autoPositiveAfter: const Duration(seconds: 10),
            negativeText: null,
            backgroundAsset: null,
            iconAsset: null,
            onPositivePressed: () {
              nav.pop();
              nav.pushReplacementNamed(
                '/relaxation_education',
                arguments: {
                  'taskId': 'week7_education',
                  'weekNumber': 7,
                  'mp3Asset': 'week7.mp3',
                  'riveAsset': 'week7.riv',
                },
              );
            },
          ),
    );
  }

  Future<String> _ensureSessionId() async {
    if (_sessionId != null && _sessionId!.isNotEmpty) return _sessionId!;

    try {
      final existing = await _week7Api.fetchWeek7Session();
      final existingId =
          existing?['session_id']?.toString() ??
          existing?['sessionId']?.toString();
      if (existingId != null && existingId.isNotEmpty) {
        _sessionId = existingId;
        return existingId;
      }
    } catch (e) {
      // 기존 세션 조회가 500이어도 신규 세션 생성으로 복구 시도
      debugPrint('[Week7Final] 기존 세션 조회 실패, 신규 생성 시도: $e');
    }

    final created = await _week7Api.createWeek7Session(
      totalScreens: 1,
      lastScreenIndex: 0,
      startTime: DateTime.now(),
      completed: false,
    );
    final createdId =
        created['session_id']?.toString() ?? created['sessionId']?.toString();
    if (createdId == null || createdId.isEmpty) {
      throw Exception('7주차 세션 ID를 확인할 수 없습니다.');
    }
    _sessionId = createdId;
    return createdId;
  }
}
