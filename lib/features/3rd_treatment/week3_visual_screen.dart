// lib/features/3rd_treatment/week3_visual_screen.dart

import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/widgets/thought_card.dart'; // ThoughtCard / ThoughtType
import 'package:gad_app_team/widgets/navigation_button.dart';
import 'package:gad_app_team/widgets/custom_appbar.dart';
import 'package:gad_app_team/widgets/blue_banner.dart'; // JellyfishBanner
import 'package:gad_app_team/widgets/custom_popup_design.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week3VisualScreen extends StatefulWidget {
  final String? sessionId;
  final List<String> previousChips; // 도움이 되지 않는 생각
  final List<String> alternativeChips; // 도움이 되는 생각

  const Week3VisualScreen({
    super.key,
    required this.sessionId,
    required this.previousChips,
    required this.alternativeChips,
  });

  @override
  State<Week3VisualScreen> createState() => _Week3VisualScreenState();
}

class _Week3VisualScreenState extends State<Week3VisualScreen> {
  late final ApiClient _client;
  late final EduSessionsApi _eduSessionsApi;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(tokens: TokenStorage());
    _eduSessionsApi = EduSessionsApi(_client);
  }

  void _showStartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => CustomPopupDesign(
            title: '이완 음성 안내 시작',
            message: '잠시 후, 이완을 위한 음성 안내가 시작됩니다.\n주변 소리와 음량을 조절해보세요.',
            positiveText: '확인',
            negativeText: null,
            backgroundAsset: null,
            iconAsset: null,
            onPositivePressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(
                context,
                '/relaxation_education',
                arguments: {
                  'sessionId': widget.sessionId,
                  'taskId': 'week3_education',
                  'weekNumber': 3,
                  'mp3Asset': 'week1.mp3',
                  'riveAsset': 'week1.riv',
                },
              );
            },
          ),
    );
  }

  Future<void> _saveSession() async {
    // 1) 이미 저장 중이면 바로 리턴
    if (_isSaving) {
      debugPrint('[Week3VisualScreen] 이미 저장 중입니다. 중복 저장 스킵');
      return;
    }

    // 2) sessionId 방어
    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('[Week3VisualScreen] sessionId 없음 → edu-sessions 업데이트 스킵');
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
        '[Week3VisualScreen] edu-sessions 업데이트 완료 (sessionId=$sessionId)',
      );
    } catch (e, st) {
      debugPrint('[Week3VisualScreen] 세션 저장 실패: $e\n$st');
      // 실패해도 화면 흐름은 막지 않되, 유저에게만 알려주고 싶으면 여기서 BlueBanner 추가 가능
      // if (mounted) {
      //   BlueBanner.show(
      //     context,
      //     '세션 저장 중 문제가 발생했어요.\n나중에 다시 시도해 주세요.',
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // 상단 패널: 도움이 되는 생각
  Widget _buildTopPanel() {
    return _buildThoughtSection(
      title: '도움이 되는 생각',
      chips: widget.alternativeChips,
      thoughtType: ThoughtType.helpful,
    );
  }

  // 하단 패널: 도움이 되지 않는 생각
  Widget _buildBottomPanel() {
    return _buildThoughtSection(
      title: '도움이 되지 않는 생각',
      chips: widget.previousChips,
      thoughtType: ThoughtType.unhelpful,
    );
  }

  /// chips가 3개 초과일 때는 3개만 보여주고 '자세히 보기'
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
                      isHelpful ? '내가 적은 도움이 되는 생각' : '내가 적은 도움이 되지 않는 생각',
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
      extendBody: true, // ✅ bottomNavigationBar 뒤까지 확장
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: '생각 구분 연습',
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

            // 🧩 내용 영역
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    bottomInset + 120, // 아래 버튼 자리 확보
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 상단 카드 (도움이 되는 생각)
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

                        // 하단 카드 (도움이 되지 않는 생각)
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
                              '오늘도 수고하셨습니다!\n내가 적은 생각을 한 번 더 비교해보며,\n어떤 방향이 마음을 더 안정시키는지 살펴보세요.',
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

      // ✅ 화면 맨 아래 고정 네비게이션 버튼
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
                _showStartDialog();
              },
            ),
          ),
        ),
      ),
    );
  }
}
