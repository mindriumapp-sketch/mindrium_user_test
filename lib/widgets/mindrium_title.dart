// lib/widgets/mindrium_title.dart
import 'package:gad_app_team/utils/text_line_material.dart';
import 'dart:math' as math;

/// 🫧 3D Mindrium 타이틀 + 버블 효과 (서브텍스트 없음)
/// - twoLine: true → "MIND\nRIUM" (샘플처럼 두 줄)
/// - scale   : 너비 1080 기준 배율 (width/1080을 그대로 넘기면 편함)
/// - height  : 위젯 고정 높이 (버블 애니메이션 공간)
class MindriumTitle extends StatefulWidget {
  final double scale;
  final bool twoLine;
  final double height;
  final int bubbleCount;

  const MindriumTitle({
    super.key,
    this.scale = 1.0,
    this.twoLine = false,     // 기본 한 줄
    this.height = 320,        // ↑ 더 넓은 타이틀 영역
    this.bubbleCount = 20,    // ↑ 더 많은 버블
  });


  @override
  State<MindriumTitle> createState() => _MindriumTitleState();
}

class _MindriumTitleState extends State<MindriumTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;

    return SizedBox(
      height: widget.height * s,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;

          return Stack(
            alignment: Alignment.center,
            children: [
              // 🫧 Floating bubbles (HTML .floating-bubble 느낌)
              ...List.generate(widget.bubbleCount, (i) {
                // 좌표/크기/속도 랜덤스러운 분포
                final left = (i + 1) / (widget.bubbleCount + 1);      // 0~1 균등 분포
                final base = 26.0 + 22.0 * ((i % 7) / 6.0);           // 26 ~ 48px
                final size = (base + 4 * math.sin(i)).clamp(26.0, 52.0) * s;

                final durSec = 6 + (i % 5);                            // 6~10초
                final delay = (i % 12) * 0.08;                         // 지연

                return _Bubble(
                  controller: _ctrl,
                  areaWidth: w,
                  areaHeight: h,
                  leftFactor: left,
                  size: size,
                  durationSec: durSec,
                  delay: delay,
                );
              }),

              // 🔤 3D 엠보싱 Mindrium 텍스트
              _Mindrium3DText(
                text: 'MINDRIUM',
                scale: s,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 🫧 개별 버블
class _Bubble extends StatelessWidget {
  final AnimationController controller;
  final double areaWidth;
  final double areaHeight;
  final double leftFactor; // 0~1
  final double size;
  final int durationSec;
  final double delay;

  const _Bubble({
    required this.controller,
    required this.areaWidth,
    required this.areaHeight,
    required this.leftFactor,
    required this.size,
    required this.durationSec,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final speedNorm = controller.value / (8 / durationSec);
        final t = (speedNorm + delay) % 1.0;

        // 아래→위
        final y = (1 - t) * (areaHeight + size * 2) - size;

        // 좌우 드리프트 더 크게 + S-curve
        final amp = 40.0; // ↑
        final sCurve = math.sin(2 * math.pi * t) * 0.5 + 0.5; // 0→1→0
        final x = leftFactor * areaWidth + (sCurve * amp) - (amp / 2);

        // 숨쉬는 스케일
        final scale = 0.9 + 0.12 * math.sin(2 * math.pi * t);

        // 위로 갈수록 투명
        final opacity = (t < 0.85 ? (0.7 + 0.2 * t) : (1 - t) * 3.5).clamp(0.0, 1.0);

        return Positioned(
          bottom: y,
          left: x,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // 중앙 하이라이트
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.35),
                    radius: 0.9,
                    colors: [
                      Color.fromARGB(235, 255, 255, 255),
                      Color.fromARGB(90, 255, 255, 255),
                    ],
                  ),
                  // 유리 림
                  border: Border.all(
                    color: Colors.white.withOpacity(0.65),
                    width: (size / 18).clamp(0.9, 2.2),
                  ),
                  // 외곽 글로우
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.35),
                      blurRadius: (size * 0.75).clamp(10.0, 26.0),
                      spreadRadius: (size * 0.06).clamp(0.6, 2.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


/// 🔤 텍스트 레이어 스택으로 3D/엠보싱 구현
class _Mindrium3DText extends StatelessWidget {
  final String text;
  final double scale;

  const _Mindrium3DText({
    required this.text,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final fs = 72 * s; // HTML의 72px 기준

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1) 바닥 긴 그림자(부드러운 드롭 섀도)
        _shadowText(fs, const Offset(0, 12), 18 * s, Colors.black.withOpacity(0.25)),

        // 2) 익스트루전(두께감) 레이어 — 살짝 어두운 청록을 여러 겹
        for (int i = 6; i >= 1; i--)
          Positioned(
            left: i * 1.0 * s,
            top:  i * 1.2 * s,
            child: _fillText(
              fs,
              const Color(0xFF2B7FA0), // 청록 그림자색
              opacity: 0.22 + i * 0.08,
            ),
          ),

        // 3) 외곽선(스트로크)로 엣지 선명도 확보
        _strokeText(fs, 6 * s, const Color(0xFF2E8FB2)),

        // 4) 좌상단 하이라이트(빛 받은 엣지)
        Positioned(
          left: -2.0 * s,
          top:  -2.0 * s,
          child: _fillText(fs, Colors.white, opacity: 0.55),
        ),

        // 5) 본문 그라데이션(상: 밝은 하늘, 하: 시안)
        _gradientFillText(
          fs,
          from: const Color(0xFFB8EBFF),
          to:   const Color(0xFF7DD3F0),
        ),

        // 6) 짧은 내림 그림자 스택(HTML main-title의 text-shadow 3단)
        _shadowText(fs, const Offset(0, 2), 0, const Color(0xFF5AB8D8)),
        _shadowText(fs, const Offset(0, 4), 0, const Color(0xFF3F9EC0)),
        _shadowText(fs, const Offset(0, 6), 0, const Color(0xFF2684A8)),
      ],
    );
  }

  // Helpers for layered text

  Widget _strokeText(double fontSize, double strokeWidth, Color strokeColor) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: 4 * scale,
        height: 1.0,
        fontSize: fontSize,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = strokeColor,
      ),
    );
  }

  Widget _gradientFillText(double fontSize, {required Color from, required Color to}) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB8EBFF), Color(0xFF7DD3F0)],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          letterSpacing: 4 * scale,
          height: 1.0,
          fontSize: fontSize,
          color: Colors.white, // ShaderMask로 대체됨
        ),
      ),
    );
  }

  Widget _fillText(double fontSize, Color color, {double opacity = 1.0}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: 4 * scale,
        height: 1.0,
        fontSize: fontSize,
        color: color.withOpacity(opacity),
      ),
    );
  }

  Widget _shadowText(double fontSize, Offset offset, double blur, Color color) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: 4 * scale,
        height: 1.0,
        fontSize: fontSize,
        color: Colors.transparent,
        shadows: [Shadow(offset: offset * scale, blurRadius: blur, color: color)],
      ),
    );
  }
}
