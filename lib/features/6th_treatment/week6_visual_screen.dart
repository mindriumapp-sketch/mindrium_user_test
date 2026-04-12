import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/thought_card.dart';
import 'package:gad_app_team/widgets/detail_popup.dart';
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/blue_banner.dart';
import 'package:gad_app_team/widgets/session_transition_dialog.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/api/relaxation_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';
import 'package:gad_app_team/data/today_task_provider.dart';
import 'package:provider/provider.dart';

class Week6VisualScreen extends StatefulWidget {
  final List<String> previousChips;
  final List<String> alternativeChips;

  const Week6VisualScreen({
    super.key,
    required this.previousChips,
    required this.alternativeChips,
  });

  @override
  State<Week6VisualScreen> createState() => _Week6VisualScreenState();
}

class _Week6VisualScreenState extends State<Week6VisualScreen> {
  Widget _buildSummaryPanel({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(28),
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
      child: child,
    );
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
    final displayText = chips.isEmpty ? '아직 입력한 내용이 없어요.' : chips.join('\n\n');
    final isHelpful = thoughtType == ThoughtType.helpful;
    final accentColor =
        isHelpful ? const Color(0xFF62BFE7) : const Color(0xFFF29B94);
    final softBgColor =
        isHelpful ? const Color(0xFFEAF8FF) : const Color(0xFFFFF1EF);
    final leadingIcon =
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

    const horizontalPadding = 24.0;
    const gapBetweenPanels = 20.0;
    final maxWidth = size.width - 48 > 980 ? 980.0 : size.width - 48;

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
                        _buildSummaryPanel(child: _buildTopPanel()),
                        const SizedBox(height: gapBetweenPanels),
                        _buildSummaryPanel(child: _buildBottomPanel()),
                        const SizedBox(height: 18),
                        const JellyfishBanner(
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
              onNext: () => _showStartDialog(context),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStartDialog(BuildContext context) async {
    final client = ApiClient(tokens: TokenStorage());
    final eduApi = EduSessionsApi(client);
    final relaxApi = RelaxationApi(client);

    try {
      await eduApi.completeWeekSession(weekNumber: 6, totalStages: 12);
      if (context.mounted) {
        context.read<TodayTaskProvider>().setEducationWeekSessionLocally(
          weekNumber: 6,
          cbtDone: true,
          educationDoneWeek: true,
          lastEducationAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[Week6Visual] edu-session 완료 처리 실패: $e');
    }

    bool isRelaxDone = false;
    try {
      isRelaxDone = await relaxApi.isWeekEducationTaskCompleted(6);
    } catch (e) {
      debugPrint('[Week6Visual] relaxation 완료 조회 실패: $e');
    }

    if (!context.mounted) return;
    final nav = Navigator.of(context);

    if (isRelaxDone) {
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
            'taskId': 'week6_education',
            'weekNumber': 6,
            'mp3Asset': 'week6.mp3',
            'riveAsset': 'week6.riv',
          },
        );
      },
    );
  }
}
