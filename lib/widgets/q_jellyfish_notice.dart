import 'package:gad_app_team/utils/text_line_material.dart';

class JellyfishNotice extends StatelessWidget {
  final String? feedback;
  final Color? feedbackColor;

  const JellyfishNotice({
    super.key,
    this.feedback,
    this.feedbackColor,
  });

  @override
  Widget build(BuildContext context) {
    // 🧩 설정값
    const double containerHeight = 120; // 전체 고정 높이 (버튼 안 흔들림)
    const double jellySize = 85.0;
    const double tailSize = 16.0; // 꼬리 크기

    final String text = feedback ??
        '화면에 보이는 생각이 어떤 생각인지 선택한 후 다음 버튼을 눌러주세요.';

    final Color effectiveTextColor =
    feedback != null
        ? (feedbackColor ?? const Color(0xFF356D91))
        : const Color(0xFF666666);

    return SizedBox(
      height: containerHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🪼 해파리 이미지
          SizedBox(
            width: jellySize,
            height: jellySize,
            child: Image.asset(
              'assets/image/jellyfish.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 4),

          // 💬 말풍선 + 꼬리
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // ✅ 말풍선 본체 먼저 배치
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 180,
                    minHeight: 50,
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          text,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: effectiveTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ 꼬리를 나중에 배치하여 위로 올라오게 함
                Positioned(
                  left: -tailSize + 2,
                  child: CustomPaint(
                    size: const Size(tailSize, tailSize),
                    painter: _LeftTailPainter(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🩵 왼쪽 삼각형 꼬리 (그림자 포함)
class _LeftTailPainter extends CustomPainter {
  final Color color;
  _LeftTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..close();

    // 부드러운 그림자
    canvas.drawShadow(path, Colors.black.withOpacity(0.1), 2.0, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
