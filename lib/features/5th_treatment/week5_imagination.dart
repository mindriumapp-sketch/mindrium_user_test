// lib/features/5th_treatment/week5_imagination.dart
import 'package:gad_app_team/utils/text_line_material.dart';

// ✅ 공용 레이아웃 & 칩 에디터
import 'package:gad_app_team/widgets/top_btm_card.dart';   // ApplyDoubleCard

// 다음 화면 (기존 로직 유지)
import 'week5_confront_anxiety.dart';

class Week5ImaginationScreen extends StatefulWidget {
  final String? sessionId;
  final List<Map<String, dynamic>>? quizResults;
  final int? correctCount;

  const Week5ImaginationScreen({
    super.key,
    required this.sessionId,
    this.quizResults,
    this.correctCount,
  });

  @override
  State<Week5ImaginationScreen> createState() => _Week5ImaginationScreenState();
}

class _Week5ImaginationScreenState extends State<Week5ImaginationScreen> {
  final TextEditingController _textController = TextEditingController();
  String _inputText = '';

  void _onTextChanged(String value) {
    setState(() => _inputText = value.trim());
  }

  // ─────────────────── 상단 패널 ───────────────────
  Widget _buildTopPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        const Text(
          '불안하면 어떤 행동을 할까요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF263C69),
            fontFamily: 'Noto Sans KR',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          '불안할 때 보통 어떤 행동을 하는지 자유롭게 적어보세요.',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w200,
            height: 1.45,
            color: Colors.black87,
            fontFamily: 'Noto Sans KR',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

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
              hintText: '예: 불안한 자리에 가면 말을 아끼고 빨리 끝나기만 바라게 돼요.',
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
        pageBuilder: (_, __, ___) => Week5ConfrontAnxietyScreen(
          sessionId: widget.sessionId,
          previousChips: [value],
          quizResults: widget.quizResults,
          correctCount: widget.correctCount,
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ApplyDoubleCard(
        appBarTitle: '불안 직면 VS 회피',

        // ◀◀ 뒤로/다음 (기존 흐름 유지)
        onBack: () => Navigator.pop(context),
        onNext: _inputText.isNotEmpty ? _goNext : null,

        // 레이아웃 옵션
        pagePadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        panelsGap: 16,
        panelRadius: 20,
        panelPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        maxWidth: 980,

        // 패널 사이 말풍선(안내)
        middleNoticeText: '아래 입력창에 떠오르는 행동을 자유롭게 적어보세요.',

        // 패널 색상(하단은 살짝 톤을 주어 입력영역 강조)
        topcardColor: Colors.white.withValues(alpha: 0.96),
        btmcardColor: const Color(0xFF7DD9E8).withValues(alpha: 0.35),

        // 실제 패널들
        topChild: _buildTopPanel(),
        bottomChild: _buildBottomPanel(),
      ),
    );
  }
}
