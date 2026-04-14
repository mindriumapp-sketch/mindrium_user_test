import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/thought_card.dart';
import 'package:gad_app_team/widgets/detail_popup.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/user_provider.dart';
import 'package:provider/provider.dart';

class Week5VisualScreen extends StatefulWidget {
  final String? sessionId;
  final List<String> previousChips; // 불안을 회피하는 행동
  final List<String> alternativeChips; // 불안을 직면하는 행동

  const Week5VisualScreen({
    super.key,
    required this.sessionId,
    required this.previousChips,
    required this.alternativeChips,
  });

  @override
  State<Week5VisualScreen> createState() => _Week5VisualScreenState();
}

class _Week5VisualScreenState extends State<Week5VisualScreen> {
  late final ApiClient _client;
  late final EduSessionsApi _eduSessionsApi;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _eduSessionsApi = EduSessionsApi(_client);
  }

  Future<void> _showStartDialog() async {
    final userProvider = context.read<UserProvider>();
    final nav = Navigator.of(context);

    try {
      await _eduSessionsApi.completeWeekSession(
        weekNumber: 5,
        totalStages: 8,
        sessionId: widget.sessionId,
      );
      await userProvider.refreshProgress();
    } catch (e) {
      debugPrint('[Week5Visual] edu-session 완료 처리 실패: $e');
    }

    if (!mounted) return;
    final shouldShowTransition = shouldShowCbtToRelaxationTransition(
      currentWeek: userProvider.currentWeek,
      mainRelaxCompleted: userProvider.mainRelaxCompleted,
      weekNumber: 5,
    );
    if (!shouldShowTransition) {
      nav.pushNamedAndRemoveUntil('/home_edu', (_) => false);
      return;
    }

    showCbtToRelaxationDialog(
      context: context,
      onMoveNow: () {
        nav.pop();
        nav.pushReplacementNamed(
          '/relaxation_education',
          arguments: {
            'sessionId': widget.sessionId,
            'taskId': 'week5_education',
            'weekNumber': 5,
            'mp3Asset': 'week5.mp3',
            'riveAsset': 'week5.riv',
          },
        );
      },
    );
  }

  Future<void> _saveSession() async {
    if (_isSaving) {
      debugPrint('[Week5VisualScreen] 이미 저장 중입니다. 중복 저장 스킵');
      return;
    }

    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('[Week5VisualScreen] sessionId 없음 → edu-sessions 업데이트 스킵');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _eduSessionsApi.updateEduSession(
        sessionId: sessionId,
        negativeItems: widget.previousChips,
        positiveItems: widget.alternativeChips,
      );
      debugPrint(
        '[Week5VisualScreen] edu-sessions 업데이트 완료 (sessionId=$sessionId)',
      );
    } catch (e, st) {
      debugPrint('[Week5VisualScreen] 세션 저장 실패: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showChipsPopup({
    required String title,
    required List<String> chips,
    required ThoughtType thoughtType,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => DetailPopup(
            title: title,
            positiveText: '돌아가기',
            negativeText: null,
            onPositivePressed: () => Navigator.pop(context),
            child:
                chips.isEmpty
                    ? const Text(
                      '입력된 항목이 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF356D91),
                      ),
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          chips.map((text) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ThoughtBubble(
                                text: text,
                                type: thoughtType,
                              ),
                            );
                          }).toList(),
                    ),
          ),
    );
  }

  Widget _buildTopPanel() {
    return _buildThoughtSection(
      title: '불안을 직면하는 행동',
      chips: widget.alternativeChips,
      thoughtType: ThoughtType.helpful,
    );
  }

  Widget _buildBottomPanel() {
    return _buildThoughtSection(
      title: '불안을 회피하는 행동',
      chips: widget.previousChips,
      thoughtType: ThoughtType.unhelpful,
    );
  }

  Widget _buildThoughtSection({
    required String title,
    required List<String> chips,
    required ThoughtType thoughtType,
  }) {
    final String displayText =
        chips.isEmpty ? '아직 입력한 내용이 없어요.' : chips.join('\n\n');
    final bool isHelpful = thoughtType == ThoughtType.helpful;
    final Color accentColor =
        isHelpful ? const Color(0xFF62BFE7) : const Color(0xFFF29B94);
    final Color softBgColor =
        isHelpful ? const Color(0xFFEAF8FF) : const Color(0xFFFFF1EF);
    final IconData leadingIcon =
        isHelpful ? Icons.chat_bubble_rounded : Icons.error_outline_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C4A7A),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: softBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(leadingIcon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isHelpful ? '내가 적은 불안을 직면하는 행동' : '내가 적은 불안을 회피하는 행동',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.65,
                  fontWeight: chips.isEmpty ? FontWeight.w500 : FontWeight.w700,
                  color:
                      chips.isEmpty
                          ? const Color(0xFF8AA0B4)
                          : const Color(0xFF243B53),
                ),
              ),
              if (chips.length > 3) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed:
                        () => _showChipsPopup(
                          title: title,
                          chips: chips,
                          thoughtType: thoughtType,
                        ),
                    child: const Text(
                      '자세히 보기',
                      style: TextStyle(
                        color: Color(0xFF626262),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double horizontalPadding = 24.0;
    const double panelRadius = 28.0;
    const double gapBetweenPanels = 20.0;
    final double maxWidth = size.width - 48 > 980 ? 980 : size.width - 48;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: '행동 구분 연습',
        confirmOnBack: false,
        showHome: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE7F7FF), Color(0xFFF5FCFF)],
                ),
              ),
            ),
            Opacity(
              opacity: 0.20,
              child: Image.asset(
                'assets/image/eduhome.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            Container(color: Colors.white.withValues(alpha: 0.08)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    bottomInset + 120,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(panelRadius),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.82),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                          child: _buildTopPanel(),
                        ),
                        const SizedBox(height: gapBetweenPanels),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(panelRadius),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.82),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                          child: _buildBottomPanel(),
                        ),
                        const SizedBox(height: 18),
                        JellyfishBanner(
                          message:
                              '오늘도 수고하셨습니다!\n내가 적은 행동을 한 번 더 비교해보며,\n어떤 방향이 불안을 줄이는 데 도움이 되는지 살펴보세요.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
            child: NavigationButtons(
              leftLabel: '이전',
              rightLabel: '다음',
              onBack: () => Navigator.pop(context),
              onNext: () async {
                await _saveSession();
                if (!mounted) return;
                await _showStartDialog();
              },
            ),
          ),
        ),
      ),
    );
  }
}
