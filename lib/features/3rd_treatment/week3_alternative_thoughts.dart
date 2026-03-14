import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/utils/text_line_utils.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_visual_screen.dart';

// ⭐ 5주차에서 썼던 더블 카드 레이아웃
import 'package:gad_app_team/widgets/top_btm_card.dart';

class Week3AlternativeThoughtsScreen extends StatefulWidget {
  final String? sessionId;
  final List<String> previousChips;

  const Week3AlternativeThoughtsScreen({
    super.key,
    required this.sessionId,
    required this.previousChips,
  });

  @override
  State<Week3AlternativeThoughtsScreen> createState() =>
      _Week3AlternativeThoughtsScreenState();
}

class _Week3AlternativeThoughtsScreenState
    extends State<Week3AlternativeThoughtsScreen> {
  final TextEditingController _textController = TextEditingController();
  String _inputText = '';

  void _onTextChanged(String value) {
    setState(() => _inputText = value.trim());
  }

  // ───────── 상단 카드 내용 ─────────
  Widget _buildTopPanel() {
    // 앞 화면에서 입력한 불안한 생각을 가져옵니다.
    final String negativeThought =
        widget.previousChips.isNotEmpty ? widget.previousChips.join(', ') : '';

    return SizedBox(
      height: 150, // 위쪽 카드 높이 통일
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '도움이 되는 생각으로 바꿔보세요',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF263C69),
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            protectKoreanWords(
              negativeThought.isNotEmpty
                  ? '앞에서 떠올린 "$negativeThought" 같은 불안한 생각을 바탕으로,\n도움이 되는 생각을 편하게 적어보세요.'
                  : '앞에서 떠올린 불안한 생각을 바탕으로,\n도움이 되는 생각을 편하게 적어보세요.',
            ),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w200,
              height: 1.45,
              color: Colors.black87,
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ───────── 하단 카드 내용 ─────────
  Widget _buildBottomPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF8ED8F8).withValues(alpha: 0.65),
              width: 1.4,
            ),
          ),
          child: TextField(
            controller: _textController,
            onChanged: _onTextChanged,
            maxLines: 8,
            minLines: 8,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
              fontFamily: 'Noto Sans KR',
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '예: 실수하더라도 누구나 그럴 수 있고, 나는 충분히 다시 해볼 수 있어요.',
              hintStyle: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF8AA0B4),
                fontWeight: FontWeight.w400,
                fontFamily: 'Noto Sans KR',
              ),
              isCollapsed: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _goNext() {
    FocusScope.of(context).unfocus();
    final value = _textController.text.trim();

    if (value.isEmpty) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => Week3VisualScreen(
              sessionId: widget.sessionId,
              previousChips: widget.previousChips,
              alternativeChips: [value],
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ApplyDoubleCard(
      appBarTitle: 'Self Talk',
      topChild: _buildTopPanel(),
      middleBannerText: '아래 입력창에 떠오르는 생각을 자유롭게 적어보세요.',
      bottomChild: _buildBottomPanel(),
      onBack: () => Navigator.pop(context),

      // ✅ 텍스트가 있을 때만 다음 버튼 활성화
      onNext: _inputText.isNotEmpty ? _goNext : null,

      // 3주차 느낌 맞춰서 하단 패널만 살짝 민트
      btmcardColor: const Color(0xFF7DD9E8).withValues(alpha: 0.25),
    );
  }
}
