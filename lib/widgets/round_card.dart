import 'package:gad_app_team/utils/text_line_material.dart';

/// 단순한 둥근 모서리와 그림자 효과를 가진 카드 위젯입니다.
/// (기존 Notebook-style 기능인 스프링과 스텁이 제거되었습니다.)
class RoundCard extends StatelessWidget { // 💡 클래스 이름을 RoundCard로 변경
  /// Main content inside the rounded page card.
  final Widget child;

  /// Inner padding of the page card.
  final EdgeInsetsGeometry? padding;

  /// Outer margin of the page card (to separate from neighbors).
  final EdgeInsetsGeometry? margin;

  /// Page background color.
  final Color backgroundColor;

  /// Corner radius of the page card.
  final double cornerRadius;

  /// Shadow opacity (0~1). Increase for a stronger lift.
  final double shadowOpacity;

  const RoundCard({ // 💡 생성자 이름도 RoundCard로 변경
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor = Colors.white,
    this.cornerRadius = 20,
    this.shadowOpacity = 0.10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(12),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: 12,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}