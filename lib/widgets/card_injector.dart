// card_injector.dart
import 'package:gad_app_team/utils/text_line_material.dart';

/// 🩵 카드 스타일을 통일하고, 기능 코드와 분리하기 위한 디자인 래퍼 위젯.
/// 기능은 외부에서 child 로 전달받음.
class CardInjector extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final double borderRadius;
  final double elevation;
  final bool outlined;
  final Color outlineColor;
  final double outlineWidth;

  const CardInjector({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    this.margin,
    this.backgroundColor = const Color(0xFFEFF6FF), // 은은한 하늘색 배경
    this.borderRadius = 20,
    this.elevation = 2,
    this.outlined = true,
    this.outlineColor = const Color(0xFFBBD9FF),
    this.outlineWidth = 1.4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 10),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            outlined
                ? Border.all(color: outlineColor, width: outlineWidth)
                : null,
        boxShadow:
            elevation > 0
                ? [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: elevation,
                    offset: const Offset(0, 1),
                  ),
                ]
                : [],
      ),
      child: child,
    );
  }
}
