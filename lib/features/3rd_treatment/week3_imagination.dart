import 'package:gad_app_team/utils/text_line_material.dart';
import 'package:gad_app_team/features/3rd_treatment/week3_alternative_thoughts.dart';

// ⭐ 더블 카드 레이아웃
import 'package:gad_app_team/widgets/top_btm_card.dart';

class Week3ImaginationScreen extends StatefulWidget {
  final String? sessionId;

  const Week3ImaginationScreen({super.key, required this.sessionId});

  @override
  State<Week3ImaginationScreen> createState() => _Week3ImaginationScreenState();
}

class _Week3ImaginationScreenState extends State<Week3ImaginationScreen> {
  final TextEditingController _textController = TextEditingController();
  String _inputText = '';

  void _onTextChanged(String value) {
    setState(() => _inputText = value.trim());
  }

  // ───────── 상단 카드 내용 ─────────
  Widget _buildTopPanel() {
    return SizedBox(
      height: 150, // 5주차 화면과 높이 맞춰서 정사이즈
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            '불안하면 어떤 일이 일어날까요?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF263C69),
              fontFamily: 'Noto Sans KR',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            '불안할 때 떠오르는 생각이나 걱정되는 부분들을 편하게 적어보세요.',
            style: TextStyle(
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
              hintText: '예: 발표 중에 말을 더듬어서 사람들이 이상하게 볼까 봐 걱정돼요.',
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
            (_, __, ___) => Week3AlternativeThoughtsScreen(
              sessionId: widget.sessionId,
              previousChips: [value],
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
      panelsGap: 0,
      height: 120,
      topPadding: 0,
      // 가운데 말풍선 텍스트
      middleBannerText: '아래 입력창에 떠오르는 생각을 자유롭게 적어보세요.',
      bottomChild: _buildBottomPanel(),
      onBack: () => Navigator.pop(context),

      // ✅ 칩이 없으면 onNext를 null로 넘겨서 버튼 비활성화
      onNext: _inputText.isNotEmpty ? _goNext : null,

      // 3주차 원래 하단 민트 느낌
      btmcardColor: const Color(0xFF7DD9E8).withValues(alpha: 0.25),
    );
  }
}
