import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/5th_treatment/week5_final_screen.dart';
import 'package:gad_app_team/widgets/top_btm_card.dart';
import 'package:gad_app_team/widgets/thought_card.dart';
import 'package:gad_app_team/widgets/detail_popup.dart';
import 'package:gad_app_team/data/api/api_client.dart';
import 'package:gad_app_team/data/api/edu_sessions_api.dart';
import 'package:gad_app_team/data/storage/token_storage.dart';

class Week5VisualScreen extends StatefulWidget {
  final String? sessionId;
  final List<String> previousChips;     // 불안을 회피하는 행동
  final List<String> alternativeChips;  // 불안을 직면하는 행동

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

  Future<void> _saveSession() async {
    // 1) 이미 저장 중이면 바로 리턴
    if (_isSaving) {
      debugPrint('[Week5VisualScreen] 이미 저장 중입니다. 중복 저장 스킵');
      return;
    }

    // 2) sessionId 방어
    final sessionId = widget.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint(
        '[Week5VisualScreen] sessionId 없음 → edu-sessions 업데이트 스킵',
      );
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

  // 공통 팝업: 전체 칩 보여주기 (ThoughtBubble로)
  void _showChipsPopup({
    required String title,
    required List<String> chips,
    required ThoughtType thoughtType,
  }) {
    showDialog(
      context: context,
      builder: (_) => DetailPopup(
        title: title,
        positiveText: '돌아가기',
        negativeText: null,
        onPositivePressed: () => Navigator.pop(context),
        child: chips.isEmpty
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
          children: chips.map((text) {
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

  // 상단 패널: 불안을 회피하는 행동
  Widget _buildTopPanel() {
    return _buildThoughtSection(
      title: '불안을 회피하는 행동',
      chips: widget.previousChips,
      thoughtType: ThoughtType.unhelpful,
    );
  }

  // 하단 패널: 불안을 직면하는 행동
  Widget _buildBottomPanel() {
    return _buildThoughtSection(
      title: '불안을 직면하는 행동',
      chips: widget.alternativeChips,
      thoughtType: ThoughtType.helpful,
    );
  }

  /// chips가 3개 초과일 때는 3개만 보여주고 '자세히 보기'
  Widget _buildThoughtSection({
    required String title,
    required List<String> chips,
    required ThoughtType thoughtType,
  }) {
    final bool needMore = chips.length > 3;
    final List<String> preview = needMore ? chips.sublist(0, 3) : chips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThoughtCard(
          title: title,
          pills: preview,
          thoughtType: thoughtType,
          titleSize: 18,
          titleWeight: FontWeight.w600,
        ),
        if (needMore) ...[
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => _showChipsPopup(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ApplyDoubleCard(
      appBarTitle: '5주차 - 불안 직면 VS 회피',
      topChild: _buildTopPanel(),
      bottomChild: _buildBottomPanel(),
      onBack: () => Navigator.pop(context),
      onNext: () async {
        final nav = Navigator.of(context);
        await _saveSession();
        if (!mounted) return;
        nav.push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Week5FinalScreen(sessionId: widget.sessionId),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      pagePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      panelsGap: 24,
      panelPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      panelRadius: 20,
      maxWidth: 980,
      topcardColor: Colors.white,
      btmcardColor: Colors.white,
    );
  }
}
