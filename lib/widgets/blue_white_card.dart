import 'package:gad_app_team/utils/text_line_material.dart';

/// 뒤 파란 카드(outer) + 앞 컬러 카드(inner)가 겹치는 카드.
/// - 제목을 상단에서 살짝 띄우는 옵션(titleTopGap)
/// - 카드 세로를 여유롭게 쓰고 싶을 때 최소 높이(minHeight) 지원
class BlueWhiteCard extends StatelessWidget {
  final double maxWidth;
  final String title;
  final Widget child;

  /// 파란(뒤) 카드 색상
  final Color outerColor;

  /// 앞(안) 카드 배경색
  final Color innerColor;

  /// 모서리 반경
  final double outerRadius;
  final double innerRadius;

  /// 파란 카드를 얼마나 크게 보이게 확장할지 (음수 inset 효과)
  final EdgeInsets outerExpand;

  /// 앞 카드 내부 패딩
  final EdgeInsetsGeometry innerPadding;

  /// 구분선
  final Color dividerColor;
  final double dividerWidth;

  /// 제목을 상단에서 얼마나 띄울지
  final double titleTopGap;

  /// 카드 최소 높이 (여유 있게 세로 공간 확보)
  final double? minHeight;

  /// 제목 스타일(기본: Bold)
  final TextStyle? titleStyle;

  const BlueWhiteCard({
    super.key,
    required this.maxWidth,
    required this.title,
    required this.child,
    this.outerColor = const Color(0xFF89BFFB),
    this.innerColor = Colors.white,
    this.outerRadius = 22,
    this.innerRadius = 20,
    this.outerExpand = const EdgeInsets.fromLTRB(10, 12, 10, 18),
    this.innerPadding = const EdgeInsets.fromLTRB(20, 22, 20, 28),
    this.dividerColor = const Color(0xFFE5EEF9),
    this.dividerWidth = 220,
    this.titleTopGap = 20,
    this.minHeight,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 🔵 뒤 파란 카드 (살짝 크게)
          Positioned.fill(
            left: -outerExpand.left,
            right: -outerExpand.right,
            top: -outerExpand.top,
            bottom: -outerExpand.bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: outerColor,
                borderRadius: BorderRadius.circular(outerRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),

          // ⚪️/🎨 앞 카드
          Container(
            width: maxWidth,
            padding: innerPadding,
            constraints: BoxConstraints(
              minHeight: minHeight ?? 0, // 필요 시 세로 여유
            ),
            decoration: BoxDecoration(
              color: innerColor,
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: titleTopGap), // ⬆️ 제목 위 여백
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style:
                      titleStyle ??
                      const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900, // Bold
                        color: Color(0xFF224C78),
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1.5,
                  width: dividerWidth,
                  color: dividerColor,
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
